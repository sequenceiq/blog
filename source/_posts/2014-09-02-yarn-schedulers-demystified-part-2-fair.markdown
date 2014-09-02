---
layout: post
title: "YARN Schedulers demystified - Part 2: Fair"
date: 2014-09-02 09:23:49 +0200
comments: true
categories: [Hadoop, YARN, Schedulers]
author: Krisztian Horvath
published: false
---

Since it's Part 2 I suggest you to read the [Part 1](http://blog.sequenceiq.com/blog/2014/07/22/schedulers-part-1/) as I'll rely on it
and I'm going to compare the 2 schedulers as well in some aspects. You can also find out how fair is fair in real life
[here](http://blog.sequenceiq.com/blog/2014/08/16/fairplay/).

## The Fair Scheduler internals

The FairScheduler's purpose is to assign resources to applications such that all apps get, on average, an equal share of resources over time.
By default the scheduler bases fairness decisions only on memory, but it can be configured otherwise. When only a single app is running
in the cluster it can take all the resources. When new apps are submitted resources that free up are assigned to the new apps,
so that each app eventually on gets roughly the same amount of resources. Queues can be weighted to determine the fraction of total
resources that each app should get.

## Configuration

Although the CapacityScheduler is the default we can easily tell YARN to use the FairScheduler. In yarn-site.xml
```
<property>
      <name>yarn.resourcemanager.scheduler.class</name>
      <value>org.apache.hadoop.yarn.server.resourcemanager.scheduler.fair.FairScheduler</value>
</property>
<property>
      <name>yarn.scheduler.fair.allocation.file</name>
      <value>/etc/hadoop/conf.empty/fair-scheduler.xml</value>
</property>
```
The FairScheduler consists of 2 configuration files: scheduler-wide options can be placed into `yarn-site.xml` and queue settings in the
`allocation file` which must be in XML format. Click [here](http://hadoop.apache.org/docs/stable/hadoop-yarn/hadoop-yarn-site/FairScheduler.html)
for a more detailed reference.  

### Few things worth noting compared to CapacityScheduler:

* Both CapacityScheduler and FairScheduler supports hierarchical queues and all queues descend from a queue named `root`.
* Both uses a queue called `default` as well.
* Applications can be submitted to leaf queues only.
* Both CapacityScheduler and FairScheduler can create new queues at run time, the only difference is the how. In case of the CapacityScheduler
    the configuration file needed to be modified and we have to explicitly tell the ResourceManager to reload the configuration, while the
    FairScheduler does the same based on the queue placement policies which is less painful.
* FairScheduler introduced scheduling policies which determines which job should get resources at each scheduling opportunity. The cool thing
    about this that besides the default ones ("fifo" "fair" "drf") anyone can create new scheduling policies by extending the
    `org.apache.hadoop.yarn.server.resourcemanager.scheduler.fair.SchedulingPolicy` class and place it to the classpath.
* FairScheduler allows different queue placement policies as mentioned earlier. These policies tell the scheduler where to place the incoming app
    among the queues. Placement can depend on users, groups or requested queue by the applications.

<!-- more -->
