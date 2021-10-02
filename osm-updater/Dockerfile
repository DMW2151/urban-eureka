FROM ubuntu:20.04

ENV DEBIAN_FRONTEND noninteractive

COPY ./osm_replicate.sh /

RUN sudo apt-get update &&\
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
RUN git clone https://github.com/openstreetmap/osm2pgsql.git 1.4.1 &&\
    mkdir build &&\
    cd build &&\
    cmake ./../1.4.1/ &&\
    make &&\
    make install

RUN wget https://raw.githubusercontent.com/openstreetmap/osm2pgsql/master/scripts/osm2pgsql-replication &&\ 
    chmod +x osm2pgsql-replication &&\
    cp osm2pgsql-replication ~/ &&\
    chmod +x osm_replicate.sh

CMD ["./osm_replicate.sh"]