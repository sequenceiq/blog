---
layout: post
title: "Groovy and Java, the runtime bug"
date: 2014-07-13 11:13:53 +0200
comments: true
categories: [bug, java, groovy]
author: Krisztian Horvath
published: false
---

I can barely count how many languages we use at SequenceIQ. Groovy is one of them.
Coding in Groovy is fast and fun, isn't it? Except when problems come up at runtime. This is one of those.  

{% img https://raw.githubusercontent.com/sequenceiq/sequenceiq-samples/master/groovy-bug/src/main/resources/wtf.png %}

<!-- more -->

The AmbariClient is written in Groovy and in this case used by a Java application. You can find the sample bug in our
[repository](https://github.com/sequenceiq/sequenceiq-samples/tree/master/groovy-bug). The same thing could have been achieved with
reflection as well. So, do you know why this can happen? It could be an interview question.
