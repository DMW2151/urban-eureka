#! /bin/bash

# Download Sample Data...
#   - https://www.cybertec-postgresql.com/en/open-street-map-to-postgis-the-basics/
#   - https://download.geofabrik.de/north-america.html

# North America Latest (09/07/2021 - Approx 3.0 GB compressed) 
# Network is Not Good, throttled by geofab server - even on r6g.medium, abt. 15-20 MB/s ~> 3 min
export PGPASSWORD=`(aws ssm get-parameters --names osm_pg__worker_pwd --region=us-east-1 | jq '.Parameters | first | .Value')`

sudo mkdir -p ~/osm/data/ &&\
    sudo wget https://download.geofabrik.de/north-america/us/delaware-latest.osm.pbf -P ~/osm/data/

osm2pgsql \
    --create \
    -U osm_worker\
    -d geospatial_core \
    -H localhost\
    --cache 4192 \
    --slim \
    --prefix=main \
    ~/osm/data/south-carolina-latest.osm.pbf

