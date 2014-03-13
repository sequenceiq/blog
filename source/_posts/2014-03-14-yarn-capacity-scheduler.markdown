---
layout: post
title: "YARN Capacity Scheduler"
date: 2014-03-14 16:17:04 +0100
comments: true
categories: [YARN, HD2, Capacity Scheduler]
author: Janos Matyas
published: false
---

Since the emergence of Hadoop 2 and the YARN based architecture we have a platform where we can run multiple applications (of different types) not constrained only to MapReduce. Different applications or different MapReduce job profiles have different resource needs, however since Hadoop 2.0 is a multi tenant platform the different users could have different access patterns or need for cluster capacity. This is achieved through YARN schedulers - allocating resources to the various running applications subject to familiar constraints of capacities and queues (for more information on YARN follow this [link](http://hortonworks.com/hadoop/yarn/) or  feel free to ask us should you have any questions).

In Hadoop 2.0, the scheduler is a pluggable piece of code that lives inside the *ResourceManager* (the JobTracker in MR1) - the ultimate authority that arbitrates resources among all the applications in the system. The scheduler in YARN does not perform monitoring or status tracking and offers no guarantees to restart failed tasks - check our sample [GitHub](https://github.com/sequenceiq/sequenceiq-samples) project to check how monitoring or progress can be tracked. 

The Capacity Scheduler was designed to allow significantly higher cluster utilization while still providing predictability for Hadoop workloads, while sharing resources in a predictable and simple manner. It uses the common notion of ‘job queues’.

In our [example](https://github.com/sequenceiq/sequenceiq-samples) we show you how to use the Capacity Scheduler, configure queues with different priorities, submit MapReduce jobs into these queues, and monitor and track the progress of the jobs - and ultimately see the differences between execution times using queues with different priorities. 

First, let’s config the Capacity Scheduler (you can use XML, [Apache Ambari](http://ambari.apache.org/) or you can configure queues programatically). In this example we use a simple xml configuration.

``` xml 
<property>
  <name>yarn.scheduler.capacity.root.queues</name>
  <value>default,highPriority,lowPriority</value>
</property>
    <property>
  <name>yarn.scheduler.capacity.root.highPriority.capacity</name>
  <value>70</value>
</property>
    <property>
  <name>yarn.scheduler.capacity.root.lowPriority.capacity</name>
  <value>20</value>
</property>
<property>
  <name>yarn.scheduler.capacity.root.default.capacity</name>
  <value>10</value>
</property>
```
We have 3 queues, with different queue priorities. Each queue is given a *minimum* guaranteed percentage of total cluster capacity available - the total guaranteed capacity must equal 100%. In our example the *highPriority* queue has 70% of the resources, the *lowPriority* 20%, and the default queue has the remaining 10%. While it is not highlight in the example above, the Capacity Scheduler provides elastic resource scheduling, which means that if there are idle resources in the cluster, then one queue can take up more of the cluster capacity than was minimally allocated . In our example we could allocate a *maximum* capacity to the *lowPriority* queue:

``` xml 
<property>
  <name>yarn.scheduler.capacity.root. lowPriority.maximum-capacity</name>
  <value>50</value>
</property>
```

Now lets submit some jobs into these queues. We will use the QuasiMonteCarlo.java example (coming with Hadoop) - a map/reduce program that estimates the value of Pi, and submit the same MapReduce jobs into the low and high priority queues. 

``` java
    //get a configuration
    Configuration priorityConf = new Configuration();
    priorityConf.set("mapreduce.job.queuename", queueName);
    …………		
    //submit the job
    JobID jobID = QuasiMonteCarlo.submitPiEstimationMRApp("PiEstimation into: "+ queueName, 10, 3, tempDir, priorityConf);
```
Once the jobs are submitted in the different queues, you can track the MapReduce job progress and monitor the queues through YARN. using YARNRunner you can get ahold of a job status, and  retrieve different informations:

``` java 
    //print overall job M/R progresses
    LOGGER.info("\nJob " + jobStatus.getJobName() + "in queue (" + jobStatus.getQueue() + ")" + " progress M/R: " + 		        jobStatus.getMapProgress() + "/" + jobStatus.getReduceProgress());
    LOGGER.info("Tracking URL : " + jobStatus.getTrackingUrl());
    LOGGER.info("Reserved memory : " + jobStatus.getReservedMem() + ", used memory : "+ jobStatus.getUsedMem() + " and  		used slots : "+ jobStatus.getNumUsedSlots());
		
    // list map & reduce tasks statuses and progress		
    TaskReport[] reports = yarnRunner.getTaskReports(jobID, TaskType.MAP);
	for (int i = 0; i < reports.length; i++) {
	LOGGER.info("MAP: Status " + reports[i].getCurrentStatus() + " with task ID " + reports[i].getTaskID() + ", and 	            progress " + reports[i].getProgress()); 
	}
```

Same way the queue capacity can be tracked as well:

```java 
…………………
    ArrayNode queues = (ArrayNode) jsonNode.path("scheduler").path("schedulerInfo").path("queues").get("queue");
    for (int i = 0; i < queues.size(); i++) {
	JsonNode queueNode = queues.get(i);						
	LOGGER.info("queueName / usedCapacity / absoluteUsedCap / absoluteCapacity / absMaxCapacity: " + 
						queueNode.findValue("queueName") + " / " +
						queueNode.findValue("usedCapacity") + " / " + 
						queueNode.findValue("absoluteUsedCapacity") + " / " + 
						queueNode.findValue("absoluteCapacity") + " / " +
						queueNode.findValue("absoluteMaxCapacity"));
    }

```




