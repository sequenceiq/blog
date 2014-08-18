---
layout: post
title: "Apache Spark - MLlib Introduction"
date: 2014-07-31 09:47:32 +0200
comments: true
categories: [Spark, MLlib, KMeans, Tez]
author: Oliver Szabo
published: true
---

### Introduction

In one of our earlier posts we have mentioned that we use Scalding (among others) for writing MR jobs. Scala/Scalding simplifies the implementation of many MR patterns and makes it easy to implement quite complex jobs like machine learning algorithms. Map Reduce is a mature and widely used framework and it is a good choice for processing large amounts of data - but not as great if you’d like to use it for fast iterative algorithms/processing. This is a use case where [Apache Spark](https://spark.apache.org/) can be quite handy. Spark is fit for these kind of algorithms, because it tries to keep everything in memory (in case of you run out of memory, you can switch to another [storage levels](http://spark.apache.org/docs/latest/programming-guide.html#rdd-persistence)).

### Apache Spark - MLlib library

[MLlib](https://spark.apache.org/docs/latest/mllib-guide.html) is a machine learning library which ships with Apache Spark, and can run on any Hadoop2/YARN cluster without any pre-installation. At SequenceIQ we use MLlib in Scala - but you could use it from Java and Python as well. Let us quickly show you an MLlib clustering algorithm with code examples.

### KMeans example
K-Means (Lloyd's algorithm) is a simple NP-hard unsupervised learning algorithm that solve well known clustering problems. The essence of the algorithm is to separate your data into K cluster. In simple terms it needs 4 steps. First of all you have to vectorize your data. (you can do that with text values too). The code looks like this:

```scala
    val data = context.textFile(input).map {
      line => Vectors.dense(line.split(',').map(_.toDouble))
    }.cache()
```
<!-- more -->

The second step is to choose K center points (centroids). The third one is to assign each vector to the group that has the closest centroid. After all this is done, next thing you will need to do is to recalculate the positions of the centroids. You have to repeat the third and fourth steps until the centroids are not moving (`the iterative stuff`). The [KMeans](https://github.com/apache/spark/blob/master/mllib/src/main/scala/org/apache/spark/mllib/clustering/KMeans.scala) MLlib model is doing that for you.

```scala
    val clusters: KMeansModel = KMeans.train(data, K, maxIteration, runs)

    val vectorsAndClusterIdx = data.map{ point =>
      val prediction = clusters.predict(point)
      (point.toString, prediction)
    }

```
After you have your model result, you can utilize it in your RDD object.

### Running Spark job on YARN
In order to run this Spark application on YARN first of all you will need a Hadoop YARN cluster. For that you could use our Hadoop as a Service API called [Cloudbreak](http://sequenceiq.com/cloudbreak) - using a `multi-node-hdfs-yarn` blueprint will set you up a Spark ready Hadoop cluster in less than 2 minutes on your favorite cloud provider. Give it a try at our hosted [Cloudbreak](https://cloudbreak.sequenceiq.com) instance.

Once your cluster it’s up and ready you can run the following command:

```bash
./bin/spark-submit --class com.sequenceiq.spark.Main --master \
yarn-client --driver-memory 1g --executor-memory 1g --executor-cores 1 \
/root/spark-clustering-1.0.jar hdfs://sandbox:9000/input/input.txt /output 10 10 1
```
Alternatively you can run this in our free Docker based Apache Spark container as well. You can get a Spark container from the official [Docker registry](https://registry.hub.docker.com/u/sequenceiq/spark/) or from our [GitHub](https://github.com/sequenceiq/docker-spark) repository.
As always we are making the source code available at [SequenceIQ's GitHub repository](https://github.com/sequenceiq/sequenceiq-samples/tree/master/spark-clustering) (check the other interesting examples as well).  You can find 2 simple input datasets for testing purposes.

The result of the clustering looks like this (generated with R):

![](https://raw.githubusercontent.com/sequenceiq/sequenceiq-samples/master/spark-clustering/data/spark-clustering_1.jpeg)

While there is a loud buzz about what’s faster than the other and there are huge numbers thrown in as the *X* multiplier factor we don’t really want to enter that game - as a fact we’d like to mention that both example performs better than Mahout KMeans (2-3x faster with 20 iterations), but these are really small datasets. We have seen larger datasets in production where the performances are quite the same, or can go the other way (especially that Spark is new and people don’t always get the configuration right).


In one of our next post we will show you metrics for a much larger dataset and other ML algorithms - follow us on [LinkedIn](https://www.linkedin.com/company/sequenceiq/), [Twitter](https://twitter.com/sequenceiq) or [Facebook](https://www.facebook) for updates.

### Apache Tez
We can’t finish this blog post before not talking about [Apache Tez](http://tez.apache.org/) - the project is aimed at building an application framework which allows for a complex directed-acyclic-graph of tasks for processing data - fast. We (and many others) believe that this can be a good alternative for Spark - especially for machine learning. The number of frameworks which are adding or moving the MR runtime to Tez is increasing - among the few to mention are Cascading, Summingbird, Conjecture - including us as well.

Note that Apache Tez has already showed **awesome** result. Being the key building block of the [Stinger inititive](http://hortonworks.com/labs/stinger/) - led by Hortonworks - managed to bring near real time queries and speed up Hive with 100x.

### Other promising machine learning frameworks

If you are interested in machine learning frameworks, you have to check  [Conjecture](https://github.com/etsy/Conjecture) or [ganitha](https://github.com/tresata/ganitha) - they both show great fueatures and have promising results.
