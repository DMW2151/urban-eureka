#! /bin/bash

# Download Sample Data...
#   - https://www.cybertec-postgresql.com/en/open-street-map-to-postgis-the-basics/
#   - https://download.geofabrik.de/north-america.html


export SRC_HOST=`(aws ssm get-parameters --names osm_pg__builder_ip --region=us-east-1 | jq -r '.Parameters | first | .Value')`
export DST_HOST=`(aws ssm get-parameters --names osm_pg__db_ip --region=us-east-1 | jq -r '.Parameters | first | .Value')`
export PGPASSWORD=`(aws ssm get-parameters --names osm_pg__worker_pwd --region=us-east-1 | jq -r '.Parameters | first | .Value')`

# Download to pgtx Disk
sudo mkdir -p ~/osm/data/ &&\
    sudo wget https://download.geofabrik.de/north-america/us-latest.osm.pbf -P ~/osm/data/

# Write to DB on NVME disk
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
    ~/osm/data/us-latest.osm.pbf

# push over to other db
time pg_dump -Fd -j8 -t public.us* -h localhost -U osm_worker -d geospatial_core -f ~/osm/dump &&\
    scp -r ~/osm/dump ubuntu@$DST_HOST:/tmp/osm/ 

# And then after shutting down the machine
# time pg_restore -Fd -j8 -h localhost -U osm_worker -d geospatial_core /tmp/osm
