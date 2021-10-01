#! /bin/sh

# On login, confirm all usr data scripts ran with the following:

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
export OSM_WORKER_PGPASSWORD=`(aws ssm get-parameters --names osm_pg__worker_pwd --region=us-east-1 | jq -r '.Parameters | first | .Value')`
export OSM_READER_PGPASSWORD=`(aws ssm get-parameters --names osm_pg__worker_pwd --region=us-east-1 | jq -r '.Parameters | first | .Value')`

# Create a writer role with DB ownership...
sudo -i -u postgres createuser osm_worker &&\
sudo -i -u postgres createdb geospatial_core -O postgres &&\
sudo -i -u postgres psql -d geospatial_core -U postgres -c "ALTER USER osm_worker WITH password '$OSM_WORKER_PGPASSWORD';"

# Create a reader role with very minimal permissions...
sudo -i -u postgres createuser osm_reader &&\
    sudo -i -u postgres psql -d geospatial_core -U postgres -c "ALTER USER osm_reader WITH password '$OSM_READER_PGPASSWORD';"

sudo -i -u postgres psql -d geospatial_core -U postgres -c """
    CREATE SCHEMA osm; 
    GRANT USAGE ON SCHEMA osm TO osm_reader;
    GRANT SELECT ON ALL TABLES IN SCHEMA osm TO osm_reader;
    ALTER DEFAULT PRIVILEGES IN SCHEMA osm GRANT SELECT ON TABLES TO osm_reader;
"""



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
    ALTER SYSTEM SET shared_buffers TO '1GB';
    ALTER SYSTEM SET work_mem TO '64MB';
    
    ALTER SYSTEM SET random_page_cost TO 1.0;

    ALTER SYSTEM SET wal_level TO minimal;
    ALTER SYSTEM SET max_wal_senders = 0;

    ALTER SYSTEM SET listen_addresses TO '*';
""" > ./postgis_system_settings.sql

# Add new System Settings and reload the db server's settings
sudo -i -u postgres psql -d geospatial_core < postgis_system_settings.sql &&\
sudo -i -u postgres psql -c "SELECT pg_reload_conf();"

# Allow connections to `geospatial-core` from any address within the VPC by
# adding the following line to the Host Based Auth file...
sudo bash -c 'echo "host    geospatial_core     osm_worker     10.0.0.0/16   trust" >>  /etc/postgresql/13/main/pg_hba.conf'
sudo bash -c 'echo "host    geospatial_core     osm_reader     10.0.0.0/16   trust" >>  /etc/postgresql/13/main/pg_hba.conf'

# ...And put rule to allow local connections as first rule under 'local' section
sudo sed -ie '/^# "local"/a local      geospatial_core     osm_worker        md5' /etc/postgresql/13/main/pg_hba.conf

# NO RESTART!?
sudo systemctl stop postgresql &&\
sudo systemctl start postgresql
