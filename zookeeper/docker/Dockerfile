FROM openjdk:11-jre-slim
MAINTAINER santhosh.tekuri@gmail.com
ENV JAVA_HOME /usr/local/openjdk-11
ENV ZK_HOME /apache-zookeeper-3.6.1-bin
RUN apt-get update \
    && apt-get install -y wget netcat \
    && wget http://archive.apache.org/dist/zookeeper/zookeeper-3.6.1/apache-zookeeper-3.6.1-bin.tar.gz \
    && tar -xzf apache-zookeeper-3.6.1-bin.tar.gz \
    && rm apache-zookeeper-3.6.1-bin.tar.gz \
    && rm -rf $ZK_HOME/docs \
    && apt-get autoremove -y wget
WORKDIR $ZK_HOME
EXPOSE 2181 2888 3888 7000
COPY zkOk.sh docker-entrypoint.sh $ZK_HOME/bin/
ENTRYPOINT ["/apache-zookeeper-3.6.1-bin/bin/docker-entrypoint.sh"]
CMD ["/apache-zookeeper-3.6.1-bin/bin/zkServer.sh", "start-foreground"]
