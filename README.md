# wordpress-terraform-aws

Mob Session #02

- Setup Wordpress using IaC tools : Terraform

## Steps

- [x] Find Ubuntu AMI.
- [x] Create
    - [x] Security Group (SG)
        - [x] Ingress
            - [x] Port 22 / Anywhere
            - [x] Port 80 / Anywhere
            - [x] Port 443 / Anywhere
        - [x] Egress : All / Anywhere
    - [x] Key-Pair
        - [x] SSH
            - [x] Ideally should go in AWS Secrets Manager.
            - [x] Use our AWS accounts to access the SSH private keys.
- [x] Create EC2 Instance with SG and the key-pair.
- [x] Create an RDS instance.
    - [x] Ensure that it is reachable from the EC2 instance via SG.
    - [x] Details of the SG:
        - [x] Ingress : Port 3306 / EC2 SG
        - [x] Egress : All / EC2 SG
- [ ] Point DNS to IP of EC2.
    - [ ] Ideally we should be using an Elastic IP.
- [x] Use user-data to setup wordpress.
    - [x] Install wp-cli, Nginx, PHP-FPM, Certbot.
    - [x] Setup Nginx config.
    - [x] Use wp-cli to setup wordpress.
    - [ ] Use Certbot to setup HTTPS.