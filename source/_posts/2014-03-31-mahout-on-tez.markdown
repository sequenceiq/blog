---
layout: post
title: "Using Mahout with Tez"
date: 2014-03-31 11:22:09 +0100
comments: true
categories: [Hortonworks, Tez, Mahout, YARN]
author: Marton Sereg
published: false
---

At SequenceIQ we are always open to the latest innovations in Hadoop, and find a way to offer a better performance and cluster utilization to our customers. We came in close touch with the [Stinger initiative](http://hortonworks.com/labs/stinger/) last year at the Hadoop Summit in Amsterdam - and ever since we have followed up with the project progress. The project was initiated by Hortonworks with the goal of a 100x performance improvement of Hive. 
Although Hive is not part of our product stack (we use other ways for SQL on Hadoop), there is one particular key component of the Stinger initiative which is very interesting to us: Apache Tez.

[Apache Tez](http://incubator.apache.org/projects/tez.html) is a new application framework built on Hadoop Yarn that can execute complex directed acyclic graphs (DAGs) of general data processing tasks. In many ways it can be thought of as a more flexible and powerful successor of the map-reduce framework. This was exactly what draw our attention and made us start thinking about using Tez as our runtime for map-reduce jobs.


####Tez and MapReduce 

At SequenceIQ we have chains of map-reduce jobs which are scheduled individually and read the output of previous jobs from HBase or HDFS. Many times our map-reduce job flow can be represented as a map-reduce-reduce pattern, however building complex job chains with the current map-reduce framework is not that easy (nor saves on performane) - we have combined the ChainMapper/ChainReducer and IdentityMapper in order to build a DAG like job flow.

In Tez data coming form reducers output can be pipelined together and eliminates IO/sync barriers, as no temporary HDFS write is required. Also jobs can be chained and represented as MRR steps with no restriction.
In MapReduce disregarding the data size, the shuffle (internal step between the map and reducer) phase writes the sorted partitions to disk, merge-sorts them and feed into the reducers. All these steps are done *in memory* with Tez and saves on this I/O heavy step, avoiding unnecessary temporary writes and reads.

####Tez and Mahout

Part of our system is running machine learning algorithms in batch, using Mahout (we do ML on streaming data using Scala, MLib and Spark as well). To improve the runtime performance of these algortihms, and decrease the cluster time they use we started to experiment with combining Tez and Mahout, and re-write a few Mahout drivers in order to build DAG's of MR jobs (MRR in particular where applicable) and submit the jobs in a Tez on YARN cluster. 

<!--more--> 

In this blog we would like to introduce you into using Tez (for your convenience we have put together a [Tez-Docker](https://github.com/sequenceiq/tez-docker) image where the Tez runtime is already configured), submit a Mahout classification job into a YARN cluster as a regular MR job and the same classification job into a Tez on YARN cluster.
We made some metrics to highlgut the differences: both in elapsed time and resource utilization.

1. Build Tez
Get the Tez code fron the [GitHub](https://github.com/apache/incubator-tez), and run `mvn clean install`. Alternatively you can get the build from [SequenceIQ S3](https://s3-eu-west-1.amazonaws.com/seq-tez/tez-0.3.0-incubating.tar.gz) and copy into HDFS under the '/tez' folder.

2. Add *-site.xml
Add the [tez-site.xml](https://raw.githubusercontent.com/sequenceiq/tez-docker/master/tez-site.xml) and [mapred-site.xml](https://github.com/sequenceiq/tez-docker/blob/master/mapred-site.xml) to Hadoop (in our case it's $HADOOP_PREFIX/etc/hadoop/). 

``` bash
echo 'TEZ_JARS=/usr/local/tez/*' >> $HADOOP_PREFIX/etc/hadoop/hadoop-env.sh
echo 'TEZ_LIB=/usr/local/tez/lib/*' >> $HADOOP_PREFIX/etc/hadoop/hadoop-env.sh
echo 'TEZ_CONF=/usr/local/hadoop/etc/hadoop' >> $HADOOP_PREFIX/etc/hadoop/hadoop-env.sh
echo 'export HADOOP_CLASSPATH=$HADOOP_CLASSPATH:$TEZ_CONF:$TEZ_JARS:$TEZ_LIB' >> $HADOOP_PREFIX/etc/hadoop/hadoop-env.sh
```
Make sure you set your HADOOP_PREFIX env variable, or use [Apache Ambari](http://ambari.apache.org/) to configure Tez (change the `mapredude.framework.name=yarn-tez`).

3. Submit a classification job (code is available from [SequenceIQ samples GitHub](https://github.com/sequenceiq/sequenceiq-samples) page.

As we will see the difference between using MapReduce and Tez are quite significant (10x fater with Tez).

Below you can see the sample Mahout classification job submitted in YARN using MapReduce.

![](https://raw.githubusercontent.com/sequenceiq/sequenceiq-samples/master/tez-dag-jobs/resources/Classification_Mahout_MR.png)

Below you can see the sample Mahout classification job submitted in YARN using Tez.

![](https://raw.githubusercontent.com/sequenceiq/sequenceiq-samples/master/tez-dag-jobs/resources/Classification_Mahout_TEZ.png)

If we dig into deeper metrics we can see the huge differences between thge file operations and HDFS I/O. The Tez framework does less file operations as the MapReduce one.

![](https://raw.githubusercontent.com/sequenceiq/sequenceiq-samples/master/tez-dag-jobs/resources/fileops_tez_vs_mr.png)

Also if we check the HDFS I/O operations we see the same results - less and more efficient HDFS operations in case of Tez.

![](https://raw.githubusercontent.com/sequenceiq/sequenceiq-samples/master/tez-dag-jobs/resources/hdfsio_tez_vs_mr.png)

All these are because the Tez runtime is using in-memory operations whenever is possible instead of temporarily persisting the sorted partitions to HDFS. 
Tez and [Hortonworks' Stinger initiative](http://hortonworks.com/labs/stinger/) is opening up new possibilities to write faster and more performant Hadoop jobs, and closes the gap between stream and batch processing.




