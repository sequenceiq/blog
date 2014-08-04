---
layout: post
title: "Launch Docker containers on Azure"
date: 2014-08-05 21:43:01 +0200
comments: true
categories: [Hadoop as a Service, Hadoop, Docker, Cloud, Cloudbreak, Azure]
author: Richard Doktorics
published: false
---

Two weeks ago we have open sourced our cloud agnostic and Docker based Hadoop as a Service API - called [Cloudbreak](http://sequenceiq.com/cloudbreak). 
The first public beta version supports Amazon’s AWS and Microsoft’s Azure, while we are already wrapping up a few new cloud provider integrations. 

While there is some documentation about running Docker containers on Amazon, there is no detailed description about running Docker on the Azure cloud.
With this blog post we would like to shed some light on it - recently there have been lots of announcements from Microsoft about Docker support (Azure CLI, Kubernetes, libswarm) but they are either not finished yet or are not ready to build a robust platform on top.
We are eagerly waiting for the [Kubernetes integration](http://azure.microsoft.com/blog/2014/07/10/azure-collaboration-with-google-and-docker/).

In the meantime, if you are interested in running a `cluster` of Docker container, or do some more complex stuff then read on.

Just to briefly recap - with Cloudbreak we are launching on demand Hadoop clusters (check our [blog](http://blog.sequenceiq.com/blog/2014/07/25/cloudbreak-technology/) for further technical details) in Docker containers. These containers are `shipped` to different cloud VMsm and dynamically find and join each other - they form a fully functional Hadoop cluster without the need to do anything manually on the host, or apply any manual pre-configuration.
So how are we doing this? 

<!--more-->

###Docker ready base VM image

First of all you need a base image with Docker installed - thus for that we have built and made available an Ubuntu 14.04 image with Docker installed. Apart from Docker, to build a fully dynamic and `service discovery` aware Docker cluster we needed [jq](http://stedolan.github.io/jq/) and [ bridge-utils](http://www.linuxfromscratch.org/blfs/view/svn/basicnet/bridge-utils.html).

Once this base image is created you will need to make it public and re-usable. In order to do that the image has to be published in [VMdepot](http://vmdepot.msopentech.com/List/Index). When you are about to use an image from VM depot, and create a VM based on that you will need to copy it in your own storage account - note that doing it at first time this can be a slow process (20-25 minutes, copying the 30 GB image).

###Dynamic networking 

Now you have an image based on that you can launch your own VMs, and the Docker container inside your VM. While there are a few options to do that, we needed to find a unified way to do so - note that  [Cloudbreak](http://sequenceiq.com/cloudbreak) is a cloud agnostic solution - and we do not want to create init scripts for each and every cloud environment we use. Amazon’s AWS has a feature so called `userdata` - an option of passing data to the instance that can be used to perform common automated configuration tasks and even run scripts after the instance starts. You can pass two types of user data to Amazon AWS: shell scripts and cloud-init directives. In order to keep the launch process unified everywhere we are using [cloud-init] (https://help.ubuntu.com/community/CloudInit) on Azure as well. 

You can use/start Docker on with different networking - using a bridged network or using a host network. You can check the init scripts in our [GitHub](https://github.com/sequenceiq/cloudbreak/blob/master/src/main/resources/azure-init.sh) repository.

**Bridged network**

```shell

# set bridge0 in docker opts
sh -c "cat > /etc/default/docker" <<"EOF"
DOCKER_OPTS="-b bridge0 -H unix:// -H tcp://0.0.0.0:2375"
EOF

CMD="docker run -d -p SOURCE_PORT:DESTINATION_PORT 0 -e SERF_JOIN_IP=$SERF_JOIN_IP -e SERF_ADVERTISE_IP=$MY_IP --dns 127.0.0.1 --name ${NODE_PREFIX}${INSTANCE_IDX} -h ${NODE_PREFIX}${INSTANCE_IDX}.${MYDOMAIN} --entrypoint /usr/local/serf/bin/start-serf-agent.sh  $IMAGE $AMBARI_ROLE"

```
**Host network**

```shell
CMD="docker run -d -e SERF_JOIN_IP=$AMBARI_SERVER_IP --net=host --name ${NODE_PREFIX}${INSTANCE_IDX} --entrypoint /usr/local/serf/bin/start-serf-agent.sh  $IMAGE $AMBARI_ROLE"
```

*Note: for cloud based clusters we are giving up on the bridged based network - mostly due to Azure's networking limitations - and will use the `net=host` solution in the next release. The bridged network will still be a supported solution, though we are using it mostly with bare metal or multi container/host solutions.*

Azure has (comparing with Amazon’s AWS or Google’s Cloud compute) an `uncommon` network setup and supports limited flexibility - in order to overcome these, and still have a dynamic Hadoop cluster different scenarios / use cases requires different Docker networking - that is quite a large **undocumented** topic which we will cover in our next blog posts - in particular the issues, differences and solutions to use Docker on different cloud providers. While we have briefly talked about [Serf](http://sequenceiq.com/cloudbreak/#technology) in the [Cloudbreak](https://cloudbreak.sequenceiq.com) documentation, we will enter in deep technical details in our next posts as well. Should you be interested in these make sure you follow us on [LinkedIn](https://www.linkedin.com/company/sequenceiq/), [Twitter](https://twitter.com/sequenceiq) or [Facebook](https://www.facebook) for updates.

###SequenceIQ’s Azure REST API - open sourced

At [SequenceIQ](htp://sequenceiq.com) we always automate everything - and in order to launch VM instances, configure networks, start containers, etc we needed a REST client which we can use it from our JAVA and Scala codebase. Since the Microsoft API is XML based - *yo, it’s 2014* - we have created and open sourced a Groovy based [Azure REST API](https://github.com/sequenceiq/azure-rest-client) - wrapping the XML calls into a nice, easy to use and clean REST API. Feel free to use it - it’s open sourced under an Apache 2 license. Note that [Cloudbreak](https://cloudbreak.sequenceiq.com) does not store your Azure user credential - where’s for example with the CLI that would have been mandatory - the only thing we need from your side to work is your subscription id. The process is documented here: http://sequenceiq.com/cloudbreak/#accounts.

###Metadata service for Azure

The another nice feature we have created for Azure VMs is a `metadata service`. While a service as such does exists on Amazon’s AWS it’s missing from Microsoft Azure - note that our Cloudbreak solution is a cloud agnostic one, and we always strive to use identical solution on all cloud providers. The instance metadata is data about your instance that you can use to configure or manage the running instances - and available via a REST call. We have developed a service as such for Azure - [AzureMetadataSetup](https://github.com/sequenceiq/cloudbreak/blob/master/src/main/java/com/sequenceiq/cloudbreak/service/stack/connector/azure/AzureMetadataSetup.java). As you can see we collect the metadata, and make it available under a `unique hash` for each cluster by calling the following resource: `/metadata/{hash}`

```java 
private Set<CoreInstanceMetaData> collectMetaData(Stack stack, AzureClient azureClient, String name) {

	... try {
                CoreInstanceMetaData instanceMetaData = new CoreInstanceMetaData(vmName,
                        getPrivateIP((String) virtualMachine),
                        getVirtualIP((String) virtualMachine));
                instanceMetaDatas.add(instanceMetaData);
            } catch (IOException e) { ...

}
```
This service is used in a few cases - for example to learn different network setups as the hosts are using different network options than the Docker containers.

As usual for us - being committed to 100% open source - we are always open sourcing everything thus you can get the details on our [GitHub](https://github.com/sequenceiq/cloudbreak) repository. 
Should you have any questions feel free to engage with us on our [blog](http://blog.sequenceiq.com/) or follow us on [LinkedIn](https://www.linkedin.com/company/sequenceiq/), [Twitter](https://twitter.com/sequenceiq) or [Facebook](https://www.facebook).





