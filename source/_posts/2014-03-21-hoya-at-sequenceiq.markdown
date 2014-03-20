---
layout: post
title: "Using Hortonworks Hoya at SequenceIQ"
date: 2014-03-21 04:54:09 +0100
comments: true
categories: [Hortonworks, Hoya, HBase, YARN]
author: Janos Matyas
published: false
---
Using Hoya at SequenceIQ

With this blog post we are starting a series of articles where we'd like to describe how we use YARN, why it is central to our product stack and why we believe that Hortonworks Hoya will be a determining building block in the Hadoop ecosystem.

While we don't want to get in details about [YARN](http://hortonworks.com/hadoop/yarn/), we'd like to briefly explain the advantages of running an application on YARN, and introduce you to [Hortonworks Hoya](https://github.com/hortonworks/hoya).

At SequenceIQ we are building a multi-tenant, scale on demand data platform, with unpredictable batch and streaming workloads.
Before YARN we have tried different cluster management frameworks with Hadoop and managed to have pretty good results with [Amazon EC2 Autoscaling groups](http://aws.amazon.com/autoscaling/). Being true believers in open source and the need to diversify of provisioning Hadoop on different environments we needed to find an open source and 'standardised' solution - welcome YARN.
(for example we provision Hadoop on [Docker](http://blog.sequenceiq.com/blog/2014/03/19/hadoop-2-dot-3-with-docker/)

YARN separates the processing engine from the resource management - and acting effectively as an OS for Hadoop.
With YARN, you can now run multiple applications in Hadoop, all sharing a common resource management and improving cluster utilisation (we will release some metrics soon).
YARN also provides the following features out of the box:

  * Multi-tenancy
  * Management and monitoring
  * High availability
  * Security
  * Failover and recovery

All of the above and the effort of the Hadoop community and the wide adoption convinced us to start implementing our platform to run on top of YARN.
During our proof of concepts we went as far as starting all our non Hadoop (and not YARN compatible) applications on YARN - by using [Hoya](https://github.com/hortonworks/hoya).

Hoya was introduced by Hortonworks mid last year - with the purpose to create Apache HBase clusters on YARN (since than it supports Apache Accumulo as well).
The code evolved pretty fast and now Hoya is a framework/application which allows you to deploy existing distributed applications on YARN - and benefit all the nice features of YARN.

In order to support different applications Hoya has a plugin provider architecture (supported plugins are in the *org.apache.hoya.providers* package).
Once a plugin is implemented (pretty straightforward, took us a few days only to understand and build a Flume and Tomcat plugin), the application is started in a YARN container and is monitored and controlled by YARN/Hoya.
The clusters can be started, stopped, frozen and re-sized dynamically - and in case of container failures Hoya deploys a replacement.

For a better architectural understanding of Hoya please read the following blog [post](http://hortonworks.com/blog/hoya-hbase-on-yarn-application-architecture/) and check the following image (courtesy of Steve Loughran/Hortonworks) below.

![Hoya](http://hortonworks.com/wp-content/uploads/2013/08/Hoya-Application-Architecture.png)

In this first post we would like to help you to get familiar with the benefits offered by Hoya and start an HBase cluster, re-scale it dynamically, freeze and stop.
First and foremost you will need an installation of Hadoop (2.3), the latest Hoya release (0.13.1) and HBase (0.98).
For your convenience we have put together an automated install script which lets you start with Hoya in a few minutes.

The script is available from our [GitHub page](https://github.com/sequenceiq/hoya-docker/blob/master/hoya-centos-install.sh).

Once Hadoop, HBase and Hoya are installed you can now create an HBase cluster.
``` bash
create-hoya-cluster() {
  hoya create hbase --role master 1 --role worker 1
    --manager localhost:8032
    --filesystem hdfs://localhost:9000 --image hdfs://localhost:9000/hbase.tar.gz
    --appconf file:///tmp/hoya-master/hoya-core/src/main/resources/org/apache/hoya/providers/hbase/conf
    --zkhosts localhost
}
```
This will launch a 2 node HBase cluster (1 Master and 1 RegionServer). Now lets increase the number of RegionServers.

``` bash
flex-hoya-cluster() {
  num_of_workers=$1
  hoya flex hbase --role worker $num_of_workers --manager localhost:8032 --filesystem hdfs://localhost:9000
}
```

This will start as many RegionServers as specified - in new YARN containers. Also the size of the cluster can be decreased if the load on the system does not demand for a larger number of RegionServers. The cluster can also be freezed (Hoya takes care about persisting the state).

``` bash
freeze-hoya-cluster() {
  hoya freeze hbase --manager localhost:8032 --filesystem hdfs://localhost:9000
}
```

Finally when you'd like to destroy the cluster and the state associated with the application you can use:

``` bash
destroy-hoya-cluster() {
  hoya destroy hbase --manager localhost:8032 --filesystem hdfs://localhost:9000
}
```
As you see installing Hoya and starting different applications (HBase in this case) is very simple - and all the nice features of YARN are instantly available for any clustered applications.
In our next post we will drive you through the steps of creating your own Hoya provider, deploy it and run on a YARN cluster.
