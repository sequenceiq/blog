---
layout: post
title: "YARN Schedulers demystified - Part 1: Capacity"
date: 2014-07-23 13:13:39 +0200
comments: true
categories: [Hadoop, YARN, Schedulers]
author: Krisztian Horvath
published: false
---

After our first [post](http://blog.sequenceiq.com/blog/2014/07/02/move-applications-between-queues/) about re-prioritizing already submitted and running jobs on different queues we have received many questions and feedbacks about the Capacity Scheduler internals. While there is `some` documentation available, there is no extensive and deep documentation about how it actually works internally. Since it's all event based it's pretty hard to understand the flow - let alone debugging it. At [SequenceIQ](http://sequenceiq.com/) we are working on a heuristic cluster scheduler - and understanding how YARN schedulers work was essential. This is part of a larger piece of work - which will lead to a fully dynamic Hadoop clusters - orchestrating [Cloudbreak](http://blog.sequenceiq.com/blog/2014/07/18/announcing-cloudbreak/) - the first open source and Docker based **Hadoop as a Service API**. As usual for us, this work and what we have already done around Capacity and Fair schedulers will be open sourced (or already contributed back to Apache YARN project).

##The Capacity Scheduler internals

The CapacityScheduler is the default scheduler used with Hadoop 2.x. Its purpose is to allow multi-tenancy and share resources between multiple organizations and applications on the same cluster. You can read about the high level abstraction
[here](http://hadoop.apache.org/docs/r2.3.0/hadoop-yarn/hadoop-yarn-site/CapacityScheduler.html). In this blog entry we'll examine it
from a deep technical point of view (the implementation can be found [here](https://github.com/apache/hadoop-common/tree/trunk/hadoop-yarn-project/hadoop-yarn/hadoop-yarn-server/hadoop-yarn-server-resourcemanager/src/main/java/org/apache/hadoop/yarn/server/resourcemanager/scheduler/capacity)
as part of the ResourceManager). I'll try to keep it short and deal with the most important aspects, preventing to write a book about it
(but still would be better than twilight).

{% img https://raw.githubusercontent.com/sequenceiq/sequenceiq-samples/master/yarn-queue-tests/src/main/resources/event-flow.gif %}

The animation shows a basic application submission event flow, but don't worry if you don't understand it yet, hopefully you will when you're done with the reading.

<!-- more -->

## Configuration

It all begins with the configuration. The scheduler consists of a queue hierarchy, something like this
(except it’s xml ah.. capacity-scheduler.xml):
```
yarn.scheduler.capacity.maximum-am-resource-percent=0.2
yarn.scheduler.capacity.maximum-applications=10000
yarn.scheduler.capacity.node-locality-delay=40
yarn.scheduler.capacity.root.acl_administer_queue=*
yarn.scheduler.capacity.root.capacity=100
yarn.scheduler.capacity.root.default.acl_administer_jobs=*
yarn.scheduler.capacity.root.default.acl_submit_applications=*
yarn.scheduler.capacity.root.default.capacity=80
yarn.scheduler.capacity.root.default.maximum-capacity=80
yarn.scheduler.capacity.root.default.state=RUNNING
yarn.scheduler.capacity.root.default.user-limit-factor=1
yarn.scheduler.capacity.root.low.acl_administer_jobs=*
yarn.scheduler.capacity.root.low.acl_submit_applications=*
yarn.scheduler.capacity.root.low.capacity=20
yarn.scheduler.capacity.root.low.maximum-capacity=40
yarn.scheduler.capacity.root.low.state=RUNNING
yarn.scheduler.capacity.root.low.user-limit-factor=1
yarn.scheduler.capacity.root.queues=default,low
```

{% img http://yuml.me/9d7e9977 %}

Generally, queues are for to prevent applications to consume more resources then they should.
Be careful when determining the capacities, because if you mess it up the `ResourceManager` won't start:
```
Service RMActiveServices failed in state INITED cause: java.lang.IllegalArgumentException: Illegal capacity of 1.1 for children of queue root.
```
The [initScheduler](https://github.com/apache/hadoop-common/blob/trunk/hadoop-yarn-project/hadoop-yarn/hadoop-yarn-server/hadoop-yarn-server-resourcemanager/src/main/java/org/apache/hadoop/yarn/server/resourcemanager/scheduler/capacity/CapacityScheduler.java#L255)
will parse the configuration file and create either [parent](https://github.com/apache/hadoop-common/blob/trunk/hadoop-yarn-project/hadoop-yarn/hadoop-yarn-server/hadoop-yarn-server-resourcemanager/src/main/java/org/apache/hadoop/yarn/server/resourcemanager/scheduler/capacity/ParentQueue.java)
or [leaf](https://github.com/apache/hadoop-common/blob/trunk/hadoop-yarn-project/hadoop-yarn/hadoop-yarn-server/hadoop-yarn-server-resourcemanager/src/main/java/org/apache/hadoop/yarn/server/resourcemanager/scheduler/capacity/LeafQueue.java)
queues and compute their capabilities.

```
capacity.LeafQueue (LeafQueue.java:setupQueueConfigs(312)) - Initializing default
capacity = 0.8 [= (float) configuredCapacity / 100 ]
asboluteCapacity = 0.8 [= parentAbsoluteCapacity * capacity ]
maxCapacity = 0.8 [= configuredMaxCapacity ]
absoluteMaxCapacity = 0.8 [= 1.0 maximumCapacity undefined, (parentAbsoluteMaxCapacity * maximumCapacity) / 100 otherwise ]
userLimit = 100 [= configuredUserLimit ]
userLimitFactor = 1.0 [= configuredUserLimitFactor ]
maxApplications = 8000 [= configuredMaximumSystemApplicationsPerQueue or (int)(configuredMaximumSystemApplications * absoluteCapacity)]
maxApplicationsPerUser = 8000 [= (int)(maxApplications * (userLimit / 100.0f) * userLimitFactor) ]
maxActiveApplications = 1 [= max((int)ceil((clusterResourceMemory / minimumAllocation) * maxAMResourcePerQueuePercent * absoluteMaxCapacity),1) ]
maxActiveAppsUsingAbsCap = 1 [= max((int)ceil((clusterResourceMemory / minimumAllocation) *maxAMResourcePercent * absoluteCapacity),1) ]
maxActiveApplicationsPerUser = 1 [= max((int)(maxActiveApplications * (userLimit / 100.0f) * userLimitFactor),1) ]
usedCapacity = 0.0 [= usedResourcesMemory / (clusterResourceMemory * absoluteCapacity)]
absoluteUsedCapacity = 0.0 [= usedResourcesMemory / clusterResourceMemory]
maxAMResourcePerQueuePercent = 0.2 [= configuredMaximumAMResourcePercent ]
minimumAllocationFactor = 0.75 [= (float)(maximumAllocationMemory - minimumAllocationMemory) / maximumAllocationMemory ]
numContainers = 0 [= currentNumContainers ]
state = RUNNING [= configuredState ]
acls = ADMINISTER_QUEUE: SUBMIT_APPLICATIONS:* [= configuredAcls ]
nodeLocalityDelay = 40
```
Although it does not imply, but application submission is only allowed to leaf queues. By default all application is submitted to
a queue called `default`. One interesting property is the `schedule-asynchronously` about which I'll talk later.

## Messaging

Once the ResourceManager is up and running, the messaging starts. Mostly everything happens via events. These events are distributed with
a [dispatcher](https://github.com/apache/hadoop-common/blob/trunk/hadoop-yarn-project/hadoop-yarn/hadoop-yarn-common/src/main/java/org/apache/hadoop/yarn/event/AsyncDispatcher.java)
among the registered event handlers. The down side of the event driven architecture that it's hard to follow the flow because
events can come from everywhere. The CapacityScheduler itself is registered for many events, and act based on these events.
Code snippets are from branch `trunk` aka `3.0.0-SNAPSHOT`.
```java
 @Override
  public void handle(SchedulerEvent event) {
    switch(event.getType()) {
    case NODE_ADDED:
    {
      NodeAddedSchedulerEvent nodeAddedEvent = (NodeAddedSchedulerEvent)event;
      addNode(nodeAddedEvent.getAddedRMNode());
      recoverContainersOnNode(nodeAddedEvent.getContainerReports(),
        nodeAddedEvent.getAddedRMNode());
    }
    break;
    case NODE_REMOVED:
    {
      NodeRemovedSchedulerEvent nodeRemovedEvent = (NodeRemovedSchedulerEvent)event;
      removeNode(nodeRemovedEvent.getRemovedRMNode());
    }
    break;
    case NODE_UPDATE:
    {
      NodeUpdateSchedulerEvent nodeUpdatedEvent = (NodeUpdateSchedulerEvent)event;
      RMNode node = nodeUpdatedEvent.getRMNode();
      nodeUpdate(node);
      if (!scheduleAsynchronously) {
        allocateContainersToNode(getNode(node.getNodeID()));
      }
    }
    break;
    case APP_ADDED:
    {
      AppAddedSchedulerEvent appAddedEvent = (AppAddedSchedulerEvent) event;
      addApplication(appAddedEvent.getApplicationId(),
        appAddedEvent.getQueue(), appAddedEvent.getUser());
    }
    break;
    case APP_REMOVED:
    {
      AppRemovedSchedulerEvent appRemovedEvent = (AppRemovedSchedulerEvent)event;
      doneApplication(appRemovedEvent.getApplicationID(),
        appRemovedEvent.getFinalState());
    }
    break;
    case APP_ATTEMPT_ADDED:
    {
      AppAttemptAddedSchedulerEvent appAttemptAddedEvent =
          (AppAttemptAddedSchedulerEvent) event;
      addApplicationAttempt(appAttemptAddedEvent.getApplicationAttemptId(),
        appAttemptAddedEvent.getTransferStateFromPreviousAttempt(),
        appAttemptAddedEvent.getShouldNotifyAttemptAdded());
    }
    break;
    case APP_ATTEMPT_REMOVED:
    {
      AppAttemptRemovedSchedulerEvent appAttemptRemovedEvent =
          (AppAttemptRemovedSchedulerEvent) event;
      doneApplicationAttempt(appAttemptRemovedEvent.getApplicationAttemptID(),
        appAttemptRemovedEvent.getFinalAttemptState(),
        appAttemptRemovedEvent.getKeepContainersAcrossAppAttempts());
    }
    break;
    case CONTAINER_EXPIRED:
    {
      ContainerExpiredSchedulerEvent containerExpiredEvent =
          (ContainerExpiredSchedulerEvent) event;
      ContainerId containerId = containerExpiredEvent.getContainerId();
      completedContainer(getRMContainer(containerId),
          SchedulerUtils.createAbnormalContainerStatus(
              containerId,
              SchedulerUtils.EXPIRED_CONTAINER),
          RMContainerEventType.EXPIRE);
    }
    break;
    default:
      LOG.error("Invalid eventtype " + event.getType() + ". Ignoring!");
    }
  }
```

### NODE_ADDED
Each time a node joins the cluster the [ResourceTrackerService](https://github.com/apache/hadoop-common/blob/trunk/hadoop-yarn-project/hadoop-yarn/hadoop-yarn-server/hadoop-yarn-server-resourcemanager/src/main/java/org/apache/hadoop/yarn/server/resourcemanager/ResourceTrackerService.java#L237)
registers the `NodeManager` and as part of the transition sends a `NodeAddedSchedulerEvent`. The scheduler keeps track of
the global cluster resources and adds the node's resources to the global.
```
Added node amb1.mycorp.kom:45454 clusterResource: <memory:5120, vCores:8>
Added node amb2.mycorp.kom:45454 clusterResource: <memory:10240, vCores:16>
```
It is also needed to update all the queue metrics since the cluster got bigger, thus the queue capacities also change. More likely to happen
that a new application can be scheduled. If the `isWorkPreservingRecoveryEnabled` is enabled on the `ResourceManager` it can recover
containers on a re-joining node.

### NODE_REMOVED
There can be many reasons that a node is being removed from the cluster, but the scenario is almost the same as adding one. A
`NodeRemovedSchedulerEvent` is sent and the scheduler subtracts the node's resources from the global and updates all the queue metrics.
Things can be a little bit complicated since the node was active part of the resource scheduling and can have running containers and
reserved resources. The scheduler will kill these containers and notify the applications so they can request new containers and
unreserve the resources.
```
rmnode.RMNodeImpl (RMNodeImpl.java:transition(569)) - Deactivating Node amb4.mycorp.kom:45454 as it is now DECOMMISSIONED
rmnode.RMNodeImpl (RMNodeImpl.java:handle(385)) - amb4.mycorp.kom:45454 Node Transitioned from RUNNING to DECOMMISSIONED
capacity.CapacityScheduler (CapacityScheduler.java:removeNode(980)) - Removed node amb4.mycorp.kom:45454 clusterResource: <memory:15360, vCores:24>
```
### APP_ADDED
On application [submission](https://github.com/apache/hadoop-common/blob/trunk/hadoop-yarn-project/hadoop-yarn/hadoop-yarn-server/hadoop-yarn-server-resourcemanager/src/main/java/org/apache/hadoop/yarn/server/resourcemanager/RMAppManager.java#L266)
an `AppAddedSchedulerEvent` is made and the scheduler will decide to accept the application or not. It depends whether it
was submitted to a leaf queue and the user have the appropriate rights (ACL) to submit to this queue and the queue can have more applications. If
any of these fails the scheduler will reject the application by sending an `RMAppRejectedEvent`. Otherwise it will register a new
`SchedulerApplication` and notify the target queue's parents about it and updates the queue metrics.
```
capacity.ParentQueue (ParentQueue.java:addApplication(495)) - Application added - appId: application_1405323437551_0001 user: hdfs leaf-queue of parent: root #applications: 1
capacity.CapacityScheduler (CapacityScheduler.java:addApplication(544)) - Accepted application application_1405323437551_0001 from user: hdfs, in queue: default
```
### APP_REMOVED
The analogy is the same as between `NODE_ADDED` and `NODE_REMOVED`. Updates the queue metrics and notifies the parent's that an application finished, removes the application and sets its final state.

### APP_ATTEMPT_ADDED
After the `APP_ADDED` event the application is in `inactive` mode. It means it won`t get any resources scheduled for - only an attempt to run it. One application can have many attempts as it can fail for many reasons.
```
rmapp.RMAppImpl (RMAppImpl.java:handle(639)) - application_1405323437551_0001 State change from SUBMITTED to ACCEPTED
resourcemanager.ApplicationMasterService (ApplicationMasterService.java:registerAppAttempt(611)) - Registering app attempt : appattempt_1405323437551_0001_000001
attempt.RMAppAttemptImpl (RMAppAttemptImpl.java:handle(659)) - appattempt_1405323437551_0001_000001 State change from NEW to SUBMITTED
capacity.LeafQueue (LeafQueue.java:activateApplications(763)) - Application application_1405323437551_0001 from user: hdfs activated in queue: default
capacity.LeafQueue (LeafQueue.java:addApplicationAttempt(779)) - Application added - appId: application_1405323437551_0001 user: org.apache.hadoop.yarn.server.resourcemanager.scheduler.capacity.LeafQueue$User@46a224a4, leaf-queue: default #user-pending-applications: 0 #user-active-applications: 1 #queue-pending-applications: 0 #queue-active-applications: 1
capacity.CapacityScheduler (CapacityScheduler.java:addApplicationAttempt(567)) - Added Application Attempt appattempt_1405323437551_0001_000001 to scheduler from user hdfs in queue default
```
Attempt states are transferred from one to another. By sending an `AppAttemptAddedSchedulerEvent` the scheduler actually tries to allocate resources. First, the application goes into the pending applications list of the queue and if the queue limits allows it, it goes into the active applications list. This active application list is the one that the queue uses when trying to allocate resources.
It works in FIFO order, but I'll elaborate on it in the `NODE_UPDATE` part.

### APP_ATTEMPT_REMOVED
On `AppAttemptRemovedSchedulerEvent` the scheduler cleans up after the application. Releases all the allocated, acquired, running containers
(in case of `ApplicationMaster` restart the running containers won't get killed), releases all reserved containers,
cleans up pending requests and informs the queues.
```
rmapp.RMAppImpl (RMAppImpl.java:handle(639)) - application_1405323437551_0001 State change from FINISHING to FINISHED
capacity.CapacityScheduler (CapacityScheduler.java:doneApplicationAttempt(598)) - Application Attempt appattempt_1405323437551_0001_000001 is done. finalState=FINISHED
scheduler.AppSchedulingInfo (AppSchedulingInfo.java:clearRequests(108)) - Application application_1405323437551_0001 requests cleared
capacity.LeafQueue (LeafQueue.java:removeApplicationAttempt(821)) - Application removed - appId: application_1405323437551_0001 user: hdfs queue: default #user-pending-applications: 0 #user-active-applications: 0 #queue-pending-applications: 0 #queue-active-applications: 0
amlauncher.AMLauncher (AMLauncher.java:run(262)) - Cleaning master appattempt_1405323437551_0001_000001
```

### NODE_UPDATE
Normally `NodeUpdateSchedulerEvents` arrive every second from every node. By setting the earlier mentioned `schedule-asynchronously` to true
the behavior of this event handling can be altered in a way that container allocations happen asynchronously from these events. Meaning
the CapacityScheduler tries to allocate new containers in every 100ms on a different [thread](https://github.com/apache/hadoop-common/blob/trunk/hadoop-yarn-project/hadoop-yarn/hadoop-yarn-server/hadoop-yarn-server-resourcemanager/src/main/java/org/apache/hadoop/yarn/server/resourcemanager/scheduler/capacity/CapacityScheduler.java#L361).
Before going into details let's discuss another important aspect.

#### Allocate
The [allocate](https://github.com/apache/hadoop-common/blob/trunk/hadoop-yarn-project/hadoop-yarn/hadoop-yarn-server/hadoop-yarn-server-resourcemanager/src/main/java/org/apache/hadoop/yarn/server/resourcemanager/scheduler/capacity/CapacityScheduler.java#L675)
method is used as a heartbeat. This is the most important call between the `ApplicationMaster` and the scheduler. Instead of using a simple empty message, the heartbeat can contain resource requests of the application. The reason it is important here is that the scheduler, more precisely the queue - when tries to allocate resources - it will check the active applications in FIFO order and see their resource requests.
```
{Priority: 20, Capability: <memory:1024, vCores:1>, # Containers: 2, Location: *, Relax Locality: true}
{Priority: 20, Capability: <memory:1024, vCores:1>, # Containers: 2, Location: /default-rack, Relax Locality: true}
{Priority: 20, Capability: <memory:1024, vCores:1>, # Containers: 2, Location: amb1.mycorp.kom, Relax Locality: true}
```
Let's examine these requests:

* Priority: requests with higher priority gets served first (mappers got 20, reducer 10, AM 0)
* Capability: denotes the required container's size
* Location: where the AM would like to get the containers. There are 3 types of locations: node-local, rack-local, off-switch.
  The location is based on the location of the blocks of the data. It is the `ApplicationMaster`'s duty to locate them. Off-switch means
  that any node in the cluster is good enough. Typically the `ApplicationMaster`'s container request is an off-switch request.
* Relax locality: in case it is set to false, only node-local container can be allocated. By default it is set to true.

#### NODE_UPDATE
Let's get back to `NODE_UPDATE`. What happens at every node update and why it happens so frequently? First of all, nodes are running the containers. Containers start and stop all the time thus the scheduler needs an update about the state of the nodes. Also it updates their resource capabilities as well. After the updates are noted, the scheduler tries to allocate containers on the nodes. The same applies to every node in the cluster. At every `NODE_UPDATE` the scheduler checks if an application reserved a container on this node. If there is reservation then tries to fulfill it. Every node can have only one reserved container. After the reservation it tries to allocate more containers by going through all the queues starting from `root`. The node can have one more container if it has at least the minimum allocation's resource capability. Going through the child queues of `root` it checks the queue's active applications and its resource requests by priority order. If the application has request for this node it tries to allocate it. If the relax locality is set to true it could also allocate container even though there is no explicit request for this node, but that's not what's going to happen first. There is another term called delay scheduling. The scheduler tries to delay any non-data-local
request, but cannot delay it for so long. The `localityWaitFactor` will determine how long to wait until fall back to rack-local then the end to off-switch requests. If everything works out it allocates a container and tracks its resource usage. If there is not enough resource capability one application can reserve a container on this node, and at the next update may can use this reservation. After the allocation is made the `ApplicationMaster` will submit a request to the node to launch this container and assign a task to it to run.
The scheduler does not need to know what task the AM will run in the container.

### CONTAINER_EXPIRED
The [ContainerAllocationExpirer's](https://github.com/apache/hadoop-common/blob/trunk/hadoop-yarn-project/hadoop-yarn/hadoop-yarn-server/hadoop-yarn-server-resourcemanager/src/main/java/org/apache/hadoop/yarn/server/resourcemanager/rmcontainer/ContainerAllocationExpirer.java)
responsibility to check if a container expires and when it does it sends an `ContainerExpiredSchedulerEvent` and the scheduler will notify the application to remove the container. The value of how long to wait until a container is considered dead can be configured.

## Animation
The animation on top shows a basic event flow starting from adding 2 nodes and submitting 2 applications with attempts. Eventually the node updates tries to allocate resources to those applications. After reading this post I hope it makes sense now.

## What's next?
In the next part of this series I'll compare it with FairScheduler, to see the differences.

For updates and further blog posts follow us on [LinkedIn](https://www.linkedin.com/company/sequenceiq/), [Twitter](https://twitter.com/sequenceiq) or [Facebook](https://www.facebook.com/sequenceiq).

Enjoy.
