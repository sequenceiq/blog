---
layout: post
title: "Pearson correlation with Scalding"
date: 2014-06-23 20:07:18 +0200
comments: true
categories: [Scalding, Scala, Hadoop, HBase, Correlation]
published: true
author: Oliver Szabo
---
## Introduction

At SequenceIQ we are processing data in batch and streaming - for both we use Scala as our prefered language; for batch processing in particular we use Scalding to build our job and data pipelines. Actually there is `Babylon` at SequenceIQ as we use Java, Scala, Go, R, Groovy, Ansible, shell, JavaScript and what not - follow up with us for a post talking about the language heterogeneity. 

Scalding is a powerful tool and great choice to simplify the writing and abstracting MapReduce jobs - an open source project originally developed by Twitter and recently the community.
In the following detailed example we'd like show you an example of how to write and test Scalding jobs, running on Hadoop. 

## Writing a Pearson correlation job

In this example, we'd like to calculate a Pearson's product-moment coefficient on 2 columns of a given [input](https://github.com/sequenceiq/sequenceiq-samples/tree/master/scalding-correlation/data).
This is a simple computation and the easiest way to find any dependency between two datasets.
First of all we need all the parameters for the given [formula](http://www.statisticshowto.com/what-is-the-correlation-coefficient-formula/).
In Scala the code would look like this:

``` scala
trait CorrelationOp {
  def calculateCorrelation(size: Long, su1: Double, su2: Double, sq1: Double, sq2: Double, dotProd: Double) : Double = {
    val dividend = (size * dotProd) - (su1 * su2)
    val divisor = scala.math.sqrt(size * sq1 - su1 * su1) * scala.math.sqrt(size * sq2 - su2 * su2)
    dividend / divisor
  }
}
```

<!-- more -->

In this example we compute all the required parameters for the correlation formula using the [Field API](https://github.com/twitter/scalding/wiki/Fields-based-API-Reference) of Scala.
First we obtain the input/output and the two comparable column arguments which comes from command line parameters (usage : --key value) and provide the schema for the CSV input.
After the input is read we map the two selected fields (product and squares); with the underlined informations, we are able to produce the required parameters (grouping part).
At the end we just need to use the formula on the given fields (second map) and write the results into a TSV file.
``` scala
  val comparableColumn1 = args("column1")
  val comparableColumn2 = args("column2")
  val samplePercent = args.getOrElse("samplePercent","1.00").toDouble

  val scheme = new Fields("id", "num1", "num2", "num3", "num4", "num5")

  Csv(args("input"), fields = scheme, skipHeader = true).read
  .sample(samplePercent)
  .map((comparableColumn1,comparableColumn2) -> ('prod, 'compSq1, 'compSq2)){
    values : (Double, Double) =>
      (values._1 * values._2, math.pow(values._1, 2), math.pow(values._2, 2))
  }
  .groupAll{
    _.size
      .sum[Double](comparableColumn1 -> 'compSum1)
      .sum[Double](comparableColumn2 -> 'compSum2)
      .sum[Double]('compSq1 -> 'normSq1)
      .sum[Double]('compSq2 -> 'normSq2)
      .sum[Double]('prod -> 'dotProduct)
  }
  .limit(1)
  .project('size,'compSum1, 'compSum2, 'normSq1, 'normSq2, 'dotProduct)
  .map(('size, 'compSum1, 'compSum2,'normSq1, 'normSq2, 'dotProduct)
    -> ('key, 'correlation)){
    fields : (Long, Double, Double, Double, Double, Double) =>
      val (size, sum1, sum2, normSq1, normSq2, dotProduct) = fields
      val corr = calculateCorrelation(size, sum1, sum2, normSq1, normSq2, dotProduct)
      (comparableColumn1 + "-" + comparableColumn2, corr)
  }
  .project('key, 'correlation)
  .write(Tsv(args("output")))

```

For running the example you will have to run the following command: (_you can use --hdfs instead of --local_)

``` bash
yarn jar scalding-correalation-1.0.jar com.sequenceiq.scalding.correlation.SimpleCorrelationJob --local --input data/data.csv --output data/corr-out.tsv --column1 num1 --column2 num2 --samplePercent 0.1
```
## Testing Scalding jobs

In order to test that your data transformations are correct, you can use the 
[JobTest](http://twitter.github.io/scalding/com/twitter/scalding/JobTest.html) class for unit testing.
``` scala
@RunWith(classOf[JUnitRunner])
class SimpleCorrelationJobTest  extends Specification {
  "A SimpleCorrelation Job" should {
    val input = List((1,2,3,3,4,5),(2,1,2,3,4,5),(3,4,5,3,4,5))
    val correctOutputLimit = 0.8

    JobTest("com.sequenceiq.scalding.correlation.SimpleCorrelationJob")
      .arg("input", "fakeInput")
      .arg("output", "fakeOutput")
      .arg("column1", "num1")
      .arg("column2", "num2")
      .arg("correlationThreshold", "0.8")
      .source(Csv("fakeInput", ",", new Fields("id","num1","num2","num3","num4","num5"),skipHeader = true), input)
      .sink[(String, Double)](Tsv("fakeOutput", fields = Fields.ALL)) {
      outputBuf =>
        val actualOutput = outputBuf.toList.head._2
        "return greater correlation result than 0.8" in {
          correctOutputLimit must be_< (actualOutput)
        }
    }
      .run
      .finish
  }
}
```

## Writing results to HBase

In case we'd like to store our data in a database (at SequenceIQ we use HBase) we can use a special Cascading Tap for it.
In this example we used [Spyglass](https://github.com/ParallelAI/SpyGlass) to store the correlation results in HBase.
``` scala
  val tableName = args("tableName")
  val quorum_name = args("quorum")
  val quorum_port = args("quorumPort").toInt

  val scheme = List('key, 'correlation)
  val familyNames = List("corrCf")

  Tsv(args("input")).read
    .toBytesWritable(scheme)
    .write(
      new HBaseSource(
        tableName,
        quorum_name + ":" + quorum_port,
        scheme.head,
        familyNames,
        scheme.tail.map((x: Symbol) => new Fields(x.name)).toList,
        timestamp = Platform.currentTime
      ))
```

## Build the application
``` bash
./gradlew clean jar
```
or
``` bash
export GRADLE_OPTS="-XX:MaxPermSize=2048m" # for tests
./gradlew clean build
```

## Running the example and persisting to HBase

In order to run the example you'll have to run the following command: (you can use --hdfs instead of --local)
``` bash
yarn jar scalding-correalation-1.0.jar com.sequenceiq.scalding.hbase.HBaseWriterJob --local --input data/corr-out.tsv --tableName corrTable --quorum localhost --quorumPort 2181
```

Hope this correlation example and introduction into Scalding was useful - you can get the example project from our [GitHub](https://github.com/sequenceiq/sequenceiq-samples/tree/master/scalding-correlation) repository.

