FROM ubuntu:21.04

ENV DEBIAN_FRONTEND noninteractive

COPY ./osm_replicate.sh /

RUN  apt-get update &&\
     apt-get -y install jq awscli wget cmake build-essential libboost-dev libexpat1-dev zlib1g-dev libbz2-dev osm2pgsql

RUN  apt-get update &&\
     apt install -y python3-pip

RUN python3 -m pip install psycopg2-binary osmium

RUN wget https://raw.githubusercontent.com/openstreetmap/osm2pgsql/master/scripts/osm2pgsql-replication &&\ 
    chmod +x osm2pgsql-replication &&\
    chmod +x osm_replicate.sh

RUN apt-get clean

CMD ["/osm_replicate.sh"]