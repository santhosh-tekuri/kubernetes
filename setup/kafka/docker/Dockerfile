FROM openjdk:11-jre-slim
MAINTAINER santhosh.tekuri@gmail.com
ENV JAVA_HOME /usr/local/openjdk-11
ENV KAFKA_HOME /kafka_2.12-2.5.0
RUN apt-get update \
    && apt-get install -y wget \
    && wget -q http://archive.apache.org/dist/kafka/2.5.0/kafka_2.12-2.5.0.tgz  \
    && tar -xzf kafka_2.12-2.5.0.tgz  \
    && rm kafka_2.12-2.5.0.tgz \
    && rm -rf $KAFKA_HOME/site-docs $KAFKA_HOME/bin/windows \
    && apt-get autoremove -y wget
WORKDIR $KAFKA_HOME
COPY docker-entrypoint.sh $KAFKA_HOME/bin/
ENTRYPOINT ["/kafka_2.12-2.5.0/bin/docker-entrypoint.sh"]
CMD ["/kafka_2.12-2.5.0/bin/kafka-server-start.sh", "config/server.properties"]
