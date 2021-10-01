#! /bin/bash

# Download Sample Data [see links below]
#   - https://www.cybertec-postgresql.com/en/open-street-map-to-postgis-the-basics/
#   - https://download.geofabrik.de/north-america.html

mkdir -p ~/osm/data/ &&\
    wget https://download.geofabrik.de/north-america/us/texas-latest.osm.pbf -P ~/osm/data/


osm2pgsql \
    --create \
    -d numtots \
    -H localhost\
    --slim \
    --hstore \
    --output-pgsql-schema=delaware\
    --style=osm_init.lua \
    --prefix=de \
    ~/osm/data/delaware-latest.osm.pbf
