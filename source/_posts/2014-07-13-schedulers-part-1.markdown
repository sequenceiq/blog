---
layout: post
title: "YARN Schedulers - Part 1: Capacity"
date: 2014-07-13 13:13:39 +0200
comments: false
categories: [Hadoop, YARN, Scheduler]
author: Krisztian Horvath
published: false
---
CapacityScheduler is the default scheduler that ships with Hadoop. Its purpose is to allow multi-tenancy and share resources between
multiple organizations on the same cluster. You can read the high level abstraction
[here](http://hadoop.apache.org/docs/r2.3.0/hadoop-yarn/hadoop-yarn-site/CapacityScheduler.html). In this blog entry we'll examine it
from a technical point of view (the implementation can be found [here](https://github.com/apache/hadoop-common/tree/trunk/hadoop-yarn-project/hadoop-yarn/hadoop-yarn-server/hadoop-yarn-server-resourcemanager/src/main/java/org/apache/hadoop/yarn/server/resourcemanager/scheduler/capacity))
as part of the ResourceManager.

## Configuration

It all begins with the configuration. The scheduler consists of a queue hierarchy, something like this:
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

Be careful when determining the queue capacities, because if you mess it up the ResourceManager won't start `(Service RMActiveServices
failed in state INITED; cause: java.lang.IllegalArgumentException: Illegal capacity of 1.1 for children of queue root)`. The
[initScheduler](https://github.com/apache/hadoop-common/blob/trunk/hadoop-yarn-project/hadoop-yarn/hadoop-yarn-server/hadoop-yarn-server-resourcemanager/src/main/java/org/apache/hadoop/yarn/server/resourcemanager/scheduler/capacity/CapacityScheduler.java#L255)
will parse the configuration file and create either [parent](https://github.com/apache/hadoop-common/blob/trunk/hadoop-yarn-project/hadoop-yarn/hadoop-yarn-server/hadoop-yarn-server-resourcemanager/src/main/java/org/apache/hadoop/yarn/server/resourcemanager/scheduler/capacity/ParentQueue.java)
or [leaf](https://github.com/apache/hadoop-common/blob/trunk/hadoop-yarn-project/hadoop-yarn/hadoop-yarn-server/hadoop-yarn-server-resourcemanager/src/main/java/org/apache/hadoop/yarn/server/resourcemanager/scheduler/capacity/LeafQueue.java)
queues. Although it does not imply, but application submission is only allowed to leaf queues. By default all application is submitted to
a queue called `default`. One interesting property is the `schedule-asynchronously` which I'll talk about later.

<!-- more -->

## Messaging

Once the ResourceManager is up and running, the messaging starts. Mostly everything happens via events. These events are distributed with
a [dispatcher](https://github.com/apache/hadoop-common/blob/trunk/hadoop-yarn-project/hadoop-yarn/hadoop-yarn-common/src/main/java/org/apache/hadoop/yarn/event/AsyncDispatcher.java)
among the registered event handlers. It's hard to follow the flow, because events can come from everywhere. The CapacityScheduler itself
is registered for many events, and act based on these events. Code snippets are from branch `trunk` aka `3.0.0-SNAPSHOT`.
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
### NODE_REMOVED
### NODE_UPDATE
### APP_ADDED
### APP_REMOVED
### APP_ATTEMPT_ADDED
### APP_ATTEMPT_REMOVED
### CONTAINER_EXPIRED
