---
layout: post
title: "Ambari configuration service"
date: 2014-07-04 10:20:05 +0200
comments: true
categories: [Hadoop, Ambari, YARN, Configuration]
published: false
author: Laszlo Puskas
---

Configuration of applications that use dynamically built YARN clusters can be challenging. This is due to the huge amount of configuration properties, some of which need to be kept in sync on YARN client app side. Think of _yarn.resourcemanager.address_, _fs.defaultFS_ to name a few. Each time these cluster specific entries change client applications need to be reconfigured. Those who ever played with clusters where the default properties are overridden know what this means...

At Sequenceiq we use Ambari for building YARN clusters (see the related [ blog post](http://blog.sequenceiq.com/blog/2014/06/17/ambari-cluster-on-docker/)) Ambari not only maintains the configuration of the cluster it manages but also provides access to them through a set of REST resources.

To overcome the configuration maintenance problem in YARN client applications, we implemented an ambari rest client app that embedded in client applications can dynamically retrieve configuration from an ambari instance. Thus the only thing needed for an app to have the proper configuration is the access to the ambari instance.

Here is a short example on how to make use of the ambari client in an arbitrary application:

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
_Note: Apart of the ```getServiceConfigMap() ``` method you'll find many more interesting and useful operations_

You can get the ambari client code from our [git repository](https://github.com/sequenceiq/ambari-rest-client)
(Clone it, build it and add it as a dependency to your project)

If you'd like to play with a "real" ambari managed cluster read [this](http://blog.sequenceiq.com/blog/2014/06/17/ambari-cluster-on-docker/) blogpost.
