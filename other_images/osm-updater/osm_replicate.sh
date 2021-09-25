#! /bin/bash

# Update the Database
/home/ubuntu/1.4.1/scripts/osm2pgsql-replication init \
    --verbose \
    -d geospatial_core \
    -H localhost \
    -P 5432 \
    -U osm_worker \
    --prefix=de \
    --server http://download.geofabrik.de/north-america/us/delaware-updates

/home/ubuntu/1.4.1/scripts/osm2pgsql-replication update \
    --verbose \
    -d geospatial_core \
    -H localhost \
    -P 5432 \
    -U osm_worker \
    --prefix=de \
    --diff-file ~/osm/data/recent_change.osc.gz

# Refresh the Cache - Process the change file and locate the tiles...
gunzip /home/ubuntu/osm/data/recent_change.osc.gz