---
layout: post
title: "Accessing HDP2 sandbox from the host"
date: 2014-03-05 08:12:44 +0000
comments: true
published: true
categories: [Hortonworks sandbox, HDP2, SOCKS proxy, SSL]
author: Laszlo Puskas
---
During development of a Hadoop project people have many options of where and how to run Hadoop. We at SequenceIQ use different environments as well (cloud based, VM or host) - and different versions/vendor distributions. A very popular distribution among developers is the Hortonworks Sandbox - which contains the latest releases across Hadoop (2.2.0) and the key related projects into a single integrated and tested platform.
While using the sandbox gets you going running a single node Hadoop (pseudo distributed) in less than 5 minutes, many developers find inconvenient to 'live' and work inside the VM when deploying, debugging or submitting jobs into a Hadoop cluster. 

There is a well documented VM host file configuration on the [Hortonworks site](http://docs.hortonworks.com/) describing how to start interacting with the VM sandbox from outside (e.g host machine), but quite soon this will turn into a port-forwarding saga (those who know how many ports does Hadoop and the ecosystem use will know what we mean). An easier and more elegant way is to use a SOCKS5 proxy (which comes with SSL by default). 
Check this short goal/problem/resolution and code example snippet if you'd like to interact with the Hortonworks Sandbox from your host (outside the VM).

## Goal

 * accessing the pseudo distributed hadoop cluster from the  host
 * reading / writing to the  HDFS
 * submitting  M/R jobs to the RM

## Problem(s)

 * it's hard to reach resources inside the sandbox (e.g. interact with HDFS, or the DataNode)
 * lots of ports need to be portforwarded
 * entries to be added to the hosts file of the  host machine
 * circumstantial configuration of clients  accessing the sandbox

## Resolution

 * use an SSL socks proxy

## Example

 * check the following sample from our *[GitHub page](https://github.com/sequenceiq/sequenceiq-samples/tree/master/hdp-sandbox-access)*

Start the SOCKS proxy 
	  
``` bash
ssh root@127.0.0.1 -p 2222 -D 1099
```

<!-- more -->

Once the proxy is up and running, edit the core-site.xml
	  	  
	  	 
``` xml 
		<property>
			<name>hadoop.socks.server</name>
			<value>localhost:1099</value>
		</property>
		<property>
			<name>hadoop.rpc.socket.factory.class.default</name>
			<value>org.apache.hadoop.net.SocksSocketFactory</value>
		</property>
```
		
Now you can run the test client
		
``` bash 
	  	  
# You can use Maven
mvn exec:java -Dexec.mainClass="com.sequenceiq.samples.SandboxTester" -Dexec.args="hdfs sandbox 8020" -Dhadoop.home.dir=/tmp
	  	  
# or run from the JAR file
	  	  
java -jar sandbox-playground-1.0.jar hdfs sandbox 8020
```
	  	  
As you see it's pretty easy and convenient to use the Hortonworks sandbox as a pre-configured development environment.

In case you'd like to use (as we do most of the time) a Hadoop cluster in the cloud (Amazon EC2), check our previous blog post [HDP2 on Amazon](http://blog.sequenceiq.com/blog/2014/02/07/hdp2-on-amazon/). 
In case you ever wondered whether it's possible to use Hadoop with Docker please follow this blog.

Hope this helps,
SequenceIQ
