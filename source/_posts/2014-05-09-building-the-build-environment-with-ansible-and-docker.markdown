---
layout: post
title: "Building the build environment with Ansible and Docker"
date: 2014-05-09 13:51:57 +0200
comments: true
categories: [Ansible,Docker,CI,Jenkins,devops]
author: Marton Sereg
published: true
---

At SequenceIQ we put a strong emphasis on automating everything we can and this automation starts with our continuous integration & delivery process.

## Introduction

Lately there is a lot of buzz around continuous integration, development and deployment. More and more companies are moving away from long release cycles towards the "release early, release often" approach. The advantages of this approach are well known: lower overhead, earlier bug discovery and bug fixing, fewer context switches for the developers to name just a few. There are very good resources to learn about these concepts - blog posts by different companies (e.g.: by [Netflix](http://techblog.netflix.com/2013/08/deploying-netflix-api.html)) and of course the [book](http://www.amazon.com/dp/0321601912) 'Continuous Delivery' by Jez Humble and David Farley - we'll now try to add our own experiences as well.

We'll share two blog posts about our continuous delivery at SequenceIQ: the first one being an introductory post about some tools we use to make the whole process easier and more robust, the second one explains the [flow](http://scottchacon.com/2011/08/31/github-flow.html) we use from committing changes to being the changes available in our different environments.

## Tools

Our CI and CD process at SequenceIQ is based on Ansible, Jenkins and of course Docker.
When we started to build our own process, we decided that we don't want to commit the same mistake that a lot of companies make about their build environment. At these companies the build servers where Jenkins and/or the other build tools are installed are often prepared once in the far past by someone who probably doesn't work there anymore. It quickly becomes something that everyone is afraid to touch and just hope that it will work forever. As the projects improve there will be a lot of different tools with a lot of different versions on the build machine and soon it leads to a small chaos, where the maintenance will involve a lot of hard manual work. To get rid of these problems, we use [Ansible](http://www.ansible.com/) to "build the build infrastructure", and Docker to run the builds in separated self-sufficient containers.

<!-- more -->

## Ansible

We have an Ansible script which starts an EC2 instance in the cloud and provisions everything on this server automatically. This script can be easily executed with a single command from a developer laptop:

```
ansible-playbook -i hosts ci.yml
```

To run this command Ansible, python and some python modules must be installed on the local machine. To avoid having different version of these tools on the development machines we automated the installation of our development environment too - maybe the topic of another post in the future.
So let's see how the Ansible script works exactly.

### Creating an instance in the cloud

First it needs to start an instance in the AWS cloud, so it invokes our **ec2 role** on localhost:
```yaml
- name: Request and init EC2 instance
  hosts: localhost
  roles:
     - ec2
```

The ec2 role requests an EC2 spot priced instance and associates it with an elastic IP. We can easily use a spot priced instance because if it gets shut down by AWS we can recreate it in a few minutes! Ansible has a few [cloud modules](http://docs.ansible.com/list_of_cloud_modules.html) which makes it quite easy to manage EC2 instances. Requesting a spot priced instance looks like this (the placeholders come from Ansible group variables):
{% raw %}
```yaml
- name: Create an EC2 spot priced instance
  local_action:
  module: ec2
  key_name: "{{ ec2.keypair }}"
  group: "{{ ec2.security_group }}"
  instance_type: "{{ ec2.instance_type }}"
  spot_price: "{{ ec2.spot_price }}"
  image: "{{ ec2.image }}"
  wait: yes
  region: "{{ ec2.region }}"
  id: "{{ ec2.idempotent_id }}"
  register: ec2result
```
{% endraw %}

### Provisioning the build server

After the EC2 instance is running and accepting SSH connections, the script can go on and start to install the tools needed. Because almost everything is running in separated Docker containers, we only need 3 things: Docker, Nginx and Jenkins. Installing Docker is pretty easy as the new Amazon Linux AMIs are [prepared](http://aws.amazon.com/amazon-linux-ami/2014.03-release-notes/) to run Docker. We only need to install it from Amazon's provided Software Repository, and start the service. It looks like this in the Ansible script:

```yaml
- name: Install Docker on Amazon Linux AMI
  when: ansible_os_family == "RedHat"
  yum: name=docker state=present

- name: Start Docker service
  service: name=docker state=started
```

After Docker is installed we can start some containers that are used by some Jenkins builds later (e.g.: a SonarQube server and a MySQL database that holds the results - we've created publicly available [containers](https://index.docker.io/u/sequenceiq/sonar-server/) on our Github page.

To install and configure Nginx we use an [existing role](https://galaxy.ansible.com/list#/roles/466) from Ansible Galaxy that is well prepared and easily configurable. We are configuring Nginx to forward requests from port 80 to either Jenkins or Sonar.

For example the configuration for Jenkins is the following in the Ansible group variables:

```yaml
nginx_sites:
  default:
    - listen 80
    - server_name jenkins.sequenceiq.com
    - location / {
       proxy_pass http://jenkins;
       proxy_redirect off;
       proxy_set_header Host $host;
       proxy_set_header X-Forwarded-Host $server_name;
      }
nginx_configs:
  proxy:
    - proxy_set_header X-Real-IP $remote_addr
    - proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for
  upstream:
    - upstream jenkins { server 127.0.0.1:8080 weight=10; }
```

The most difficult thing to install is Jenkins: we want our configurations and jobs to be instantly available as well. Jenkins has a [command-line interface](https://wiki.jenkins-ci.org/display/JENKINS/Jenkins+CLI) that allows access from a script. It has a lot of built-in commands to manage jobs and other configurations and it even has a command to execute a Groovy script on the server. We use these features extensively to prepare the whole Jenkins environment from sketch. Our Jenkins role (that will be available soon on Ansible Galaxy) is able to do the following:
- Install Jenkins and its dependencies, and get the Jenkins CLI jar from the specified URL.
- Configure the global Jenkins properties like the mail server, or the properties needed for the Github pull request builder plugin - it is simply achieved by copying a global config.xml to the Jenkins home directory using Ansible's copy module.
- Install and update plugins through the Jenkins CLI. Installing plugins looks like this:

{% raw %}
```yaml
- name: Install plugins
  sudo: yes
  shell: java -jar {{ jenkins.cli_dest }} -s http://localhost:8080/ install-plugin {{item.item}}
  when: item.stdout.find('false') != -1
  with_items: check_plugins.results
  notify:
  - 'Restart Jenkins'
```
{% endraw %}

- Configure security (we use Github OAuth). The Jenkins CLI doesn't have any dedicated commands for setting security, but it can be configured with a Groovy script that can be invoked from the CLI:

```groovy
def githubSecurityRealm = new org.jenkinsci.plugins.GithubSecurityRealm("https://github.com", "https://api.github.com", clientId, clientSecret)
def authorizationStrategy = new org.jenkinsci.plugins.GithubAuthorizationStrategy("admin1,admin2",true,"organization name",true,false,false)
jenkins.model.Jenkins.instance.setSecurityRealm(githubSecurityRealm)
jenkins.model.Jenkins.instance.setAuthorizationStrategy(authorizationStrategy)
jenkins.model.Jenkins.instance.save()

```

- Copy private keys for Github builds - it simply copies the predefined private SSH keys from a local directory to the `~/.ssh` directory of the Jenkins user. We use a dedicated Github user to communicate with Github from Jenkins.

- Creating jobs from XML configuration. The Jenkins CLI supports the creation of Jenkins jobs through the create-job command that accepts an XML file as input that defines the Jenkins job. Currently our Jenkins role works by invoking this command for every job that is defined in the variables and has a corresponding XML file in a predefined directory.  We are planning to later modify this role to have a template that holds the structure of a Jenkins job XML so it won't be needed to create the whole XML file manually, only the required parameters among the Ansible variables.

{% raw %}
```yaml
- name: Create jenkins jobs
  shell: java -jar {{ jenkins.cli_dest }} -s http://localhost:8080/ create-job {{ item }} < {{ jenkins.dest }}/{{item}}.xml
  with_items: jenkins_jobs
  when: existing_jobs.changed and existing_jobs.stdout.find('{{ item }}') == -1
```
{% endraw %}

## Docker

The other tool besides Ansible that we use extensively in our build environment is Docker. Docker is a quickly expanding technology that enables the creation of lightweight application containers. If you don't know about Docker yet, check out the official [Getting Started guide](https://www.docker.io/gettingstarted/) or our own [blog post](http://blog.sequenceiq.com/blog/2014/04/04/hadoop-docker-introduction/) about it.
With the help of Docker we don't need to worry about the tools needed for the builds or its dependencies on the continuous integration server as they are packaged in separate containers. Every one of our builds on Jenkins are only a few lines that runs a container, maybe copies something out of it and removes the container after it finished. We provide a few environment variables, some shared directories or some links between containers where needed. One of our jobs in Jenkins that builds the master branch looks like this:
```bash
#!/bin/bash
docker run -i --name $BUILD_TAG \
-v "/var/lib/jenkins/.gradle-api:/root/.gradle:rw" \
-e "SONAR_USERNAME=$SONAR_USERNAME" \
-e "SONAR_PW=$SONAR_PW" \
-e "BUILD_NUMBER=$BUILD_NUMBER" \
-e "KEY=$(cat /var/lib/jenkins/.ssh/id_rsa| base64 -w 0)" \
-e "REPO=$REPO_ADDRESS" \
-e "BRANCH=master" \
-e "BUILD_TASKS=clean build sonarRunner uploadArchives" \
-e "BUILD_ENV=jenkins" \
-e "GRADLE_OPTS=-XX:MaxPermSize=512m" \
--link sonar_server:sonar \
--link sonar_mysql:sonar_db \
sequenceiq/build /etc/build-project.sh
sleep 5
docker cp $BUILD_TAG:/tmp/prj/build/build.info $WORKSPACE
docker rm $BUILD_TAG

```

And not only our builds run in Docker, some other tools we use on the build environment also run in containers. For instance our code quality management tool, SonarQube and the MySQL database it uses also runs in separate containers. This way we don't need to install them on the EC2 instance directly, we only need to link them where needed - see the example above!

In our next blog post about continuous integration we'll explain the process we use at SequenceIQ to continuously deliver the new features to production using the Github flow with Jenkins and Docker.

