FROM ubuntu:22.04

RUN apt-get update && \
    apt-get install -y ca-certificates

COPY mongodb-bi-linux-x86_64-ubuntu2204-v2.14.27.tgz /tmp/mongodb-bi.tgz

RUN tar -xzf /tmp/mongodb-bi.tgz -C /opt && \
    mv /opt/mongodb-bi-linux-x86_64-ubuntu2204-v2.14.27 /opt/mongodb-bi && \
    rm /tmp/mongodb-bi.tgz

EXPOSE 3307

CMD ["/opt/mongodb-bi/bin/mongosqld","--mongo-uri=mongodb://adoring_wilson:27017","--addr=0.0.0.0:3307","--schemaSource=mongodb"]