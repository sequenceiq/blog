---
layout: "Apache Ambari 1.7.0 early access"
date: 2014-09-05 18:37:37 +0200
comments: true
categories: [Apache Ambari, Early access, Hadoop, Provisioning]
author: Janos Matyas
published: false
---


At [SequenceIQ] (http://sequenceiq.com/) we use [Apache Ambari] (http://ambari.apache.org/) every day - it’s our tool to provision Hadoop clusters. 

Beside that we are contributors to Ambari, we are so excited about the coming Apache Ambari 1.7.0 new [features](https://cwiki.apache.org/confluence/pages/viewpage.action?pageId=30755705) that we could not help and put together an **early access** [Ambari 1.7.0 Docker container](https://github.com/sequenceiq/docker-ambari/tree/1.7.0-ea). 

Give it a try, and provision an arbitrary number of Hadoop cluster on your laptop (or production environment), using our container and Ambari shell. Let us know how it works for you. Enjoy.

###Get the Docker container
In case you don’t have Docker browse among our previous posts - we have a few posts about howto’s, examples and best practices in general for Docker and in particular about how to run the full Hadoop stack on Docker.

```
docker pull sequenceiq/ambari:1.7.0
```

<!--more-->


Once you have the container you are almost ready to go - however we’d like to ease your work even more and **oversimplify** Hadoop provisioning. 

###Get ambari-functions
Get the following `ambari-functions` [file](https://github.com/sequenceiq/docker-ambari/blob/1.7.0-ea/ambari-functions) from our GitHub. 
```
curl -Lo .amb j.mp/docker-ambari-170ea && . .amb
```

###Create your cluster 

```
amb-deploy 4
```

**Whaaat?** No really, that’s it - we have just provisioned you a 4 node Hadoop cluster in less than 2 minutes. Docker, Apache Ambari and our contributions combined are quite powerful. You can always start playing with you desired services by changing the [blueprints](https://github.com/sequenceiq/ambari-rest-client/tree/master/src/main/resources/blueprints) - the full Hadoop stack is supported.

If you’d lie to play and understand how this works check our previous blog posts - a good start is this first post about one of our contribution, the [Ambari Shell](http://blog.sequenceiq.com/blog/2014/05/26/ambari-shell/).

You have just seen how easy is to provision a Hadoop cluster on your laptop, if you’d like to see how we provision a Hadoop cluster using the very same Docker image you can check our open source, cloud agnostic Hadoop as a Service API - [Cloudbreak](http://blog.sequenceiq.com/blog/2014/07/18/announcing-cloudbreak/) - with [autoscaling](http://blog.sequenceiq.com/blog/2014/08/27/announcing-periscope/).

	
for updates follow us on [LinkedIn](https://www.linkedin.com/company/sequenceiq/), [Twitter](https://twitter.com/sequenceiq) or [Facebook](https://www.facebook.com/sequenceiq).


