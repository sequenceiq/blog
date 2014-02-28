---
layout: post
title: "ETL - producing better quality data"
date: 2014-02-27 08:12:44 +0000
comments: true
published: false
categories: [Data cleaning, ETL]
author: Richard Doktorics
---

On my way to work this morning I read an interesting article about the quality of data being produced by different systems and applications. While the article was emphasizing that the quality of the data should not be an IT problem (but management), our believe is that at the high volume, velocity and variety (the "3Vs" of big data) the data is produced today, the process of producing data is a shared responsibility between management and the IT department.

Since the emerging of Hadoop, the TCO of storing large amounts of data in HDFS is lower than ever before - and now it makes sense to store all the data an enterprise produces in order to find patterns, correlations and break the data silos - something which was very specific for different departments within an organization. Storing such an amount of data (structured, unstructured, logs, clickstream, etc) inevitable produces a 'bad' data quality - but this depends on your point of view. For us data is just data - we don't want to qualify it - and has it's own intrinsic value, but the quality of it depends on the ETL process. When someone engages with our API and the xTract Spacetime platform, among the first step is the configuration of data sources, and the attached ETL processes. We offer an extremely sophisticated ETL process and the ability to 'clean' the data (batch or streaming) while arrives into xTract Spacetime, but we always suggest our customers to keep the raw data as well.

During the architecture of the xTract Spacetime platform we have tried and PoCd different ETL frameworks and implementations - and we choose [Kite Morphlines](https://github.com/kite-sdk/kite/tree/master/kite-morphlines) being at the core of our ETL process. Morphlines is an open source framework that reduces the time and skills necessary to build and change Hadoop ETL stream processing applications that extract, transform and load data into Apache Solr, HBase, HDFS, Enterprise Data Warehouses, or Analytic Online Dashboards.

Since runs on Hadoop, scalability is not a problem - we have seen enterprises producing 50 terabytes data per day and missing the 24 hour ETL window, by not being able to scale horizontally their ETL processes. Morphlines is built on top of the Kite framework (a great framework for making easier to build systems on top of the Hadoop), and it's extremely easy to extend. We would like to show and give you examples about how to use and create a Morphlines Command to implement your custom transformation (if the many existing ones does not fit your requirement).

The implementation of a Command starts with implementing a CommandBuilder 

Actually a new morphline command implementation is not that hard. You have to implement a builder class (see below), define the name of the command and  extend the AbstractCommand base class. That simple.

``` java ToLowerCaseBuilder implements CommandBuilder

@Override
  public Collection<String> getNames() {
    return Collections.singletonList("toLowerCase");
  }

```


``` java toLowerCase Morphlines command

@Override
protected boolean doProcess(Record record) {
  ListIterator iter = record.get(fieldName).listIterator();
  while (iter.hasNext()) {
    iter.set(transformFieldValue(iter.next()));
  }
    return super.doProcess(record);
}
  
  private Object transformFieldValue(Object value) {
    return value.toString().toLowerCase(locale);
  }

```


To configure your new morhline command

``` java toLowerCase config

morphlines : [
  {
   id : morphline1
       importCommands : ["com.sequenceiq.samples.**"]

       commands : [
         {
           toLowerCase {
             field : Name
             locale : en_us
           }
         }
       ]
  }
]

```


There is a custom tester tool which waiting a file as an input, a file as a config and an expected output. Among our plans is to build a UI on top of Kite Morphlines as well - part of our product stack. While we consider the Morhplines configuration, and defining the transformations simple and easy to use, many of our users might prefer a custom UI whee you can define your own ETL process visually.

That’s it. You can find the samples at our [GitHub page](https://github.com/sequenceiq/sequenceiq-samples). 
Hope you enjoy it, let us know if you need help or have any questions.
