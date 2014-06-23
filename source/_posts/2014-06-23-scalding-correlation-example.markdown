---
layout: post
title: "Scalding correlation example"
date: 2014-06-23 14:07:18 +0200
comments: true
categories: [Scalding, Scala, Hadoop, HBase, Correlation]
published: false
author: Oliver Szabo
---
## Introduction

Previously we mention that we are using mostly scalding for batch processing.
Scalding is a powerful tool and great choice if you want to simplify the writing of your MapReduce jobs.
In the following detailed example we show how to write and test scalding jobs.

## Writing Pearson correlation job

In our example, we calculate Pearson's product-moment coefficient on 2 columns of a given input.(you can find the data [here](https://github.com/sequenceiq/sequenceiq-samples/tree/master/scalding-correlation/data))
This computation is the easiest way to find any dependence between two sets of data.
Fist of all we need all the parameters for the given [formula](http://www.statisticshowto.com/what-is-the-correlation-coefficient-formula/).
In Scala code it looks like this:

``` scala
trait CorrelationOp {
  def calculateCorrelation(size: Long, su1: Double, su2: Double, sq1: Double, sq2: Double, dotProd: Double) : Double = {
    val dividend = (size * dotProd) - (su1 * su2)
    val divisor = scala.math.sqrt(size * sq1 - su1 * su1) * scala.math.sqrt(size * sq2 - su2 * su2)
    dividend / divisor
  }
}
```
At below we compute all the required parameters for the correlation formula in the scalding job with [Field API](https://github.com/twitter/scalding/wiki/Fields-based-API-Reference).
Firstly we obtain input/output and 2 comparamble column arguments which comes from command line parameters (usage : --key value) and provide scheme for the CSV input.
After the input is read we map the 2 selected fields (product and squares). With the underlined informations, we are able to produce the required parameters (grouping part).
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
For running the example you have to run the following command: (you can use --hdfs instead of --local)
``` bash
yarn jar scalding-correalation-1.0.jar com.sequenceiq.scalding.correlation.SimpleCorrelationJob --local --input data/data.csv --output data/corr-out.tsv --column1 num1 --column2 num2 --samplePercent 0.1
```
## Testing Scalding jobs
Because mostly these kind of jobs represent the most critical operations in the business logic, you may want to test the jobs.
For checking that your data transformations are correct, you can use
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

In case of we want to store our data in a database we can use special Cascading Taps for it.
Here I used [Spyglass](https://github.com/ParallelAI/SpyGlass) to store the correlation results to HBase.
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
For running the example you have to run the following command: (you can use --hdfs instead of --local)
``` bash
yarn jar scalding-correalation-1.0.jar com.sequenceiq.scalding.hbase.HBaseWriterJob --local --input data/corr-out.tsv --tableName corrTable --quorum localhost --quorumPort 2181
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
You can get the example project from our [GitHub](https://github.com/sequenceiq/sequenceiq-samples/tree/master/scalding-correlation) repository
