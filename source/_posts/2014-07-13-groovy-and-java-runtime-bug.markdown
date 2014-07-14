---
layout: post
title: "Groovy and Java, the runtime bug"
date: 2014-07-13 11:13:53 +0200
comments: true
categories: [bug, Java, Groovy]
author: Krisztian Horvath
published: true
---

I can barely count how many languages we use at SequenceIQ _[based on our GitHUb repository it's Java, Scala, Groovy, Go, CoffeeScript, JavaScript, R and Shell (Ansible, Dockerfile, AWS CLI, what not)]_. Groovy is one of them.
Coding in Groovy is fast and fun, isn't it? Except when problems come up at runtime. This is one of those.  

{% img https://raw.githubusercontent.com/sequenceiq/sequenceiq-samples/master/groovy-bug/src/main/resources/wtf.png %}

<!-- more -->

The AmbariClient is written in Groovy and in this case used by a Java application. You can find the sample bug in our
[repository](https://github.com/sequenceiq/sequenceiq-samples/tree/master/groovy-bug). The same thing could have been achieved with
reflection as well. Do you know why this can happen? It could be an interview question...
