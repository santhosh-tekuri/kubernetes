FROM openjdk:11-jre-slim
MAINTAINER santhosh.tekuri@gmail.com
RUN set -eux \
    && groupadd -r kafka --gid=1000 \
    && useradd -r -g kafka --uid=1000 kafka \
    && apt-get update \
    && apt-get install -y wget \
    && wget -q -O kafka.tgz http://archive.apache.org/dist/kafka/2.5.0/kafka_2.12-2.5.0.tgz  \
    && mkdir /kafka \
    && tar -xzf kafka.tgz -C /kafka --strip-components=1  \
    && chown -R kafka:kafka /kafka \
    && rm kafka.tgz \
    && rm -rf /kafka/site-docs /kafka/bin/windows \
    && apt-get autoremove -y wget
ENV JAVA_HOME=/usr/local/openjdk-11 \
    PATH=$PATH:/kafka/bin
USER kafka
WORKDIR /kafka
