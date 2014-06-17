---
layout: post
title: "Ambari provisioned Hadoop cluster on Docker"
date: 2014-06-17 10:51:14 +0200
comments: true
categories: [Apache Ambari,Docker, Hadoop, DevOps]
author: Lajos Papp
published: true
---

We are getting close to release and open source our **Docker-based Hadoop Provisioning** project.
The [slides](http://www.slideshare.net/JanosMatyas/docker-based-hadoop-provisioning)
were presented recently at the [Hadoop Summit](http://hadoopsummit.org/san-jose/), and
there is an interest from the community to learn the technical details.

The project - called [Cloudbreak](http://docs.cloudbreak.apiary.io/) - will provide a REST API to provision a Hadoop cluster - anywhere. The cluster can be hosted
on AWS EC22, Azure, physical servers or even your laptop, but always based on the same concept:
[Apache Ambari](http://ambari.apache.org/) managed [Docker](http://www.docker.com/)
containers.

This blog entry is the first in a series, where we describe the Docker layer step-by-step:

- Single-node Docker based Hadoop "cluster" locally
- Multi-node Docker based Hadoop cluster
- Multi-node Docker based Hadoop cluster on EC2
- Cloudbreak

## Get Docker

The only required software is Docker, so if you don't have it yet, jump to the
installation section of the [official documentation](https://docs.docker.com/installation/).

The very basic you need to work with Docker containers, is described in the
[users guide](https://docs.docker.com/userguide/dockerizing/).

## Single-node Cluster

All setup is based on [Docker images](https://hub.docker.com/u/sequenceiq/) only
the glue-code is different. Lets start with the most simple setup:

 - starts a Docker container in the background that runs **ambari-server** and **ambari-agent**.
 - starts another container which:
   - waits for the agent connecting to the server
   - starts an [ambari-shell](https://github.com/sequenceiq/ambari-shell), which will instruct ambari-server on its REST API:
     - define an **[Ambari Blueprint](https://cwiki.apache.org/confluence/display/AMBARI/Blueprints)** by posting a JSON to `<AMBARI_URL>/api/v1/blueprints`
     - create a Hadoop cluster by posting a JSON to `<AMBARI_URL>/api/v1/clusters` using the blueprint created in the previous step

```
docker run -d -p 8080 -h amb0.mycorp.kom --name ambari-singlenode sequenceiq/ambari --tag ambari-server=true
docker run -e BLUEPRINT=single-node-hdfs-yarn --link ambari-singlenode:ambariserver -t --rm --entrypoint /bin/sh sequenceiq/ambari -c /tmp/install-cluster.sh
```

or if you want a **twitter-sized** one-liner to start with Hadoop in less then a minute:

```
curl -LOs j.mp/ambari-singlenode && . ambari-singlenode
```

<!-- more -->

When you pull the `sequenceiq/ambari` image first it will take a couple of minutes (for me it was 4 minutes).
Meanwhile you have sterted the download lets explain all those parameters.

## 1. container: ambari-server and ambari-agent

Lets break down the parameters of the first container:
```
docker run -d -p 8080 -h amb0.mycorp.kom --name ambari-singlenode sequenceiq/ambari --tag ambari-server=true
```

- **-d** : Detached mode, container runs in the background
- **-p 8080** : Publish ambari web and REST API port
- **-h amb0.mycorp.kom** : hostname
- **--name ambari-singlenode** : assign a name to the container
- **sequenceiq/ambari** : the name of the image
- **--tag ambari-server=true** : the *command* but please note that this is appended to the *entrypoint*.

The default *entrypoint* of the image is `start-serf-agent.sh`
[see the Dockerfile](https://github.com/sequenceiq/docker-ambari/blob/master/ambari-server/Dockerfile#L24)
so the `--tag ambari-server=true` command is actually an argument of the [serf agent](http://www.serfdom.io/).

### Serf
What is [Serf](http://www.serfdom.io/)? The definition goes like:

> Serf is a decentralized solution for cluster membership, failure detection, and orchestration. Lightweight and highly available.

Right now it doesn't seem to make any sense to talk about membership and cluster, but remember we want to
have the exact same process/tools for dev env and production.

The only Serf feature we use at this point is that you can define shell scripts based **event-handlers** for
each membership events:

- member-join
- member-failed
- member-leave
- member-xxx

The **member-join** event-handler script will check the Serf tags, defined by `--tag name=value`
and will start:
 - ambari-server java process: if the **ambari-server** tag is **true**
 - ambari-agent python process: if the **ambari-agent** tag is **true**

You might noted that only the **ambar-server** tag is defined. The reason is that **ambari-agent** is defined as **true** by default.

## 2. container: ambari-shell

```
docker run -e BLUEPRINT=single-node-hdfs-yarn --link ambari-singlenode:ambariserver -t --rm --entrypoint /bin/sh sequenceiq/ambari -c /tmp/install-cluster.sh
```

- **-e BLUEPRINT=single-node-hdfs-yarn** : the template to use for the cluster (single-node-hdfs-yarn/multi-node-hdfs-yarn/lambda-architecture) [see json on github](https://github.com/sequenceiq/ambari-rest-client/tree/master/src/main/resources/blueprints)
- **--link ambari-singlenode:ambariserver ** :  it will make all exposed ports and the private ip of `ambari-singlenode` available as `AMBARISERVER_xxx` env variables
- **-t** : pseudo terminal, to see the progress
- **--rm** : remove the container once it's finished
- **--entrypoint /bin/sh** : the default entrypoint runs the shell in interactive mode, we want to overwrite it with a script specified as `/tmp/install-cluster.sh`

# Install completed

Once Ambari-shell completed with the installation, you are ready to use it.
To find out the IP of the Ambari server run:

```
docker inspect -f "{{.NetworkSettings.IPAddress}}" ambari-singlenode
```

To start with you can browse ambari web ui on `port 8080`. The default username/password is admin/admin.

or if you can't reach directly the private IP of the container (windows users), use the port exposed to the host:
```
docker port ambari-singlenode 8080
```

# Next steps

In the upcomming blog post we will do a multinode Hadoop cluster with the same toolset, so stay tuned ...
