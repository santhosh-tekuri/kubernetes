FROM openjdk:11-jre-slim
MAINTAINER santhosh.tekuri@gmail.com
RUN set -eux \
    && groupadd -r zookeeper --gid=1000 \
    && useradd -r -g zookeeper --uid=1000 zookeeper \
    && apt-get update \
    && apt-get install -y wget netcat \
    && wget -q -O zookeeper.tar.gz http://archive.apache.org/dist/zookeeper/zookeeper-3.6.1/apache-zookeeper-3.6.1-bin.tar.gz \
    && mkdir /zookeeper \
    && tar -xzf zookeeper.tar.gz -C /zookeeper --strip-components=1 \
    && chown -R zookeeper:zookeeper /zookeeper \
    && rm zookeeper.tar.gz \
    && rm -rf /zookeeper/bin/*.cmd /zookeeper/docs \
    && apt-get autoremove -y wget
ENV JAVA_HOME=/usr/local/openjdk-11 \
    PATH=$PATH:/zookeeper/bin
USER zookeeper
WORKDIR /zookeeper
EXPOSE 2181 2888 3888 7000
ENTRYPOINT ["zkServer.sh"]
CMD ["start-foreground"]
