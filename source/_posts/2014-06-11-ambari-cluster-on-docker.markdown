---
layout: post
title: "ambari cluster on docker"
date: 2014-06-11 12:51:14 +0200
comments: true
categories: [Apache Ambari,Docker, Hadoop, DevOps]
author: Lajos Papp
---

# Apache Ambari cluster on docker

We are getting close to release our **Docker-based Hadoop Provisioning** product.
The [slides](http://www.slideshare.net/JanosMatyas/docker-based-hadoop-provisioning)
were presented recently on [Hadoop Summit](http://hadoopsummit.org/san-jose/), and
there is an interest to know the technical details.

We will provide a REST api to provision a hadoop cluster. The cluster can be hosted
on AWS ec2, or azure, or even on your laptop, but always based on the same concept:
[Apache Ambari](http://ambari.apache.org/) managed [docker](http://www.docker.com/)
containers.

So this blog entry is the first in a series, where we describe the docker layer
step-by-step:

- Single-node docker "cluster" locally
- Multi-node docker cluster locally
- Multi-node docker cluster on ec2

## Get docker

The only required software is docker, so if you don't have it yet, jump to the
installation section of the [official documentation](https://docs.docker.com/installation/).

The very basic you need to work with docker containers, is described in the
[users guide](https://docs.docker.com/userguide/dockerizing/).

## Single-node Cluster

All setup is based on [docker images](https://hub.docker.com/u/sequenceiq/) only
the glue-code is different. Lets start with the most simple setup:

 - start a single docker container that runs **ambari-server** and **ambari-agent** in the background.
 - start an other container which:
   - waits for the agent connecting to the server
   - starts an ambari-shell, which will instruct ambari-server on its REST api:
     - define an **[Ambari Blueprint](https://cwiki.apache.org/confluence/display/AMBARI/Blueprints)** via the ambari REST api
     - create a cluster by using the blueprint created in the previous step

```
docker run -d -p 8080 -h amb0.mycorp.kom --name ambari-singlenode sequenceiq/ambari --tag ambari-server=true
docker run -e BLUEPRINT=single-node-hdfs-yarn --link ambari-singlenode:ambariserver -it --rm --entrypoint /bin/sh sequenceiq/ambari-shell -c /tmp/install-cluster.sh
```

or if you want to do it in a **twitter-sized** one-liner:

```
curl -LOs j.mp/ambari-singlenode && . ambari-singlenode
```

<!-- more -->

When you pull the `sequenceiq/ambari` image first it will take a couple of minutes (for me it was 5 minutes).
Meanwhile lets explain all those parameters.

## 1. container: ambari-server and ambari-agent

Lets break down the parameters of the first container:
```
docker run -d -p 8080 -h amb0.mycorp.kom --name ambari-singlenode sequenceiq/ambari --tag ambari-server=true
```

- **-d** : Detached mode, container runs in the background
- **-p 8080** : Publish ambari web and REST api port
- **-h amb0.mycorp.kom** : hostname
- **--name ambari-singlenode** : assign a name to the container
- **sequenceiq/ambari** : the name of the image
- **--tag ambari-server=true** : the *command* but please note that this is appended to the *entrypoint*.

The default *entrypoint* of the image is `start-serf-agent.sh`
[see the Dockerfile](https://github.com/sequenceiq/docker-ambari/blob/master/ambari-server/Dockerfile#L24)
so the `--tag ambari-server=true` command is actually an argument of the [serf agent](http://www.serfdom.io/).

### Serf
What is [serf](http://www.serfdom.io/)? The definition goes like:

> Serf is a decentralized solution for cluster membership, failure detection, and orchestration. Lightweight and highly available.

Right now it doesn't seem to make any sense to talk about membership and cluster, but remember we want to
have the exact same process/tools for dev env and production.

The only serf feature we use right now, that you can define shell script **event-handler** for
each membership events:

- member-join
- member-failed
- member-xxx

The **member-join** event-handler script will check the serf tags, defined by `--tag name=value`
an will start:
 - ambari-server java process: if the **ambari-server** tag is **true**
 - ambari-agent python process: if the **ambari-agent** tag is **true**

You might noted that only the **ambar-server** tag is defined. The reason is that
 **ambari-agent** defined as **true** by default.

## 2. container: ambari-shell

```
docker run -e BLUEPRINT=single-node-hdfs-yarn --link ambari-singlenode:ambariserver -it --rm --entrypoint /bin/sh sequenceiq/ambari-shell -c /tmp/install-cluster.sh
```

- **-e BLUEPRINT=single-node-hdfs-yarn** : the template to use for the cluster (single-node-hdfs-yarn/multi-node-hdfs-yarn/lambda-architecture) [see json on github](https://github.com/sequenceiq/ambari-rest-client/tree/master/src/main/resources/blueprints)
- **--link ambari-singlenode:ambariserver ** : xx
- **-t** : pseudo terminal, to see the progress
- **--rm** : remove the container once it's finished
- **--entrypoint /bin/sh** : the default entrypoint runs the shell in interactive mode, we want to overwrite it with a script specified as `/tmp/install-cluster.sh`
