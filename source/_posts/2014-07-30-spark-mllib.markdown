---
layout: post
title: "Apache Spark - MLlib Introduction"
date: 2014-07-30 09:47:32 +0200
comments: true
categories: [Spark, MLlib, Clustering, KMeans]
author: Oliver Szabo
published: false
---
## Introduction

Earlier, we mention that we use Scalding (among others) for writing MR jobs. Scala/Scalding simplifies the implementation of many MR patterns and makes it easy to implement much more complex jobs e.g.: machine learning algorithms. Map Reduce is a really I/O heavy framework and it is great choice for text processing. But not as great if you want to use it for iterative algorithms. And here [Apache Spark](https://spark.apache.org/) enters the frame. Spark is fit for these kind of algorithms, because it keeps everything in memory. (in case of you run out of memory, you can switch to another [storage level](http://spark.apache.org/docs/latest/programming-guide.html#rdd-persistence))

## Apache Spark - MLlib libary

[MLlib](https://spark.apache.org/docs/latest/mllib-guide.html) is a machine learning libary for Apache Spark. Below we show how easy to use it for clustering.

## KMeans example
K-Means (Lloyd's algorithm) is a simple NP-hard unsupervised learning algorithms that solve the well known clustering problems. The essence of the algorithm is to separate your data into K cluster. In simple terms it needs 4 steps. First of all you have to vectorize our data. (you can do that with text values too). In the code it looks like this:

```scala
    val data = context.textFile(input).map {
      line => Vectors.dense(line.split(',').map(_.toDouble))
    }.cache()
```
The second step is to choose K center points. (centroids) The third one is assign each vector to the group that has the closest centroid. After all is done, recalculate the positions of the centroids. You have to repeat the third and fourth steps until the centroids not moving. [KMeans](https://github.com/apache/spark/blob/master/mllib/src/main/scala/org/apache/spark/mllib/clustering/KMeans.scala) MLlib model can do that for you (2-3-4 steps without centroid delta checking)

```scala
    val clusters: KMeansModel = KMeans.train(data, K, maxIteration, runs)

    val vectorsAndClusterIdx = data.map{ point =>
      val prediction = clusters.predict(point)
      (point.toString, prediction)
    }

```
After you have your model result, you can utilize it in your RDD object. If we would have implement this as MR jobs, it would have also required more jobs.

## Running Spark job on YARN
In order to run this Spark application on YARN you need the following command:

```bash
./bin/spark-submit --class com.sequenceiq.spark.Main --master \
yarn-client --driver-memory 1g --executor-memory 1g --executor-cores 1 \
/root/spark-clustering-1.0.jar hdfs://sandbox:9000/input/input.txt /output 10 10 1
```
You can run this in our [Spark based docker container](https://github.com/sequenceiq/docker-spark). Source code can be downloaded from [here](https://github.com/sequenceiq/sequenceiq-samples/tree/master/spark-clustering). You can find 2 simple input data for testing purposes. Both example performs better than Mahout KMeans (2-3x faster with 20 iterations), but these are really small data. In one of our next post we will show you metrics for much larger data.
## Other promising machine learning frameworks

If you are interested in machine learning frameworks, you have to check  [Conjecture](https://github.com/etsy/Conjecture) or [ganitha](https://github.com/tresata/ganitha) which are under development. If [Cascading 3.0](http://www.infoq.com/news/2014/05/driven) will support Spark, these frameworks can be much more usable (not only for MR jobs).
