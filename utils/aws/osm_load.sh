#! /bin/bash

# Script is manually run on the OSM builder instance, gets data from the OSM mirror 
# and pushes over to the main DB

export SRC_HOST=`(aws ssm get-parameters --names osm_pg__builder_ip --region=us-east-1 | jq -r '.Parameters | first | .Value')`
export DST_HOST=`(aws ssm get-parameters --names osm_pg__db_ip --region=us-east-1 | jq -r '.Parameters | first | .Value')`
export PGPASSWORD=`(aws ssm get-parameters --names osm_pg__worker_pwd --region=us-east-1 | jq -r '.Parameters | first | .Value')`

# Download to pgtx Disk
sudo mkdir -p ~/osm/data/ &&\
    sudo wget https://download.geofabrik.de/north-america-latest.osm.pbf -P ~/osm/data/


# Write to DB disk
osm2pgsql \
    --create \
    -U osm_worker\
    -d geospatial_core \
    -H localhost \
    --cache=48000 \
    --number-processes 16 \
    --hstore \
    --slim \
    --prefix=osm\
    --output-pgsql-schema=osm\
    ~/osm/data/north-america-latest.osm.pbf

# Push DB dump over to other DB's filesystem && terrminate this instance, the other instance can restore
# whenever with `pg_restore -Fd -j8 -h localhost -U osm_worker -d geospatial_core /tmp/osm`
time pg_dump -Fd -j8 -t public.us* -h localhost -U osm_worker -d geospatial_core -f ~/osm/dump &&\
    scp -r ~/osm/dump ubuntu@$DST_HOST:/tmp/osm/ 



