---
layout: post
title: "Multinode Hadoop cluster on Docker"
date: 2014-06-19 22:29:10 +0200
comments: true
categories: [Apache Ambari,Docker, Hadoop, DevOps]
author: Lajos Papp
published: true
---

# Multi-node hadoop cluster on Docker

In the [previous post](http://blog.sequenceiq.com/blog/2014/06/17/ambari-cluster-on-docker/)
you saw how easy is to create a single-node Hadoop *cluster* on your devbox.

Now lets raise the bar and create a multinode Hadoop cluster on docker. Before we
start, make sure you have the latest ambari image:

```
docker pull sequenceiq/ambari:latest
```

## One-liner

Once you have the latest image, you can start runnin Docker containers.
But instead of typing long command `docker run [options] image [command]`,
we have created a couple of [shell functions](https://github.com/sequenceiq/docker-ambari/blob/master/ambari-functions)

So the impatient can provision a 3 node Hadoop cluster by this oneliner:
```
curl -Lo .amb j.mp/docker-ambari && . .amb && amb-deploy-cluster
```

<!-- more -->
