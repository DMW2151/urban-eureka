#! /bin/bash

# Download Sample Data...
#   - https://www.cybertec-postgresql.com/en/open-street-map-to-postgis-the-basics/
#   - https://download.geofabrik.de/north-america.html

# North America Latest (09/07/2021 - Approx 3.0 GB compressed) 
# Network is Not Good, throttled by geofab server - even on r6g.medium, abt. 15-20 MB/s ~> 3 min
export SRC_HOST=`(aws ssm get-parameters --names osm_pg__builder_ip --region=us-east-1 | jq -r '.Parameters | first | .Value')`
export DST_HOST=`(aws ssm get-parameters --names osm_pg__db_ip --region=us-east-1 | jq -r '.Parameters | first | .Value')`
export PGPASSWORD=`(aws ssm get-parameters --names osm_pg__worker_pwd --region=us-east-1 | jq '.Parameters | first | .Value')`

sudo mkdir -p /pgmnt/osm/data/ &&\
    sudo wget http://download.geofabrik.de/north-america/us-northeast-latest.osm.pbf -P /pgmnt/osm/data/

osm2pgsql \
    -U osm_worker\
    -d geospatial_core \
    -H localhost\
    --cache=16384\
    --hstore \
    --slim \
    --prefix=us_ne \
    /pgmnt/osm/data/us-northeast-latest.osm.pbf

# push over to other db
time pg_dump -Fc -Z6 -t public.us_ne* -h $SRC_HOST -U osm_worker -d geospatial_core -f /tmp/us-northeast-latest.dump &&\
    scp -r /tmp/us-northeast-latest.dump/ ubuntu@$DST_HOST:/tmp/us-northeast-latest.dump

# And then after shutting down the machine
# time pg_restore --clean -h localhost -U osm_worker -d geospatial_core < /tmp/pei_fc.dump
