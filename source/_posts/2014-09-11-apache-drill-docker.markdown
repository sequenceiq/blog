---
layout: post
title: "Apache Drill on Docker - query as a service "
date: 2014-09-11 18:00:00 +0200
comments: true
categories: [Drill, SQL, Docker]
author: Janos Matyas
published: false
---

As you might be already familiar, we have `dockerized` most of the Hadoop ecosystem - we are running MR2, Spark, Storm, Hive, HBase, Pig, Oozie, etc in Docker containers - on bare metal and in the cloud as well. We have started to use (and contribute) to Docker quite a while ago, and beside the `mainstream` benefits of containers one feature was extremely appealing to us - **the SOA way of DevOps**. Before I go on and explore what we mean under this allow me to collect a few links for your reference (all open sourced under an **Apache 2 license**), in case you plan to use Hadoop in Docker containers.

| Name                  | Description | Documentation | GitHub |
|-----------------------|----|--------| ---------- | 
| Apache Hadoop  | Pseudo dist. container | http://blog.sequenceiq.com/blog/2014/08/18/hadoop-2-5-0-docker/ | https://github.com/sequenceiq/hadoop-docker |
| Apache Ambari   | Multi node - full Hadoop stack, blueprint based | http://blog.sequenceiq.com/blog/2014/06/19/multinode-hadoop-cluster-on-docker/ | https://github.com/sequenceiq/docker-ambari |
| Cloudbreak 	     | Cloud agnostic Hadoop as a Service | http://blog.sequenceiq.com/blog/2014/07/18/announcing-cloudbreak/ | https://github.com/sequenceiq/cloudbreak |
| Periscope 	     | SLA policy based autoscaling for Hadoop clusters | http://blog.sequenceiq.com/blog/2014/08/27/announcing-periscope/ | https://github.com/sequenceiq/periscope |

## Apache Drill at SequenceIQ

[Apache Drill](http://incubator.apache.org/drill/) is an open source, low latency SQL query engine for Hadoop and NoSQL. It has many nice and interesting features, but one of the most interesting one (at least for us) is the [storage plugin](https://cwiki.apache.org/confluence/display/DRILL/Storage+Plugin+Registration) and the tolerance/support for dynamic schemas. At [SequenceIQ](http://sequenceiq.com/) the pre and post processed data ends up in different storage systems/layers. Obliviously we use HDFS, for low latency queries we use HBase and recently (with the emergence of Tez - which we consider the next big thing) we started to use Hive as well. Quite often there is a need to access the data from `legacy` systems - and more often we see `SQL` coming back in the picture. Just FYI, for SQL on HBase we are using [Apache Phoenix](http://phoenix.apache.org/), and of course we have released and open sourced a [Docker container](http://blog.sequenceiq.com/blog/2014/09/04/sql-on-hbase-with-apache-phoenix/). 

As you see there are many storage systems use - and Drill helps us with aggregating these under one common `ANSI SQL syntax`. You can query data from HDFS, HBase, Hive, local or remote distributed file system - or write your own custom storage plugin.

<!-- more -->

### Lifecycle of a Drill query 

Let’s take a simple example (from the Drill samples), where we query a file, with a `WHERE` clause. Your statement is submitted in `Sqlline` - a very popular (used with our Phoenix container as well) Java interface which can talk to a JDBC driver. The `SELECT` statement is passed into [Optiq](http://optiq.incubator.apache.org/). Optiq is a library for query parsing and planning, and allows pluggable transformation rules. Optiq also has a cost-based query optimizer. At high level, based on the above the statements are converted into Drill `logical operators`, and form a Drill logical plan. This plan is then submitted into one `DrillBit service` - usually running on each datanode, to benefit on the data locality, during query execution. This logical plan is then transformed into a physical plan - a simple DAG  of physical operators - using a Drill’s `optimizer`. This physical plan is broken into a multi-level execution tree (hello MPP) that is executed by multiple DrillBits. The story goes on as there are statistics collected, endpoint affinities are checked (metadata based preferred endpoint selection) and the plan is broken in fragments, but at a high level this is the execution flow. 
There are some interesting things going on under the hood which we can cover it one of the following posts - about writing our custom storage plugin. 

##  Apache Drill on Docker 

Now as you have a good overview about the capabilities of Drill, we’d like to expand on what we mean under **SOA way of DevOps**. Though Drill is a complex piece of software, essentially the provided service is extremely simple: *queries data*. We have created a [Drill Docker](https://registry.hub.docker.com/u/sequenceiq/drill/) container and wrapped the `query` service inside. If you’d like to use Drill, the only thing you will have to do is to launch our Drill container - the `query service` is available *as a Service*. We have built the container in such a way that the data layer is separated from the `query service` - you can launch the container when and where you’d like to do, and attach the data using volumes. Once the data layer is attached, the only remaining thing is to let Drill know where to query - by either using one of the existing, or creating a new storage configuration.

### Pull the container 

The Drill container is available as a trusted build on Docker.io. You can get and start using it - the only prerequisite is to have Docker installed.

`docker pull sequenceiq/drill`

### Use the container

Once the container is pulled you are ready to query your data by running:

`docker run -it -v /data:/data sequenceiq/drill /etc/bootstrap.sh`

Note that the `-v /data:/data` flag specifies that you are mounting your `/data` directory on the host into a `/data` directory inside the container. The files inside the directory will be available for Drill to query, by either using the default `dfs` storage plugin, or by a custom one. To check, or create a storage plugin or to access the Drill UI you should go to `http://CONTAINER_IP:8047`. You can find your container IP by using `docker inspect ID`.

In case you don't have any data, but would still like to explore Drill, start the contaier as: 

`docker run -it sequenceiq/drill /etc/bootstrap.sh`

The sample data installed by default with Drill is available inside the container, thus you'd be able to run all the Drill examples/tutorials.

###Drill Rest API

Get Drillbit status: `http://localhost:8047/status`       
Get all submitted queries: `http://localhost:8047/queries`       
Get status of a given query:`http://localhost:8047/query/{QUERY_ID}`

The next version of the container will be a fully distributed (based on our Hadoop container and Hazelcast) Apache Drill Docker container. Until then feel free to let us know how you `drill` and follow us on [LinkedIn](https://www.linkedin.com/company/sequenceiq/), [Twitter](https://twitter.com/sequenceiq) or [Facebook](https://www.facebook.com/sequenceiq).



