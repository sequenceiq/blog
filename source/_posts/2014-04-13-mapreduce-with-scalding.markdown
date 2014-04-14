---
layout: post
title: "Mapreduce with Scalding"
date: 2014-04-13 19:55:38 +0200
comments: true
categories: [Scalding, Hadoop]
author: Richard Doktorics
published: false
---

Scalding is a Scala library that makes it easy to specify Hadoop MapReduce jobs. Scalding is built on top of Cascading. Scalding is similar to Pig, but it was writen in Scala, bringing advantages of Scala to your MapReduce jobs. This framework currently used by @Twitter, @Ebay, @Soundcloud.


This example will show you how you can use scalding with Hadoop 2.3 nad how easy to write a mapreduce with few line of Scala code.

##Build the project
Our example will transform a csv file to an other with a filter step.
If you want to build the project than write

`./gradlew clean build` in the project library.

##Run the sample
If you want to run our sample than you can run with these parameters in local

``` bash
yarn jar scalding-sample-0.1.jar com.sequenceiq.samples.scalding.CsvToCsvFilterJob --local --schema {YOUR_SCHEME} --input {INPUT} --type {TYPE} --operator {OPERATOR} --field {FILTER_FIELD} --operand {OPERAND} --output {OUTPUT_PATH}
```

or if you want to running on hdfs then use this
``` bash
yarn jar scalding-sample-0.1.jar com.sequenceiq.samples.scalding.CsvToCsvFilterJob --hgfs --schema {YOUR_SCHEME} --input {INPUT} --type {TYPE} --operator {OPERATOR} --field {FILTER_FIELD} --operand {OPERAND} --output {OUTPUT_PATH}
```

In our sample we using this command
``` bash
yarn jar scalding-sample-0.1.jar com.sequenceiq.samples.scalding.CsvToCsvFilterJob --hgfs --schema id,name --input /input.csv --type int --operator eq --field id --operand 1 --output /output.csv
```


The code part is very easy

``` java
validation()
  input(args)
    .filter(filterableField) {field: String => createFilterCriterion(field)}
    .write(output(args))
```

Firstly we make a validation before everything else and if the input data is fine then we doing the filter with the specific criteria.
We are using hadoop 2 with cascading pattern in the project so you can submit your jobs with for example java into a remote cluster which using hadoop2 like this way.

``` java
  	JobRunner.runJob(
  		configurationService.getConfiguration(),
        new String[]{
            parameters..
        }
    );
```
Here is the sample project: [scalding sample](https://github.com/sequenceiq/sequenceiq-samples/tree/master/scalding-sample)

Enjoy,
SequenceIQ