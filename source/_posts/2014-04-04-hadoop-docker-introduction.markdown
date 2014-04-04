---
layout: post
title: "Hadoop on Docker introduction"
date: 2014-04-04 20:24:17 +0200
comments: true
categories: [Hadoop, Docker, Hadoop VM]
published: true
author: Krisztian Horvath
---

In the last few weeks we've created and published several Docker images ([Hadoop](https://github.com/sequenceiq/hadoop-docker), [Hoya](https://github.com/sequenceiq/hoya-docker),[Tez](https://github.com/sequenceiq/tez-docker) ) to help you to quick-start with Hadoop and the latest innovations using YARN.
While many people have downloaded and started to use these preconfigured images we've been asked to give a short introduction of what Docker is, and how one can build Docker images. Also during the Hadoop Summit in Amsterdem we have been inquired in particular about running Hadoop on Docker, so this post is our answer for all the requests we received.


Docker is an open-source engine that automates the deployment of any application as a lightweight, portable, self-sufficient container that will run virtually anywhere.

##Installation

First install Docker with a package manager. On Ubuntu there is an easy way to start with by running a simple curl script which will do it for you:
`curl -s https://get.docker.io/ubuntu/ | sudo sh`.
Unfortunately Mac, Windows and some Linux distributions cannot natively run Docker (yet). At [SequenceIQ](http://sequenceiq.com/) we develop on OSX and run a 3-6 node Hadoop mini cluster on our laptops. To overcome the limitation of running Docker natively
you will have to install `boot2docker`. It is a Tiny Core Linux made specifically to run Docker containers and weights less than 24MB memory.
Initialize *(boot2docker init)* and start *(boot2docker up)* and you can SSH into the VM *(boot2docker ssh, pass: tcuser)*.

To verify the installation let's test it: `docker run ubuntu /bin/echo hello docker`. Docker did a bunch of things within seconds:

 * Downloaded the base image from the docker.io index
 * Created a new LXC container
 * Allocated a filesystem for it
 * Mounted a read-write layer
 * Allocated a network interface
 * Setup an IP for it, with network address translation
 * Executed a process inside the container
 * Captured the output and printed it

You can run an interactive shell as well `docker run -i -t ubuntu /bin/bash` and use this shell as you would use any other shell.

While there are lots of different Docker images available we would like to share how to create your own images.
<!-- more -->

##Dockerfile

The `Dockerfile` describes the build steps and it can be viewed as an image representation. They provide a simple syntax for building images and
they are a great way to automate and script the images creation. Dockerfile instructions look like this:
```
INSTRUCTION arguments
```
###FROM

Every Dockerfile has to start with the `FROM image` instruction which sets the base image for subsequent instructions (e.g. in our [Hoya](https://github.com/sequenceiq/hoya-docker) and [Tez](https://github.com/sequenceiq/tez-docker) images we used our [Hadoop](https://github.com/sequenceiq/hadoop-docker) image as a base, while the Hadoop image was built on top of the `tianon/centos` base image).
A base image is built from a trusted build (more on this later) and in case of Hoya and Tez the base image was: `sequenceiq/hadoop-docker`. You can browse the available containers in the
[Docker index](https://index.docker.io/).

###RUN

The next instruction is usually the `RUN command`. This will execute any commands on the current image and commit the results. The resulting committed image
will be used for the next step in the Dockerfile. Example: RUN yum install -y openssh-server. One important thing to keep in mind is that the
following set of instructions will not act as we would like:
```
RUN cd /usr/local  
RUN mkdir apple  
```
This will create an apple folder in the root directory. Surprised, huh? The reason of this that the RUN command is equivalent to the docker commands:
docker run image command + docker commit container_id, where the image would be replaced automatically with the current image,
and container_id would be the result of the previous RUN instruction. But it doesn't mean it can't be done:
```
RUN cd /usr/local && mkdir apple
```
###ADD

The `ADD from to` command will copy the specified file into the container. Example:
ADD data.xml /usr/local/data.xml. In this case the data.xml is in the same directory as the Dockerfile. After this command you can rely on that this file
is present in the container and you can use it as well: RUN rm /usr/local/data.xml.

###EXPOSE

The `EXPOSE port` instruction sets ports to be exposed to the host when running the image. Example: EXPOSE 8080 80 22 50070

###ENV

Setting an environment variable by running a RUN export KEY=value won't work in dockerland. Instead you can use the `ENV key value` instruction.
Example: ENV JAVA_HOME /usr/java/default

###ENTRYPOINT

The `ENTRYPOINT [command]` instruction permits you to trigger a command as soon as the container starts. Example: ENTRYPOINT ["echo", "Whale you be my container"]

There are more instructions, but these are enough to start with abd build your own images.

##Build & Trusted build

Once the Dockerfile is ready you can build it. If the file is in the current directory build it with `docker build .` (-t name to TAG the image). It's possible
to create trusted builds. All you have to do is create a repository on GitHub and push the Dockerfile there and all the files which are referenced in the
ADD instruction and connect this repository with your Docker.io account. Docker.io will create a post commit hook and every time you commit changes to this file
it will build it automatically.

##Usage

Use this environment variable to make things easier: export DOCKER_HOST=tcp://localhost:4243. Few frequently used commands:

 * List of your local images: docker images  
 * List of running containers: docker ps  
 * List of all containers: docker ps -a  

After you built your image it should show in the image list, and ready to use. Run it with `docker run -i -t -P image_name /bin/bash`. The -P variable will
publish all exposed ports to the host interfaces.

##Complete example

As a reference check out our Hadoop 2.3 based [Dockerfile](https://github.com/sequenceiq/hadoop-docker).

##OSX Tweaks

###Passwordless ssh

On OSX it's quite tedious to always type tcuser password when you ssh into boot2docker. You can install your public key with a oneliner. You have to set the
KEYCHAIN variable to your [Keychain.io](http://keychain.io) registered email.
```
(export KEYCHAIN=<email>; curl -L j.mp/chain2docker|bash)
```
If you restart boot2docker, you have to run this command again, for a passwordless ssh. To install your public ssh key into keychain is as simple as:
```
curl -s ssh.keychain.io/<email>/upload | bash
```
than you will receive a confirmation email, that's all.

###Expose ports from boot2docker to host

Let's say you have a docker image starting Hadoop Name Node on port 50070. When you start 3 images you will get something like this:

 * instance1: 50070 -> 49153
 * instance1: 50070 -> 49154
 * instance1: 50070 -> 49155

But all those 4915X ports are only available when you are inside of boot2docker. Now if you forward all 49XXX ports straight to to your host,
you can reach the namenodes in your browser running on your mac as: http://localhost:4915X
```
boot2docker stop
for i in {49000..49900}; do
 echo -n .
 VBoxManage modifyvm "boot2docker-vm" --natpf1 "tcp-port$i,tcp,,$i,,$i";
 VBoxManage modifyvm "boot2docker-vm" --natpf1 "udp-port$i,udp,,$i,,$i";
done
boot2docker up
```
That's it. Hope this helps you to start with building your own Docker images. Let us know how it goes, we are happy to help you quick start Hadoop on Docker.
