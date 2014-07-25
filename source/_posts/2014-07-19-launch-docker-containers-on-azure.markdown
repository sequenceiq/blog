---
layout: post
title: "Launch Docker containers on Azure"
date: 2014-07-19 21:43:01 +0200
comments: true
categories: [Hadoop as a Service, Hadoop, Docker, Cloud, Cloudbreak, Azure]
author: Richard Doktorics
published: false
---

We just now open sourced the Cloudbreak which is a Hadoop as a Service API which supports currently 2 cloud provider. Of course one of is the Amazon it is not a big present and the other is the Microsoft Azure.
This blog post main theme will be the Azure integration.

Our Azure integration begins with an azure rest client which was developed with the hortonworks. It is a java library which can communicate with your azure account by the azure rest API. We do not want to use the azure cli because it is not the best solution when you have a user group who dont want to give you the full controll on their account.
In our solution we need just your subscription id which not a sensitive information. In our implementation we generating a .jks file and a certificate file and you have to upload this certificate file to the Azure portal. After that we can easily communicate with the Azure when our rest client using your jks file in every request.

You can easily launch a Docker container in every cloud you just have to install the Docker on the virtual machine. The problem on our side was that we needed to run the container when the vm is started. On amazon there is a solution which name is userdata script. Currently azure not supporting this solution on every vm just on ubuntu because this system has a component which name is cloud-init(https://help.ubuntu.com/community/CloudInit).
So we got an Ubuntu and intalled a jq(http://stedolan.github.io/jq/), bridge-utils(http://www.linuxfromscratch.org/blfs/view/svn/basicnet/bridge-utils.html) and a docker. We wanted to starting these machine as fast as they can so pulled down our ambari image(https://registry.hub.docker.com/u/sequenceiq/ambari/).

You can easily store your images in the Vmdepot(http://vmdepot.msopentech.com/List/Index) this is the way what we choosen. The problem with azure that if you want to use this image as operating system than you have to copy this 30gb image into your storage. This method basically 20-25 minutes unfortunately so the first start is quite slow.
The AWS has a service which name is metadata service it is basically supporting to reach information about the virtual machine on a easy way. Unfortunatelly this function is missing in Azure so we built our own metadata service which give us very usefull information about the machine. This service based on a hash which is very own in every cluster and you can reach the information without any authentication.
When the virtual machine is starting then it begins to polling the endpoint for the information. We need this info for the network setup setup because the docker containers using different network option then the owner machine.

---NETWORK--

This release is the 0.1 so if you find some bug please post us or feel free to contribute.
