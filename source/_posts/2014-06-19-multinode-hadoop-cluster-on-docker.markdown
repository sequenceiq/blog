---
layout: post
title: "Multinode Hadoop cluster on Docker"
date: 2014-06-19 22:29:10 +0200
comments: true
categories: [Apache Ambari,Docker, Hadoop, DevOps]
author: Lajos Papp
published: true
---

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

It does the following steps:

- starts ambari server in a daemon docker (background) container (and also an ambar-agent self connecting)
- starts `n-1` daemon containers with `ambari-agent` connecting to the server
- runs AmbariShell with attached terminal (to see provision progress)
  - AmbariShell will post the built-in multi-node blueprint to `/api/v1/blueprints` REST api
  - AmbariShell auto-assign hosts to host_groups defined in the blueprint
  - cretaes a cluster, by posting to the `/api/v1/clusters` REST api

## Custom blueprint

If you have your own blueprint, put it up into a [gist](https://gist.github.com/)
and you can use it from AmbariShell. First start AmbariShell:
```
amb-start-cluster 2
amb-shell
```

In AmbariShell the `hint` command will always guide you on the happy path,
and remember that devops are lazy, so instead of typing press `<TAB>`.

Autocomplete will help you to:

 - complete command considering the context (without any blueprint, cluster command are not available)
 - add required parameters
 - add optional parameters: pres tab after double dash `--<TAB>`
 - complete parameter arguments, such as blueprint names, hostnames ...

```
host list
blueprint add --url https://gist.githubusercontent.com/lalyos/xxx/raw/custum-blueprint.json
cluster build --blueprint custom-blueprint
cluster assign --hostGroup host_group_1 --host amb0.mycorp.kom
cluster assign --hostGroup host_group_2 --host amb1.mycorp.kom
cluster assign --hostGroup host_group_2 --host amb1.mycorp.kom
cluster create
```
