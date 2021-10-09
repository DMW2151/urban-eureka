---
title: Database Benchmarking - PostGIS Tileserver
author: Dustin Wilson
date: September 25, 2021
---

![](./images/sample_tiles.png)

The following document describes benchmarks comparing AWS Graviton2-backed instances and x86-backed instances for the purpose of serving dynamic tiles from a PostGIS database server. The specs of these tests may not be a perfect analogue for realistic tile generation, but they should shed light on the relative performance of several candidate database configurations.

From these tests I'd like to understand the performance benefit of hosting a PostGIS DB on a Graviton backed EC2 instance for this specific use case. I'd also like to evaluate the difference in performance between DBs hosted on NVME drives (offered by the `m6gd` family of instances) and standard `gp3` and `gp2` volumes.

---------------

## Results Summary

1. A PostGIS instance deployed on a `m6gd.large` offers better tile-serving performance compared to an equivalent x86 instance (`t3.large`). Testing tile-generation on a `m6gd.large` instance yielded 60% more tile requests/second for layers comprised of points and polygons.

2. There is minimal distinction in tile-serving performance between a DB running on ephemeral NVME or `gp3` volume. Given this fact, I will provision a `gp3` instance to host my DB instead of (dangerously) relying on ephemeral NVME storage from the `m6gd` family.

3. There is minimal distinction in tile-serving performance between the default PostGIS parameters and "optimized" parameters. These parameters may be geared for analytical, rather than transactional workloads. I will proceed with PostGIS suggested parameters, seems that they will do no harm during periods of light load and may boost performance under heavy load.
  
4. Loading OSM data to PostgreSQL is memory intensive. Performance is difficult to isolate because the process involves CPU, disk, and memory heavy components. In general, a `m6g.4xlarge` instance can load a small (3GB) sized OSM extract **3x** faster than a `m6g.large` instance. The greatest difference in performance came from the `CREATE INDEX` stages which ran **5x** faster on the larger instance. I'll use a 4XL spot instance to load the OSM data to PostgreSQL and dump it to a DB running on a more affordable instance.

5. Redis, while a peripheral element of this system, is still worth testing. When using large keys to simulate cached map tiles, Redis performed 1.5-2x faster on m6g relative to t3 instances.

---------------

## 0.1 System Setup

This test compares the following instances. Both are general purpose instances which provide a balance of compute, memory and networking resources.

### 0.1 Test Graviton and X86 Instances

| Instance                       | `m6gd.large`     |`t3.large`|
| ------------------------------ | ---------------- | -------- |
| vCPU                           | 2                | 2        |
| Memory (GiB)                   | 8                | 8        |
| Instance Storage (GIB)         | 1 x 118 NVMe SSD | EBS-Only |
| Network Bandwidth (Gbps)       | Up to 10         | n/a      |
| EBS Bandwidth (Mbps)           | Up to 4,750      | Up to 5  |
Table: Figure 0.1.1 - Instances Evaluated

Note, the `m6gd.large` also includes custom built AWS Graviton2 Processor with 64-bit Arm cores. The `t3.large` includes Up to 3.1 GHz Intel Xeon Platinum Processor and Intel AVX, Intel AVX2, Intel Turbo. Both instances are EBS optimized and offer enhanced networking, although our workload is most dependent on memory and disk performance.

### 0.2 PostgreSQL Software Version

Both instances (`m6gd` and `t3.large`) are running `psql (13.4 (Ubuntu 13.4-1.pgdg20.04+1))` installed via the following user-data script. A new database (`geospatial_core`) and user (`osm_worker`) were created for the tests.

Figure 0.2.1 - PostgreSQL Initialization

```{.bash .numberLines}
#!/bin/sh

# Add PostgreSQL Apt Repo
sudo sh -c 'echo "deb http://apt.postgresql.org/pub/repos/apt\
    $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list' &&\
    wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo apt-key add -

# Install PostgreSQL + PostGIS + Geospatial Utilities
sudo apt-get update &&\
sudo apt-get -y install \
    postgresql-13 \
    postgresql-client-13 \
    postgis postgresql-13-postgis-3 \
    gdal-bin \
    osm2pgsql &&\
sudo apt-get clean
```

## 1.0 - Benchmarking With PGBench - Basic Tests

The first series of tests uses a utility included with most PostgreSQL distributions called `pgbench`.

