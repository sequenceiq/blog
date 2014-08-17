---
layout: post
title: "Periscope - brings QoS to multi-tenant Hadoop YARN clusters"
date: 2014-07-21 18:37:37 +0200
comments: true
categories: [QoS, Hadoop, SLA, Cloud, Schedulers, Periscope]
author: Janos Matyas
published: false
---
*Periscope is a powerful, fast, thick and top-to-bottom right-hander, eastward from Sumbawa's famous west-coast. Timing is critical, as needs a number of elements to align before it shows its true colors.*

*Periscope is a heuristic Hadoop scheduler you associate with a QoS profile. Built on YARN schedulers, cloud and VM resource management API's it allows you to associate SLAs to applications and customers.*

##Overview

The purpose of Periscope is to bring QoS to a multi-tenant Hadoop cluster, while allowing to apply SLAs to individual applications and customers.
At [SequenceIQ](http://sequenceiq.com) working with multi-tenant Hadoop clusters for quite a while we have always seen the same frustration and fight for resource between users.
The **FairScheduler** was partially solving this problem - bringing in fairness based on the notion of [Dominant Resource Fairness](http://static.usenix.org/event/nsdi11/tech/full_papers/Ghodsi.pdf).
With the emergence of Hadoop 2 YARN and the **CapacityScheduler** we had the option to maximize throughput and the utilization of the cluster for a multi-tenant cluster in an operator-friendly manner.
The scheduler works around the concept of queues. These queues are typically setup by administrators to reflect the economics of the shared cluster.
While there is a pretty good abstraction and brings some level of SLA for `predictable` workloads, it often needs proper `design ahead`.
The queue hierarchy and resource allocation needs to be changed when new tenants and workloads are moved to the cluster.

Periscope was designed around the idea of `dynamic` clusters - without any need to preconfigure queues, cluster nodes or apply capacity planning ahead.

##How it works

Periscope monitors the application progress, the number of YARN containers/resources and their allocation on nodes, queue depths, and the number of nodes and their health.
Since we have switched to YARN a while ago (been among the first adopters) we have run an open source [monitoring project](https://github.com/sequenceiq/yarn-monitoring), based on R.
We have been collecting metrics from the YARN Timeline server, Hadoop Metrics2 and Ambari's Nagios/Ganglia - and profiling applications and correlating with these metrics.
One of the key findings we have found - and have applied to Periscope - was that while low level metrics are good to understand the cluster health - they might not necessarily help on making decisions when applying different SLAs on a multi-tenant cluster.
Focusing on higher level building blocks as queue depth, YARN containers, etc actually brings in the same quality of service, while not being lost in low level details.
We will follow up with examples and metrics on coming blog posts - make sure you follow us on [LinkedIn](https://www.linkedin.com/company/sequenceiq/), [Twitter](https://twitter.com/sequenceiq) or [Facebook](https://www.facebook).

_Example: Applying SLA based on `resource` load might not be the best solution - each application tasks generates different loads, and a CPU heavy reduce step might be followed by an I/O heavy mapper - making a decision based on a low `snapshot` might not be the right option.
Also note that a YARN cluster can run different applications - MR2, HBase, Spark, etc - and they all generate different load across different timeframes.
When YARN allocates containers it associates `resources` - it's actually more predictable to let YARN to deal with the resource allocation, and have Periscope orchestrate the process._

Periscope works with two types of Hadoop clusters: `static` and `dynamic`.

##Clusters

### Static clusters
From Periscope point of view we consider a cluster static when the cluster capacity can't be increased horizontally.
This means that the hardware resources are already given - and the throughput can't be increased by adding new nodes.
Periscope introspects the job submission process, monitors the applications and applies the following SLAs:

  1. Application ordering - can guaranty that a higher priority application finishes before another one (supporting parallel or sequential execution)
  2. Moves running applications between priority queues
  3. *Attempts* to enforce time based SLA (execution time, finish by, finish between, recurring)
  4. *Attempts* to enforce guaranteed cluster capacity requests ( x % of the resources)
  5. Support for distributed (but not YARN ready) applications using Apache Slider
  
_Note: not all of the features above are supported in the first `public beta` version. There are dependencies we contributed to Ambari and YARN but will be included in the next release (1.7 and 2.6)_

### Dynamic clusters
From Periscope point of view we consider a cluster dynamic when the cluster capacity can be increased horizontally.
This means that nodes can be added dynamically - thus the throughput can be increased or decreased based on the cluster load, and scheduled applications.
In order to do that Periscope instructs [Cloudbreak](http://sequenceiq.com/cloudbreak/) to add or remove nodes from the cluster based on the SLAs and thus continuously provide a high *quality of service* for the multi-tenand Hadoop cluster.
Just to refresh memories - [Cloudbreak](http://sequenceiq.com/products.html) is [SequenceIQ's](http://sequenceiq.com) open source, cloud agnostic Hadoop as a Service API.
Given the option of provisioning or decommissioning cluster nodes on the fly, Periscope allows you to use the following set of SLAs:

  1. Application ordering - can guaranty that a higher priority application finishes before another one (supporting parallel or sequential execution)
  2. Moves running applications between priority queues
  3. *Enforce* time based SLA (execution time, finish by, finish between, recurring) by increasing cluster capacity and throughput
  4. Smart decommissioning - avoids HDFS storms, keeps `payed` nodes alive till the last minute
  5. *Enforce* guaranteed cluster capacity requests ( x % of the resources)
  6. *Private* cluster requests - supports provisioning of short lived private clusters with the possibility to merge
  7. Support for distributed (but not YARN ready) applications using Apache Slider

_Note: not all of the features above are supported in the first `public beta` version. There are dependencies we contributed to Ambari and YARN but will be included in the next release (1.7 and 2.6)_


### High level technical details  

When we have started to work on Periscope we checked different solutions - and we quickly realized that there are no such products available.
Apache YARN in general, and the scheduler API's in particular have solved few of the issues we had - and they have certainly bring some level of SLA to Hadoop.
At [SequenceIQ](https://sequenceiq.com) we run all our different applications in YARN - and when we decided to create a heuristic scheduler we new from beginning that it has to be built on the functionality given by YARN.
In order to create the scheduler we had to contribute code to YARN, Hadoop and Ambari - and were trying to add all the low level features directly into the YARN codebase.
Periscope has a [REST API](http://docs.periscope.apiary.io/) and supports pluggable SLA rules described in YAML format.
We will follow up with technical details in coming blog posts, so make sure you subscribe to on of our channels.

### Resources

Periscope code : https://github.com/sequenceiq/periscope

Periscope documentation: http://sequenceiq.com/periscope

Periscope API: http://docs.periscope.apiary.io/ 

### What's next, kudos, etc

This is the first `public beta` release of Periscope made available on our [GitHub](https://github.com/sequenceiq/periscope) page.
While we are already using this internally we would like the community to help us battle test it, let us know if you find issues or raise feature requests. We are happy to help. 

Further releases will bring tighter integration with Ambari (especially around cluster resources), an enhanced (or potentially new) YARN scheduler and a Machine learning based job classification model.

We would like to say a big *thank you* for the YARN team - this effort would have not been possible without their contribution, and their support with our contributions.
At SequenceIQ we are 100% committed to open source - and releasing Periscope under an [Apache 2 licence](http://www.apache.org/licenses/LICENSE-2.0) was never a question.

Stay tuned and make sure you follow us on [LinkedIn](https://www.linkedin.com/company/sequenceiq/), [Twitter](https://twitter.com/sequenceiq) or [Facebook](https://www.facebook).

Enjoy.
