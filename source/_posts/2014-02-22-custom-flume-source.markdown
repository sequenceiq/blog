---
layout: post
title: "Custom flume source"
date: 2014-02-22 15:45:48 +0100
comments: true
published: false
categories: flume 
author: Krisztian Horvath
---
Data analysis starts with collecting the actual data into a common system, in our case a hadoop cluster. Flume is an Apache project aiming to help us solve this problem in a very efficient and elegant way.

In flume terminology a source is responsible to listen and consume events coming from clients and forward them to one or more channels. Events can have any arbitrary format, it all depends on what source do we use. Flume provides us many sources, but only a few of them is capable to collect data through network. 

In this article I will discuss how you can implement your own that meets your demands through creating a websocket source.
There are two types of sources: event driven and pollable. In case of a pollable source, flume will start a thread to periodically call the following method to check whether there are new data or not:
``` java PollableSource interface
public Status process() throws EventDeliveryException; 
```
With event driven source you will have to take care yourself of receiving the data from the clients. For our websocket example we will use embedded Jetty 9.1. Extend the AbstractEventDrivenSource class and override the mandatory methods to bootstrap the source. In the doConfigure method you can ask the properties you need from the context. These properties are coming from your agent’s configuration file. More on this later..
``` java protected void doConfigure(Context context)
        this.host = context.getString(HOST_KEY);
        this.port = context.getInteger(PORT_KEY);
        this.path = context.getString(PATH_KEY);
        this.enableSsl = context.getBoolean(SSL_KEY, false);
```
Eventually the doStart will kick off the embedded Jetty as shown:
``` java protected void doStart()
	try {
        JettyWebSocketServer server = new JettyWebSocketServer(host, port, path, getChannelProcessor());
        server.start();
    } catch (Exception e) {
        LOGGER.error("Error starting jetty server", e);
        throw new FlumeException(e);
    }
```
<!-- more -->

Channel processor plays an important role here. Its purpose to forward the incoming events to the configured channels. 

Creating an embedded Jetty server is pretty easy and straightforward even with SSL support. I am not going in to details you can find the source code here https://github.com/sequenceiq/sequenceiq-samples You will have to create a Servlet which will create a new listener for every session or you can just simply ignore some requests based on different headers. On new message all you have to do is create a flume event out of it and pass is to the channelprocessor. 

```java public void onWebSocketText(String s) 
SimpleEvent event = new SimpleEvent();
event.setBody(s.getBytes());
channelProcessor.processEvent(event);
```
From this point the data will travel through the configured channels and sinks to end up on its final destination. It is committed in one transaction so if any component fails the whole process fails.

To deploy your custom source put the packaged jar to Flume’s classpath. 


{% blockquote %}
Flume now supports a special directory called plugins.d which automatically picks up plugins that are packaged in a specific format.
{% endblockquote %}

e.g plugins.d/websocket/lib/yoursource.jar

From now on you can use it:  
agent.sources = websocket  
agent.sources.websocket.type = com.sequenceiq.samples.flume.source.JettyWebSocketSource  
agent.sources.websocket.host = localhost  
agent.sources.websocket.port = 60000  
agent.sources.websocket.path = /flume  

Test it directly from your browser:
```javascript 
var ws = new WebSocket("ws://127.0.0.1:60000/flume")
ws.send("Some message")
```
That's it. Hope you enjoyed. We will be back with some ETL processing.