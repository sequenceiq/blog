---
layout: post
title: "TopK on Apache Tez"
date: 2014-09-20 14:08:04 +0200
comments: true
categories: [Apache Tez]
author: Krisztian Horvath
published: false
---

The Apache Tez community draw the attention with their latest release [0.5.0](http://tez.apache.org/releases/0.5.0/release-notes.txt)
of the application framework and they're getting a bigger and bigger hype every time - which they truly deserve. At
SequenceIQ we always try to find and provide the best solutions to our customers while we're also involved in many Apache projects to
share our experience we gain during the investment of the latest innovations. We're working hard on a new project called
[Banzai Pipeline](http://docs.banzai.apiary.io/) which we'll open source in the near future and is capable to run jobs on `MR`, `Spark` and `Tez`.
In the next couple of posts we'll compare these runtimes on different jobs and for the first comparison we chose TopK. Before going into
details let's revisit what Apache Tez is made of.

## Apache Tez key concepts

* One of the most important feature is that there is no heavy deployment phase which otherwise could go wrong in many ways - probably sounds familiar
for most of us. There is a nice [install guide](http://tez.apache.org/install.html) on the project's page which you can follow, but basically
you have to copy a bunch of jars to HDFS and you're almost good to go.
* Multiple versions of Tez can be used at the same time which solves a common problem, the rolling upgrades.
* Distributed data processing jobs typically look like `DAGs` (directed acyclic graphs) and Tez relies on this concept to define your jobs.
DAGs are made from `Verticles` and `Edges`. Verticles in the graph represent data transformations while edges represent the data movement
from producers to consumers. The DAG itself defines the structure of the data processing and the relationship between producers and consumers.

Tez provides faster execution and higher predictability because it:

* Eliminates replicated write barriers between successive computations
* Eliminates the job launch overhead
* Eliminates the extra stage of map reads in every workflow job
* Provides better locality
* Capable to re-use containers which reduces the scheduling time and speeds up incredibly the short running tasks
* Can share in-memory data across tasks
* Can run multiple DAGs in one session
* The core engine can be customized (vertex manager, DAG scheduler, task scheduler)
* Provides an event mechanism to communicate between tasks (data movement events to inform consumers by the data location)

I could go on and on with the list, but let's see the TopK implementation.

<!-- more -->

## TopK

The goal is to find the top K elements of a dataset. In our case it's a simple CSV and we're looking for the top elements in a given column.
In order to do that we need to group and sort them to take the K elements. The implementation can be found in our
[GitHub](https://github.com/sequenceiq/sequenceiq-samples) repository. The important part starts
[here](https://github.com/sequenceiq/sequenceiq-samples/blob/master/tez-topk/src/main/java/com/sequenceiq/tez/topk/TopK.java#L109) with the
DAG creation. First of all we define a `DataSourceDescriptor` which represents our dataset and a `DataSinkDescriptor` where we'll
write the results to. As you can see there are plenty of utility classes to help you define your DAGs. Now that the input and output is
ready let's define our `Vertices`. You'll see the actual data transformation is really easy as Hadoop will take care of the heavy
parts. The first Vertex is a
[tokenizer](https://github.com/sequenceiq/sequenceiq-samples/blob/master/tez-topk/src/main/java/com/sequenceiq/tez/topk/TopK.java#L160)
which does nothing more than splitting the rows of the CSV and emit a record with the selected column as the key and 1 as the value.
The interesting part here is the `initialize` method which reads the `UserPayload` to find out in which column we're looking for
the top K elements. What happens after the first Vertex is that Hadoop will group the records by key, so we'll have all the keys
with a bunch of 1s. In the next Vertex we
[sum](https://github.com/sequenceiq/sequenceiq-samples/blob/master/tez-topk/src/main/java/com/sequenceiq/tez/topk/TopK.java#L192)
these values so we'll have all the words in the given column counted and emit records where the id is the number of occurrences and the key
is the word in the selected column. Hadoop takes care of the sorting part, the only problem is that it will sort it in ascending order.
We can fix it by defining a custom [rawcomparator](https://github.com/sequenceiq/sequenceiq-samples/blob/master/tez-topk/src/main/java/com/sequenceiq/tez/topk/TopK.java#L254).
All we have left is to [take](https://github.com/sequenceiq/sequenceiq-samples/blob/master/tez-topk/src/main/java/com/sequenceiq/tez/topk/TopK.java#L213)
the first K element and write it to HDFS and we're done. Except that we have to
[define](https://github.com/sequenceiq/sequenceiq-samples/blob/master/tez-topk/src/main/java/com/sequenceiq/tez/topk/TopK.java#L141)
the data movements with edges. The execution of this DAG looks something like this:

{% img http://yuml.me/b6bf74a3 %}

In the last Vertex we start collecting the grouped sorted data so we can take the first K elements. This part kills the parallelism as
we need to see the global picture here that's why you can see that the parallelism is
[set](https://github.com/sequenceiq/sequenceiq-samples/blob/master/tez-topk/src/main/java/com/sequenceiq/tez/topk/TopK.java#L129) to 1.
We didn't specify it in the previous 2 Vertices which means that this will be decided at run time.
