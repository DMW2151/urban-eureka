# Needs to
# 1. Get Diffs
# 2. Run Diffs
# 3. Calculte tiles of diffs
# 4. log diffs to Service
# 5. Invalidate diffs in Redis

# NOTE: ON UBUNTU 21.04 - Version 1.4.1 is installed via apt, on 20.04 - needs to
# be build from source, which is painful...

# docker build --tag=local/monit .
FROM ubuntu:21.04

ARG DEBIAN_FRONTEND=noninteractive

RUN apt-get update && \
    apt-get install -y \ 
        make \
        cmake \
        g++ \
        libboost-dev \
        libboost-system-dev \
        libboost-filesystem-dev \
        libexpat1-dev zlib1g-dev \
        libbz2-dev \
        libpq-dev \
        libproj-dev \
        lua5.3 \
        liblua5.3-dev \
        pandoc \
        python3-pip \
        git &&\
    apt-get clean

RUN git clone https://github.com/openstreetmap/osm2pgsql.git 1.4.1

RUN mkdir build &&\
    cd build &&\
    cmake ./../1.4.1/ &&\
    make &&\
    make install

# Need Psycopg2..
RUN pip3 install psycopg2-binary osmium
