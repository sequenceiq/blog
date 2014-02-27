---
layout: post
title: "ETL - producing better quality data"
date: 2014-02-27 08:12:44 +0000
comments: true
published: false
categories: [Data cleaning, ETL]
author: Janos Matyas
---

On my way to work this morning I read an interesting article about the quality of data being produced by different systems and applications. While the article was emphasizing that the quality of the data should not be an IT problem (but management), our believe is that at the high volume, velocity and variety (the "3Vs" of big data) the data is produced today, the process of producing data is a shared responsibility between management and the IT department.

Since the emerging of Hadoop, the TCO of storing large amounts of data in HDFS is lower than ever before - and now it makes sense to store all the data an enterprise produces in order to find patterns, correlations and break the data silos - something which was very specific for different departments within an organization. Storing such an amount of data (structured, unstructured, logs, clickstream, etc) inevitable produces a 'bad' data quality - but this depends on your point of view. For us data is just data - we don't want to qualify it - and has it's own intrinsic value, but the quality of it depends on the ETL process. When someone engages with our API and the xTract Spacetime platform, among the first step is the configuration of data sources, and the attached ETL processes. We offer an extremely sophisticated ETL process and the ability to 'clean' the data (batch or streaming) while arrives into xTract Spacetime, but we always suggest our customers to keep the raw data as well.

During the architecture of the xTract Spacetime platform we have tried and PoCd different ETL frameworks and implementations - and we choose [Kite Morphlines](https://github.com/kite-sdk/kite/tree/master/kite-morphlines) being at the core of our ETL process. Among the first reasons we stick with Morphlines was the scalability - we have seen enterprises producing 50 terabytes data per day and missing the 24 hour ETL window. Morphlines is built on top of the Kite framework (a great framework for making easier to build systems on top of the Hadoop). 
We found it easy to embed into our data streaming part of the system but Morphlines can also be embedded with MR, Crunch, HBase, Hive, Pig and Sqoop as well. Since our goal from the very beginning was to create data lakes, instead of data silos the ability to load data into HDFS, HBase and Apache Solr was a very important feature as well.

<!-- more -->

The Basic idea behind the morphline is to transform our data something else. We think that, what is really matters what you want to make with your data. In some case the raw data is not in the best fit for example for a recommendation process. In the past there was a Cloudera project which name was Morphline. Now this project is the [Kite Morphlines](https://github.com/kite-sdk/kite/tree/master/kite-morphlines). Some very dedicated guy in the community developing this fantastic project. In the beginning of february the SequenceIQ was on a Big Data meetup where one of the Cloudera best brains was the performer who was Wolfgang Hoschek. He mentioned this project in her presentation so I checked on the Github and we decided to use Kite in our application for the etl processing. 
Actually a new morphline command implementation is not so hard. You have to implement the CommandBuilder where you have to define the name of the command and an extended class of the AbstractCommand base class. After that implement the processing logic that’s all.

``` java ToLowerCaseBuilder implements CommandBuilder

@Override
  public Collection<String> getNames() {
    return Collections.singletonList("toLowerCase");
  }

```


``` java toLowerCase command logic

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


And how you can configure your new morhline command?

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


I made a custom tester tool which waiting a file as an input, a file as a config and an expected output. This help us to testing our custom solutions because here in the SequenceIQ the thorough testing is very important. We planning to build a UI on the top of the Kite because, some of our users are not datascientists or you do not want to learn the morphline syntax, you just want to do the etl process as easy as possible.
And It's much easier to edit on UI and see the result immediately.
That’s it. You can find the samples here https://github.com/sequenceiq/sequenceiq-samples. Hope you enjoyed.