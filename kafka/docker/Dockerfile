FROM openjdk:11-jre-slim
MAINTAINER santhosh.tekuri@gmail.com
ENV JAVA_HOME /usr/local/openjdk-11
RUN set -eux \
    && apt-get update \
    && apt-get install -y wget \
    && wget -q http://archive.apache.org/dist/kafka/2.5.0/kafka_2.12-2.5.0.tgz  \
    && mkdir /kafka \
    && tar -xzf kafka_2.12-2.5.0.tgz -C /kafka --strip-components=1  \
    && rm kafka_2.12-2.5.0.tgz \
    && rm -rf /kafka/site-docs /kafka/bin/windows \
    && apt-get autoremove -y wget
WORKDIR /kafka
COPY docker-entrypoint.sh /kafka/bin/
ENTRYPOINT ["/kafka/bin/docker-entrypoint.sh"]
CMD ["/kafka/bin/kafka-server-start.sh", "config/server.properties"]
