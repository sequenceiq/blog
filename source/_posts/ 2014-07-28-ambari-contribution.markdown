##The search

At SequenceIQ we frequently provision Hadoop clusters on different environments - and for a long time we have been in a search for the right tool. In this blog post we’d like describe our needs, our contribution and how we ended up using Apache Ambari pretty much for everything which is related to provisioning and and configuration. 

We are building an open source, cloud agnostic, Docker based Hadoop as a Service API called [Cloudbreak](http://sequenceiq.com/cloudbreak) - and in order to be able to span up dynamic Hadoop clusters we needed a provisioning tool. During the past period of time we have been checking all the available alternatives - and we decided to go along with Apache Ambari. While there are many benefits (and there have been many posts about this) of Ambari for us the most important key points were:
	
	* 100% open source under Apache 2 license
	* very active and agile development time
	* available REST API
	* support of blueprints

##The contribution process

We are a company with very strong focus on DevOps - and we always automate everything and try to use CLI/shells. Once we have made the decision to use Apache Ambari the first thing we looked for was a command line shell (and a REST client to be used from Java/Scala) - but realized that currently it’s missing.

We have quickly engaged with the Apache Ambari community and a few engineers from Hortonworks, have presented our idea - and once we have agreed on details and filled a JIRA the process accelerated. Since the shell and the Groovy based REST client is built on the foundation of the Apache Ambari REST API having a clean, well though and documented API was paramount - and this is what we have exactly found. Nevertheless, once in a while had some questions which the community had quickly answered, using the mailing lists.

The contribution process (at a high level) it's pretty much the same as for most of the Apache projects. I'd like to highlight this in a few bullet points, though this is extensively described on the projects WIKI.
	
	* Create a JIRA issue and discuss it with the community
	* Fork the GitHub repository
	* Write your contribution
	* Create test(s) for the new code
	* Create documentation
	* Create a patch
	* Follow up with your JIRA issue

##Apache Ambari Shell

The goal we set with the Apache Ambari shell was to provide an interactive command line tool which supports:

	* all functionality available through the REST API or Ambari web UI
	* makes possible complete automation of management task via scripts
	* context aware command availability
	* tab completion
	* required/optional parameter support
	* hint command to guide you on the usual path
	

### Connect Ambari Shell to the server

Once the server is up and running (10-20 sec) you can connect to it with the shell:
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

### Create a cluster

All commands are context aware and are available only when it makes sense. For example the `cluster create` command is not available
until a blueprint hasn't been added or selected. A good approach is to use the `hint` command - as the Ambari UI, this will give
you hints about the available commands and the flow of creating or configuring a cluster. You can always use TAB for completion
or available parameters.


Initially there are no blueprints available - you can add blueprints from file or URL. For your convenience we've added two
blueprints as defaults. You can get these blueprints by using the `blueprint defaults` command. The result is the following:

```
ambari-shell> blueprint defaults
ambari-shell> blueprint list
```
```
  BLUEPRINT              STACK
  ---------------------  -------
  multi-node-hdfs-yarn   HDP:2.0
  single-node-hdfs-yarn  HDP:2.0
```

Once the blueprints are added you can use them to create a cluster by typing `cluster build --blueprint single-node-hdfs-yarn`.
Now that the blueprint is selected you have to assign the hosts to the available host groups. Use

```
ambari-shell> cluster build --blueprint single-node-hdfs-yarn
CLUSTER_BUILD:single-node-hdfs-yarn> cluster assign --hostGroup host_group_1 --host server.ambari.com

  HOSTGROUP     HOST
  ------------  -----------------
  host_group_1  server.ambari.com
```
Once you are happy with the host - host group associations you can choose `cluster create` to start building the cluster.
Progress can be checked either at the Amabri UI or using the `tasks` command.
```

CLUSTER_BUILD:single-node-hdfs-yarn> cluster create
Successfully created the cluster
CLUSTER:single-node-hdfs-yarn> tasks

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

### Commands

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

### What's next

As our [Cloudbreak](http://sequenceiq.com/cloudbreak) project evolves we are constantly adding new features and upgrading the Apache Ambari shell and REST client. Among the forthcoming contributions you can find the followings: 

	* add new node to the cluster and install host components on it
	* decommission nodes and completely remove from the cluster
	* modify configuration
	

### Summary
To sum it up in less than two minutes watch this video:
<script type="text/javascript" src="https://asciinema.org/a/9783.js" id="asciicast-9783" async></script>
