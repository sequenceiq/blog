---
layout: post
title: "Re-prioritize running jobs with YARN schedulers"
date: 2014-07-02 10:20:05 +0200
comments: true
categories: [Hadoop, Scheduler]
published: false
author: Krisztian Horvath
---
At SequenceIQ we run different applications all within the same Hadoop YARN cluster. Often the deployed Hadoop stack is a multi-tenant and multi-application and runtime setup - and as usual for a scenario as such end users will try to use or book as much cluster capacity as possible. A great help for solving these problems are YARN schedulers - however in our case due to certain SLA and QoS requirements we needed to step further. We have invested a great effort to build custom YARN schedulers, learn about application insights (check our [blog post](http://blog.sequenceiq.com/blog/2014/05/01/mapreduce-job-profiling-with-R/) about how we use R to profile running jobs) and we would like to share our experience with the community. Let's dig into technical details.

In YARN, one of the ResourceManager's most important role is the scheduling (allocating available resources in the cluster) between competing applications. It doesn't care about per-application states nor internal flows and optimizations, but the overall resource requirements of
each application. Currently there are 3 different scheduler implementations available: FIFO, Fair, Capacity.  

Going back a few weeks in time we blogged about how to configure the
[CapacityScheduler](http://blog.sequenceiq.com/blog/2014/03/14/yarn-capacity-scheduler/) and use different queue
setups. Based on the feedbacks we have received we realized that there is a lack of knowledge about how these schedulers work and many people have asked to fill that gap. Good news that we didn't
forget about you. We're going to start a post series where we'll explain them a little bit detailed with fancy diagrams and code examples. 

But before doing that, let's visit a concrete problem we encountered while we were developing our product stack.
We wanted to use the CapacityScheduler, but for different reasons (SLA and QoS) move the submitted applications between different queues to set a priority among them - at runtime (quick reminder: queues are either a composition of other queues or a collection of applications, forming a tree).
Cross application priorites can't be configured yet, only priorities between tasks within the application. The only problem is if you check the code you'll find this:

```java
@Override
  public String moveApplication(ApplicationId appId, String newQueue) throws YarnException {
    throw new YarnException(getClass().getSimpleName()
        + " does not support moving apps between queues");
  }
```

<!-- more -->

Currently this operation is supported only by the FairScheduler. Why is it not implemented? Let us know in a comment and you might receive a surprise present from us :). In the meantime if we'd like
to implement it what would be the steps? Lets start with the following queue hierarchy and their capabilities taken from the integration tests:

{% img http://yuml.me/1fe68e90 %}

Assume we've submitted 2 applications, **app1** to `b2` and **app2** to `a2` (submitting applications is only allowed to leaf queues). What if **app2** is
pending for so long because of the queue capacity and my friend's friend's dog cannot wait anymore to see his data clustering result? We could play with the queue capacities and max capacities, but then other apps might get scheduled as well and we don't want that.
Then we could move the app to a queue where it can get resources with a much higher chance. To move an app to somewhere
else in the hierarchy we have to consider and update a whole bunch of things. Let's move **app1** to queue `b1`.

Obviously we have to check if the target queue is a leaf queue and moving the app there does not violate any constraints. But how to do that?
The first part is easy (leaf or parent), but what about the other one? It has to do something with queue capacities, but checking only the target
queue's capacity is not enough, we have to go up in the hierarchy (because the parent queues also keep track the number of applications
and resource usages) but for how deep? The lowest common ancestor of the source and target is enough, because above that nothing changes. In our
case it's the `b` (b1, b2). Finding it is not that hard since the queues are declared like this:

 * root.a.a1
 * root.a.a2
 * root.b.b1
 * root.b.b2
 * root.b.b3

Going back until `b` and check the capacities:
```java
    CSQueue currentQueue = targetQueue;
    while (currentQueue != lowestCommonAncestor) {
      // maxApps
      if (currentQueue.getNumApplications() == this.conf.getMaximumApplicationsPerQueue(currentQueue.getQueueName())) {
        throw new YarnException("Moving app attempt " + appAttId + " to queue "
          + queueName + " would violate queue maxApps constraints on"
          + " queue " + currentQueue.getQueueName());
      }

      // maxCapacity
      float potentialNewCapacity = Resources.divide(calculator, clusterResource, Resources.add(currentQueue.getUsedResources(), consumption), clusterResource);
      if (potentialNewCapacity >= currentQueue.getAbsoluteMaximumCapacity()) {
        throw new YarnException("Moving app attempt " + appAttId + " to queue "
          + queueName + " would violate queue maxCapacity constraints on"
          + " queue " + currentQueue.getQueueName());
      }
      currentQueue = currentQueue.getParent();
    }
```

If everything is fine we can execute the movement.
```java
private void executeMove(SchedulerApplication app, FiCaSchedulerApp attempt, LeafQueue oldQueue, LeafQueue newQueue) {
    oldQueue.removeApplicationAttempt(attempt);
    attempt.move(newQueue); // This updates all the queue metrics 'til the parent
    app.setQueue(newQueue);
    newQueue.trackApplications(attempt.getApplicationId(), attempt.getUser());
    newQueue.submitApplicationAttempt(attempt, attempt.getUser());
}
```

There are so many things implemented in these method calls it wouldn't fit here, but it serves the purpose here as pseudo code.

 * oldQueue.removeApplicationAttempt(attempt);  
   Remove the application from the active and pending list. Notify the parents that an app has been removed.

 * attempt.move(newQueue);  
   Update the queue metrics upwards to root.

 * app.setQueue(newQueue);  
   Set the target queue in the app.

 * newQueue.trackApplications(attempt.getApplicationId(), attempt.getUser());  
   Notify the parents that a new application has been moved here.

 * newQueue.submitApplicationAttempt(attempt, attempt.getUser());  
   Finally submit the application attempt to the queue.

As usual we always release the code as well - you can get the details from our [GitHub](https://github.com/sequenceiq) page. 

  * Move applications between Capacity Scheduler queues [implementation](https://github.com/sequenceiq/hadoop-common/blob/branch-2.4.1/hadoop-yarn-project/hadoop-yarn/hadoop-yarn-server/hadoop-yarn-server-resourcemanager/src/main/java/org/apache/hadoop/yarn/server/resourcemanager/scheduler/a/ExtendedCapacityScheduler.java#L924).

  * Test case [implementation](https://github.com/sequenceiq/hadoop-common/blob/branch-2.4.1/hadoop-yarn-project/hadoop-yarn/hadoop-yarn-server/hadoop-yarn-server-resourcemanager/src/test/java/org/apache/hadoop/yarn/server/resourcemanager/scheduler/a/TestExtendedCapacitySchedulerAppMove.java).


In case you are interested on the YARN Scheduler series make sure to follow us on [LinkedIn](https://www.linkedin.com/company/sequenceiq/) or [Twitter](https://twitter.com/sequenceiq) for the upcoming posts.
