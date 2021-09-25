# Database Benchmarking

The following document describes benchmarks comparing Graviton2-backed instances and x86-backed instances for the purpose of serving dynamic tiles from a PostGIS database server. The specs of these tests may not be a perfect analogue for realistic tiles, but they should shed light on the relative performance of several candidate database configurations.

## Hardware
This test compares the following instances. Both are general purpose instances which provide a balance of compute, memory and networking resources.

### Test Graviton Instance

| Instance                       | `m6gd.large`*    |`t3.large`|
| ------------------------------ | ---------------- | -------- |
| vCPU                           | 2                | 2        |
| Memory (GiB)                   | 8                | 8        |
| Instance Storage (GIB)         | 1 x 118 NVMe SSD | EBS-Only |
| Network Bandwidth (Gbps)       | Up to 10         | n/a      |
| EBS Bandwidth (Mbps)           | Up to 4,750      | Up to 5  |

* Note, The `m6gd.large` also includes custom built AWS Graviton2 Processor with 64-bit Arm cores. The `t3.large` includes Up to 3.1 GHz Intel Xeon Platinum Processor and Intel AVX, Intel AVX2, Intel Turbo. Both instances are EBS optimized and offer enhanced networking.

## PostgreSQL Software Version

Both instances are running `psql (13.4 (Ubuntu 13.4-1.pgdg20.04+1))`, installed via the following user-data scripts. A new database (`geospatial_core`) and user (`osm_worker`) were created for the tests.

```bash
#! /bin/sh

# Add PostgreSQL Apt Repo
sudo sh -c 'echo "deb http,//apt.postgresql.org/pub/repos/apt\
    $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list' &&\
    wget --quiet -O - https,//www.postgresql.org/media/keys/ACCC4CF8.asc | sudo apt-key add -

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

## 0.1 - Benchmarking With PGBench - Max Transactions/Second

The first series of tests uses a utility included with most PostgreSQL distributions called `pgbench`.

> `pgbench` is a simple program for running benchmark tests on PostgreSQL. It runs the same sequence of SQL commands over and over, possibly in multiple concurrent database sessions, and then calculates the average transaction rate (transactions per second).

Without any specific transaction specified, `pgbench` defaults to a series of very basic `SELECT`, `INSERT`, and `UPDATE` statements. To run the most basic benchmarking, the following script was run against the local postgreSQL/postGIS database.

```bash
#! /bin/sh
pgbench -d geospatial_core -U osm_worker -i &&\
     pgbench -c 10 -j 2 -d geospatial_core -U osm_worker -t 10000
```

The table below shows the results of tests run on an `M6gd` instance with the PostgreSQL data-directory located on default `gp3`, `gp2`, and `NVME SSD` volumes. The `gp3` volume strictly dominates the `gp2` instance as the default IOPs (3000/s) and Throughput (125/MBps) are far superior to the `gp2`'s  (100/s, Undefined). 


| Instance | PostgreSQL Data Directory | Tx/Second  |
|----------|---------------------------|------------|
| M6GD     | GP2                       |  620.65    |
| M6GD     | GP3                       |  885.33    |
| M6GD     | NVME                      |  862.93    |
| T3       | GP3                       |  732.00    |

Compare the results from the ARM based instance above to the 

## Benchmarking With PGBench - Delaware Query TileGen

```SQL
-- Test 2 - Basic with the following params
ALTER SYSTEM SET shared_buffers TO '4GB';
ALTER SYSTEM SET work_mem TO '256MB';
ALTER SYSTEM SET maintenance_work_mem TO '10GB';
ALTER SYSTEM SET autovacuum_work_mem TO '2GB';
ALTER SYSTEM SET random_page_cost TO 1.0;
ALTER SYSTEM SET wal_level TO minimal;
ALTER SYSTEM SET full_page_writes TO off;
```

Set Optimized GIS Params

```bash
#! /bin/sh
sudo -i -u postgres psql -d geospatial_core < postgis_system_settings.sql &&\
    sudo -i -u postgres psql -c "SELECT pg_reload_conf();"
```

Reset Starter PostGIS Params

```bash
#! /bin/sh
sudo -i -u postgres psql -d geospatial_core -c "ALTER SYSTEM RESET ALL;"  &&\
    sudo -i -u postgres psql -c "SELECT pg_reload_conf();"
```

```bash
#! /bin/sh
sudo -su postgres pgbench -i &&\
    pgbench -c 10 -j 2 -t 1000 -U osm_worker -d geospatial_core -f de_tile_bench.sql
```

Zoom (9, 13)

```SQL
WITH pts AS (
    SELECT st_setsrid(
        ST_GeneratePoints(
            st_geomfromtext(
                'POLYGON ((`
                    -76.16379349 38.29608890,
                    -76.16379349 39.86611630,
                    -74.95903281 39.86611630,
                    -74.95903281 38.29608890,
                    -76.16379349 38.29608890
                `))'
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
    FROM public.main_polygon c2, pts
    WHERE c2.way && st_envelope(
        st_transform(pts.rdpts, 3857)
    )
) a;
```

**Point**

| Instance | PostgreSQL Data Directory | PostgreSQL Settings | Tx/Second |
|----------|---------------------------|---------------------|-----------|
| M6GD     | GP2                       | Basic               | 73.058869 |
| M6GD     | GP3                       | Basic               | 74.309501 |
| M6GD     | NVME                      | Basic               | 73.919339 |
| T3       | GP3                       | Basic               | 46.489644 |
| M6GD     | GP2                       | GIS                 | 74.155636 |
| M6GD     | GP3                       | GIS                 | 74.329485 |
| M6GD     | NVME                      | GIS                 | 75.358891 |
| T3       | GP3                       | GIS                 | 46.689258 |

**Polygon**

| Instance | PostgreSQL Data Directory | PostgreSQL Settings | Tx/Second |
|----------|---------------------------|---------------------|-----------|
| M6GD     | GP3                       | Basic               |  17.33267 |
| M6GD     | NVME                      | Basic               | 17.252142 |
| M6GD     | GP3                       | GIS                 | 17.622211 |
| M6GD     | NVME                      | GIS                 |  18.67926 |