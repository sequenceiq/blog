---
layout: post
title: "Create Hadoop clusters in the cloud using a CLI"
date: 2014-08-07 21:43:01 +0200
comments: true
categories: [Hadoop as a Service, Hadoop, Cloud, Cloudbreak, CLI, Shell]
author: Janos Matyas
published: true
---

Few weeks back we have announced [Cloudbreak](http://blog.sequenceiq.com/blog/2014/07/18/announcing-cloudbreak/) - the open source Hadoop as a Service API. Included in the release we open sourced a REST API, REST client, UI and a CLI/shell. In this post we’d like to show you how easy is to use [Cloudbreak shell](https://github.com/sequenceiq/cloudbreak-shell) in order to create on demand Hadoop clusters on your favorite cloud provider. 

While it’s up to everybody's personal preference whether to use a UI, a command line interface or the REST API directly, at SequenceIQ we prefer to use command line tools whenever it’s possible because it’s much faster than interacting with a web UI and it’s a better candidate for automation. Yeah - we have mentioned this many times - we are `obsessed with automation`; any step which is a candidate of doing it twice we script and automate it. 

This `thing` with the automation does not affect the effort and quality standards we put on building the UI - [Cloudbreak](https://cloudbreak.sequenceiq.com/) has an extremely intuitive and clean **responsive** UI and it’s built on the latest and greatest web UI framework - [Angular JS](https://angularjs.org/). We will have a post about the UI, however we consider it so simple to use that we ask you to go ahead and give it a try. You are a signup and a few clicks away from your Hadoop cluster. 

Now back to the CLI. Remember one of our Apache contribution - the [Ambari shell and REST API](http://blog.sequenceiq.com/blog/2014/05/26/ambari-shell/)? Well, the Cloudbreak shell is built on the same technology - Spring Shell. It’s an interactive shell that can be easily extended using a Spring based programming model and battle tested in various projects like Spring Roo, Spring XD, and Spring REST Shell Combine these two projects to create a powerful tool. 

## Cloudbreak Shell

The goal with the CLI was to provide an interactive command line tool which supports:

* all functionality available through the REST API or Cloudbreak web UI
* makes possible complete automation of management task via **scripts**
* context aware command availability
* tab completion
* required/optional parameter support
* **hint** command to guide you on the usual path

## Install Cloudbreak Shell
You have 3 options to give it a try:
- use our prepared [docker image](https://registry.hub.docker.com/u/sequenceiq/cloudbreak/)
- download the latest self-containing executable jar form our maven repo
- build it from source

We will follow up with the first two, in this post we’d like to guide you through the third option.

### Build from source

If want to use the code or extend it with new commands follow the steps below. You will need:
- jdk 1.7
- maven 3.x.x

```
git clone https://github.com/sequenceiq/cloudbreak-shell.git
cd cloudbreak-shell
mvn clean package
```

<!--more-->

## Connect to Cloudbreak
In order to use the shell you will have to have a Cloudbreak account. You can get one by subscribing to our hosted and free [Cloudbreak](https://cloudbreak.sequenceiq.com/) instance. Alternatively you can build your own Cloudbreak and deploy it within your organization - for that just follow up with the steps in the Cloudbreak [documentation](http://sequenceiq.com/cloudbreak/#quickstart-and-installation). We suggest to try our hosted solution as in case you have any issues we can always help you with. Please feel free to create bugs, ask for enhancements or just give us feedback by either our [GitHub repository](https://github.com/sequenceiq/cloudbreak) or the other channels highlighted in the product documentation.
The shell is built as a single executable jar with the help of [Spring Boot](http://projects.spring.io/spring-boot/).

```
Usage:
  java -jar cloudbreak-shell-0.1-SNAPSHOT.jar                 : Starts Cloudbreak Shell in interactive mode.
  java -jar cloudbreak-shell-0.1-SNAPSHOT.jar --cmdfile=<FILE> : Cloudbreak executes commands read from the file.

Options:
  --cloudbreak.host=<HOSTNAME>       Hostname of the Cloudbreak REST API Server [use:cloudbreak-api.sequenceiq.com].
  --cloudbreak.port=<PORT>           Port of the Cloudbreak REST API Server [use:80].
  --cloudbreak.user=<USER>           Username of the Cloudbreak user [use:your user name ].
  --cloudbreak.password=<PASSWORD>   Password of the Cloudbreak admin [use: your password].

Note:
  All options are mandatory.
```
Once you are connected you can start to create a cluster. If you are lost and need guidance through the process you can use `hint`. You can always use `TAB` for completion. Note that all commands are `context aware` - they are available only when it makes sense - this way you are never confused and guided by the system on the right path.

### Create a cloud credential

In order to start using Cloudbreak you will need to have a cloud user, for example an Amazon AWS account. Note that Cloudbreak **does not** store you cloud user details - we work around the concept of [IAM](http://aws.amazon.com/iam/) - on Amazon (or other cloud providers) you will have to create an IAM role, a policy and associate that with your Cloudbreak account - for further documentation please refer to the [documentation](http://sequenceiq.com/cloudbreak/#accounts).

```
credential createEC2 --description “description" --name “myCredentialName" --roleArn "arn:aws:iam::NUMBER:role/cloudbreak-ABC" --sshKeyUrl “URL towards your AWS public key"
```

Alternatively you can upload your public key from a file as well, by using the `—sshKeyPath` switch. You can check whether the credential was creates successfully by using the `credential list` command. You can switch between your cloud credential - when you’d like to use one and act with that you will have to use:

```
credential select --id #ID of the credential
```

### Create a template

A template gives developers and systems administrators an easy way to create and manage a collection of cloud infrastructure related resources, maintaining and updating them in an orderly and predictable fashion. A template can be used repeatedly to create identical copies of the same stack (or to use as a foundation to start a new stack).

```
template createEC2 --description "awstemplate" --name "awstemplate" --region EU_WEST_1 --instanceType M3Large --sshLocation 0.0.0.0/0 
```
You can check whether the template was created successfully by using the `template list` command. Check the template with or select if you are happy with:

```
template show --id #ID of the template

template select --id #ID of the template
```
### Create a stack 

Stacks are template `instances` - a running cloud infrastructure created based on a template. Use the following command to create a stack to be used with your Hadoop cluster:

```
stack create --name “myStackName" --nodeCount 20 
```
### Select a blueprint 

We ship default Hadoop cluster blueprints with Cloudbreak. You can use these blueprints or add yours. To see the available blueprints and use one of them please use:

```
blueprint list

blueprint select --id #ID of the blueprint
```
### Create a Hadoop cluster 
You are almost done - one more command and this will create your Hadoop cluster on your favorite cloud provider. Same as the API, or UI this will use your `template`, and by using CloudFormation will launch a cloud `stack` - once the `stack` is up and running (cloud provisioning is done) it will use your selected `blueprint` and install your custom Hadoop cluster with the selected components and services. For the supported list of Hadoop components and services please check the [documentation](http://sequenceiq.com/cloudbreak/#supported-components).

```
cluster create --description “my cluster desc"
```
You are done - you can check the progress through the Ambari UI. If you log back to [Cloudbreak UI](https://cloudbreak.sequenceiq.com/) you can check the progress over there as well, and learn the IP address of Ambari.

### Automate the process
Each time you start the shell the executed commands are logged in a file line by line and later either with the `script` command or specifying an `—cmdfile` option the same commands can be executed again.

## Commands

For the full list of available commands please check below. Please note that all commands are context aware, and you can always use `TAB` for command completion.


    * blueprint add - Add a new blueprint with either --url or --file
    * blueprint defaults - Adds the default blueprints to Cloudbreak
    * blueprint list - Shows the currently available blueprints
    * blueprint select - Select the blueprint by its id
    * blueprint show - Shows the blueprint by its id
    * cluster create - Create a new cluster based on a blueprint and template
    * cluster show - Shows the cluster by stack id
    * credential createAzure - Create a new Azure credential
    * credential createEC2 - Create a new EC2 credential
    * credential defaults - Adds the default credentials to Cloudbreak
    * credential list - Shows all of your credentials
    * credential select - Select the credential by its id
    * credential show - Shows the credential by its id
    * exit - Exits the shell
    * help - List all commands usage
    * hint - Shows some hints
    * quit - Exits the shell
    * script - Parses the specified resource file and executes its commands
    * stack create - Create a new stack based on a template
    * stack list - Shows all of your stack
    * stack select - Select the stack by its id
    * stack show - Shows the stack by its id
    * stack terminate - Terminate the stack by its id
    * template create - Create a new cloud template
    * template createEC2 - Create a new EC2 template
    * template defaults - Adds the default templates to Cloudbreak
    * template list - Shows the currently available cloud templates
    * template select - Select the template by its id
    * template show - Shows the template by its id
    * version - Displays shell version



As usual for us - being committed to 100% open source - we are always open sourcing everything thus you can get the details on our [GitHub](https://github.com/sequenceiq/cloudbreak-shell) repository.
Should you have any questions feel free to engage with us on our [blog](http://blog.sequenceiq.com/) or follow us on [LinkedIn](https://www.linkedin.com/company/sequenceiq/), [Twitter](https://twitter.com/sequenceiq) or [Facebook](https://www.facebook).
