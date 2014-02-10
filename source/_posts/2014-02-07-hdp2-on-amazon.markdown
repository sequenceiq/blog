---
layout: post
title: "Set up HDP2 on Amazon EC2"
date: 2014-02-07 16:17:04 +0000
comments: true
categories: HDP2 EC2 Hortonworks
author: Janos Matyas
---

During the last years we have seen many blog entries and articles about how to set up Hadoop on Amazon EC2. All these tutorials and articles had one thing in common - you had to go through a large number of manual (and painful) steps, read screenshots and redo the whole thing all over.

Since we use Amazon EC2 quite a lot, and Hadoop as well (especially the Hortonworks distribution) we have gone through these steps many times - and have scripted the whole process from the very beginning up to having an N node of Hadoop (HDP2 in this case) cluster in less then five minutes.

Moreover, the cluster is a 'production ready' setup from infrastructure point of view - it is provisioned in a logically isolated section of the cloud, with his own IP address range, creation of subnets, and configuration of route tables and network gateways.

Once the instances are provisoned, the HDP2 setup is done by Apache Ambari UI - for more advanced users we will provide the setup being one thorugh Ambari's RESTful API - follow this space.

All the EC2 instances are tagged with the user name - thus you can create different clusters for different employees, all under the same AWS account (with IAM).

We believe that this is the right way to provision Hadoop in the cloud - during development and testing we had to provision Hadoop clusters of different sizes, and going through these steps manually would take lots of time. 

This way we are able to provision Hadoop clusters in the cloud in the matter of minutes - independently of the size.

The script is available at: https://github.com/sequenceiq/hadoop-cloud-scripts

Enjoy,
SequenceIQ

