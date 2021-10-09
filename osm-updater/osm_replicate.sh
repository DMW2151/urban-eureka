#! /bin/bash
set -x

# Connect to the OSM replication server and connects to the main DB, processes updates between the two
# services

# [DEV ONLY][WARN]: Host Based Auth on the DB allows for `trust` connections within private subnet; so no PGPASSWORD
# needed -> consider changing this for production

# Update the Database 
/osm2pgsql-replication init -vvv -d ${PG__DATABASE} -H ${PG__HOST} -P ${PG__PORT} -U ${PG__USER} --prefix=osm --server ${OSM__UPDATE_SERVER} &&\
    /osm2pgsql-replication update -vvv -d ${PG__DATABASE} -H ${PG__HOST} -P ${PG__PORT} -U ${PG__USER} --prefix=osm
