---
layout: post
title: "Mapreduce with Scalding"
date: 2014-04-14 13:55:38 +0200
comments: true
categories: [Scalding, Hadoop]
author: Richard Doktorics
published: false
---

At SequenceIQ we have many pre-built and configurable MapReduce jobs (complex math algorithms, filtering, sorting and correlation patterns, samplings, top-n, joins, partitioning, etc) - as building blocks of our job worklow. We needed to find a quick way to build and test these jobs during developement on 'local' mode and be able to push the same jobs to a large test cluster without any modifications. 
Though in general we use Java, we always strive for efficiency when we need to solve a problem and we use different  languages (not just JVM based) in our stack (e.g. Groovy, Go and R) - to write MapReduce jobs we have choosen Scala and the Scalding library. Scalding is a Scala library developed by Twitter that abstracts and makes easy to write Hadoop MapReduce jobs. In many ways Scalding is similar to Pig, but it was writen in Scala, bringing the advantages of Scala to your MapReduce jobs (e.g. type safety - how many times you have submitted a job to a cluster only to learn 5 hours later that you can't convert a String to Double). 


This example will show you how you can use Scalding with Hadoop 2.3 and how easy is to write a MapReduce job with few lines of Scala code.

##Build the project
In our example we will transform a csv file to an other one with a filter step.
To build the project use:

`./gradlew clean build` in the project library.

##Run the sample
To run the sample with these parameters in local mode:

``` bash
yarn jar scalding-sample-0.1.jar com.sequenceiq.samples.scalding.CsvToCsvFilterJob --local --schema {YOUR_SCHEME} --input {INPUT} --type {TYPE} --operator {OPERATOR} --field {FILTER_FIELD} --operand {OPERAND} --output {OUTPUT_PATH}
```

or if you want to run the exampke using HDFS then use:
``` bash
yarn jar scalding-sample-0.1.jar com.sequenceiq.samples.scalding.CsvToCsvFilterJob --hdfs --schema {YOUR_SCHEME} --input {INPUT} --type {TYPE} --operator {OPERATOR} --field {FILTER_FIELD} --operand {OPERAND} --output {OUTPUT_PATH}
```

To run the filtering example the parameters are like this:
``` bash
yarn jar scalding-sample-0.1.jar com.sequenceiq.samples.scalding.CsvToCsvFilterJob --hdfs --schema id,name --input /input.csv --type int --operator eq --field id --operand 1 --output /output.csv
```

The code looks extremely simple:

``` java
validation()
  input(args)
    .filter(filterableField) {field: String => createFilterCriterion(field)}
    .write(output(args))
```

First there is a validation and in case of the input data is OK then we are doing a filtering with the specified criterias.
In this example (as in all our other examples) we are using Hadoop 2 - with the ability to submit Scalding jobs into a remote Hadoop 2 cluster. Note that Scalding depends on the Cascading library which does not support Hadoop 2 and there is no ability to submit jobs to a remote cluster - our example has removed the Hadoop 1 dependencies and lets you to submit jobs to any remote Hadoop 2 cluster.

``` java
  	JobRunner.runJob(
  		configurationService.getConfiguration(),
        new String[]{
            parameters..
        }
    );
```
You can get the example project from our [GitHub](https://github.com/sequenceiq/sequenceiq-samples/tree/master/scalding-sample) repository.

Should you have any Scalding or Scala questions or observations let us know.
Enjoy,
SequenceIQ
