# Deployment Notes


## OSM Build process

One of the challenges of building a dynamic mapping platform is finding suitable hardware to build and serve the database. In this application I'm seeding my database with the Open Street Map extract of North America. This data is approx 150GB uncompressed and contains unique layers for all OSM nodes in the US, Mexico, and Canada. This data was provided by [geofabrik](https://geofabrik.de), a mirror of OSM.

In general, loading OSM extracts into PostgreSQL can be quite simple thanks to the open source tooling that's been built around the project. One of the most popular tools, `osm2pgsql`, however, has significant hardware requirements to enable planet or continent sized extracts. The [osm2pgsql manual](https://osm2pgsql.org/doc/manual.html#tuning-the-postgresql-server) recommends a machine with at least 32GB RAM to load a extract like mine (~11GB compressed) into a PostgreSQL database.

>As a rule of thumb you need at least as much main memory as the PBF file with the OSM data is large. So for a planet file you currently need at least 64 GB RAM. Osm2pgsql will not work with less than 2 GB RAM.

### OSM Bulk Ingest Architecture

### Database Selection

First, we need a database. the requirements on the database are not as stringent as on the OSM builder as the database simply must serve traffic, not perform large imports or analytical queries. In my case,an `M6gd` or `R6gd` instance seemed like the best choice for my workload. `M6g` instances are ideal for general purpose workloads and `R6g` are ideal for memory intensive workloads. From the outset, it is unclear if serving tile requests will require the additional memory of the `R6g` family. First, I considered using an RDS instance, however, RDS instances are significantly more expensive compared to self-hosting the same database server on the equivalent hardware in EC2.

For example, the [AWS Pricing Calculator - RDS](https://calculator.aws/#/createCalculator/RDSPostgreSQL) gives an estimated cost of ~$260 for a 250GB single-AZ RDS instance hosted on `db.m6gd.xlarge` (2 VCPU + 16GB RAM).

```bash
1 instance(s) x 0.318 USD hourly x 730 hours in a month = 232.1400 USD
250 GB per month x 0.115 USD x 1 instances = 28.75 USD (Storage Cost)
```

Compare this with the [AWS Pricing Calculator - EC2](https://calculator.aws/#/createCalculator/EC2) estimate of ~$140 for an `m6gd.xlarge` (4VCPU + 16 GB RAM) instance on EC2. Also remember, that the `m6gd` family of instances automatically come with ephemeral NVME storage. This instance gives ~1TB of NVME storage, which is more than satisfactory to hold my database, and offers the benefits of hosting on an SSD rather than `gp3`.

```bash
1 instances x 0.1808 USD x 730 hours in a month = 131.98 USD (monthly onDemand cost)
100 GB x 0.08 USD x 1 instances = 8.00 USD (EBS Storage Cost) # Including 100GB of GP3 at 3000 IOPs && 125MB/s for incidental data
```

Obviously, there are consequences to choosing to host on EC2 vs. RDS. However, for this application these drawbacks were well worth assuming the additional risk for. Multi-AZ replication, auto-backups, etc. are secondary given that we're not working with sensitive data and this is in fact a hackathon project.

[TODO] - Insert Tests

### OSM Builder Sidecar

Because building is significantly more resource intensive than just serving the database tiles, I decided to use two separate machines for building and serving the database. Building and serving tiles on the same machine is feasible, however, 32GB RAM instances are quite expensive and the profile of serving tile requests is quite different from loading OSM data. As mentioned before, The [osm2pgsql manual](https://osm2pgsql.org/doc/manual.html#tuning-the-postgresql-server) recommends specific hardware for ingesting OSM. In general, the recommendations boil down to the following.

- Machine w. >= 64GB RAM
- Database hosted on NVME SSD
- Machine w. >= 8 CPU

To get such a machine, I purchased a `m6gd.2xlarge` (only 32GB RAM, but it worked) on the spot market for a few hours, this allowed me to download, build, and dump an OSM extract to the main database instance without incurring the long-term costs of having such a machine up. Given more time, this job could be better automated with AWS Batch, Ansible, or even a Terraform `remote-exec` block, but since this is not intended to be a repeatable process, I left it as is and just SSH'd into the build instance to kick off the build job.

#### Notes on Build Process

With `osm2pgsql`, the build process can be very simple, in my case, it was calling a single command on the builder machine.

```bash
osm2pgsql \
    -U osm_worker\
    -d geospatial_core\
    -H localhost\
    --cache=16384\
    --slim \
    /pgmnt/osm/data/extract.osm.pbf
```

```bash
Reading in file: /pgmnt/osm/data/us-northeast-latest.osm.pbf
Using PBF parser.
Processing: Node(151275k 627.7k/s) Way(16815k 93.42k/s) Relation(152560 4237.78/s)  parse time: 457s
...
...
...
Stopped table: us_ne_ways in 441s
Osm2pgsql took 911s overall
node cache: stored: 151275987(100.00%), storage efficiency: 50.00% (dense blocks: 0, sparse nodes: 151275987), hit rate: 100.00%
```
