---
layout: post
title: "Apache Tez cluster on Docker"
date: 2014-09-19 09:42:58 +0200
comments: true
categories: [Apache Tez, Docker, Hadoop, Performance]
author: Janos Matyas
published: false
---

This week the [Apache Tez](http://tez.apache.org/) community announced the release of the 0.5 version of the project. At SequenceIQ we came across Tez early 2013 - when [Hortonworks](http://hortonworks.com/) launched the `Stinger Initiative`. Though at [SequenceIQ](http://sequenceiq.com/) we are not using Hive (that might change soon), we have quickly realized the `other` capabilities of Tez - the expressive data flow API, data movement patterns, dynamic graph reconfiguration, etc - to name a few. 

We than quickly became `advocates` of Tez - and have started to run internal PoC projects, rewrite ML algorithms and legacy MR2 code on Tez. The new release comes with a stable developer API and a proven stability track, thus this has triggered a `major` re-architecture/refactoring project at SequenceIQ. While I don’t want to enter in too deep details, we are building the **Heroku/Cloudfoundry of the Hadoop ecosystem** - with the first two stages of the project already released: 

[Cloudbreak](http://blog.sequenceiq.com/blog/2014/07/18/announcing-cloudbreak/) - our Docker based cloud agnostic Hadoop as a Service API (AWS, Azure, Google Cloud, DigitalOcean)
	
[Periscope](http://blog.sequenceiq.com/blog/2014/08/27/announcing-periscope/) - an SLA policy based autoscaling API for Hadoop YARN


The last piece is a project called [Banzai Pipeline](http://docs.banzai.apiary.io/) - a big data pipeline API (with 50+ pre-built data and job pipes), running on MR2, Tez and Spark. 

With all these said, we have put together a `Tez Ready` Docker based Hadoop cluster to share our excitement and allow you to quickly start and get familiar with the nice features of the Tez API. The cluster is built on our Apache Ambari Docker container, with some additional features. The containers are` service discovery` aware - you don’t need to setup anything beforehand, or configure IP addresses or DNS names - the only thing you will need to do is just specify the number of nodes desired in your cluster, and you are ready to go.

I'd like to highlight one important thing for us - being crazy about automation/DevOps - the simplicity and the capability of running multiple versions of Tez on the same YARN cluster. We are contributors to many Apache projects (Hadoop, YARN, Ambari, etc) and since we have started to use Tez we consider to contribute there as well (at the end of the day will be a core part of our platform). Adding new features, changing code or fixing bugs always introduce undesired `features` - nevertheless, the Tez binaries built by different colleagues can be tested at scale, using the same cluster without affecting each others work. Check Gopal V's good [introduction]((https://github.com/t3rmin4t0r/notes/wiki/I-Like-Tez,-DevOps-Edition-(WIP)) about Tez and DevOps.

##Apache Tez cluster on Docker

The container’s code is available in our [GitHub]() repository.

###Pull the image from Docker Repository

We suggest to always pull the container from the official Docker repository - as this is always maintained and supported by us. 

```
docker pull sequenceiq/ambari:tez
```

<!-- more -->

### Building the image

Alternatively you can always build your own container based on our Dockerfile.

```
docker build --rm -t sequenceiq/ambari:tez
```

## Running the cluster
We have put together a few shell functions to simplify your work, so before to start get the following `ambari-functions` [file](https://github.com/sequenceiq/docker-ambari/blob/1.7.0-ea/ambari-functions) from our GitHub.

!!!CHANGE ME - Specify the Docker.io TAG

```
curl -Lo .amb j.mp/docker-ambari-tez && . .amb
```

###Create your Apache Tez cluster

```
amb-deploy-cluster 4
```

###Testing


Should you have any questions let us know through our social channels using [LinkedIn](https://www.linkedin.com/company/sequenceiq/), [Twitter](https://twitter.com/sequenceiq) or [Facebook](https://www.facebook.com/sequenceiq).