> pgbench is a simple program for running benchmark tests on PostgreSQL. It runs the same sequence of SQL commands over and over, possibly in multiple concurrent database sessions, and then calculates the average transaction rate (transactions per second).

Without any specific transaction specified, `pgbench` defaults to a series of very basic `SELECT`, `INSERT`, and `UPDATE` statements. To run this style of benchmarking, the following script was run against the postgreSQL/postGIS database on each ot the test instances.

Figure 1.0.1 - Basic PGbench Benchmarking

```{.bash .numberLines}
#! /bin/sh
pgbench -d geospatial_core -U osm_worker -i &&\
     pgbench -c 10 -j 2 -d geospatial_core -U osm_worker -t 10000
```

The test asks the database to use 2 threads (`-j`) to handle 10 clients (`-c`) running 10000 transactions (`-t`) each. The table below shows the results of tests run on an `m6gd` instance with the PostgreSQL data-directory located on `gp3`, `gp2`, and `NVME SSD` volumes and a `t3` instance using `gp3`.

For all tests, the default `gp3` volume configuration was used (3000 IOP/s, 125MB/s throughput). Given that `gp3` volumes are cheaper than `gp2` ([aws blog on gp2 and gp3](https://aws.amazon.com/blogs/storage/migrate-your-amazon-ebs-volumes-from-gp2-to-gp3-and-save-up-to-20-on-costs/)), `gp3` strictly dominates the `gp2` volume and I limited further testing with this volume type.


| Instance | PostgreSQL Data Directory | Tx/Second  |
|----------|---------------------------|------------|
| M6GD     | GP2                       |  620.65    |
| M6GD     | GP3                       |  885.33    |
| M6GD     | NVME                      |  862.93    |
| T3       | GP3                       |  732.00    |
Table: Figure 1.0.2 - Test Results - Basic pgbench Benchmarking

The results above suggest that the `gp3` and ephemeral NVME disk performed very similarly. Unsurprisingly, the `gp2` instance lagged behind by a great deal (25%) in transactions per second. The `gp3` instance attached to a `t3.large` gave middling results. It's unclear what specifically drives this difference. Unlike `dd`, `pgbench` is meant for testing PostgreSQL as a whole rather than raw disk performance. These tests could be augmented with results of `dd` to understand the raw disk performance of these options.

## 1.0 - Benchmarking With PGBench - Workload Specific Tests

While the default `pgbench` test easily runs hundreds of transactions per second, our workload will be more memory intensive than a series of `SELECT` statements. To benchmark specific workloads, `pgbench` allows the user to define test transactions to run against the database.


|     Name     |  Size   |
|--------------|---------|
| dela_line    | 33 MB   |
| dela_nodes   | 82 MB   |
| dela_point   | 4216 kB |
| dela_polygon | 34 MB   |
| dela_rels    | 2912 kB |
| dela_roads   | 4392 kB |
| dela_ways    | 52 MB   |
Table: Figure 1.1.1a -- Delaware Tables and Geospatial Indexes

|         Name         | Type  |    Table     |   Size   |
|----------------------|-------|--------------|----------|
| dela_line_way_idx    | index | dela_line    | 16 MB    |
| dela_point_way_idx   | index | dela_point   | 1992 kB  |
| dela_polygon_way_idx | index | dela_polygon | 10024 kB |
| dela_roads_way_idx   | index | dela_roads   | 1312 kB  |
Table: Figure 1.1.1b -- Delaware Tables and Geospatial Indexes

The query below generates 2 random points in the bounding box of the state of Delaware. From there, the query creates an envelope from those points, [segments](https://postgis.net/docs/ST_Segmentize.html) and [simplifies](https://postgis.net/docs/ST_Simplify.html) all shapes in that envelope, and then [creates a tile](https://postgis.net/docs/ST_AsMVTGeom.html) to return to the user. In a real query, the CTE to generate `pts` would not exist, instead our API would pass along the points of the envelope to use. I suspect this CTE has minimal effect on the end results of the test.

Figure 1.1.2 -- Sample Tile Generation Query (`de_tile_bench.sql`)

```{.sql .numberLines}
WITH pts AS (
    SELECT st_setsrid(
        ST_GeneratePoints(
            st_geomfromtext(
                'POLYGON ((
                    -76.16379349 38.29608890, -76.16379349 39.86611630,
                    -74.95903281 39.86611630, -74.95903281 38.29608890, -76.16379349 38.29608890
                ))'
            ) , 2
        ), 4326
    ) AS rdpts
)
SELECT ST_AsMVT(a.*) FROM (
    SELECT ST_AsMVTGeom(
        st_segmentize(
            st_simplify(
                st_transform(c2.way, 4326), 0.001, false
            ), 0.01
        ),
        st_transform(
            st_envelope(
                st_transform(pts.rdpts, 3857)
            ), 4326
        ),
        extent=>4096,
        buffer=>256
    )
    FROM public.dela_polygon c2, pts
    WHERE c2.way && st_envelope(st_transform(pts.rdpts, 3857))
) a;
```

Figure 1.1.3 - Delaware Benchmarking Test

```{.bash .numberLines}
#! /bin/sh
sudo -su postgres pgbench -i &&\
    sudo -su postgres pgbench -c 10 -j 2 -t 1000 -U osm_worker -d geospatial_core -f de_tile_bench.sql
```

I performed these tests using the following instances and relations. It should be noted that `polygon` and `point` differ in size by a factor of 10, and the performance of aggregation on polygons may be distinctly different that on points. In all cases, `NVME` and `gp3` on `mg6d` performed very near identically, while the `T3` instance lagged behind again.

| Instance | PostgreSQL Data Directory | PostgreSQL Settings | Relation | Tx/Second |
|----------|---------------------------|---------------------| -------- |-----------|
| M6GD     | GP3                       | Basic               | point    | 74.309501 |
| M6GD     | NVME                      | Basic               | point    | 73.919339 |
| T3       | GP3                       | Basic               | point    | 46.489644 |
| M6GD     | GP3                       | Basic               | polygon  | 17.332670 |
| M6GD     | NVME                      | Basic               | polygon  | 17.252142 |
| T3       | GP3                       | Basic               | polygon  | 10.990216 |
Table: Figure 1.1.4 - Test Results - Delaware Benchmarking Test

I performed the same suite of tests from `1.1.4` again using a series of `GIS Optimized Parameters` suggested by the `osm2pgsql` and PostGIS documentation. The parameters used are displayed below in `1.1.5`. At this scale, these parameters provided no additional performance boost relative to PostGIS default parameters. This makes sense, as these parameters seemed to be for tuning a DB doing large-scale geospatial analytics.

Figure 1.1.5 - PostGIS documentation suggested parameters

```{.sql .numberLines}
ALTER SYSTEM SET shared_buffers TO '4GB';
ALTER SYSTEM SET work_mem TO '256MB';
ALTER SYSTEM SET maintenance_work_mem TO '10GB';
ALTER SYSTEM SET autovacuum_work_mem TO '2GB';
ALTER SYSTEM SET random_page_cost TO 1.0;
ALTER SYSTEM SET wal_level TO minimal;
ALTER SYSTEM SET full_page_writes TO off;
```

| Instance | PostgreSQL Data Directory | PostgreSQL Settings | Relation | Tx/Second |
|----------|---------------------------|---------------------| -------- |-----------|
| M6GD     | GP3                       | GIS                 | point    | 74.329485 |
| M6GD     | NVME                      | GIS                 | point    | 75.358891 |
| T3       | GP3                       | GIS                 | point    | 46.689258 |
| M6GD     | GP3                       | GIS                 | polygon  | 17.622211 |
| M6GD     | NVME                      | GIS                 | polygon  | 18.679260 |
| T3       | GP3                       | GIS                 | polygon  | No Test   |
Table: Figure 1.1.6 - Test Results - Delaware Benchmarking Test Using `GIS Optimized` Parameters

## 2.0 -  "Benchmarking" With OSM2PGSQL - Loading Alabama OSM Extract

The [osm2pgsql manual](https://osm2pgsql.org/doc/manual.html#tuning-the-postgresql-server) recommends specific hardware for ingesting OSM. In general, the recommendations boil down to the following:

* \>= 64GB RAM
* \>= 8 CPU
* Database hosted on NVME SSD

First, I considered using an RDS instance, however, RDS instances are significantly more expensive compared to self-hosting the same database server on the equivalent hardware in EC2. For example, the [AWS Pricing Calculator - RDS](https://calculator.aws/#/createCalculator/RDSPostgreSQL)gives an estimated cost of ~$260 for a 250GB single-AZ RDS instance hosted on `db.m6gd.xlarge` (2 VCPU + 16GB RAM). Compare this with the [AWS Pricing Calculator - EC2](https://calculator.aws/#/createCalculator/EC2) estimate of ~$140 for an `m6gd.xlarge` (4VCPU + 16 GB RAM) instance on EC2.

Figure 2.0.1/2.0.2 - db.m6gd.xlarge RDS vs EC2 Instance Cost

```bash
1 instance(s) x 0.318 USD hourly x 730 hours in a month = 232.1400 USD
250 GB per month x 0.115 USD x 1 instances = 28.75 USD (Storage Cost)

# Including 100GB of GP3 at 3000 IOPs && 125MB/s for incidental data
1 instances x 0.1808 USD x 730 hours in a month = 131.98 USD (monthly onDemand cost)
100 GB x 0.08 USD x 1 instances = 8.00 USD (EBS Storage Cost)
```

Obviously, there are consequences to choosing to host on EC2 vs. RDS. However, for this application these drawbacks were worth assuming that additional risk for the price. I wanted to consider using a spot instance for the initial load and then downgrading to a less powerful instance for serving regular traffic. The figures below compare the results of loading the Alabama OSM on `m6gd.large`, `m6gd.4xlarge`, and `t3.large` spot instances. This may be a bit small for a test to see the real performance benefit from the `m6gd.4xlarge` instance, but we see on the order of **2x** performance on ingestion and **5x** performance on index creation relative to the `m6gd.4xlarge` machine relative to the `m6gd.large` and `t3.large`

Figure 2.0.3 - Load Alabama Query

```{.bash .numberLines}
#! /bin/sh
osm2pgsql \
    --create \
    -U osm_worker\
    -d geospatial_core \
    -H localhost\
    --cache 4096 \  ## 4096 on XXX.large, 16384 on m6gd.4xlarge
    --number-processes 2 \ ## 2 on XXX.large, 8 on m6gd.4xlarge
    --slim \
    --prefix=al \
    ~/osm/data/alabama-latest.osm.pbf
```

| Instance | Size    | PostgreSQL Data Directory | Point | Road | Line | Polygon |
|----------|---------|---------------------------|-------|------|------|---------|
| t3       | Large   | GP3                       |     9 |   16 |   41 |      43 |
| m6gd     | Large   | GP3                       |     6 |   11 |   54 |      73 |
| mg6d     | 4XLarge | GP3                       |     1 |    2 |   14 |      11 |
Table: Figure 2.0.4 - OSM Index Creation Times By Layer - Alabama State Extract (seconds)

| Instance | Size    | PostgreSQL Data Directory | Node | Way | Relation |
|----------|---------|---------------------------|------|-----|----------|
| t3       | Large   | GP3                       |   27 |  26 |        4 |
| m6gd     | Large   | GP3                       |   45 |  20 |        3 |
| mg6d     | 4XLarge | GP3                       |   20 |  12 |        2 |
Table: Figure 2.0.5 - OSM Ingestion Times By Object Type - Alabama State Extract (seconds)


## A.1 - Additional Comment on Delaware Benchmarking

One may argue that the tests performed in `1.0` are not representative of a real workload due to the small size of the test data. On the contrary, the GIST indexing that PostGIS uses for intersecting shapes scales very well. As the index size increases 10x, 100x, etc, I would not worry about the ability to efficiently access points in (relatively small) user requested regions.

The bulk of the tile-generation process is contingent on the other aspects of creating a tile, e.g. segmenting, simplifying, and clipping shapes, transforming projections, and aggregating the response in MVT format. This test captures all the core functionality the DB will need to handle for to create a tile.

As further proof of this fact consider the results of the `EXPLAIN ANALYZE` in `Figure A.1.1`. This figure shows the result of one call of `de_test_bench.sql`. Notice that the indexing to locate relevant features took <10ms, and the aggregation to MVT tile took >50ms.

Figure A.1.1 - `EXPLAIN ANALYZE` - sample execution of Delaware Test Query

```{.sql .numberLines}
Aggregate (actual time=62.420..62.421 rows=1 loops=1)
  ->  Nested Loop (actual time=0.478..10.051 rows=3373 loops=1)
        ->  Seq Scan on pts (actual time=0.043..0.045 rows=1 loops=1)
        ->  Index Scan using dela_polygon_way_idx on dela_polygon c2 (actual time=0.338..8.549 rows=3373 loops=1)
              Index Cond: (way && st_envelope(st_transform(pts.rdpts, 3857)))

Planning Time: 0.419 ms
Execution Time: 62.581 ms
```

In `Figure A.1.3`, I repeat a query like `de_test_bench.sql`, but instead use the OSM extract of New Jersey rather than Delaware. New Jersey is a slightly larger, but much denser state and has about 10x the OSM data as Delaware.

|    Name    | Type  |  Size  |
|------------|-------|--------|
| nj_line    | table | 237 MB |
| nj_nodes   | table | 596 MB |
| nj_point   | table | 32 MB  |
| nj_polygon | table | 269 MB |
| nj_rels    | table | 11 MB  |
| nj_roads   | table | 30 MB  |
| nj_ways    | table | 379 MB |
Table: Figure A.1.2a -- New Jersey Tables and Geospatial Indexes

|        Name        | Type  |   Table    |  Size   |
|--------------------|-------|------------|---------|
| nj_line_way_idx    | index | nj_line    | 111 MB  |
| nj_point_way_idx   | index | nj_point   | 13 MB   |
| nj_polygon_way_idx | index | nj_polygon | 125 MB  |
| nj_roads_way_idx   | index | nj_roads   | 8712 kB |
Table: Figure A.1.2b -- New Jersey Tables and Geospatial Indexes

Analyzing `nj_test_bench.sql` yields the following results, notice that even with more data to index scan through, the index scan still occupies <20% of the total tile-generation time. It seems the limiting factor in this type of query is aggregating the returned polygons to an MVT tile (regardless of how many points are returned), not locating the shapes within an area.

As long as the return set is not too large (e.g. the application isn't trying to query all polygons in a 100km<sup>2</sup> area), tile-generation will stay fast.

Figure A.1.3 - `EXPLAIN ANALYZE` - Sample Execution of NJ Test Query - Querying Entire State

```{.sql .numberLines}
Aggregate (actual time=371.264..371.265 rows=1 loops=1)
  ->  Nested Loop (actual time=0.854..51.523 rows=20384 loops=1)
        ->  Seq Scan on pts (actual time=0.013..0.014 rows=1 loops=1)
        ->  Index Scan using nj_polygon_way_idx on nj_polygon c2 (actual time=0.818..43.408 rows=20384 loops=1)
              Index Cond: (way && st_envelope(st_transform(pts.rdpts, 3857)))

Planning Time: 0.229 ms
Execution Time: 372.143 ms
```

## A.2 - A Bonus Test - Redis

Redis is very fast, but the performance of Redis can be inflated by these tests. Fetching data from the cache, albeit 2x as slow on x86 instances, is still very fast. The bulk of the performance bottleneck in my system is PostGIS, but I also performed some Redis benchmarks to see what affect architecture has on setting and gettinng medium-large sized (32kb) keys.

```{.bash .numberLines}
## Setup
sudo apt-get update &&\
    apt-get install -y redis-server

## Test
redis-benchmark -t set,get -n 100000 -d 32000
```

Using ARM instances:

```{.bash .numberLines}
====== GET ======
  100000 requests completed in 1.68 seconds
  50 parallel clients
  32000 bytes payload
  keep alive: 1

99.83% <= 1 milliseconds
100.00% <= 1 milliseconds
59347.18 requests per second

====== SET ======
  100000 requests completed in 1.31 seconds
  50 parallel clients
  32000 bytes payload
  keep alive: 1

99.98% <= 1 milliseconds
100.00% <= 1 milliseconds
76219.51 requests per second
```


Using X86 Instances:

```{.bash .numberLines}
====== SET ======
  100000 requests completed in 2.41 seconds
  50 parallel clients
  32000 bytes payload
  keep alive: 1

30.90% <= 1 milliseconds
99.62% <= 2 milliseconds
99.89% <= 3 milliseconds
99.91% <= 4 milliseconds
99.98% <= 5 milliseconds
99.98% <= 6 milliseconds
100.00% <= 6 milliseconds
41425.02 requests per second

====== GET ======
  100000 requests completed in 2.64 seconds
  50 parallel clients
  32000 bytes payload
  keep alive: 1

79.24% <= 1 milliseconds
99.95% <= 2 milliseconds
100.00% <= 2 milliseconds
37864.45 requests per second
```
