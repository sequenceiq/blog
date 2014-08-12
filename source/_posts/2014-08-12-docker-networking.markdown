---
layout: post
title: "Docker intercontainer networking explained"
date: 2014-08-12 10:53:15 +0200
comments: true
categories: [Docker, Linux, Hadoop, Cloudbreak, Network]
author: Attila Kanto
published: true
---

The purpose of this blog entry is to cover advanced topics regarding Docker networking and explain different concepts to inter-connect Docker containers when the containers are running on different host machines.
For the demonstration we are using VMs on [VirtualBox](https://www.virtualbox.org/) launched with [Vagrant](http://www.vagrantup.com/), but the explained networking concepts work also on Amazon EC2 (with VPC) and Azure unless stated otherwise.

To set up the the test environment clone the [SequenceIQ's samples repository](https://github.com/sequenceiq/sequenceiq-samples) and follow the instructions.

```
git clone git@github.com:sequenceiq/sequenceiq-samples.git
cd sequenceiq-samples/docker-networking
vagrant up
```

The ```vagrant up``` command launches the test setup, which conatins two Ubuntu 14.04 VMs with the network configuration:

* [NAT](https://www.virtualbox.org/manual/ch06.html#network_nat)
* [Private networking](https://docs.vagrantup.com/v2/networking/private_network.html)

The NAT (related to eth0 interface on VMs) is used only for access the external network from VMs e.g. download files from debian repository, but it is not used for inter-container communication. The Vagrant sets up a properly configured Host Only Networking in VirtualBox therefore the VMs can communicate with each other on the defined IP addresses:

* vm1: 192.168.40.11
* vm2: 192.168.40.12

Let's see how Docker containers running on these VMs can send IP packets to each other.

##Setting up bridge0
The Docker attaches all containers to the virtual subnet implemented by docker0, this means that by default on both VMs the Docker containers will be launched with IP addresses from range 172.17.42.1/24. This is a problem for some of the solutions explained below, because if the containers on different hosts have the same IP addresses then we won't be able to properly route the IP packets between them. Therefore on each VMs a network bridge is created with the following subnets:

* vm1: 172.17.51.1/24
* vm2: 172.17.52.1/24

This means that every container luanched on vm1 will get an IP address from range 172.17.51.2 - 172.17.51.255 and containers on vm2 will have an address from range 172.17.52.2 - 172.17.52.255.

```bash
# do not execute, it was already executed on vm1 as root during provision from Vagrant
brctl addbr bridge0
sudo ifconfig bridge0 172.17.51.1 netmask 255.255.255.0
sudo bash -c 'echo DOCKER_OPTS=\"-b=bridge0\" >> /etc/default/docker'
sudo service docker restart

# do not execute, it was already executed on vm1 as root during provision from Vagrant
sudo brctl addbr bridge0
sudo ifconfig bridge0 172.17.52.1 netmask 255.255.255.0
sudo bash -c 'echo DOCKER_OPTS=\"-b=bridge0\" >> /etc/default/docker'
sudo service docker restart
```

As noted in the comments the above configuration is already executed during the provisioning of VMs and it was copied here just for the sake of clarity and completeness.

##Expose container ports to host

Probably the simplest way to solve inter-container communication is to expose ports from container to the host. This can be done with the ```-p``` switch. E.g. exposing the port 3333 is as simple as:

```bash
# execute on vm1
sudo docker run -it --rm --name cont1 -p 3333:3333 ubuntu /bin/bash -c "nc -l 3333"

# execute on vm2
sudo docker run -it --rm --name cont2 ubuntu /bin/bash -c "nc -w 1 -v 192.168.40.11 3333"
#Result: Connection to 192.168.40.11 3333 port [tcp/*] succeeded!
```

This might be well suited for cases when the communication ports are defined in advance (e.g. MySQL will run on port 3306), but will not work when the application uses dynamic ports for communication (like Hadoop does with IPC ports).

##Host networking

If the the container is started with `--net=host` then it avoids placing the container inside of a separate network stack, but as the Docker documentation says this option "tells Docker to not containerize the container's networking". The ```cont1``` container can bind directly to the network interface of host therefore the ```nc``` will be available directly on 192.168.40.11.

```bash
# execute on vm1
sudo docker run -it --rm --name cont1 --net=host ubuntu /bin/bash -c "nc -l 3333"

# execute on vm2
sudo docker run -it --rm --name cont2 ubuntu /bin/bash -c "nc -w 1 -v 192.168.40.11 3333"
#Result: Connection to 192.168.40.11 3333 port [tcp/*] succeeded!
```

Of course if you want to access cont2 from cont1 then cont2 also needs to be started with ```--net=host``` option.
The host networking is very powerful solution for inter-container communication, but it has its drawbacks, since the ports used by the container can collide with the ports used by host or other containers utilising --net=host option, because all of them are sharing the same network stack.

##Direct Routing
So far we have seen methods where the containers have used the IP address of host to communicate with each other, but there are solutions to inter-connect the containers by using their own IPs. If we are using the containers own IPs for routing then it is important that we shall be able to distinguish based on IP which container is running on vm1 and which one is running on on vm2, this was the reason why the bridge0 interface was created as explained in "Setting up bridge0" section.
To make the things a bit easier to understand I have created a simplified diagram of the network interfaces in our current test setup. If I would like to oversimplify the thing then I would say that, we shall setup the routing in that way that the packets from one container are following the red lines shown on the diagram.

-> {% img https://raw.githubusercontent.com/sequenceiq/sequenceiq-samples/master/docker-networking/img/routing.png %} <-

To achive this we need to configure the routing table on hosts in that way that every packet which destination is 172.17.51.0/24 is forwarded to vm1 and every IP packet where the destination is 172.17.52.0/24 is forwarded to vm2. To repeat it shortly, the containers running on vm1 are placed to subnet 172.17.51.0/24, containers on vm2 are on subnet 172.17.52.0/24.

```bash
# execute on vm1
sudo route add -net 172.17.52.0 netmask 255.255.255.0 gw 192.168.40.12
sudo iptables -t nat -F POSTROUTING
sudo iptables -t nat -A POSTROUTING -s 172.17.51.0/24 ! -d 172.17.0.0/16 -j MASQUERADE
sudo docker run -it --rm --name cont1  ubuntu /bin/bash
#Inside the container (cont1)
nc -l 3333

# execute on vm2
sudo route add -net 172.17.51.0  netmask 255.255.255.0  gw 192.168.40.11
sudo iptables -t nat -F POSTROUTING
sudo iptables -t nat -A POSTROUTING -s 172.17.52.0/24 ! -d 172.17.0.0/16 -j MASQUERADE
sudo docker run -it --rm --name cont2  ubuntu /bin/bash
#Inside the container (cont2)
nc -w 1 -v 172.17.51.2 3333
#Result: Connection to 172.17.51.2 3333 port [tcp/*] succeeded!
```

The ```route add``` command adds the desired routing to the route table, but you might wonder why the iptables configuration is necessary. The reason for that the Docker by default sets up a rule to the nat table to masquerade all IP packets that are leaving the machine. In our case we definitely don't want this, therefore we delete all MASQUERADE rules with -F option. At this point we already would be able to make the connection from one container to other and vice verse, but the containers would not be able to communicate with the outside world, therefore an iptables rule needs to be added to masquerade the packets that are going outside of 172.17.0.0/16. I need to mention the another approach would be to use the [--iptables=false](https://docs.docker.com/articles/networking/#between-containers) option of the daemon to avoid any manipulation in the iptables and you can do all the config manually.

Such kind of direct routing from one vm to other vm works great and easy to set up, but cannot be used if the hosts are not on the same subnet. If the host are located the on different subnet the tunneling might be an option as you will see it in the next section.

_Note: This solution works on Amazon EC2 instances only if the [Source/Destionation Check](http://docs.aws.amazon.com/AmazonVPC/latest/UserGuide/VPC_NAT_Instance.html#EIP_Disable_SrcDestCheck) is disabled._

_Note: Due to the packet filtering policy of Azure this method cannot be used there._

##Generic Routing Encapsulation (GRE) tunnel

GRE is a tunneling protocol that can encapsulate a wide variety of network layer protocols inside virtual point-to-point links.
The main idea is to create a GRE tunnel between the VMs and send all traffic through it:

-> {% img https://raw.githubusercontent.com/sequenceiq/sequenceiq-samples/master/docker-networking/img/gre.png %} <-

In order to create a tunnel you need to specify the name, the type (which is gre in our case) and the IP address of local and the remote end. Consequently the tun2 name used for the tunnel on on vm1 since from vm1 perspective that is the tunnel endpoint which leads to vm2 and every packet sent to tun2 to will eventually come out on vm2 end.

```bash
#GRE tunnel config execute on vm1
sudo iptunnel add tun2 mode gre local 192.168.40.11 remote 192.168.40.12
sudo ifconfig tun2 10.0.201.1
sudo ifconfig tun2 up
sudo route add -net 172.17.52.0 netmask 255.255.255.0 dev tun2
sudo iptables -t nat -F POSTROUTING
sudo iptables -t nat -A POSTROUTING -s 172.17.51.0/24 ! -d 172.17.0.0/16 -j MASQUERADE
sudo docker run -it --rm --name cont1  ubuntu /bin/bash
#Inside the container (cont1)
nc -l 3333

#GRE tunnel config execute on vm2
sudo iptunnel add tun1 mode gre local 192.168.40.12 remote 192.168.40.11
sudo ifconfig tun1 10.0.202.1
sudo ifconfig tun1 up
sudo route add -net 172.17.51.0 netmask 255.255.255.0 dev tun1
sudo iptables -t nat -F POSTROUTING
sudo iptables -t nat -A POSTROUTING -s 172.17.52.0/24 ! -d 172.17.0.0/16 -j MASQUERADE
sudo docker run -it --rm --name cont2  ubuntu /bin/bash
#Inside the container (cont2)
nc -w 1 -v 172.17.51.2 3333
#Result: Connection to 172.17.51.2 3333 port [tcp/*] succeeded!
```

After the tunnel is set up and activated the remaining commands are very similar to the commands executed in the "Direct Routing" section. The main difference here is that we do not rout ethe traffic directly to other vm, but we are routing it into ```dev tun1``` and ```dev tun2``` respectively.

With GRE tunnels a point-to-point connection is set up between two hosts, which means that if you have more then two hosts in your network and want to interconnect all of them, then n-1 tunnel endpoint needs to be created on every host, which will be quite challenging to maintain if you have a large cluster.

_Note: GRE packets are [filtered out](http://msdn.microsoft.com/en-us/library/azure/dn133803.aspx) on Azure therefore this solution cannot be used there._

##Virtual Private Network (VPN)

If more secured connections is required between containers then VPNs can be used on VMs. This addiotional security might significantly increase processing overhead. This overhead is highly depends on which VPN solution are you going to use. In this demo we use the VPN capabilities of SSH which is not really suited for production use. In order to enable the VPN capabilites of ssh the  PermitTunnel parameter needs to be switched on in sshd_config. If you are using the Vagranfile provided to this tutorial then nothing needs to be done, since this parameter was already set up for you during provisioning in the bootstrap.sh.

```bash
#execute on vm1
sudo ssh -f -N -w 2:1 root@192.168.40.12
sudo ifconfig tun2 up
sudo route add -net 172.17.52.0 netmask 255.255.255.0 dev tun2
sudo iptables -t nat -F POSTROUTING
sudo iptables -t nat -A POSTROUTING -s 172.17.51.0/24 ! -d 172.17.0.0/16 -j MASQUERADE
sudo docker run -it --rm --name cont1  ubuntu /bin/bash
#Inside the container (cont1)
nc -l 3333

#execute on vm2
sudo ifconfig tun1 up
sudo route add -net 172.17.51.0 netmask 255.255.255.0 dev tun1
sudo iptables -t nat -F POSTROUTING
sudo iptables -t nat -A POSTROUTING -s 172.17.52.0/24 ! -d 172.17.0.0/16 -j MASQUERADE
sudo docker run -it --rm --name cont2  ubuntu /bin/bash
#Inside the container (cont2)
nc -w 1 -v 172.17.51.2 3333
#Result: Connection to 172.17.51.2 3333 port [tcp/*] succeeded!
```

The ssh is launched with -w option where the numerical ids of tun devices were specified. After executing the command the tunnel interfaces are created on both VMs. The interfaces needs to be be activated with ifconfig up and after that we need to setup the rooting to direct the traffic to  172.17.51.0/24 and 172.17.52.0/24 to tun2 and tun1.

As mentioned the VPN capabilities of SSH is not recommended in production, but other solutions like  [OpenVPN](https://openvpn.net/index.php/open-source.html) would worth a try to seacure the communication between the hosts (and also between the containers).

##Conclusion

The above examples were hand written mainly for demonstration purposes, but there are great tools like [Pipework](https://github.com/jpetazzo/pipework) that can make your life simpler and will do the heavy lifting for you.

If you want to check how the these methods are working in production environment you are just a few clicks from it, since under the hood these methods are responsible to solve the inter-container communication in our cloud agnostic Hadoop as a Service API called [Cloudbreak](http://sequenceiq.com/cloudbreak/).

For updates follow us on [LinkedIn](https://www.linkedin.com/company/sequenceiq/), [Twitter](https://twitter.com/sequenceiq) or [Facebook](https://www.facebook.com/sequenceiq).
