##The search

At SequenceIQ we frequently provision Hadoop clusters on different environments - and for a long time we have been in a search for the right tool. In this blog post we’d like describe our needs, our contribution and how we ended up using Apache Ambari pretty much for everything which is related to provisioning and and configuration. 

We are building an open source, cloud agnostic, Docker based Hadoop as a Service called [Cloudbreak](http://sequenceiq.com/cloudbreak) - and in order to be able to span up dynamic Hadoop clusters we needed a provisioning tool. During the past period we have been checking all the available alternatives - and we decided to go along with Apache Ambari. While there are many benefits (and there have been many posts about this) of Ambari for us the most important key points were:
	
	* 100% open source under Apache 2 license
	* very active and agile development time
	* available REST API
	* support of blueprints

##First steps

We are a company with very strong focus on DevOps - and we always automate everything and try to use CLI/shells. Once we have made the decision to use Apache Ambari the first thing we looked for was a command line shell (and a REST client to be used from Java/Scala) - but realized that currently it’s missing. We have quickly engaged with the Apache Ambari community and a few engineers from Hortonworks, have presented our idea - and once we have agreed on details and filled a JIRA the process accelerated. 

##Apache Ambari Shell

The goal we set with the Apache Ambari shell was to provide an interactive command line tool which supports:

*all functionality available through the REST API or Ambari web UI
*makes possible complete automation of management task via scripts
*context aware command availability
*tab completion
*required/optional parameter support
*hint command to guide you on the usual path


