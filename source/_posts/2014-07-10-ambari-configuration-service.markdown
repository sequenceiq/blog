---
layout: post
title: "Ambari configuration service"
date: 2014-07-04 10:20:05 +0200
comments: true
categories: [Hadoop, Ambari, YARN, Configuration]
published: false
author: Laszlo Puskas
---

At SequenceIQ we use Apache Ambari for provisioning, managing, and monitoring Apache Hadoop clusters on different environments. However Ambari has more than these - especially for us who frequently build (automated) large on-demand Hadoop clusters in cloud environments and submit different applications into. These Hadoop clusters carry different components, configurations and services - think of dev->test->UAT->PROD cluster lifecycles, different settings, SLA's, etc).

Configuration of applications that use dynamically built YARN clusters can be challenging. This is due to the huge amount of configuration properties, some of which needs to be kept in sync on YARN client application side. Think of _yarn.resourcemanager.address_, _fs.defaultFS_ to name a few. Each time these cluster specific entries change, client applications needs to be reconfigured. Those who ever played with clusters where the default properties are overridden know what this means...

At Sequenceiq we use Ambari for building on-demand YARN clusters (see the related [ blog post](http://blog.sequenceiq.com/blog/2014/06/17/ambari-cluster-on-docker/)). In our case Ambari not only maintains the configuration of the cluster it manages but also provides access to them through a set of REST resources.

To overcome the configuration maintenance problem in YARN client applications, we implemented an Ambari REST client application that embedded in client applications can dynamically retrieve configuration from an Ambari instance. Thus the only thing needed for an application to have the proper configuration is the access to the Ambari instance.

The Ambari REST client is an open source project we developed and contributed to Apache Ambari - it's a Groovy REST client used by the [Ambari Shell](https://github.com/sequenceiq/ambari-shell) and [Cloudbreak](http://docs.cloudbreak.apiary.io/).

<!-- more -->

Here is a short example on how to make use of the Ambari client in an arbitrary application:

``` java
public class AmbariConfigurationService {
...
private AmbariClient ambariClient;

public AmbariConfigurationService(){
  // inject / provide the service with the ambari related properties
  ambariClient = new AmbariClient(ambariHost, ambariPort, ambariUser, ambariPass);
}

// list with the properties needed by the application
private List<String> configList = Arrays.asList("mapreduce.framework.name", "yarn.resourcemanager.address", "hbase.zookeeper.quorum" );

// assembles a Configuration instance with the properties needed by the application
public Configuration getConfiguration() {
        //  use this constructor to avoid loading of properties from the classpath!
        Configuration configuration = new Configuration(false);

        // Map with service specific configuration. The keys are service names: eg.: yarn-site, hbase-site, global ...
        Map<String, Map<String, String>> serviceConfigMap = ambariClient.getServiceConfigMap();

        for (Map.Entry<String, Map<String, String>> serviceEntry : serviceConfigMap.entrySet()) {
            for (Map.Entry<String, String> configEntry : serviceEntry.getValue().entrySet()) {
                if (configList.contains(configEntry.getKey())) {
                    configuration.set(configEntry.getKey(), configEntry.getValue());
                }
            }
        }

        // decorate the config with application specific entries, like "dfs.client.use.legacy.blockreader", "mapreduce.job.user.classpath.first"
        decorateConfiguration(configuration);

        return configuration;
    }
}
```
_Note: Apart of the ```getServiceConfigMap() ``` method you'll find a few interesting and useful operations_

You can get the Ambari client code from the [SequenceIQ GitHub repository](https://github.com/sequenceiq/ambari-rest-client)
(Clone it, build it and add it as a dependency to your project).

If you'd like to play with a "real" Ambari managed cluster check out [this](http://blog.sequenceiq.com/blog/2014/06/19/multinode-hadoop-cluster-on-docker/) older blogp ost as well.


Let us know how it works for you - for updates follow us on [LinkedIn](https://www.linkedin.com/company/sequenceiq/), [Twitter](https://twitter.com/sequenceiq) or [Facebook](https://www.facebook.com/sequenceiq).
