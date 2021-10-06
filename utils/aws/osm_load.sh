#! /bin/bash

# Script is manually run on the OSM builder instance, gets data from the OSM mirror 
# and pushes over to the main DB

export DST_HOST=`(aws ssm get-parameters --names osm_pg__db_ip --region=us-east-1 | jq -r '.Parameters | first | .Value')`
export PGPASSWORD=`(aws ssm get-parameters --names osm_pg__worker_pwd --region=us-east-1 | jq -r '.Parameters | first | .Value')`

# Download to pgtx Disk
sudo mkdir -p ~/osm/data/ &&\
    sudo wget https://download.geofabrik.de/north-america-latest.osm.pbf -P ~/osm/data/ &&\
    sudo wget https://download.geofabrik.de/south-america-latest.osm.pbf -P ~/osm/data/ &&\
    sudo wget https://download.geofabrik.de/central-america-latest.osm.pbf -P ~/osm/data/


# Merge the files to a single file -> OSM does NOT like `append!`
sudo osmium merge /home/ubuntu/osm/data/central-america-latest.osm.pbf \
    /home/ubuntu/osm/data/south-america-latest.osm.pbf \
    /home/ubuntu/osm/data/north-america-latest.osm.pbf \
    -o ~/osm/data/western-hemisphere.osm.pbf

# RM base files 
rm ~/osm/data/south-america-latest.osm.pbf ~/osm/data/central-america-latest.osm.pbf ~/osm/data/north-america-latest.osm.pbf

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
    ~/osm/data/western-hemisphere.osm.pbf

# Push DB dump over to other DB's filesystem && terrminate this instance, the other instance can restore
# whenever with `pg_restore -Fd -j8 -h localhost -U osm_worker -d geospatial_core /tmp/osm`
sudo mkdir -p /home/ubuntu/osm/data/dump &&\
    sudo chmod 777 /home/ubuntu/osm/data/dump

time pg_dump -Fd -j8 -t *.osm_* -h localhost -U osm_worker -d geospatial_core -f ~/osm/data/dump &&\
    scp -r ~/osm/data/dump ubuntu@$DST_HOST:/tmp/osm/



