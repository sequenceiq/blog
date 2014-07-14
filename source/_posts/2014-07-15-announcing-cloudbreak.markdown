---
layout: post
title: "Cloudbreak - the Hadoop as a Service API"
date: 2014-06-15 18:37:53 +0200
comments: true
categories: [Hadoop as a Service, Hadoop, Docker, Cloud]
author: Janos Matyas
published: false
---

Today is a great day for us - we are announcing the first public beta version of our open source and cloud agnostic Hadoop as a Service API. During our daily work with large Hadoop clusters in the cloud, Dockerized environments and bare metal we were doing the same things over and over again. Although we are automating always everything we felt that something is missing - an open source, cloud agnostic Hadoop as a Service API.

When we have started to work on Cloudbreak - first of all to solve our internal needs - we set the following criteria:

* Use open source software and be *open source* under Apache 2 license
* Have the ability to quickly launch arbitrary sized Hadoop clusters
* Be cloud provider agnostic and create an SDK which allow to quickly add new providers
* Have a REST API and a CLI in order to be able to automate the whole process
* Support different Hadoop services and configurations in a declarative way
* Elastic and flexible enough, with the ability to resize running clusters
* Secure

##Docker and the cloud

At SequenceIQ we are running all our core processes in Docker containers - and that is true for Hadoop and the whole ecosystem as well. While we have [blogged](http://blog.sequenceiq.com/blog/2014/06/19/multinode-hadoop-cluster-on-docker/) and open sourced lots of [things](https://hub.docker.com/u/sequenceiq/) related to our Dockerized environments, Cloudbreak is build on the foundation of these works and reusing the same technologies we have released before.

* Docker containers - all the Hadoop ecosystem is installed and running inside Docker containers, and these containers are `shipped` between different cloud vendors, keeping it cloud agnostic
* Apache Ambari - to declaratively define of a Hadoop cluster
* Serf - for cluster membership, failure detection, and orchestration that is decentralized, fault-tolerant and highly available for dynamic clusters

<!-- more -->

While there is an extensive list of articles explaining the benefits of using Docker, we would like to highlight our motivations in a few bullet points.

* Reproducible, testable environment - we are recreating complete config environments in seconds, and being able to work with the same container on our laptop and production/cloud environment
* Isolation - each container is separated and runs in his own isolated sandbox
* Versioning - we are able to easily modify containers, and ship only the changed bits saving bandwith; essential for large clusters
* Central repository - you can build an entire cluster from a trusted and centralized container repository
* Smart resource allocation - containers can be `shipped` anywhere and resources can be allotted


##Cloudbreak main components

###Cloudbreak API

With Cloudbreak you are one POST away from your on-demand Hadoop cluster. For further documentation please follow up with the [general](http://sequenceiq.com/cloudbreak/) and [API](http://docs.cloudbreak.apiary.io/) documentation.

###Cloudbreak REST client

In order to ease your work with the REST API we have created and use a Groovy REST client. The code is available at our [GitHub repository](https://github.com/sequenceiq/cloudbreak-rest-client).

###Cloudbreak CLI

As we automate everything and we are a very DevOps focused company we are always trying to create easy ways to interact with our systems and API’s. In case of Cloudbreak we have created and released a [command line shell](https://github.com/sequenceiq/cloudbreak-shell).

###Cloudbreak UI

For those who does not want to use the REST API but would like to explore first the capabilities of the Hadoop as a Service API can check our hosted [Cloudbreak UI](https://cloudbreak.sequenceiq.com/).

##What’s next?

After this post we will launch a few Cloudbreak related blog posts to drive you through the technology, API and Cloudbreak insigts. In the meantime we suggest you to go through our [documentations](http://sequenceiq.com/cloudbreak/), try [Cloudbreak](http://cloudbreak.sequenceiq.com/) and let us know how does it works for you.

Please note that [Cloudbreak](http://cloudbreak.sequenceiq.com/) is under development, in public beta - while we consider the codebase stable for deployments please let us know if you face any problems through [GitHub](https://github.com/sequenceiq/cloudbreak) issues. Also we are welcome your open source contribution - let it be a bug fix or a new cloud provider [implementation](http://sequenceiq.com/cloudbreak/#add-new-cloud-providers).

Finally your opinion is important for us - if you’d like to see your favourite cloud provider among the existing ones, please fill this questionnaire: https://docs.google.com/forms/d/129RVh6VfjRsuuHOcS3VPbFYTdM2SEjANDsGCR5Pul0I/viewform

For updates follow us on [LinkedIn](https://www.linkedin.com/company/sequenceiq/), [Twitter](https://twitter.com/sequenceiq) or [Facebook](https://www.facebook.com/sequenceiq).


