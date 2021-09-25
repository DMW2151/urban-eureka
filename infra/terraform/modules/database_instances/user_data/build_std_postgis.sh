#! /bin/sh

# On login, confirm all usr data scripts ran with the following:
#
# sudo -i -u postgres psql -U postgres -c "show data_directory"
#       data_directory       
# ---------------------------
#  /pgmnt/postgresql/13/main

# Add PostGIS repo to apt
sudo sh -c 'echo "deb http://apt.postgresql.org/pub/repos/apt\
    $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list' &&\
    wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo apt-key add -

# apt install PostgreSQL + PostGIS + Geospatial Utilities
sudo apt-get update &&\
sudo apt-get -y install \
    postgresql-13 \
    postgresql-client-13 \
    postgis postgresql-13-postgis-3 \
    gdal-bin \
    sysstat \
    awscli \
    jq \
    osm2pgsql &&\
sudo apt-get clean

# Initialize a PostGIS database with a non superuser user, `osm_worker` - get password from parameter store...
export OSM_WORKER_PGPASSWORD=`(aws ssm get-parameters --names osm_pg__worker_pwd --region=us-east-1 | jq '.Parameters | first | .Value')`

sudo -i -u postgres createuser osm_worker &&\
sudo -i -u postgres createdb geospatial_core -O postgres &&\
sudo -i -u postgres psql -d geospatial_core -U postgres -c "ALTER USER osm_worker WITH password '$OSM_WORKER_PGPASSWORD';"

# Add Extenstions for OSM2PGSQL
sudo -i -u postgres psql -d geospatial_core -c "CREATE EXTENSION postgis;" &&\
sudo -i -u postgres psql -d geospatial_core -c "CREATE EXTENSION hstore;"

# Set POSTGIS Optimized Parameters, see suggestions below. Note, those parameters
# refer to a slightly smaller instance than what we're working with, but are used
# as a guideline:
#
# [REFERENCE] 
# https://postgis.net/workshops/postgis-intro/tuning.html
# https://postgis.net/docs/manual-3.0/performance_tips.html
# https://osm2pgsql.org/doc/manual.html#tuning-the-postgresql-server

echo """
    ALTER SYSTEM SET shared_buffers TO '4GB';
    ALTER SYSTEM SET work_mem TO '256MB';
    ALTER SYSTEM SET maintenance_work_mem TO '10GB';
    ALTER SYSTEM SET autovacuum_work_mem TO '2GB';
    ALTER SYSTEM SET random_page_cost TO 1.0;
    ALTER SYSTEM SET wal_level TO minimal;
    ALTER SYSTEM SET full_page_writes TO off;
    ALTER SYSTEM SET listen_addresses TO '*';
""" > ./postgis_system_settings.sql

# Allow connections to `geospatial-core` from any address within the VPC by
# adding the following line to the Host Based Auth file...
sudo bash -c 'echo "host    geospatial_core     osm_worker     10.0.0.0/16   trust" >>  /etc/postgresql/13/main/pg_hba.conf'

# ...And put rule to allow local connections as first rule under 'local' section
sudo sed -ie '/^# "local"/a local      geospatial_core     osm_worker        md5' /etc/postgresql/13/main/pg_hba.conf

# Add new System Settings and reload the db server's settings
sudo -i -u postgres psql -d geospatial_core < postgis_system_settings.sql &&\
sudo -i -u postgres psql -c "SELECT pg_reload_conf();" &&\