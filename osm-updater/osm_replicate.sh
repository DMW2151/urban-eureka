#! /bin/bash
set -x

# Update the Database
~/osm2pgsql-replication init \
    --verbose \
    -d ${PG__DATABASE} \
    -H ${PG__HOST} \
    -P ${PG__PORT} \
    -U ${PG__USER} \
    --prefix=osm \
    --server ${OSM__UPDATE_SERVER}

~/osm2pgsql-replication update \
    --verbose \
    -d ${PG__DATABASE} \
    -H ${PG__HOST} \
    -P ${PG__PORT} \
    -U ${PG__USER} \
    --prefix=osm