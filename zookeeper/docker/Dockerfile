FROM openjdk:11-jre-slim
MAINTAINER santhosh.tekuri@gmail.com
ENV JAVA_HOME /usr/local/openjdk-11
RUN apt-get update \
    && apt-get install -y wget netcat \
    && wget -q http://archive.apache.org/dist/zookeeper/zookeeper-3.6.1/apache-zookeeper-3.6.1-bin.tar.gz \
    && mkdir /zookeeper \
    && tar -xzf apache-zookeeper-3.6.1-bin.tar.gz -C /zookeeper --strip-components=1 \
    && rm apache-zookeeper-3.6.1-bin.tar.gz \
    && rm -rf /zookeeper/bin/*.cmd /zookeeper/docs \
    && apt-get autoremove -y wget
WORKDIR /zookeeper
EXPOSE 2181 2888 3888 7000
COPY zkOk.sh docker-entrypoint.sh /zookeeper/bin/
ENTRYPOINT ["/zookeeper/bin/docker-entrypoint.sh"]
CMD ["/zookeeper/bin/zkServer.sh", "start-foreground"]
