
## Stuff done outside of IaC

- Set up a `k8s` iam user manually which had all the rights needed for the project (ec2/vpc/ecr/etc).
- created an access key which is stored in a .tf file that is excluded from the git repo for security purposes.
 - manually set up an ~/.aws/credentials file on the nodes after they were brought up so that it could be used for pulling ecr images, accessing s3, etc.

## Files in repo
- ./application/src
	- The provided demo app, no changes.
- ./application/deployment.yml
	- k8s deployment file for demo app. 
	 Mostly boilerplate with the addition of a stanza with a secret to use for pulling ECR iamges from a private repo. Secret created with..
`kubectl create secret docker-registry regcred --docker-server=<AWS  account  #>.dkr.ecr.us-east-1.amazonaws.com --docker-username=AWS --docker-password=$(aws ecr get-login-password) --namespace=demo-app`
- ./application/service.yml
	- Config for service to go with the demo app
		- Again basically boilerpoint, wtih a NodePort definition for access.
- ./tf/variable.tf
	- Basic instance config info. Ami to use / instance type / region / ssh key
		- `num_nodes` defines the number of worker nodes to build.
- ./tf/output.tf
	- Gathers ip's of created ec2s.
- ./tf/main.tf
	- Meat of the config. 
	There are comments explaining what most parts do in the file.
	Basically gives all the config needed to build the cluster using 1 master and \<n\> worker nodes which are spread across AZs for redundancy (when n>1)
- ./tf/scripts/install_master.sh
- ./tf/scripts/install_worker.sh
	- Mostly boilerplate k8s install scripts.
		- The main difference between the two is the last step.
For the master it runs `kubeadm token create --print-join-command` and save the output to an s3 bucket so that worker nodes can pull it down and run it to join the cluster.
For the worker(s) it downloads this join command and executes it.

## Future considerations for Prod
