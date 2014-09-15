---
layout: post
title: "Cloudbreak new provider implementation - Part I: Prepare your host OS"
date: 2014-09-15 09:42:58 +0200
comments: true
categories: [Cloudbreak, Docker, Hadoop, Cloud, GoogleCloud]
categories: Richard Doktorics
published: false
---


Our hadoop as a service API has some cloud provider implementation like Azure and AWS.
About the [Cloudbreak](http://sequenceiq.com/cloudbreak/) one of the most important thing is that we need to support as much cloud as we could. Our new implementation will support the [Google Cloud](https://cloud.google.com/).
I thought this article series will help to the contributors whose want to implement a new cloud provider in [Cloudbreak](http://sequenceiq.com/cloudbreak/). In every cloud implementation one of the most important
thing is to select the host OS on the actual Cloud and make a custom image for the [Cloudbreak](http://sequenceiq.com/cloudbreak/). This actual post will write the steps which were necessary to make a custom image on Google Cloud and will show
what is the paradigm to make a custom image on a selected Cloud.

<!-- more -->

## Why do we need custom image in every cloud?

First, the installation process is much easier and faster on a custom image because we are using docker on the host OS so cocking an image with the specific containers is very useful instead of pulling the docker images in every instance creation.
We using the [nsenter](https://registry.hub.docker.com/u/jpetazzo/nsenter/) for debugging purpose and the [sequenceiq/ambari:pam-fix](https://registry.hub.docker.com/u/sequenceiq/ambari/) to run the cluster. We were automate these installation processes with a tool like [Ansible](http://www.ansible.com/home).
So the first step is to define your own [Playbook](http://docs.ansible.com/playbooks.html) to install everything on the virtual machine.
Our simplest playbook:

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

In google cloud you have 2 choices:

- Create snapshot with the default images
- Create a custom image with a not supported OS

## Image creation with snapshot

We are using Debian as host image on Google Cloud. I created a virtual machine with the default [Debian](https://developers.google.com/compute/docs/operating-systems#backported_debian_7_wheezy) image.
First you need to create a persistent disk:

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

when it is finished then you can shh to the `example-instance`. You can now check your mounted volumes with this command:

```
ls -l /dev/disk/by-id/google-*
```

Now you need to create a folder which will contain the backed image:

```
sudo mkdir /mnt/tmp
```

You have to format your partition before the image creation:

```
sudo /usr/share/google/safe_format_and_mount -m "mkfs.ext4 -F" /dev/sdb /mnt/tmp
```

Now you can start the image creation which will be about 10 minutes:

```
sudo gcimagebundle -d /dev/sda -o /mnt/tmp/ --log_file=/tmp/imagecreation.log
```

You have now an image in /tmp with a special hex number like `/tmp/HEX-NUMBER.image.tar.gz`

You just upload it to a google bucket and it is done.

```
gsutil cp /mnt/tmp/IMAGE_NAME.image.tar.gz gs://BUCKET_NAME
```

## Image creation with Custom OS?

Then now comes the second option which is now an [Ubuntu server 14.04](http://www.ubuntu.com/download/server). The special thing in the Ubuntu that there is [no default image in Google Cloud](https://developers.google.com/compute/docs/operating-systems).
I used a [Virtualbox](https://www.virtualbox.org/) which is very easy to install on mac. Download a Ubuntu server from the webpage http://www.ubuntu.com/server.
Install the Ubuntu into the [Virtualbox](https://www.virtualbox.org/) as general and then install everything which is needed for the custom OS.
You have to install the [Google Cloud SDK](https://developers.google.com/cloud/sdk/) to the instance. This is needed for the custom image because it contains some extra feature like google-startup-scripts.
This helps to run the startup script which is in ubuntu the cloud-init solution but you need the Google Cloud sdk to run this script.
After the installation add the following kernel options to the `/etc/default/grub`:

```
# to enable paravirtualization functionality.
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

Now you can prepare the official image into a tar file. You have to select the virtual box image file on your disk and convert it.
You can convert your vmdk file to raw type because this is only valid for [Google Cloud](https://cloud.google.com/).

```
qemu-img convert -f vmdk -O raw VMDK_FILE_NAME.vmdk disk.img
```

The .img file name has to be `disk.img`. After the convert you have to make a tar file with this command:

```
tar -Szcf <image-tar-name>.tar.gz disk.raw
```

And the upload to a Google Cloud Bucket:

```
gsutil cp <image-tar-name>.tar.gz gs://<bucket-name>
```

Now you have an official image template but you have to create the image in google cloud:

```
gcutil addimage my-ubuntu gs://<bucket-name>/ubuntu_image.tar.gz
```

Ok now you finished everything and you have an image with `my-ubuntu` name.
