#!/bin/bash

set -e

## Fetch Monitoring Docker image from Azure Container Registry 
while getopts ":t:u:p:" opt; do
  case $opt in
    t) tenant="$OPTARG"
    ;;
    u) username="$OPTARG"
    ;;
    p) password="$OPTARG"
    ;;
    \?) echo "Invalid option -$OPTARG" >&2
    ;;
  esac
done

if [[ -z "$tenant" || -z "$username" || -z "$password" ]]
then
echo -e "\nError : Tenant, ACR username and password are mandatory arguments.Please provide required arguments to setup monitoring pipeline.Exiting the script..."
exit 1
else
# Tenant=AzTenant
echo -e "\n#################################### Monitoring Setup For **$tenant** ####################################\n\n"
echo -e "###################################### Installing Docker and Azure CLI #########################################\n\n"
sudo apt update
sudo apt install apt-transport-https ca-certificates curl gnupg2 software-properties-common -y
curl -fsSL https://download.docker.com/linux/debian/gpg | sudo apt-key add -
sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/debian $(lsb_release -cs) stable"
sudo apt update
apt-cache policy docker-ce
sudo apt install docker-ce -y
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash

echo -e "\n\n###################################### Logging into ACR and Pulling Monitoring Image ###########################\n\n"

sudo az acr login --name ghmccontainer --username $username -p $password

sudo docker pull ghmccontainer.azurecr.io/monitor:latest

## Create Environment variable files for MDS and MDM
echo -e "\n\n###################################### Creating Environment variable files for MDS and MDM #####################\n\n"


        rm -f ~/collectd
	cat <<EOT >> ~/collectd
	# Setting Environment variables for Monitoring
		 
	export MONITORING_TENANT=$tenant
	export MONITORING_ROLE=GHPI
	export MONITORING_ROLE_INSTANCE=${tenant}_1
EOT
 MDSD_ROLE_PREFIX=/var/run/mdsd/default
 MDSDLOG=/var/log
 MDSD_OPTIONS="-A -c /etc/mdsd.d/mdsd.xml -d -r $MDSD_ROLE_PREFIX -e $MDSDLOG/mdsd.err -w $MDSDLOG/mdsd.warn -o $MDSDLOG/mdsd.info"

 rm -f ~/mdsd
        cat <<EOT >> ~/mdsd

	# Check 'mdsd -h' for details.

	# MDSD_OPTIONS="-d -r ${MDSD_ROLE_PREFIX}"

	MDSD_OPTIONS="-A -c /etc/mdsd.d/mdsd.xml -d -r $MDSD_ROLE_PREFIX -e $MDSDLOG/mdsd.err -w $MDSDLOG/mdsd.warn -o $MDSDLOG/mdsd.info"

	export MONITORING_GCS_ENVIRONMENT=Test

	export MONITORING_GCS_ACCOUNT=GHPILOGS

	export MONITORING_GCS_REGION=westus

	# or, pulling data from IMDS

	# imdsURL="http://169.254.169.254/metadata/instance/compute/location?api-version=2017-04-02&format=text"

	# export MONITORING_GCS_REGION="$(curl -H Metadata:True --silent $imdsURL)"


	# see https://jarvis.dc.ad.msft.net/?section=b7a73824-bbbf-49fc-8c3e-a97c27a7659e&page=documents&id=66b7e29f-ddd6-4ab9-ad0a-dcd3c2561090
	export MONITORING_GCS_CERT_CERTFILE=/etc/mdsd.d/gcscert.pem   # update for your cert on disk

	export MONITORING_GCS_CERT_KEYFILE=/etc/mdsd.d/gcskey.pem     # update for your private key on disk


	# Below are to enable GCS config download

	export MONITORING_GCS_NAMESPACE=GHPILOGS

	export MONITORING_CONFIG_VERSION=1.3

	export MONITORING_USE_GENEVA_CONFIG_SERVICE=true
        export MONITORING_TENANT=$tenant
        export MONITORING_ROLE=GHPI
        export MONITORING_ROLE_INSTANCE=${tenant}_1
EOT

## Run container using Monitoring image, if not running already. Copy above created env variable files to container and start the cron job on running container..
echo -e "Created env variables files for MDM and MDS\n"

echo -e "\n\n###################################### Running and setting up container ########################################\n\n"

MyContainerId="$(sudo docker ps -aqf "name=monitor")"

#echo $MyContainerId
if [[ ! -z $MyContainerId ]]
then
echo -e "A container with id $MyContainerId is already running. Stopping the container...\n"
sudo docker stop $MyContainerId
fi

MyContainerId="$(sudo docker run -it --privileged --rm -d --network host --name monitor ghmccontainer.azurecr.io/monitor:latest)"

if [[ -z $MyContainerId ]]
then
echo "Error : Failed to run monitor container.Exiting the script..."
exit 1
fi
echo -e "\nMonitoring container with Id $MyContainerId has started successfully...\n"

	sudo docker cp ~/collectd $MyContainerId:/etc/default/collectd
	sudo docker cp ~/mdsd $MyContainerId:/etc/default/mdsd
        sudo docker exec -itd $MyContainerId bash -c '/etc/init.d/cron start'
	
echo -e "Setting up of Monitoring container is successful.\n"
fi

