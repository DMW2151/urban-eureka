#! /bin/sh

# User Data to initialize a new PostGIS instance on Ubuntu 20.04 using the
# instances NVME drive as a data directory...

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
    git &&\
sudo apt-get clean

# Manual Install for OSM2PGSQL Version 1.4.1, not available via apt on 20.04
git clone https://github.com/openstreetmap/osm2pgsql.git 1.4.1 &&\
    mkdir build &&\
    cd build &&\
    cmake ./../1.4.1/ &&\
    make &&\
    make install

# Need Psycopg2..
pip3 install psycopg2-binary osmium

# Initialize a PostGIS database with a non superuser user, `osm_worker` - get password from parameter store...
export OSM_WORKER_PGPASSWORD=`(aws ssm get-parameters --names osm_pg__worker_pwd --region=us-east-1 | jq -r '.Parameters | first | .Value')`


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
    ALTER SYSTEM SET shared_buffers TO '1GB';
    ALTER SYSTEM SET work_mem TO '64MB';
    ALTER SYSTEM SET maintenance_work_mem TO '10GB';
    
    ALTER SYSTEM SET random_page_cost TO 1.0;
    
    ALTER SYSTEM SET wal_level TO minimal;
    ALTER SYSTEM SET max_wal_senders = 0;
    ALTER SYSTEM SET max_wal_size = '10GB';
    
    ALTER SYSTEM SET checkpoint_completion_target = 0.9;

    ALTER SYSTEM SET effective_cache_size = '16GB';
    ALTER SYSTEM SET effective_io_concurrency = 500;

    ALTER SYSTEM SET fsync TO 'off';
    ALTER SYSTEM SET autovacuum  TO 'off';
    ALTER SYSTEM SET full_page_writes TO off;
    ALTER SYSTEM SET synchronous_commit = 'off';
    ALTER SYSTEM SET jit TO 'off';
    ALTER SYSTEM SET max_parallel_workers_per_gather TO 0;
""" > ./postgis_system_settings.sql

# Add new System Settings and stop the db server before changing the data directory...
sudo -i -u postgres psql -d geospatial_core < postgis_system_settings.sql &&\
sudo -i -u postgres psql -c "SELECT pg_reload_conf();" &&\
sudo systemctl stop postgresql
    
# # Mount /pgmnt to ephemeral NVME storage at `/dev/nvme1n1`
# sudo mkdir -p /pgtx &&\
# sudo mkfs -t xfs /dev/nvme1n1 &&\
# sudo mount /dev/nvme1n1 /pgtx 

# # # Sync the old data directory and the new...this is a fast operation b/c the db is fresh
# sudo rsync -av /var/lib/postgresql /pgtx

# Replace the data directory of the db server to use /pgmnt, the mount point for 
# the NVME drive by changing the value of `data_directory` in the system config
# sudo sed -i "s|^data_directory.*|data_directory='/pgtx/postgresql/13/main'|g" /etc/postgresql/13/main/postgresql.conf 

# Allow connections to `geospatial-core` from any address within the VPC by
# adding the following line to the Host Based Auth file...
sudo bash -c 'echo "host    geospatial_core     osm_worker     10.0.0.0/16   trust" >>  /etc/postgresql/13/main/pg_hba.conf'

# ...And put rule to allow local connections as first rule under 'local' section
sudo sed -ie '/^# "local"/a local      geospatial_core     osm_worker        md5' /etc/postgresql/13/main/pg_hba.conf

# # Reloading postgreSQL also reloads the config and finishes intializing the instance...
sudo systemctl start postgresql
