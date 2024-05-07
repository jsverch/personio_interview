
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
		- Again basically boilerplate, wtih a NodePort definition for access.
- ./tf/variable.tf
	- Basic instance config info. Ami to use / instance type / region / ssh key
		- `num_nodes` defines the number of worker nodes to build.
- ./tf/output.tf
	- Gathers ip's of created ec2s.
- ./tf/main.tf
	- Meat of the config. 
	There are comments explaining what most parts do inline in the file.
	Basically gives all the config needed to build the cluster using 1 master and \<n\> worker nodes which are spread across AZs for redundancy (when n>1)
- ./tf/scripts/install_master.sh
- ./tf/scripts/install_worker.sh
	- Mostly boilerplate k8s install scripts.
		- The main difference between the two is the last step.
For the master it runs `kubeadm token create --print-join-command` and save the output to an s3 bucket so that worker nodes can pull it down and run it to join the cluster.
For the worker(s) it downloads this join command and executes it.

## Future considerations
	- CI/CD
		- In the real world I'm sure the company has a chosen standard, but for purposes of this example we could use a couple of github actions.
			- One "Terraform" action which will execute a terraform apply any time there is a push to main
			- One "Deploy to Kubernetes cluster" action which does the end to end job of building the docker image, pushing it to ECR, and finally deploying it to the cluster.
		- Rollbacks
			- For terraform you can revert to the commit with the state you want to rollback to and run a terraform apply.	
			- For the docker image / actual application, you can either also revert to the good commit and allow the ci/cd to run through, or for a quicker emergency fix, assuming you are retaining images in ecr, you can sinply manually deploy the previous version tag'd image, or a previous known good version.

	- Ingress / network
		- In my example I used a simple NodePort to allow access to the applicaiton. In the real world we'd probably want something like the aws alb ingress controller for more scalability and robustness.

	- Scaling, performane, etc.
		- There are lots of choices for (auto)scaling, the ultimate solution will depend of overall cluster architecture. For purpose of this example I'd probably choose something simple like k8s' HPA. This can be configured to add pod replicas based on configurable metrics. Metric choice in the real world would depend on knowing and/or profiling your application to undersand the necessary scaling factors. With a deeper knowledge of the application it's also possible that you would find hortizontal scaling isn't the right mechanism and would want to use vertical scaling instead. In addition you'd probably wan't something, either automatic scaling, or monitoring of capacity to drive "manual" (via terraform) scaling of the overall cluster as the scale of the running deployments changes. Something like cluster autoscaler can be used for this.