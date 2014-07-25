---
layout: post
title: "Docker ships Hadoop to the cloud"
date: 2014-07-25 14:56:39 +0200
comments: true
categories: [Cloudbreak, Docker, Hadoop, Cloud]
author: Janos Matyas
published: false
---

A week ago we have opensourced [Cloudbreak](https://cloudbreak.sequenceiq.com/) the first Docker based Hadoop as a Service API. In this post we'd like to introduce you into the technical details and the building blocks of the architecture.
Cloudbreak is built on the foundation of cloud providers APIs, Apache Ambari, Docker containers, Serf and dnsmasq. It is a cloud agnostic solution - as all the Hadoop services and components are running inside Docker containers - and these containers are shipped accross different cloud providers.

##How it works

From Docker containers point of view we have two kind of containers - based on their Ambari role - server and agent. There is one Docker contaier running the Ambari server, and there are many Docker containers running the Ambari agents. The used Docker image is always the same: `sequenceiq/ambari` and 
the Ambari role is decided based on the `$AMBARI_ROLE` variable.

For example on Amazon EC2 this is how we start the containers:

``` bash
docker run -d -p <LIST of ports> -e SERF_JOIN_IP=$SERF_JOIN_IP --dns 127.0.0.1 --name ${NODE_PREFIX}${INSTANCE_IDX} -h ${NODE_PREFIX}${INSTANCE_IDX}.${MYDOMAIN} --entrypoint /usr/local/serf/bin/start-serf-agent.sh  $IMAGE $AMBARI_ROLE
```

As we are starting up the instances, and the Docker containers on the host we'd like them to join each other and be able to communicate - though we don't know the IP addresses beforehand.
For that we use Serf - and pass along the IP address `SERF_JOIN_IP=$SERF_JOIN_IP` of the first container. Using a gossip protocol Serf will automatically discover each other, set the DNS names, and configure the routing between the nodes.
Serf reconfigures the DNS server `dnsmasq` running inside the container, and keeps it up to date with the joining or leaving nodes information.
As you can see at startup we always pass a `--dns 127.0.0.1` dns server for the container to use.

As you see there is no cloud specific code at the Docker containers level - as we have bloged about this beforehand, the same technology can be (and we are using it) on bare metal as well. 
Check our previous blog posts about a [multi node Hadoop cluster on any host](http://blog.sequenceiq.com/blog/2014/06/19/multinode-hadoop-cluster-on-docker/).

For additional information you can check our slides from the [Hadoop Summit 2014](http://www.slideshare.net/JanosMatyas/docker-based-hadoop-provisioning).

Once Ambari is started it will install the selected components based on the passed Hadoop blueprint - and start the desired services. 

##Technology

###Apache Ambari

The Apache Ambari project is aimed at making Hadoop management simpler by developing software for provisioning, managing, and monitoring Apache Hadoop clusters. Ambari provides an intuitive, easy-to-use Hadoop management web UI backed by its RESTful APIs.

![](https://raw.githubusercontent.com/sequenceiq/cloudbreak/master/docs/images/ambari-overview.png)

Ambari enables System Administrators to:

1. Provision a Hadoop Cluster
  * Ambari provides a step-by-step wizard for installing Hadoop services across any number of hosts.
  * Ambari handles configuration of Hadoop services for the cluster.

2. Manage a Hadoop Cluster
  * Ambari provides central management for starting, stopping, and reconfiguring Hadoop services across the entire cluster.

3. Monitor a Hadoop Cluster
  * Ambari provides a dashboard for monitoring health and status of the Hadoop cluster.
  * Ambari leverages Ganglia for metrics collection.
  * Ambari leverages Nagios for system alerting and will send emails when your attention is needed (e.g. a node goes down, remaining disk space is low, etc).

Ambari enables to integrate Hadoop provisioning, management and monitoring capabilities into applications with the Ambari REST APIs.
Ambari Blueprints are a declarative definition of a cluster. With a Blueprint, you can specify a Stack, the Component layout and the Configurations to materialise a Hadoop cluster instance (via a REST API) without having to use the Ambari Cluster Install Wizard.

![](https://raw.githubusercontent.com/sequenceiq/cloudbreak/master/docs/images/ambari-create-cluster.png)

###Docker

Docker is an open platform for developers and sysadmins to build, ship, and run distributed applications. Consisting of Docker Engine, a portable, lightweight runtime and packaging tool, and Docker Hub, a cloud service for sharing applications and automating workflows, Docker enables apps to be quickly assembled from components and eliminates the friction between development, QA, and production environments. As a result, IT can ship faster and run the same app, unchanged, on laptops, data center VMs, and any cloud.

The main features of Docker are:

1. Lightweight, portable
2. Build once, run anywhere
3. VM - without the overhead of a VM
  * Each virtualised application includes not only the application and the necessary binaries and libraries, but also an entire guest operating system
  * The Docker Engine container comprises just the application and its dependencies. It runs as an isolated process in userspace on the host operating system, sharing the kernel with other containers.
    ![](https://raw.githubusercontent.com/sequenceiq/cloudbreak/master/docs/images/vm.png)

4. Containers are isolated
5. It can be automated and scripted

###Serf

Serf is a tool for cluster membership, failure detection, and orchestration that is decentralised, fault-tolerant and highly available. Serf runs on every major platform: Linux, Mac OS X, and Windows. It is extremely lightweight.
Serf uses an efficient gossip protocol to solve three major problems:

  * Membership: Serf maintains cluster membership lists and is able to execute custom handler scripts when that membership changes. For example, Serf can maintain the list of Hadoop servers of a cluster and notify the members when nodes come online or go offline.

  * Failure detection and recovery: Serf automatically detects failed nodes within seconds, notifies the rest of the cluster, and executes handler scripts allowing you to handle these events. Serf will attempt to recover failed nodes by reconnecting to them periodically.
    ![](https://raw.githubusercontent.com/sequenceiq/cloudbreak/master/docs/images/serf-gossip.png)

  * Custom event propagation: Serf can broadcast custom events and queries to the cluster. These can be used to trigger deploys, propagate configuration, etc. Events are simple fire-and-forget broadcast, and Serf makes a best effort to deliver messages in the face of offline nodes or network partitions. Queries provide a simple realtime request/response mechanism.
    ![](https://raw.githubusercontent.com/sequenceiq/cloudbreak/master/docs/images/serf-event.png)

