---
layout: post
title: "Data cleaning with MapReduce and Morphline"
date: 2014-03-11 16:21:07 +0100
comments: true
categories: [MapReduce, Morphline, HDFS, Data cleaning, ETL]
author: Krisztian Horvath
published: false
---
[Previously](http://blog.sequenceiq.com/blog/2014/02/28/etl-and-data-quality/) we saw how easily extensible is Kite Morphlines framrwork with your custom commands. In this post we are going to use it to remove columns from a dataset to demonstrate how it can be used end embedded in MapReduce jobs. 
Download the MovieLens + IMDb/Rotten Tomatoes dataset from [Grouplens](http://grouplens.org/datasets/hetrec-2011/), extract it, and it should contain a file called user_ratedmovies.dat. 
It is basically a tsv file and we are going to use the exact same column names as it is given in the first line. 

```
userID	movieID	rating	date_day  date_month  date_year	date_hour  date_minute	date_second
75		3		1		29		 10			  2006		23			17			16
75		32		4.5		29		 10			  2006		23			23			44
75		110		4		29		 10			  2006		23			30			8
75		160		2		29		 10			  2006		23			16			52
75		163		4		29		 10			  2006		23			29			30
75		165		4.5		29		 10			  2006		23			25			15
75		173		3.5		29		 10			  2006		23			17			37
```

Let’s just say we don’t need all the
data from here and remove the last 3 columns (date_hour, date_minute, date_second). We can achieve this with the following 2 commands:

```
{
	readCSV {
  		separator : "\t"
  		columns : [userID,movieID,rating,date_day,date_month,date_year,date_hour,date_minute,date_second]
  		ignoreFirstLine : false
  		trim : true
  		charset : UTF-8
	}
}	 

{
	java {
  	  imports : "import java.util.*;"
  	  code: """
        record.removeAll("date_hour");
        record.removeAll("date_minute");
        record.removeAll("date_second");
    	  return child.process(record);
        """
	}
}
```
<!-- more -->
Create our mapper only job to process the data. What we need to do is build the Morphline command chain by parsing the 
configuration file as shown

```java protected void setup(Context context)
File morphLineFile = new File(context.getConfiguration().get(MORPHLINE_FILE));
String morphLineId = context.getConfiguration().get(MORPHLINE_ID);
RecordEmitter recordEmitter = new RecordEmitter(context);
MorphlineContext morphlineContext = new MorphlineContext.Builder().build();
Command morphline = new org.kitesdk.morphline.base.Compiler().compile(morphLineFile, morphLineId, morphlineContext, recordEmitter);
```
and pass the lines through it.
```java protected void map(Object key, Text value, Context context)
Record record = new Record()
record.put(Fields.ATTACHMENT_BODY, new ByteArrayInputStream(value.toString().getBytes()));
if (!morphline.process(record)) {
	LOGGER.info("Morphline failed to process record: {}", record);
}
record.removeAll(Fields.ATTACHMENT_BODY);
```
Notice that the compile method takes an important parameter called finalChild which is in our example the `RecordEmitter`. 
The returned command will feed records into finalChild which means if this parameter is not provided a DropRecord command will 
be assigned automatically. In Apache Flume there is a Collector command to avoid loosing any transformed record. 
The only thing left is to outbox the processed record and write the results to HDFS. The RecordEmitter will serve this purpose:
```java
@Override
public boolean process(Record record) {
	line.set(record.toString());
  try {
  	context.write(line, null);
  } catch (Exception e) {
      LOGGER.warn("Cannot write record to context", e);
  }
  return true;
}
```
By default the readCSV command extracts the ATTACHMENT_BODY into headers with id provided in the columns field so the 
transformed data will look like this (3 columns were dropped):
```
{date_day=[10], date_month=[10], date_year=[2008], movieID=[62049], rating=[4.5], userID=[71534]}
```
The source code is available in our samples repository on [GitHub](https://github.com/sequenceiq/sequenceiq-samples). 
It is just a simple example but you can go further and download a much bigger dataset with 10 millions of lines and process it with multiple nodes to see how it scales.
