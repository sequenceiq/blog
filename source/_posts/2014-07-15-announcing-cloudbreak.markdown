---
layout: post
title: "Cloudbreak - the Hadoop as a Service API"
date: 2014-07-15 18:37:53 +0200
comments: true
categories: [Hadoop as a Service, Hadoop, Docker, Cloud]
author: Janos Matyas
published: false
---

_Cloudbreak is a powerful left surf that breaks over a coral reef, a mile off southwest the island of Tavarua, Fiji._

_Cloudbreak is a cloud agnostic Hadoop as a Service API. Abstracts the provisioning and ease management and monitoring of on-demand clusters._

Today is a big day for us - we are announcing the first `public beta` version of our open source and cloud agnostic **Hadoop as a Service API**. During our daily work with large Hadoop clusters in the cloud, `dockerized` environments and bare metal we were doing the same things over and over again. Although we are automating and `dockerizing` always everything we felt that something is missing - an open source, cloud agnostic Hadoop as a Service API. Welcome **[Cloudbreak]**(https://github.com/sequenceiq/cloudbreak) - you are one POST away from your on-demand Hadoop cluster.

When we have started to work on Cloudbreak - first of all to solve our internal needs at SequenceIQ - we set the following criteria:

* Use open source software and be **100% open source** under Apache 2 license
* Have the ability to quickly launch arbitrary sized Hadoop clusters
* Be cloud provider agnostic and create an SDK which allow to quickly add new providers
* No more glue code, repeating the same things over and over again
* Have a REST API and a CLI in order to be able to automate the whole process
* Support different Hadoop services and configurations in a declarative way 
* Elastic and flexible enough, with the ability to resize running clusters
* Secure

##Docker and the cloud

At SequenceIQ we are running all our core applications and processes in Docker containers - and that is true for Hadoop and all of the services as well. During the last few months we have [blogged](http://blog.sequenceiq.com/blog/2014/06/19/multinode-hadoop-cluster-on-docker/) and open sourced all of [building blocks](https://hub.docker.com/u/sequenceiq/) of our Dockerized systems and **Cloudbreak** is built on the foundation of these and reusing the same technologies we have released before. 

* [Docker containers](https://hub.docker.com/u/sequenceiq/) - all the Hadoop services are installed and running inside Docker containers, and these containers are `shipped` between different cloud vendors, keeping Cloudbreak cloud agnostic
* [Apache Ambari](https://github.com/sequenceiq/ambari-rest-client) - to declaratively define a Hadoop cluster
* [Serf](https://github.com/sequenceiq/docker-serf) - for cluster membership, failure detection, and orchestration that is decentralised, fault-tolerant and highly available for dynamic clusters

<!-- more -->

While there is an extensive list of articles explaining the benefits of using Docker, we would like to highlight our motivations in a few bullet points.

* Write once, run anywhere - our solution uses the same Docker containers on different cloud providers, `dockerized` environments or bare metal, no difference at all
* Reproducible, testable environment - we are recreating complete config environments in seconds, and being able to work with the same container on our laptop and production/cloud environment
* Isolation - each container is separated and runs in his own isolated sandbox
* Versioning - we are able to easily version and modify containers, and ship only the changed bits saving bandwidth; essential for large clusters deployed in the cloud
* Central repository - you can build an entire cluster from a trusted and centralised container repository, the Docker Registry/Hub
* Smart resource allocation - containers can be `shipped` anywhere and resources can be allotted


##Cloudbreak main components

###Cloudbreak API

Cloudbreak is a RESTful Hadoop as a Service API. Once it is deployed in your favourite servlet container exposes a REST API allowing to span up Hadoop clusters of arbitrary sizes on your selected cloud provider. With Cloudbreak you are one POST away from your on-demand Hadoop cluster. You can get the code from our [GitHub repository](https://github.com/sequenceiq/cloudbreak). For further documentation please follow up with the [general](http://sequenceiq.com/cloudbreak/) and [API](http://docs.cloudbreak.apiary.io/) documentation, or subscribe to one of our social channels in order to receive notifications about further blog posts. We are launching a series of posts to dig into Cloudbreak details and make it easier for you to learn, understand and use Hadoop in the cloud.

###Cloudbreak REST client

In order to ease your work with the REST API and embed in your codebase we have created (and also extensively use) a Groovy REST client. The code is available at our [GitHub](https://github.com/sequenceiq/cloudbreak-rest-client) repository.

###Cloudbreak CLI

As we automate everything and we are a very DevOps focused company we are always trying to create easy ways to interact with our systems and API’s. In case of Cloudbreak we have created and released a [command line shell](https://github.com/sequenceiq/cloudbreak-shell), the Cloudbreak CLI. The CLI allows you to use all the REST calls, and it has a large number of easing commands. Interactive help and completion is available.

###Cloudbreak UI

For those who does not want to use the REST API but would like to explore first the capabilities of the Hadoop as a Service API can check our hosted [Cloudbreak UI](https://cloudbreak.sequenceiq.com/). Cloudbreak UI is the easiest way to start exploring the system - a secure and intuitive way to launch on-demand Hadoop clusters. 

##What’s next?

After this post we will launch a few Cloudbreak related blog posts to drive you through the technology, API and Cloudbreak insights. In the meantime we suggest you to go through our [documentation](http://sequenceiq.com/cloudbreak/), try [Cloudbreak](http://cloudbreak.sequenceiq.com/) and let us know how does it works for you. We would like to listen your change requests, and ideas. 

Please note that [Cloudbreak](http://cloudbreak.sequenceiq.com/) is under development, in public beta - while we consider the codebase stable for deployments (and use it daily) please let us know if you face any problems through [GitHub](https://github.com/sequenceiq/cloudbreak) issues. Also we are welcome your open source contribution - let it be a bug fix or a new cloud provider [implementation](http://sequenceiq.com/cloudbreak/#add-new-cloud-providers).  

Finally your opinion is important for us - if you’d like to see your favourite cloud provider among the existing ones, please fill this [questionnaire](https://docs.google.com/forms/d/129RVh6VfjRsuuHOcS3VPbFYTdM2SEjANDsGCR5Pul0I/viewform). Make your voice matter!

For updates follow us on [LinkedIn](https://www.linkedin.com/company/sequenceiq/), [Twitter](https://twitter.com/sequenceiq) or [Facebook](https://www.facebook.com/sequenceiq).
