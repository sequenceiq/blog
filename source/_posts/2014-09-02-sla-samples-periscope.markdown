---
layout: post
title: "SLA policies for autoscaling Hadoop clusters"
date: 2014-09-02 18:37:37 +0200
comments: true
categories: [QoS, Autoscaling, SLA, Cloud, Schedulers, Periscope]
author: Janos Matyas
published: false
---

Last week we have [announced](http://blog.sequenceiq.com/blog/2014/08/27/announcing-periscope/) and open sourced [Periscope](http://sequenceiq.com/periscope/) - the industry’s first SLA policy based autoscaling API for Hadoop YARN clusters. In this post we’d like to come up with some examples, setting up alarms and attach scaling policies to your Hadoop cluster.

Periscope is built on existing (and coming/contributed by us) features provided by Apache Hadoop, YARN, Ambari, Docker containers and SequenceIQ’s [Cloudbreak](http://sequenceiq.com/cloudbreak/). Just FYI, [Cloudbreak](http://sequenceiq.com/cloudbreak/) is our open source and cloud agnostic Hadoop as a Service API, built on Docker containers. While Periscope can attach scaling policies to `static` and `dynamic` clusters - in this post we’d like to emphasize Periscope’s capabilities while working with -- `dynamic - cloud based Hadoop deployments  - such as Hadoop clusters deployed with [Cloudbreak](http://sequenceiq.com/cloudbreak/).

SLAs policies are configured based on `alarms`, whereas an alarm is created based on `metrics` - these entities are explained below. 

##Alarms 

An alarm watches a `metric` over a specified time period, and used by one or more action or scaling policy based on the value of the metric relative to a given threshold over the time period. A few of the supported `metrics` are listed below:

*`PENDING_CONTAINERS`- pending YARN containers

*`PENDING_APPLICATIONS` - pending/queued YARN applications

*`LOST_NODES` - cluster nodes lost

*`UNHEALTHY_NODES` - unhealthy cluster nodes

*`GLOBAL_RESOURCES` - global resources 

<!--more-->

Measured `metrics` are compared with pre-configured values using operators. The `comparison operators` are: `LESS_THAN`, `GREATER_THAN`, `LESS_OR_EQUAL_THAN`, `GREATER_OR_EQUAL_THAN`, `EQUALS`.
In order to avoid reacting for sudden spikes in the system and apply policies only in case of a sustained system stress, `alarms` have to be sustained over a `period` of time.  The `period` specifies the time period in minutes during the alarm has to be sustained. Also a `threshold` can be configured, which specifies the variance applied by the operator for the selected `metric`.

For the `alarm` related REST operations you can check the [API](http://docs.periscope.apiary.io/reference/alarms) documentation. Alarms can issue `notifications` as well - for example if a metric is reached for the configured time and threshold a notification event is raised - in the given example below this notification is an email.

```
# set metric alarms
curl -X POST -H "Content-Type: application/json" -d '{"alarms":[{"alarmName":"pendingContainerHigh","description":"Number of pending containers is high","metric":"PENDING_CONTAINERS","threshold":10,"comparisonOperator":"GREATER_THAN","period":1},{"alarmName":"freeGlobalResourcesRateLow","description":"Low free global resource rate","metric":"GLOBAL_RESOURCES","threshold":1,"comparisonOperator":"EQUALS","period":1,"notifications":[{"target":[“mick.fanning@aspworldtour.com"],"notificationType":"EMAIL"}]}]}' localhost:8081/clusters/1/alarms | jq .
curl -X PUT -H "Content-Type: application/json" -d '{"alarmName":"unhealthyNodesHigh","description":"Number of unhealthy nodes is high","metric":"UNHEALTHY_NODES","threshold":5,"comparisonOperator":"GREATER_OR_EQUAL_THAN","period":5}' localhost:8081/clusters/1/alarms | jq .
```

##SLA scaling policies

Scaling is the ability to increase or decrease the capacity of the Hadoop cluster or application.  When scaling policies are used, the capacity is automatically increased or decreased according to the conditions defined.
Periscope will do the heavy lifting and based on the alarms and the scaling policy linked to them it executes the associated policy. By default a fully configured and running [Cloudbreak](https://cloudbreak.sequenceiq.com/) cluster contains no SLA policies.  An SLA scaling policy can contain multiple `alarms`. 

As an alarm is triggered a `scalingAdjustment` is applied, however to keep the cluster size within boundaries a `minSize` and `maxSize` is attached to the cluster - thus a scaling policy can never over or undersize a cluster. Also in order to avoid stressing the cluster we have introduced a `cooldown` period (minutes) - though an alarm is raised and there is an associated scaling policy, the system will not apply the policy within the configured timeframe. In an SLA scaling policy the triggered policies are applied in order. 

Hosts can be added or removed from specific `hostgroups`. Periscope and Cloudbreak uses Apache Ambari to provision a Hadoop cluster. Ambari host groups are a set of machines with the same Hadoop “components” installed. You can set up a cluster having different hostgroups - and run different services, thus having a heterogenous cluster. 

In the following example we downscale a cluster when the unused resources are high.

```
# set scaling policy
curl -X POST -H "Content-Type: application/json" -d '{"minSize":2,"maxSize":10,"cooldown":30,"scalingPolicies":[{"name":"downScaleWhenHighResource","adjustmentType":"NODE_COUNT","scalingAdjustment":2,"hostGroup":"slave_1","alarmId":"101"},{"name":"upScaleWhenHighPendingContainers","adjustmentType":"PERCENTAGE","scalingAdjustment":40,"hostGroup":"slave_1","alarmId":"100"}]}' localhost:8081/clusters/1/policies | jq .
```

For the `policy` related REST operations you can check the [API](http://docs.periscope.apiary.io/reference/scaling-policy) documentation. 

Let us know how Periscope works for you - and for updates follow us on [LinkedIn](https://www.linkedin.com/company/sequenceiq/), [Twitter](https://twitter.com/sequenceiq) or [Facebook](https://www.facebook.com/sequenceiq).


