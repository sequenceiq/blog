---
layout: post
title: "YARN Schedulers demystified - Part 2: Fair"
date: 2014-09-05 18:00:00 +0200
comments: true
categories: [Hadoop, YARN, Schedulers]
author: Krisztian Horvath
published: false
---

In our previous blog post we have been demystifying the [Capacity scheduler internals](http://blog.sequenceiq.com/blog/2014/07/22/schedulers-part-1/) - as promised in this post is the Fair scheduler’s time. You can check also our previous post to find out how fair is the Fair scheduler in real life [here](http://blog.sequenceiq.com/blog/2014/08/16/fairplay/).

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

### Few things worth noting compared to CapacityScheduler regarding queues

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
* In FairScheduler applications can be submitted to non-existing queues if the `create` flag is set and it will create that queue, while the
    CapacityScheduler will instantly reject the submission.
* From Hadoop 2.6.0 ([YARN-1495](https://issues.apache.org/jira/browse/YARN-1495)) both schedulers will let users to manually move
    applications across queues.  
    `Side note: ` This feature allows us to re-prioritize and define SLAs on applications and place them to queues where they get the enforced
    resources. Our newly open sourced project [Periscope](http://blog.sequenceiq.com/blog/2014/08/27/announcing-periscope/) will add this
    capability for static clusters besides dynamic ones in the near future.

<!-- more -->

## Messaging

The event mechanism is the same as with CapacityScheduler - thus I'm not going to take account the events - and if you check the handler methods
([here](https://github.com/apache/hadoop-common/blob/trunk/hadoop-yarn-project/hadoop-yarn/hadoop-yarn-server/hadoop-yarn-server-resourcemanager/src/main/java/org/apache/hadoop/yarn/server/resourcemanager/scheduler/capacity/CapacityScheduler.java#L956)
and [here](https://github.com/apache/hadoop-common/blob/trunk/hadoop-yarn-project/hadoop-yarn/hadoop-yarn-server/hadoop-yarn-server-resourcemanager/src/main/java/org/apache/hadoop/yarn/server/resourcemanager/scheduler/fair/FairScheduler.java#L1134))
you can notice that they look fairly the same.
```java
@Override
  public void handle(SchedulerEvent event) {
    switch (event.getType()) {
    case NODE_ADDED:
      if (!(event instanceof NodeAddedSchedulerEvent)) {
        throw new RuntimeException("Unexpected event type: " + event);
      }
      NodeAddedSchedulerEvent nodeAddedEvent = (NodeAddedSchedulerEvent)event;
      addNode(nodeAddedEvent.getAddedRMNode());
      recoverContainersOnNode(nodeAddedEvent.getContainerReports(),
          nodeAddedEvent.getAddedRMNode());
      break;
    case NODE_REMOVED:
      if (!(event instanceof NodeRemovedSchedulerEvent)) {
        throw new RuntimeException("Unexpected event type: " + event);
      }
      NodeRemovedSchedulerEvent nodeRemovedEvent = (NodeRemovedSchedulerEvent)event;
      removeNode(nodeRemovedEvent.getRemovedRMNode());
      break;
    case NODE_UPDATE:
      if (!(event instanceof NodeUpdateSchedulerEvent)) {
        throw new RuntimeException("Unexpected event type: " + event);
      }
      NodeUpdateSchedulerEvent nodeUpdatedEvent = (NodeUpdateSchedulerEvent)event;
      nodeUpdate(nodeUpdatedEvent.getRMNode());
      break;
    case APP_ADDED:
      if (!(event instanceof AppAddedSchedulerEvent)) {
        throw new RuntimeException("Unexpected event type: " + event);
      }
      AppAddedSchedulerEvent appAddedEvent = (AppAddedSchedulerEvent) event;
      addApplication(appAddedEvent.getApplicationId(),
        appAddedEvent.getQueue(), appAddedEvent.getUser(),
        appAddedEvent.getIsAppRecovering());
      break;
    case APP_REMOVED:
      if (!(event instanceof AppRemovedSchedulerEvent)) {
        throw new RuntimeException("Unexpected event type: " + event);
      }
      AppRemovedSchedulerEvent appRemovedEvent = (AppRemovedSchedulerEvent)event;
      removeApplication(appRemovedEvent.getApplicationID(),
        appRemovedEvent.getFinalState());
      break;
    case APP_ATTEMPT_ADDED:
      if (!(event instanceof AppAttemptAddedSchedulerEvent)) {
        throw new RuntimeException("Unexpected event type: " + event);
      }
      AppAttemptAddedSchedulerEvent appAttemptAddedEvent =
          (AppAttemptAddedSchedulerEvent) event;
      addApplicationAttempt(appAttemptAddedEvent.getApplicationAttemptId(),
        appAttemptAddedEvent.getTransferStateFromPreviousAttempt(),
        appAttemptAddedEvent.getIsAttemptRecovering());
      break;
    case APP_ATTEMPT_REMOVED:
      if (!(event instanceof AppAttemptRemovedSchedulerEvent)) {
        throw new RuntimeException("Unexpected event type: " + event);
      }
      AppAttemptRemovedSchedulerEvent appAttemptRemovedEvent =
          (AppAttemptRemovedSchedulerEvent) event;
      removeApplicationAttempt(
          appAttemptRemovedEvent.getApplicationAttemptID(),
          appAttemptRemovedEvent.getFinalAttemptState(),
          appAttemptRemovedEvent.getKeepContainersAcrossAppAttempts());
      break;
    case CONTAINER_EXPIRED:
      if (!(event instanceof ContainerExpiredSchedulerEvent)) {
        throw new RuntimeException("Unexpected event type: " + event);
      }
      ContainerExpiredSchedulerEvent containerExpiredEvent =
          (ContainerExpiredSchedulerEvent)event;
      ContainerId containerId = containerExpiredEvent.getContainerId();
      completedContainer(getRMContainer(containerId),
          SchedulerUtils.createAbnormalContainerStatus(
              containerId,
              SchedulerUtils.EXPIRED_CONTAINER),
          RMContainerEventType.EXPIRE);
      break;
    default:
      LOG.error("Unknown event arrived at FairScheduler: " + event.toString());
    }
  }
```

### NODE_ADDED && NODE_REMOVED
It's the same as in CapacityScheduler, adjusts the global resources based on whether a node joined or left the cluster.

### APP_ADDED
Application submission is slightly different from CapacityScheduler (well not on client side as it's the same there), but because of
the queue placement policy. Administrators can define a [QueuePlacementPolicy](https://github.com/apache/hadoop-common/blob/trunk/hadoop-yarn-project/hadoop-yarn/hadoop-yarn-server/hadoop-yarn-server-resourcemanager/src/main/java/org/apache/hadoop/yarn/server/resourcemanager/scheduler/fair/QueuePlacementPolicy.java)
which will determine where to place the submitted application. A QueuePlacementPolicy stands from a list of [QueuePlacementRules](https://github.com/apache/hadoop-common/blob/trunk/hadoop-yarn-project/hadoop-yarn/hadoop-yarn-server/hadoop-yarn-server-resourcemanager/src/main/java/org/apache/hadoop/yarn/server/resourcemanager/scheduler/fair/QueuePlacementRule.java).
These rules are ordered meaning that the first rule which can place the application into a queue will apply. If no rule can apply the
application submission will be rejected. Each rule accept a `create` argument in which case it's true the rule can create a queue if it is missing.
The following rules exist:

* [User](https://github.com/apache/hadoop-common/blob/trunk/hadoop-yarn-project/hadoop-yarn/hadoop-yarn-server/hadoop-yarn-server-resourcemanager/src/main/java/org/apache/hadoop/yarn/server/resourcemanager/scheduler/fair/QueuePlacementRule.java#L124):
    places the application into a queue with user's name e.g: root.chris
* [PrimaryGroup](https://github.com/apache/hadoop-common/blob/trunk/hadoop-yarn-project/hadoop-yarn/hadoop-yarn-server/hadoop-yarn-server-resourcemanager/src/main/java/org/apache/hadoop/yarn/server/resourcemanager/scheduler/fair/QueuePlacementRule.java#L140):
    places the application into a queue with the user's primary group name e.g: root.hdfs
* [SecondaryGroupExistingQueue](https://github.com/apache/hadoop-common/blob/trunk/hadoop-yarn-project/hadoop-yarn/hadoop-yarn-server/hadoop-yarn-server-resourcemanager/src/main/java/org/apache/hadoop/yarn/server/resourcemanager/scheduler/fair/QueuePlacementRule.java#L160):
    places the application into a queue with the user's secondary group name
* [NestedUserQueue](https://github.com/apache/hadoop-common/blob/trunk/hadoop-yarn-project/hadoop-yarn/hadoop-yarn-server/hadoop-yarn-server-resourcemanager/src/main/java/org/apache/hadoop/yarn/server/resourcemanager/scheduler/fair/QueuePlacementRule.java#L188):
    places the application into a queue with the user's name under the queue returned by the nested rule
* [Specified](https://github.com/apache/hadoop-common/blob/trunk/hadoop-yarn-project/hadoop-yarn/hadoop-yarn-server/hadoop-yarn-server-resourcemanager/src/main/java/org/apache/hadoop/yarn/server/resourcemanager/scheduler/fair/QueuePlacementRule.java#L258):
    places the application into a queue which was requested when submitted
* [Default](https://github.com/apache/hadoop-common/blob/trunk/hadoop-yarn-project/hadoop-yarn/hadoop-yarn-server/hadoop-yarn-server-resourcemanager/src/main/java/org/apache/hadoop/yarn/server/resourcemanager/scheduler/fair/QueuePlacementRule.java#L282):
    places the application into the default queue
* [Reject](https://github.com/apache/hadoop-common/blob/trunk/hadoop-yarn-project/hadoop-yarn/hadoop-yarn-server/hadoop-yarn-server-resourcemanager/src/main/java/org/apache/hadoop/yarn/server/resourcemanager/scheduler/fair/QueuePlacementRule.java#L324):
    it is a termination rule in the sequence of rules, if no rule applied before then it will reject the submission

ACLs are also checked before creating and adding the application to the list of `SchedulerApplications` and updating the metrics.

### APP_REMOVED
Simply stops the application and sets it's final state.

### APP_ATTEMPT_ADDED
The analogy is the same with the CapacityScheduler that application attempts trigger the application to actually run. Based on the
allocation configuration mentioned above the [MaxRunningAppsEnforcer](https://github.com/apache/hadoop-common/blob/trunk/hadoop-yarn-project/hadoop-yarn/hadoop-yarn-server/hadoop-yarn-server-resourcemanager/src/main/java/org/apache/hadoop/yarn/server/resourcemanager/scheduler/fair/MaxRunningAppsEnforcer.java)
will decide whether the app is placed into the `runnableApps` or the `nonRunnableApps` inside of the queue. `MaxRunningAppsEnforcer` also
keeps track of the runnable and non runnable apps per user. Attempt states are also transferred from one to another.

### APP_ATTEMPT_REMOVED
Releases all the allocated, acquired, running containers (in case of `ApplicationMaster` restart the running containers won't get killed),
releases all reserved containers, cleans up pending requests and informs the queues. `MaxRunningAppsEnforcer` gets updated as well.

### NODE_UPDATE
As we learned from CapacityScheduler `NodeUpdateSchedulerEvents` arrive every second. FairScheduler support asynchronous scheduling on a
different thread regardless of the `NodeManager's` `heartbeats` as well. We also learned the importance of the `Allocation` method which
issues the `ResourceRequests` of an application and in this case it does exactly the same as in case of CapacityScheduler. You can read
about the form of these requests there. At each node update the scheduler updates the capacities of the resources if it's changed, processes
the completed and newly launched containers, updates the metrics and tries to allocate resources to applications. Just like with CapacityScheduler
container reservation has the advantage thus it gets fulfilled first. If there is no reservation it tries to schedule in a queue which is
farthest below fair share. The scheduler first orders the queues and then the applications inside the queues using the configured
[SchedulingPolicy](https://github.com/apache/hadoop-common/tree/trunk/hadoop-yarn-project/hadoop-yarn/hadoop-yarn-server/hadoop-yarn-server-resourcemanager/src/main/java/org/apache/hadoop/yarn/server/resourcemanager/scheduler/fair/policies).
As I mentioned in the configuration section there are 3 default policies available:

* [FifoPolicy](https://github.com/apache/hadoop-common/blob/trunk/hadoop-yarn-project/hadoop-yarn/hadoop-yarn-server/hadoop-yarn-server-resourcemanager/src/main/java/org/apache/hadoop/yarn/server/resourcemanager/scheduler/fair/policies/FifoPolicy.java)
    (fifo) - Orders first by priorities and then by submission time.
* [DominantResourceFairnessPolicy](https://github.com/apache/hadoop-common/blob/trunk/hadoop-yarn-project/hadoop-yarn/hadoop-yarn-server/hadoop-yarn-server-resourcemanager/src/main/java/org/apache/hadoop/yarn/server/resourcemanager/scheduler/fair/policies/DominantResourceFairnessPolicy.java)
    (drf) - Orders by trying to equalize dominant resource usage.
    (dominant resource usage is the largest ratio of resource usage to capacity among the resource types it is using)
* [FairSharePolicy](https://github.com/apache/hadoop-common/blob/trunk/hadoop-yarn-project/hadoop-yarn/hadoop-yarn-server/hadoop-yarn-server-resourcemanager/src/main/java/org/apache/hadoop/yarn/server/resourcemanager/scheduler/fair/policies/FairSharePolicy.java)
    (fair) - Orders via weighted fair sharing. In addition, Schedulables below their min share get priority over those whose
    min share is met. Schedulables below their min share are compared by how far below it they are as a ratio. For example, if job A has 8
    out of a min share of 10 tasks and job B has 50 out of a min share of 100, then job B is scheduled next, because B is at 50% of its
    min share and A is at 80% of its min share. Schedulables above their min share are compared by (runningTasks / weight).

SchedulingPolicies can be written and used by anyone without major investment to how to do it. All it takes is to extend a
[class](https://github.com/apache/hadoop-common/blob/trunk/hadoop-yarn-project/hadoop-yarn/hadoop-yarn-server/hadoop-yarn-server-resourcemanager/src/main/java/org/apache/hadoop/yarn/server/resourcemanager/scheduler/fair/SchedulingPolicy.java)
and place the implementation to the classpath and restart the `ResourceManager`. Even though it's easy to do and it's not a major investment
the fairness will depend on it thus the effect will be major, so you should really consider it. After the decision of which application should
get resources first the game is pretty much the same as with the CapacityScheduler. First it tries to allocate container on a data local node
and after a delay on a rack local node and in the end falling back to an off switch node.

### CONTAINER_EXPIRED
Cleans up the expired containers just like it would be a finished container.

## What's next?
We might do a Part 3 post about the FIFOScheduler, though that's really straightforward - nevertheless, let us know if you'd like to read about. As we have already mentioned, last week we released [Periscope](http://sequenceiq.com/periscope/) - the industry’s first SLA policy based autoscaling API for Hadoop YARN - all these features we have blogged about are based on our contribution in Hadoop, YARN and Ambari -so stay tuned and follow us on [LinkedIn](https://www.linkedin.com/company/sequenceiq/), [Twitter](https://twitter.com/sequenceiq) or [Facebook](https://www.facebook.com/sequenceiq) for updates.

