---
layout: post
title: "Cloudbreak new provider implementation - Part I: Build your custom image"
date: 2014-09-18 09:42:58 +0200
comments: true
categories: [Cloudbreak, Docker, Hadoop, Cloud, Google Cloud]
categories: Richard Doktorics
published: true
---

Not so long ago we have released [Cloudbreak](http://blog.sequenceiq.com/blog/2014/07/18/announcing-cloudbreak/) - the cloud agnostic, open source and Docker based Hadoop as a Service API (with support for [autoscaling](http://blog.sequenceiq.com/blog/2014/08/27/announcing-periscope/) Hadoop clusters). As we have `dockerized` the whole Hadoop ecosystem, we are shipping the containers to different cloud providers, such as Amazon AWS, Microsoft Azure and Google Cloud Compute. Also Cloudbreak has an [SDK](http://sequenceiq.com/cloudbreak/#add-new-cloud-providers) which allows you to quickly add your favorite cloud provider. In this post (series) we’d like to guide you trough the process, and show you how to create a custom image - on Google Cloud. We have chose Google Cloud as this is the least documented and has the smallest amount on default images (there are thousand for Amazon, and hundreds for Azure). Nevertheless on all cloud provider usually you’d like to have a custom image with your preferred OS, configuration and potentially installed applications.

<!-- more -->

### Why do we need custom images on every cloud?

All the above are true for us as well - with some simplifications. We use Docker to run every process/application - for the benefits we have covered in other posts many times - and apart from Docker, our (or the customer’s) preferred OS and a few other helper/debugger things (such as [nsenter](https://registry.hub.docker.com/u/jpetazzo/nsenter/)) 
we are almost fine. We have made some PAM related fixes/contributions for Docker - and until they are not in the upstream we have built/derive from our base layer/containers - so with this and the actual containers included this is pretty much how a cloud base image looks like for us.

As usual we always automate everything - building custom cloud base images is part of the automation and our CI/CD process as well. For that we use [Ansible](http://www.ansible.com/home) as the preferred IT automation tool. So the first step is to define your own [playbook](http://docs.ansible.com/playbooks.html) to install everything on the virtual machine.

A simple playbook looks like this:

```
  - name: Install Docker
    shell: curl -sL https://get.docker.io/ | sh
    when: ansible_distribution == 'Debian' or ansible_distribution == 'Ubuntu'

  - name: Pull sequenceiq/ambari image
    shell: docker pull sequenceiq/ambari:pam-fix

  - name: Pull jpetazzo/nsenter image
    shell: docker pull jpetazzo/nsenter

  - name: Install bridge-utils
    apt: name=bridge-utils state=latest
    when: ansible_distribution == 'Debian' or ansible_distribution == 'Ubuntu'

  - name: install jq
    shell: curl -o /usr/bin/jq http://stedolan.github.io/jq/download/linux64/jq && chmod +x /usr/bin/jq

```

Using Google cloud you have 2 choices:

..* Create snapshots starting from a default image
..* Create a custom image 

### Image creation using snapshots

We are using Debian as the host OS on Google Cloud, and have created a virtual machine using the default [Debian](https://developers.google.com/compute/docs/operating-systems#backported_debian_7_wheezy) image. First thing first, you need to create a persistent disk:

```
gcloud compute disks create temporary-disk --zone ZONE
```

Then create a virtual machine with the temporary-disk:

```
gcloud compute instances create example-instance \
  --scopes storage-rw --image IMAGE \
  --disk name=temporary-disk device-name=temporary-disk --zone ZONE
```

And attach the disk to the google cloud instance:

```
gcloud compute instances attach-disk example-instance
  --disk temporary-disk --device-name temporary-disk --zone ZONE
```

When this is finished then you can `shh` to the `sample-instance`. You can now check your mounted volumes with this command:

```
ls -l /dev/disk/by-id/google-*
```

Now you need to create a folder which will contain your custom built image:

```
sudo mkdir /mnt/tmp
```

You have to format your partition before the image creation:

```
sudo /usr/share/google/safe_format_and_mount -m "mkfs.ext4 -F" /dev/sdb /mnt/tmp
```

Now you can start building the image which will last about 10 minutes:

```
sudo gcimagebundle -d /dev/sda -o /mnt/tmp/ --log_file=/tmp/imagecreation.log
```

You have now an image in /tmp with a special hex number like `/tmp/HEX-NUMBER.image.tar.gz`

Once you uploaded it to a Google bucket you are done, and ready to use it.

```
gsutil cp /mnt/tmp/IMAGE_NAME.image.tar.gz gs://BUCKET_NAME
```

### Create a custom image - using your favorite OS

[Ubuntu server 14.04](http://www.ubuntu.com/download/server) is many’s preferred Linux distribution - unluckily there is no default image using Ubuntu as the OS in the Google Cloud](https://developers.google.com/compute/docs/operating-systems). Luckily this is not that complicated - the process below works with any other OS as well. In order to start you should have [Virtualbox](https://www.virtualbox.org/) installed. Download an Ubuntu server from [Ubuntu’s](http://www.ubuntu.com/server) web page.
Install in into the [Virtualbox](https://www.virtualbox.org/) box, start it and `ssh` into. Once you are inside you will have to install the [Google Cloud SDK](https://developers.google.com/cloud/sdk/). This is needed for the custom image, as contains some extra feature like `google-startup-scripts`. Remember that Ubuntu (and in general a few cloud providers) support `cloud-init` scripts, and this is why we need the Google Cloud SDK - as we ship these images to the `cloud`.

After the installation add the following kernel options into the `/etc/default/grub`:

```
# to enable paravirtualization
CONFIG_KVM_GUEST=y

# to enable the paravirtualized clock.
CONFIG_KVM_CLOCK=y

# to enable paravirtualized PCI devices.
CONFIG_VIRTIO_PCI=y

# to enable access to paravirtualized disks.
CONFIG_SCSI_VIRTIO=y

# to enable access to the networking.
CONFIG_VIRTIO_NET=y
```

Now you are ready to prepare an `official` image into a tar file, by selecting the virtual box image file on your disk and convert it.
You can convert your `vmdk` file into the supported raw type by using:

```
qemu-img convert -f vmdk -O raw VMDK_FILE_NAME.vmdk disk.img
```

The .img file name has to be `disk.img`. After you have converted the image, you have to make a tar file:

```
tar -Szcf <image-tar-name>.tar.gz disk.raw
```

Same as before, you have to upload in to a Google Cloud Bucket:

```
gsutil cp <image-tar-name>.tar.gz gs://<bucket-name>
```

Now you have an `official` image template but you have to create the image in Google Cloud:

```
gcutil addimage my-ubuntu gs://<bucket-name>/ubuntu_image.tar.gz
```

Once this is done you have created your custom built Google Cloud image, and you are ready to start cloud instances using it. Let us know how it works for you, and make sure you follow us on [LinkedIn](https://www.linkedin.com/company/sequenceiq/), [Twitter](https://twitter.com/sequenceiq) or [Facebook](https://www.facebook.com/sequenceiq) for updates.
