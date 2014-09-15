---
layout: post
title: "Apache Hadoop 2.5.0 on Docker"
date: 2014-08-18 20:07:18 +0200
comments: true
categories: [Apache, Hadoop, Docker, Registry]
published: false
author: Janos Matyas
---
Following the release cycle of Hadoop, today we are releasing a new `2.5.1` version of our [Hadoop Docker container](https://registry.hub.docker.com/u/sequenceiq/hadoop-docker/). Up until today the container was only `CentOS` based, but during the last few months we got lots of requests to release a Hadoop container on `Ubuntu` as well. From now on we will have both released, supported and published to the offical Docker repository.

##Centos

### Build the image

In case you'd like to try directly from the [Dockerfile](https://github.com/sequenceiq/hadoop-docker/tree/2.5.1) you can build the image as:

```
docker build  -t sequenceiq/hadoop-docker:2.5.1 .
```
<!-- more -->

### Pull the image

As it is also released as an official Docker image from Docker's automated build repository - you can always pull or refer the image when launching containers.

```
docker pull sequenceiq/hadoop-docker:2.5.1
```

### Start a container

In order to use the Docker image you have just build or pulled use:

```
docker run -i -t sequenceiq/hadoop-docker:2.5.1 /etc/bootstrap.sh -bash
```

## Ubuntu

### Build the image

In case you'd like to try directly from the [Dockerfile](https://github.com/sequenceiq/docker-hadoop-ubuntu/tree/2.5.1) you can build the image as:

```
docker build  -t sequenceiq/hadoop-ubuntu:2.5.1 .
```
<!-- more -->

### Pull the image

As it is also released as an official Docker image from Docker's automated build repository - you can always pull or refer the image when launching containers.

```
docker pull sequenceiq/hadoop-ubuntu:2.5.1
```

### Start a container

In order to use the Docker image you have just build or pulled use:

```
docker run -i -t sequenceiq/hadoop-ubuntu:2.5.1 /etc/bootstrap.sh -bash
```

## Testing

You can run one of the stock examples:

```
cd $HADOOP_PREFIX
# run the mapreduce
bin/hadoop jar share/hadoop/mapreduce/hadoop-mapreduce-examples-2.5.1.jar grep input output 'dfs[a-z.]+'

# check the output
bin/hdfs dfs -cat output/*
```

## Hadoop native libraries, build, Bintray, etc

The Hadoop build process is no easy task - requires lots of libraries and their right version, protobuf, etc and takes some time - we have simplified all these, made the build and released a 64b version of Hadoop nativelibs on our [Bintray repo](https://bintray.com/sequenceiq/sequenceiq-bin/hadoop-native-64bit/2.5.0/view/files). Enjoy. 

Should you have any questions let us know through our social channels as [LinkedIn](https://www.linkedin.com/company/sequenceiq/), [Twitter](https://twitter.com/sequenceiq) or [Facebook](https://www.facebook.com/sequenceiq).
