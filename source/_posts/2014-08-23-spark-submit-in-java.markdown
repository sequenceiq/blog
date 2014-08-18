---
layout: post
title: "Submit Spark job to YARN in Java code"
date: 2014-08-23 10:09:28 +0200
comments: true
categories: [YARN, Spark]
author: Oliver Szabo
published: false
---
### Submit an Apache Spark application to YARN

In our previous Apache Spark related post we have seen that how to write a simple machine learning job.
Now we reveal that how to submit a job in Java code. But first you need to note that how to do it in normal way.
Basically as you see at the [documentation](https://spark.apache.org/docs/1.0.1/submitting-applications.html), you have to use the [spark-submit](https://github.com/apache/spark/blob/master/bin/spark-submit) script to submit a job. In nutshell SparkSubmit is called
by the [spark-class](https://github.com/apache/spark/blob/master/bin/spark-class) script with a lots of decorated arguments. In our example we examine only the YARN part of the submissions.
As you can see at [SparkSubmit.scala](https://github.com/apache/spark/blob/master/core/src/main/scala/org/apache/spark/deploy/SparkSubmit.scala) YARN [Client](https://github.com/apache/spark/blob/master/yarn/stable/src/main/scala/org/apache/spark/deploy/yarn/Client.scala) is loaded and invoke its main method.
(based on the arguments of the script)

<!-- more -->
```scala
    // If we're deploying into YARN, use yarn.Client as a wrapper around the user class
    if (!deployOnCluster) {
      childMainClass = args.mainClass
      if (isUserJar(args.primaryResource)) {
        childClasspath += args.primaryResource
      }
    } else if (clusterManager == YARN) {
      childMainClass = "org.apache.spark.deploy.yarn.Client"
      childArgs += ("--jar", args.primaryResource)
      childArgs += ("--class", args.mainClass)
    }

    ...
    // Here we invoke the main method of the Client
    val mainClass = Class.forName(childMainClass, true, loader)
    val mainMethod = mainClass.getMethod("main", new Array[String](0).getClass)
    try {
      mainMethod.invoke(null, childArgs.toArray)
    } catch {
      case e: InvocationTargetException => e.getCause match {
        case cause: Throwable => throw cause
        case null => throw e
    }
```

In case if you would like to submit a job to YARN in Java code, you can just simply use this Client class directly in your application.
(but you have to make sure, every environment variable what you need is set properly).

### Passing Configuration object

In the main method the org.apache.hadoop.conf.Configuration object is not passed to the Client class. Configuration is created explicitly in a constructor, which is actually okay (then client configurations are loaded from $HADOOP_CONF_DIR/core-site.xml and $HADOOP_CONF_DIR/yarn-site.xml).
But what if you want to use (for example) an [Ambari Configuration Service](http://blog.sequenceiq.com/blog/2014/07/09/ambari-configuration-service/) for retrieve your configuration?

```scala
    ... // Client class - constructor
      def this(clientArgs: ClientArguments, spConf: SparkConf) =
        this(clientArgs, new Configuration(), spConf)

    ... // Client object - main method
    System.setProperty("SPARK_YARN_MODE", "true")
    val sparkConf = new SparkConf()

    try {
      val args = new ClientArguments(argStrings, sparkConf)
      new Client(args, sparkConf).run()
    } catch {
      case e: Exception => {
        Console.err.println(e.getMessage)
        System.exit(1)
      }
    }

    System.exit(0)
```
Fortunately, the configuration could be passed here (there is a Configuration field in the Client), but you have to write your own main method.
### Code example
In our example we also use the 2 client XMLs as configuration (demonstration purposes only), the main difference here is that we read the properties from the XMLs and filling them in the Configuration.
Then we pass the Configuration object to the Client (which is directly invoked here).
```scala
 def main(args: Array[String]) {
    val config = new Configuration()
    fillProperties(config, getPropXmlAsMap("config/core-site.xml"))
    fillProperties(config, getPropXmlAsMap("config/yarn-site.xml"))

    System.setProperty("SPARK_YARN_MODE", "true")

    val sparkConf = new SparkConf()
    val cArgs = new ClientArguments(args, sparkConf)

    new Client(cArgs, config, sparkConf).run()

  }
```
To build the project use this command from the spark-submit directory:
```bash
./gradlew clean build
```
Then you find the required jars in spark-submit-runner/build/libs (uberjar with all required dependencies) and spark-submit-app/build/libs. Put them in the same directory (do this also with this [config folder](https://github.com/sequenceiq/sequenceiq-samples/tree/master/spark-submit/spark-submit-runner/src/main/resources) too). After that run this command:
```bash
java -cp spark-submit-runner-1.0.jar com.sequenceuq.spark.SparkRunner \
  --jar spark-submit-app-1.0.jar \
  --class com.sequenceiq.spark.Main \
  --driver-memory 1g \
  --executor-memory 1g \
  --executor-cores 1 \
  --arg hdfs://sandbox:9000/input/sample.txt \
  --arg /output \
  --arg 10 \
  --arg 10
```
During the submission note that: not just the app jar, but the spark-submit-runner jar is also uploaded (which is an uberjar) to the HDFS. To avoid this, you have to upload it to the HDFS manually and set SPARK_JAR environment variable.

```bash
export SPARK_JAR="hdfs:///spark/spark-submit-runner-1.0.jar"
```
If you got "Permission denied" exception on submit, you should set HADOOP_USER_NAME environment variable to root.

This example can be downloaded from [here](https://github.com/sequenceiq/sequenceiq-samples/tree/master/spark-submit) and the sample input from [here](https://raw.githubusercontent.com/sequenceiq/sequenceiq-samples/master/spark-clustering/data/input.txt)

For updates follow us on [LinkedIn](https://www.linkedin.com/company/sequenceiq/), [Twitter](https://twitter.com/sequenceiq) or [Facebook](https://www.facebook.com/sequenceiq).
