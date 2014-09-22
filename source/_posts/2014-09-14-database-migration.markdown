---
layout: post
title: "Managing database migrations with docker"
date: 2014-09-14 18:00:00 +0200
comments: true
categories: [Liquibase, Docker]
author: Laszlo Puskas
published: false
---


## Introduction

As applications evolve their underlying data model change. New functionalities often need data model changes and the initial design
needs to be adapted to the ever changing demands.

These changes generate two type of tasks related to the data model: structural changes (eg.: addition/removal of tables, columns, constraints etc ...)
and migration of the existing data to the new version of the datamodel.

As the data model gets more and more complex  - this will happen in spite of trying to keep it as simple as possible -
the complexity of these tasks grow proportionally.

This happens here at Sequenceiq too; this post is about how we tried to address these problems.

## Directives

* We need a process to follow each time such changes arise
* Use appropriate tools that do the job (instead of reinventing the wheel)
* Make the process automated

### The process

The process - as the common sense suggests - could be split in the following steps:

* Start from the initial version of the database (the version in production)
* Perform changes required by the new version of the application
* Capture and store differences between the two versions of the database
* (Automatically) Apply changes to the initial database version
* Perform tests
* Apply changes to the production

### Tools

* Dockerized (Postgres) database
* Dockerized liquibase
* Jenkins

### Implementation

#### Start from the initial version of the database

To start with, you need a database that's (structurally) identical to the production. There are several ways to achieve this;
we try to keep it simple, so here's what we do:
* we always have a QA database which is identical to the production (obviously the data is not the same)
* in our application we use JPA backed by Postgres
* we make a copy of the *data* folder of the postgres installation into an arbitrary location on the host
* we pass it as a volume to a Docker container running Postgres

This is the command you need to run every time you need a database in the initial state:


```
docker run -d \
  --name $CONTAINER_NAME \
  -v /$WORKING_DIR/data:/data \
  -p 5432:5432 \
  -e "USER=$DB_USER" \
  -e "PASS=$DB_PASS" \
  -e "DB=$DB_NAME" \
paintedfox/postgresql
```
where the passed in variables are the following:
* CONTAINER_NAME - the name of the database Docker container
* DB_USER - the database user name
* DB_PASS - the database password
* DB_NAME - the databaste schema

You have a running database now; you can connect to it on your localhost, port 5432 with the given username/password.


#### Perform changes required by the new version of the application

As expected, this is the most challenging part in the process: changes need to be implemented and also captured so that they
 can be applied any time (preferably in an automated way)

As we're using JPA (with Hibernate as JPA provider) incremental structural changes are executed with the
SchemaUpdate tool. This can be done during the application startup or using *ant* or *maven*. As we continuously
test the application we choose to start the application configured to update the database based on the changed data model
(annotations). Alternatively you could regenearte the whole schema. (See the SchemaUpdate tool documentation:
[here](http://docs.jboss.org/hibernate/core/3.6/reference/en-US/html/toolsetguide.html))

At this point we have a database that corresponds to the new version of the application.

Please note here, that only incremental changes have been applied to the database till now, meaning that for example new fields have been added,
 but old/deprecated fields haven't been deleted. Two kind of scripts need to be implemented manually:

1. implement those changes that couldn't be performed by the SchemaUpdate tool, such as cleanup (SQL) scripts.

2. implement data migration scripts, that is, to write those scripts that adapt the existing data to the new structure. Think of cases
 when for example an entity field becomes a new entity; and instead of a value you need to store a reference to the new entity. We store
 these kind of scripts in a separate project under version control in form of *Liquibase changlogs*


#### Dockerized Liquibase

Speaking of tools, we found that [Liquibase](http://www.liquibase.org/index.html) addresses many of our requirements, especially by its
mechanism for version handling and automatic application of "changelogs".

We use Liquibase for the following tskas

1. track database changes;
2. generate diffs between different versions of the database
3. apply changelogs


We have created a docker image that holds a liquibase installation.

Containers built from this image can be used to perform liquibase operations on any host and besides saves us a
lot of time by having the installation and configuration shipped, and helps us to automate some of the tasks;

You can use the container for performing liquibase tasks manually in a terminal, or you can start the container to automatically perform
specific tasks (and quit eventually)

To start the container linked to the previously started database container and perform manual operations, run:

```
docker run -it \
--name $LIQUIBASE_CONTAINER \
--link $DB_CONTAINER:db \
--entrypoint /bin/bash \
-v /$LIQUIBASE_CHANGELOGS:/changelogs \
$LIQUIBASE_DOCKER_IMAGE \
/bin/bash
```

Here the meaning of variables are the following:

* LIQUIBASE_CONTAINER the name of the Liquibase Docker container
* DB_CONTAINER the name of the databes container the Liquibase container is to be linked to
* LIQUIBASE_CHANGELOGS the folder holding the liquibase changelogs (Liquibase will read and write here)
* LIQUIBASE_DOCKER_IMAGE the name of the dockerized Liquibase Docker image 


#### Test the migration

At this point you can execute automated "smoke" tests to check the migration.


#### Apply liquibase changesets to the production database

All the work done till now should be recorded as liquibase changesets. The last step of the work is to apply these changesets
to the production database.
