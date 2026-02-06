# AWS-Public-Private-Architecture
VPC with servers in private subnets and NAT


This Architecture demonstrates how to create a VPC that  can be usesd for servers in a production environment. To improve resiliency, you deploy the servers in two Availability Zones, by using an Auto Scaling group and an Application Load Balancer. For additional security, we can  deploy the servers in private subnets. The servers receive requests through the load balancer. The servers can connect to the internet by using a NAT gateway. To improve resiliency, you deploy the NAT gateway in both Availability Zones.
