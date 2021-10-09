FROM ubuntu:21.04

ENV DEBIAN_FRONTEND noninteractive


RUN  apt-get update &&\
     apt-get -y install jq awscli wget cmake build-essential libboost-dev libexpat1-dev zlib1g-dev libbz2-dev osm2pgsql &&\
     apt-get clean

RUN  apt-get update &&\
     apt install -y python3-pip

RUN python3 -m pip install psycopg2-binary osmium


COPY ./osm_replicate.sh /

RUN wget https://raw.githubusercontent.com/openstreetmap/osm2pgsql/master/scripts/osm2pgsql-replication &&\ 
    chmod +x osm2pgsql-replication &&\
    chmod +x osm_replicate.sh

RUN echo "30 */4 * * * /osm_replicate.sh >> /var/log/script.log 2>&1" >> crontab.txt &&\
    crontab crontab.txt

ENTRYPOINT ["/usr/sbin/cron", "-f", "-l", "8"]