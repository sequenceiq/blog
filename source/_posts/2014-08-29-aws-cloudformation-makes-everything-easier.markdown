---
layout: post
title: "Infrastructure management with CloudFormation"
date: 2014-08-29 16:13:06 +0200
comments: true
categories: [Cloud, Cloudbreak, AWS, CloudFormation, infrastructure]
author: Marton Sereg
published: true
---


Our Hadoop as a Service solution, [Cloudbreak](https://cloudbreak.sequenceiq.com) integrates with multiple cloud providers to deploy Hadoop clusters in the cloud. It means that every time a cluster is requested, Cloudbreak goes to the selected cloud provider and creates a new, separated infrastructure through the provider’s API. Building this infrastructure can be a real pain and can cause a lot of problems - it involves a lot of API calls, the polling of created building blocks, the management of failures and the necessary rollbacks to name a few. With the help of [AWS CloudFormation](http://aws.amazon.com/cloudformation/) we were able to avoid most of these problems when integrating AWS in Cloudbreak.


###Problems with the traditional approach

When Cloudbreak creates a Hadoop cluster it should first create the underlying infrastructure on the cloud provider. The building blocks are a bit different on every provider, the following resources are created on AWS:

- a virtual private cloud (VPC)
- a subnet
- an internet gateway
- a route table
- an auto scaling group and its launch configuration
- a security group

Although AWS has a pretty good API and great SDKs to communicate with it, we needed to deal with the above described problems if we would like to create all of these elements one by one through the Java SDK. The code would start with something like this with the creation of the VPC:

```java
AmazonEC2Client amazonEC2Client = new AmazonEC2Client(basicSessionCredentials);
amazonEC2Client.setRegion(region);

CreateVpcRequest vpcRequest = new CreateVpcRequest().withCidrBlock(10.0.0.0/24);
CreateVpcResponse vpcResponse = amazonEC2Client.createVpc(createVpcRequest);

//poll vpc creation until it’s state is available
waitForVPC(amazonEC2Client, vpcResponse.getVpc());

ModifyVpcAttributeRequest modifyVpcRequest = new ModifyVpcAttributeRequest().withEnableDnsHostnames(true).withEnableDnsSupport(true);
amazonEC2Cient.modifyVpcAttribute(modifyVpcRequest);
```

<!--more-->

The above code is only a taste of the whole thing. The VPC is one of the most simple resources with very few attributes to set. Also the polling of the creation process isn’t detailed here as well as failure handling. In addition the different resources would be scattered around the code making it impossible to have an overview of the whole stack and making it much harder to find bugs or to modify some attributes. With CloudFormation all of the above problems can be solved very easily.

###Introduction to CloudFormation

According to the [AWS CloudFormation documentation](http://aws.amazon.com/cloudformation/) it was designed to create and manage a collection of related AWS resources easily and provisioning and updating them in an orderly and predictable fashion. What it really means is that the resources can be described declaratively in a JSON document (a *template*) and the whole *stack* can be created/updated/deleted with a simple API call. AWS also handles failures, and rollbacks the whole stack if something goes wrong. Furthermore it is able to send notifications to *SNS topics* when some event occurs (e.g.: a resource creation started or the resource is completed), making the polling of resource creations unnecessary.

###Template structure

We don’t want to give a detailed introduction on how the structure of a CloudFormation template look like, the [AWS documentation](http://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/template-anatomy.html) covers it really well and there are also a lot of [samples](http://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/sample-templates-services-us-west-2.html).
Instead we’re trying to focus on the advantages that CloudFormation gave us while using it, so let’s jump in the middle and start with a simple example. The declaration of a VPC in a template looks like this:

```json
"Resources" : {
  "MY_VPC" : {
    "Type" : "AWS::EC2::VPC",
    "Properties" : {
      "CidrBlock" : { "10.0.0.0/16" },
      "EnableDnsSupport" : "true",
      "EnableDnsHostnames" : "true",
      "Tags" : [
        { "Key" : "Application", "Value" : { "Ref" : "AWS::StackId" } },
        { "Key" : "Network", "Value" : "Public" }
      ]
    }
  }
}
```


The JSON syntax can be a bit complicated sometimes, especially when dealing with a lot of references to other properties with the *"Ref"* keyword or some other built-in CloudFormation [functions](http://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/intrinsic-function-reference.html), but it is much clearer than the Java code above.
Other than resources, there are other parts of a CloudFormation template (*Conditions*, *Mappings*, *Outputs*, *Intrinsic Functions*) but here we will cover only one more: *Parameters*.

Declaring a parameter means that there is no hard-coded value for a given attribute, rather it is given to the template when creating the stack. If you’d like to have an EC2 Instance  in your template but you don’t want to hardcode its type, you can have a parameter like this:

```json
"Parameters" : {
  "InstanceType" : {
    "Description" : "EC2 instance type",
    "Type" : "String",
    "Default" : "m3.medium",
    "AllowedValues" : [ "m3.medium","m3.large","m3.xlarge","m3.2xlarge"],
    "ConstraintDescription" : "must be a valid EC2 instance type."
  }
}
```

After it’s declared, you can reference it from a resource with the *Ref* keyword:

```json
"EC2Instance" : {
  "Type" : "AWS::EC2::Instance",
  "Properties" : {
    "SecurityGroups" : [ { "Ref" : "InstanceSecurityGroup" } ],
    "InstanceType" : { "Ref" : "InstanceType" },
    "KeyName" : { "Ref" : "KeyName" },
    "ImageId" : "ami-123456",
    "EbsOptimized" : "true"
  }
}
```

You can reference not only parameters, but other resources as well. In the above code example there is a reference to *InstanceSecurityGroup* that is an *AWS::EC2::SecurityGroup* type resource and that is declared in an other part of the template.

###Creating the stack

So we’ve declared a few resources, how can we tell AWS to create the stack? Let’s see how it looks like with the Java SDK (two parameters are passed to the template):

```java
CreateStackRequest createStackRequest = new CreateStackRequest()
    .withStackName(“MyCFStack")
    .withTemplateBody(templateAsString)
    .withNotificationARNs(notificationTopicARN)
    .withParameters(
        new Parameter().withParameterKey("InstanceCount").withParameterValue(“3"),
        new Parameter().withParameterKey("InstanceType").withParameterValue(“m3.large"));

client.createStack(createStackRequest);
```

And that’s it. It’s every code that should written in Java to create the complete stack. It is pretty straightforward, the only thing that needs to be explained is the *notification ARN* part. It is the identifier of an *SNS topic* and it is detailed below.

###Callbacks

CloudFormation is able to send notifications to SNS *topics* when an event occurs. An event is when a resource creation is started, finished or failed (and the same with delete). SNS is Amazon’s Simple Notification Service that enables endpoints to subscribe to a topic, and when a message is sent to a topic every subscriber receives that message. AWS supports a lot of endpoint types. It can send notifications by email or text message, to Amazon Simple Queue Service (SQS) queues, or to any HTTP/HTTPS endpoint. In the Cloudbreak project we’re using HTTP endpoints as callback URLs. We’re also creating topics and subscriptions from code but that could fill up another full blog post.


If you just like to try SNS, you can create a topic and a subscription from the AWS Console. After you have a confirmed subscription of an HTTP endpoint (e.g.: *example.com/sns*), you can very easily create an HTTP endpoint in Java (with some help from [Spring](http://spring.io/)):

```java
@RequestMapping(value="sns", method = RequestMethod.POST)
@ResponseBody
public ResponseEntity<String> receiveSnsMessage(@RequestBody String request) {
  // parse and handle request
}
```

For a more detailed example see the [controller class](https://github.com/sequenceiq/cloudbreak/blob/master/src/main/java/com/sequenceiq/cloudbreak/controller/AmazonSnsController.java) in Cloudbreak.
So every time a CloudFormation stack event occurs, Cloudbreak receives a message that is parsed and handled correctly - there is no need to poll the creation of resources and dealing with timeouts.


###Failures and rollbacks

It is always possible that something will go wrong when creating a stack with a lot of resources. With the traditional approach you must keep track of the resources that were created and you will have to implement some rollback logic that gets called when something unexpected happens and that rolls back the already created elements somehow. With CloudFormation these things are completely done by AWS.

The resources in the stack are tracked so the only thing you have to save is the identifier of the stack. If one of the resources fails to be created AWS rolls back every other resource and puts the stack in *ROLLBACK_COMPLETED* state. It also sends the failure message to the SNS topic with the exact cause of the failure.
The same is true if you’d like to delete the stack. The only call that you will have to send to the AWS API is the deletion of the stack (very similar to the creation in Java). CloudFormation will delete every resource one by one and will take care of failures.


###Notes

The template we used in Cloudbreak is available [here](https://github.com/sequenceiq/cloudbreak/blob/master/src/main/resources/templates/aws-cf-stack.ftl). It is not a pure CloudFormation template because of some limitations - the number of attached volumes cannot be specified dynamically and it is not possible to specify it as a parameter if spot priced instances are needed or not - we ended up generating the template with Freemarker.



###Terraform
The [company](http://www.hashicorp.com/products) that brought us [Vagrant](http://www.vagrantup.com/), [Packer](http://www.packer.io/) and a few more useful things has recently announced a new project named [Terraform](http://www.terraform.io/intro/index.html). Terraform is inspired by tools like CloudFormation or [OpenStack’s Heat](https://wiki.openstack.org/wiki/Heat), but goes further as it supports multiple cloud platforms and their services can also be combined. If you’re interested in managing infrastructure from code and configuration you should check out that project too, we’ll keep an eye on it for sure.

Stay tuned and make sure you follow us on [LinkedIn](https://www.linkedin.com/company/sequenceiq/), [Twitter](https://twitter.com/sequenceiq) or [Facebook](https://www.facebook.com/sequenceiq).
