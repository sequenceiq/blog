---
layout: post
title: "Multi-node Hadoop cluster on Docker"
date: 2014-06-19 22:29:10 +0200
comments: true
categories: [Apache Ambari,Docker, Hadoop, DevOps, Multi-node]
author: Lajos Papp
published: true
---

In the [previous post](http://blog.sequenceiq.com/blog/2014/06/17/ambari-cluster-on-docker/)
you saw how easy is to create a single-node Hadoop *cluster* on your devbox.

Now lets raise the bar and create a multinode Hadoop cluster on Docker. Before we
start, make sure you have the latest ambari image:

```
docker pull sequenceiq/ambari:latest
```

## One-liner

Once you have the latest image, you can start runnin Docker containers.
But instead of typing long commands like `docker run [options] image [command]`,
we have created a couple of [shell functions](https://github.com/sequenceiq/docker-ambari/blob/master/ambari-functions) to help you with Docker commands.

Using these functions the impatient can provision a 3 node Hadoop cluster with this one-liner:
```
curl -Lo .amb j.mp/docker-ambari && . .amb && amb-deploy-cluster
```

<!-- more -->

It does the following steps:

- runs `ambari-server start` in a daemon Docker (background) container (and also an `ambari-agent start`)
- runs `n-1` daemon containers with `ambari-agent start` connecting to the server
- runs AmbariShell with attached terminal (to see provision progress)
  - AmbariShell will post the built-in multi-node blueprint to `/api/v1/blueprints` REST API
  - AmbariShell auto-assign hosts to host_groups defined in the blueprint
  - creates a cluster, by posting to the `/api/v1/clusters` REST API

## Custom blueprint

If you have your own blueprint, put it into a [gist](https://gist.github.com/)
and you can use it from AmbariShell. First start AmbariShell:
```
amb-start-cluster 2
amb-shell
```

AmbariShell will wait for:

- Ambari REST API
Below you will see a happy path to create a multi node Hadoop cluster using the AmbariShell.

```
host list
blueprint add --url https://gist.githubusercontent.com/lalyos/xxx/raw/custum-blueprint.json
cluster build --blueprint custom-blueprint
cluster assign --hostGroup host_group_1 --host amb0.mycorp.kom
cluster assign --hostGroup host_group_2 --host amb1.mycorp.kom
cluster assign --hostGroup host_group_2 --host amb1.mycorp.kom
cluster create
```

In AmbariShell the `hint` command will always guide you on the happy path,
and remember that devops are lazy, so instead of typing press `<TAB>` for autocomplete or suggestions.

Autocomplete will help you to:

 - complete the command in the given context (e.g. without any blueprint, cluster commands are not available)
 - add required parameters
 - add optional parameters: pres tab after double dash `--<TAB>`
 - complete parameter arguments, such as blueprint names, hostnames ...

## Summary

Ever since we started to use Docker we are always developing against a multi-node
Hadoop cluster - as running a 3-4 node cluster in a laptop actually has less overhead
than working on a Sandbox VM.

We are *Dockerizing* the Hadoop ecosystem and simplifying the provisioning
process - watch this space or follow us on [LinkedIn](https://www.linkedin.com/company/sequenceiq/)
for the latest news about [Cloudbreak](http://docs.cloudbreak.apiary.io/) - the
open source cloud agnostic *Hadoop as a Service* API built on Docker.

Hope this helps and simplifies your development process - let us know how it goes
for you or if you need any help with Hadoop on Docker.
