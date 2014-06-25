---
layout: post
title: "Apache Hadoop 2.4.0 on Docker"
date: 2014-06-25 20:07:18 +0200
comments: true
categories: [Apache, Hadoop, Docker, Registry]
published: true
author: Janos Matyas
---

Following on the success of our Hadoop 2.3 Docker [image](https://registry.hub.docker.com/u/sequenceiq/hadoop-docker/) and aligning with the Hadoop release cycle, we have released an Apache Hadoop 2.4 pseudo distributed Docker image - same as the previous version this is available as a trusted and automated build on the official Docker registry.

Please note that beside this Docker image, we have released and maintain a [pseudo-distributed](http://blog.sequenceiq.com/blog/2014/06/17/ambari-cluster-on-docker/) and [distributed](http://blog.sequenceiq.com/blog/2014/06/19/multinode-hadoop-cluster-on-docker/) Hadoop images provisioned with Apache Ambari. As they are provisioned with Ambari, you have the option to change, and and remove Hadoop components using cluster blueprints.

## Build the image

In case you'd like to try directly from the [Dockerfile](https://github.com/sequenceiq/hadoop-docker) you can build the image as:

```
docker build  -t sequenceiq/hadoop-docker .
```

## Pull the image

As it is also released as an official Docker image from Docker's automated build repository - you can always pull or refer the image when launching containers.

```
docker pull sequenceiq/hadoop-docker:2.4.0
```

## Start a container

In order to use the Docker image you have just build or pulled use:

```
docker run -i -t sequenceiq/hadoop-docker /etc/bootstrap.sh -bash
```

## Testing

You can run one of the stock examples:

```
cd $HADOOP_PREFIX
# run the mapreduce
bin/hadoop jar share/hadoop/mapreduce/hadoop-mapreduce-examples-2.4.0.jar grep input output 'dfs[a-z.]+'

# check the output
bin/hdfs dfs -cat output/*
```

## Hadoop native libraries, build, Bintray, etc

The Hadoop build process is no easy task - requires lots of libraries and their right version, protobuf, etc and takes some time - we have simplified all these, made the build and released a 64b version of Hadoop nativelibs on our [Bintray repo](https://bintray.com/sequenceiq/sequenceiq-bin/hadoop-native-64bit/2.4.0/view/files). Enjoy. 

