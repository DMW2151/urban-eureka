#! /bin/bash

# Download Sample Data...
#   - https://www.cybertec-postgresql.com/en/open-street-map-to-postgis-the-basics/
#   - https://download.geofabrik.de/north-america.html

# North America Latest (09/07/2021 - Approx 3.0 GB compressed) 
# Network is Not Good, throttled by geofab server - even on r6g.medium, abt. 15-20 MB/s ~> 3 min

sudo mkdir -p ~/osm/data/ &&\
    sudo wget https://download.geofabrik.de/north-america/us/alabama-latest.osm.pbf -P ~/osm/data/

osm2pgsql \
    --create \
    -U osm_worker\
    -d geospatial_core \
    -H localhost\
    --cache 4096 \
    --number-processes 8 \
    --slim \
    --prefix=tx \
    ~/osm/data/alabama-latest.osm.pbf

