#! /bin/bash

# Download Sample Data [see links below]
#   - https://www.cybertec-postgresql.com/en/open-street-map-to-postgis-the-basics/
#   - https://download.geofabrik.de/north-america.html

export PGPASSWORD=`(aws ssm get-parameters --names osm_pg__worker_pwd --region=us-east-1 | jq -r '.Parameters | first | .Value')`

mkdir -p ~/osm/data/ &&\
    wget https://download.geofabrik.de/north-america/us/delaware-latest.osm.pbf -P ~/osm/data/


osm2pgsql \
    --create \
    -U osm_worker\
    -d geospatial_core \
    -H localhost \
    --slim \
    --output-pgsql-schema osm\
    --hstore \
    --prefix=osm \
    ~/osm/data/delaware-latest.osm.pbf
