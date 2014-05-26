---
layout: post
title: "Apache Ambari + Spring Shell = Ambari Shell"
date: 2014-05-26 15:42:11 +0200
comments: true
categories: [Apache Ambari,Spring Shell,Hadoop]
author: Krisztian Horvath
published: true
---

## Introduction

[Apache Ambari's](http://ambari.apache.org/) goal is to make Hadoop cluster management as simple as possible. It provides an intuitive easy-to-use
web UI backed by its RESTful API. With only a few clicks you're able to install Hadoop services across any number of hosts and Ambari will take
care of the configurations as well. After the installation is complete you can monitor your cluster taking leverage of
[Ganglia](http://ganglia.sourceforge.net/) and [Nagios](http://www.nagios.org/). At SequenceIQ we use command line tools whenever it's possible,
because it's much faster than interacting with a web UI and it's a better candidate for automation. Here comes
[Spring Shell](https://github.com/spring-projects/spring-shell#readme) to our rescue. An interactive shell that can be easily extended
using a Spring based programming model and battle tested in various projects like [Spring Roo](http://projects.spring.io/spring-roo/) and
[Spring XD](http://docs.spring.io/spring-xd/docs/1.0.0.BUILD-SNAPSHOT/reference/html/). Combine these two projects and a really powerful tool
will come to light.

## Ambari Shell

The goal is to provide an interactive command line tool which supports:

* all functionality available through the Ambari web UI
* context aware command availability
* tab completion
* required/optional parameter support

Since we're open sourcing the project, it should be available and part of the official Ambari repository [soon](https://issues.apache.org/jira/browse/AMBARI-5482),
but if you're eager to try it you can build your own from our [repository](https://github.com/sequenceiq/ambari-shell) (mvn clean install).
The shell is distributed as a single executable jar with the help of another project called [Spring Boot](http://projects.spring.io/spring-boot/).
Let's see how it works in real life.

<!-- more -->

As usual we've crated a [Docker](https://github.com/sequenceiq/ambari-docker) image so you can start experimenting with the shell and it's
available at the Docker repository, which means you only need to run the following to get a running Ambari server:
```
docker run -d -P -h server.ambari.com --name ambari-singlenode sequenceiq/ambari
```
and you can connect to it with the shell:
```
Usage:
  java -jar ambari-shell.jar                  : Starts Ambari Shell in interactive mode.
  java -jar ambari-shell.jar --cmdfile=<FILE> : Ambari Shell executes commands read from the file.

Options:
  --ambari.host=<HOSTNAME>       Hostname of the Ambari Server [default: localhost].
  --ambari.port=<PORT>           Port of the Ambari Server [default: 8080].
  --ambari.user=<USER>           Username of the Ambari admin [default: admin].
  --ambari.password=<PASSWORD>   Password of the Ambari admin [default: admin].

Note:
  At least one option is mandatory.
```
The `--ambari` options can be omitted if the values are the defaults otherwise you only need to specify the difference,
e.g just the port is different: `--ambari.port=49178`.
```
        _                _                   _  ____   _            _  _
   / \    _ __ ___  | |__    __ _  _ __ (_)/ ___| | |__    ___ | || |
  / _ \  | '_ ` _ \ | '_ \  / _` || '__|| |\___ \ | '_ \  / _ \| || |
 / ___ \ | | | | | || |_) || (_| || |   | | ___) || | | ||  __/| || |
/_/   \_\|_| |_| |_||_.__/  \__,_||_|   |_||____/ |_| |_| \___||_||_|

Welcome to Ambari Shell. For command and param completion press TAB, for assistance type 'hint'.
```
The currently supported commands are:

* `blueprint add` - Add a new blueprint with either --url or --file
* `blueprint defaults` - Adds the default blueprints to Ambari
* `blueprint list` - Lists all known blueprints
* `blueprint show` - Shows the blueprint by its id
* `cluster assign` - Assign host to host group
* `cluster build` - Starts to build a cluster
* `cluster create` - Create a cluster based on current blueprint and assigned hosts
* `cluster delete` - Delete the cluster
* `cluster preview` - Shows the currently assigned hosts
* `cluster reset` - Clears the host - host group assignments
* `debug off` - Stops showing the URL of the API calls
* `debug on` - Shows the URL of the API calls
* `exit` - Exits the shell
* `hello` - Prints a simple elephant to the console
* `help` - List all commands usage
* `hint` - Shows some hints
* `host components` - Lists the components assigned to the selected host
* `host focus` - Sets the useHost to the specified host
* `host list` - Lists the available hosts
* `quit` - Exits the shell
* `script` - Parses the specified resource file and executes its commands
* `service components` - Lists all services with their components
* `service list` - Lists the available services
* `tasks` - Lists the Ambari tasks
* `version` - Displays shell version

All commands are context aware and are available only when it makes sense. For example the `cluster create` command is not available
until a blueprint hasn't been added or selected. A good approach is to use the `hint` command - as the Ambari UI, this will give
you hints about the available commands and the flow of creating or configuring a cluster. You can always use TAB for completion
or available parameters. Be nice and say `hello`:
```
                .-.._
          __  /`     '.
       .-'  `/   (   a \
      /      (    \,_   \
     /|       '---` |\ =|
    ` \    /__.-/  /  | |
       |  / / \ \  \   \_\
       |__|_|  |_|__\
```
Initially there are no blueprints available - you can add blueprints from file or URL. For your convenience we've added two
blueprints as defaults. You can get these blueprints by using the `blueprint defaults` command. The result is the following:
```
  BLUEPRINT              STACK
  ---------------------  -------
  multi-node-hdfs-yarn   HDP:2.0
  single-node-hdfs-yarn  HDP:2.0
```
Once the blueprints are added you can use them to create a cluster by typing `cluster build --blueprint single-node-hdfs-yarn`.
Now that the blueprint is selected you have to assign the hosts to the available host groups. Use
`cluster assign --hostGroup host_group_1 --host server.ambari.com`.
```
  HOSTGROUP     HOST
  ------------  -----------------
  host_group_1  server.ambari.com
```
Once you are happy with the host - host group associations you can choose `cluster create` to start building the cluster.
Progress can be checked either at the Amabri UI or using the `tasks` command.
```
  TASK                        STATUS
  --------------------------  -------
  HISTORYSERVER INSTALL       QUEUED
  ZOOKEEPER_SERVER START      PENDING
  ZOOKEEPER_CLIENT INSTALL    PENDING
  HDFS_CLIENT INSTALL         PENDING
  HISTORYSERVER START         PENDING
  NODEMANAGER INSTALL         QUEUED
  NODEMANAGER START           PENDING
  ZOOKEEPER_SERVER INSTALL    QUEUED
  YARN_CLIENT INSTALL         PENDING
  NAMENODE INSTALL            QUEUED
  RESOURCEMANAGER INSTALL     QUEUED
  NAMENODE START              PENDING
  RESOURCEMANAGER START       PENDING
  DATANODE START              PENDING
  SECONDARY_NAMENODE START    PENDING
  DATANODE INSTALL            QUEUED
  MAPREDUCE2_CLIENT INSTALL   PENDING
  SECONDARY_NAMENODE INSTALL  QUEUED
```

Each time you start the shell the executed commands are logged in a file line by line and later either with the `script` command
or specifying an `--cmdfile` option the same commands can be executed.

## Summary
To sum it up in less than two minutes watch this video:
<script type="text/javascript" src="https://asciinema.org/a/9783.js" id="asciicast-9783" async></script>
