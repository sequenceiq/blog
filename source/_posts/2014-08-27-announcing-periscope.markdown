---
layout: post
title: "Periscope - autoscaling for Hadoop YARN"
date: 2014-08-27 18:37:37 +0200
comments: true
categories: [QoS, Autoscaling, SLA, Cloud, Schedulers, Periscope]
author: Janos Matyas
published: true
---


*Periscope is a powerful, fast, thick and top-to-bottom right-hander, eastward from Sumbawa's famous west-coast. Timing is critical, as needs a number of elements to align before it shows its true colors.*

*Periscope brings QoS and autoscaling to Hadoop YARN. Built on cloud resource management and YARN schedulers, allows to associate SLA policies to applications.*

After the very positive reception of [Cloudbreak](https://cloudbreak.sequenceiq.com/) - the first open sourced and cloud agnostic Hadoop as a Service API - today we are releasing the `public beta` version of our open source **SLA policy based autoscaling API** for Hadoop YARN clusters.

##Overview

The purpose of Periscope is to bring QoS and autoscaling to a multi-tenant Hadoop YARN cluster, while allowing to apply SLA policies to individual applications.
At [SequenceIQ](http://sequenceiq.com) working with multi-tenant Hadoop clusters for quite a while, we have always seen the same frustration and fight for resource between users.
The **FairScheduler** was partially solving this problem - bringing in fairness based on the notion of [Dominant Resource Fairness](http://static.usenix.org/event/nsdi11/tech/full_papers/Ghodsi.pdf).
With the emergence of Hadoop 2 YARN and the **CapacityScheduler** we had the option to maximize throughput and utilization for a multi-tenant cluster in an operator-friendly manner.
The scheduler works around the concept of queues. These queues are typically setup by administrators to reflect the economics of the shared cluster.
While this is a pretty good abstraction and brings some level of SLA for predictable workloads, it often needs proper design ahead.
The queue hierarchy and resource allocation needs to be changed when new tenants and workloads are moved to the cluster.

Periscope was designed around the idea of `autoscaling` clusters - without any need to preconfigure queues, cluster nodes or apply capacity planning ahead.

<!--more-->

##How it works

Periscope monitors the application progress, the number of YARN containers/resources and their allocation, queue depths, the number of available cluster nodes and their health. 
Since we have switched to YARN a while ago (been among the first adopters) we have run an open source [monitoring project](https://github.com/sequenceiq/yarn-monitoring), based on R.
We have been collecting metrics from the YARN Timeline server, Hadoop Metrics2 and Ambari's Nagios/Ganglia - and profiling the applications and correlating with these metrics.
One of the key findings was that while low level metrics are good to understand the cluster health - they might not necessarily help on making decisions when applying different SLA policies on a multi-tenant cluster. 
Focusing on higher level building blocks as queue depth, YARN containers, etc actually brings in the same quality of service, while not being lost in low level details.

Periscope works with two types of Hadoop clusters: `static` and `dynamic`. Periscope does not require any pre-installation - the only thing it requires is to be `attached` to an Ambari server's REST API.

##Clusters

### Static clusters
From Periscope point of view we consider a cluster `static` when the cluster capacity can't be increased horizontally.
This means that the hardware resources are already given - and the throughput can't be increased by adding new nodes.
Periscope introspects the job submission process, monitors the applications and applies the following SLAs:

  1. Application ordering - can guarantee that a higher priority application finishes before another one (supporting parallel or sequential execution)
  2. Moves running applications between priority queues
  3. *Attempts* to enforce time based SLA (execution time, finish by, finish between, recurring)
  4. *Attempts* to enforce guaranteed cluster capacity requests ( x % of the resources)
  5. Support for distributed (but not YARN ready) applications using Apache Slider
  6. Attach priorities to SLAs
  
_Note: not all of the features above are supported in the first `public beta` version. There are dependencies we contributed to Hadoop, YARN and Ambari and they will be included in the next releases (2.6 and 1.7)_


### Autoscaling clusters
From Periscope point of view we consider a cluster `dynamic` when the cluster capacity can be increased horizontally.
This means that nodes can be added or removed on the fly - thus the cluster’s throughput can be increased or decreased based on the cluster load and scheduled applications.
Periscope works with [Cloudbreak](http://sequenceiq.com/cloudbreak/) to add or remove nodes from the cluster based on the SLA policies and thus continuously provide a high *quality of service* for the multi-tenand Hadoop cluster.
Just to refresh memories - [Cloudbreak](http://sequenceiq.com/products.html) is [SequenceIQ's](http://sequenceiq.com) open source, cloud agnostic Hadoop as a Service API.
Given the option of provisioning or decommissioning cluster nodes on the fly, Periscope allows you to use the following set of SLAs:

  1. Application ordering - can guarantee that a higher priority application finishes before another one (supporting parallel or sequential execution)
  2. Moves running applications between priority queues
  3. *Enforce* time based SLA (execution time, finish by, finish between, recurring) by increasing cluster capacity and throughput
  4. Smart decommissioning - avoids HDFS storms, keeps `paid` nodes alive till the last minute
  5. *Enforce* guaranteed cluster capacity requests ( x % of the resources)
  6. *Private* cluster requests - supports provisioning of short lived private clusters with the possibility to merge them.
  7. Support for distributed (but not YARN ready) applications using Apache Slider
  8. Attach priorities to SLAs

_Note: not all of the features above are supported in the first `public beta` version. There are dependencies we contributed to Hadoop, YARN and Ambari and they will be included in the next releases (2.6 and 1.7)_


### High level technical details  

When we have started to work on Periscope we checked different solutions - and we quickly realized that there are no any open source solutions available.
Apache YARN in general, and the scheduler API's in particular have solved few of the issues we had - and they have certainly bring some level of SLA to Hadoop.
At [SequenceIQ](https://sequenceiq.com) we run all our different applications on YARN - and when we decided to create a heuristic scheduler we knew from very beginning that it has to be built on the functionality given by YARN.
In order to create Periscope we had to contribute code to YARN, Hadoop and Ambari - and were trying to add all the low level features directly into the YARN codebase.
Periscope has a [REST API](http://docs.periscope.apiary.io/) and supports pluggable SLA policies.
We will follow up with technical details in coming blog posts, so make sure you subscribe to on of our social channels.

### Resources

Get the code : https://github.com/sequenceiq/periscope

Documentation: http://sequenceiq.com/periscope

API documentation: http://docs.periscope.apiary.io/ 

### What's next, etc

This is the first `public beta` release of Periscope made available on our [GitHub](https://github.com/sequenceiq/periscope) page.
While we are already using this internally we would like the community to help us battle test it, let us know if you find issues or raise feature requests. We are always happy to help.

Further releases will bring tighter integration with Ambari (especially around cluster resources), an enhanced (or potentially new) YARN scheduler and a Machine learning based job classification model.

We would like to say a big *thank you* for the YARN team - this effort would have not been possible without their contribution. Also we would like to thank them by supporting us with our contributions as well.
At SequenceIQ we are 100% committed to open source - and releasing Periscope under an [Apache 2 licence](http://www.apache.org/licenses/LICENSE-2.0) was never a question.

Stay tuned and make sure you follow us on [LinkedIn](https://www.linkedin.com/company/sequenceiq/), [Twitter](https://twitter.com/sequenceiq) or [Facebook](https://www.facebook).

Enjoy.
