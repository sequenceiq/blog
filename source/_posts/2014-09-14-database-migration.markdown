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

As applications evolve their undrelying data model change. New functionalities often need data model changes and the initial design needs to be adapted to the ever changing demands.

These changes generate two type of tasks related to the data model: structural changes (eg.: addition/removal of tables, columns, constraints etc ...)
and migration of the existing data to the new version of the datamodel.

As the data model gets more and more complex (this will happen in spite of trying to keep it as simple as possible :) )
the complexity of these tasks grow proportionally.

This happens here at Sequenceiq too; this post is about how we tried to address these problems.

## Directives

* We need a process to follow each time such changes arise
* Use appropriate tools that do the job (instead of reinventing the wheel)
* Maximize the number of automated tasks
* Minimize the amount of tasks to be performed manually

### The process

* go offline: snapshot the current state of the database
* perform structural changes
* capture differences
* perform manual changes (data migration / transformations)
* capture differences
* test the migration
* get a new snapshot and (automatically) replay changes
* (eventually go online)

### Tools

* Dockerized database
* Dockerized liquibase
* Jenkins

### Implementation

#### Get a snapshot of the current production database

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


#### Perform incremental structural changes

As we're using JPA (with Hibernate as JPA provider) incremental structural changes are executed with the
SchemaUpdate tool. This can be done during the application startup or using *ant* or *maven*. As we continuously
test the application we start the application configured to update the database based on the changed data model
(annotations). Alternatively you could regenearte the whole schema. (See the SchemaUpdate tool documentation:
[here](http://docs.jboss.org/hibernate/core/3.6/reference/en-US/html/toolsetguide.html))


#### Capture structural differencies

At this point we have a database that corresponds to the new version of the application.

We use liquibase to track database changes, to generate diffs between different versions of the database and finally to
execute changesets to bring our databases up-to-date with the latest app version.

We have created a docker image that holds a liquibase installation. Containers built from this image can be used to perform
liquibase operations on any host, thus helps us to automate some of the tasks involving liquibase.

To start the container linked to the previously started database container run the command:

```
TBD
```

#### Perform manual changes

After structural changes are performed (and captured in liquibase changesets!) usually there are some data migration tasks
that can't be done automatically. (eg.: a field has been extracted as an entity) In such cases the migration scripts have to
be implemented manually. Add the specific SQLs to the liquibase changesets. These are to be executed along with the previously
generated scripts.


#### Test the migration

At this point you can execute automated "smoke" tests to check the migration.


#### Apply liquibase changesets to the production database

All the work done till now should be recorded as liquibase changesets. The last step of the work is to apply these changesets
to the production database.
