#!/bin/bash

POSITIONAL=()
while [[ $# -gt 0 ]]
do
key="$1"
    case "$key" in
    --tenant)  
        tenant=$2
        shift
        shift
        echo "Tenant: $tenant"
        ;;
    --vmManagedUserId)  
        vmManagedUserId=$2
        shift
        shift
        echo "vmManagedUserId: $vmManagedUserId"
        ;;
    --monitoringRole)  
        monitoring_role=$2
        shift
        shift
        echo "monitoring role: $monitoring_role"
        ;;
    --configVersion)  
        config_version=$2
        shift
        shift
        echo "config version: $config_version"
        ;;
    --frontEndUrl)  
        front_end_url=$2
        shift
        shift
        echo "front end url: $front_end_url"
        ;;
    --monitoringNamespace)  
        monitoring_namespace=$2
        shift
        shift
        echo "monitoring namespace: $monitoring_namespace"
        ;;
    --monitoringEnvironment)  
        monitoring_environment=$2
        shift
        shift
        echo "monitoring environment: $monitoring_environment"
        ;;
    --monitoringAccount)  
        monitoring_account=$2
        shift
        shift
        echo "monitoring account: $monitoring_account"
        ;;
    --containerRegistry)  
        container_registry=$2
        shift
        shift
        echo "container registry: $container_registry"
        ;;
    --containerLabel)  
        container_label=$2
        shift
        shift
        echo "container label: $container_label"
        ;;
     --isReplica)
        is_replica=$2
        shift
        shift
        echo "is replica: $is_replica"
	;;
     *)
        echo "Invalid parameter: $1"
        exit 1
        ;;
    esac
done

if [[ -z "$tenant" ]]
then 
    echo "\nError: Tenant is mandatory. Please provide Tenant to setup monitoring pipeline. Exiting the script."
    exit 1
fi

if [[ -z "$vmManagedUserId" ]]
then 
    echo "\nError: vmManagedUserId is mandatory. Please provide vmManagedUserId to setup monitoring pipeline. Exiting the script."
    exit 1
fi

if [[ -z "$monitoring_role" ]]
then 
    echo "\nError: monitoring role is mandatory. Please provide monitoring role to setup monitoring pipeline. Exiting the script."
    exit 1
fi

if [[ -z "$config_version" ]]
then 
    echo "\nError: config version is mandatory. Please provide config version to setup monitoring pipeline. Exiting the script."
    exit 1
fi

if [[ -z "$front_end_url" ]]
then 
    echo "\nError: front end url is mandatory. Please provide front end url to setup monitoring pipeline. Exiting the script."
    exit 1
fi

if [[  -z "$monitoring_namespace" ]]
then 
    echo "\nError: monitoring namespace is mandatory. Please provide monitoring namespace to setup monitoring pipeline. Exiting the script."
    exit 1
fi

if [[ -z "$monitoring_environment" ]]
then 
    echo "\nError: monitoring environment is mandatory. Please provide monitoring environment to setup monitoring pipeline. Exiting the script."
    exit 1
fi

if [[ -z "$monitoring_account" ]]
then 
    echo "\nError: monitoring account is mandatory. Please provide monitoring account to setup monitoring pipeline. Exiting the script."
    exit 1
fi

if [[ -z "$container_registry" ]]
then 
    echo "\nError: container registry is mandatory. Please provide container registry to setup monitoring pipeline. Exiting the script."
    exit 1
fi

if [[ -z "$container_label" ]]
then 
    echo "\nError: container label is mandatory. Please provide container label to setup monitoring pipeline. Exiting the script."
    exit 1
fi

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

  sudo az login --identity --username $vmManagedUserId
  sudo az acr login --name $container_registry
  container_name=$container_registry".azurecr.io/"$container_label":latest"
  sudo docker pull $container_name

 #  echo -e "Converting pem file to cert and private key file...."
  GCS_CERT_FOLDER=/gcscerts
 #  GCS_CERT_WITH_KEY=$GCS_CERT_FOLDER/geneva-cert.pem
  GCS_CERT=$GCS_CERT_FOLDER/gcscert.pem
  GCS_KEY=$GCS_CERT_FOLDER/gcskey.pem

#   echo -e "Cleaning up existing geneva auth certificate and private key if any"
#   if [ -f "$GCS_CERT" ]; then
#      echo -e "Removing existing Geneva auth certificate: $GCS_CERT"
#      sudo rm -f "$GCS_CERT"
#   fi

#   if [ -f "$GCS_KEY" ]; then
#      echo -e "Removing existing Geneva auth key: $GCS_KEY"
#      sudo rm -f "$GCS_KEY"
#   fi

#   if [ -f "$GCS_CERT_WITH_KEY" ]; then
#      echo -e "Extracting Geneva auth certificate and key from the file: $GCS_CERT_WITH_KEY"
#      sudo openssl x509 -in "$GCS_CERT_WITH_KEY" -out "$GCS_CERT"  && sudo chmod 744 "$GCS_CERT" 
#      sudo openssl pkey -in "$GCS_CERT_WITH_KEY" -out "$GCS_KEY" && sudo chmod 744 "$GCS_KEY"      
#     else 
#       echo -e "Unable to find the Geneva certificate-key file : $GCS_CERT_WITH_KEY. Skipping the certificate and key extraction.."
#   fi
    
## Create Environment variable files for MDS and MDM
echo -e "\n\n###################################### Creating Environment variable files for MDS and MDM #####################\n\n"

echo "export FRONT_END_URL=$front_end_url" > EnvVariables.sh 

sudo rm -f /tmp/collectd
cat > /tmp/collectd <<EOT
# Setting Environment variables for Monitoring
         
export MONITORING_TENANT=$tenant
export MONITORING_ROLE=$monitoring_role
export MONITORING_ROLE_INSTANCE=${tenant}_primary

if [ $is_replica = "true" ] || [ $is_replica = "True" ] ; then
{
	export MONITORING_ROLE_INSTANCE=${tenant}_replica
}
fi

EOT

MDSD_ROLE_PREFIX=/var/run/mdsd/default
MDSDLOG=/var/log
MDSD_OPTIONS="-A -c /etc/mdsd.d/mdsd.xml -d -r $MDSD_ROLE_PREFIX -e $MDSDLOG/mdsd.err -w $MDSDLOG/mdsd.warn -o $MDSDLOG/mdsd.info"

sudo rm -f /tmp/mdsd
cat > /tmp/mdsd <<EOT
    # Check 'mdsd -h' for details.

    # MDSD_OPTIONS="-d -r ${MDSD_ROLE_PREFIX}"

    MDSD_OPTIONS="-A -c /etc/mdsd.d/mdsd.xml -d -r $MDSD_ROLE_PREFIX -e $MDSDLOG/mdsd.err -w $MDSDLOG/mdsd.warn -o $MDSDLOG/mdsd.info"

    export MONITORING_GCS_ENVIRONMENT=$monitoring_environment

    export MONITORING_GCS_ACCOUNT=$monitoring_account

    export MONITORING_GCS_REGION=westus
    # or, pulling data from IMDS

    # imdsURL="http://169.254.169.254/metadata/instance/compute/location?api-version=2017-04-02&format=text"

    # export MONITORING_GCS_REGION="$(curl -H Metadata:True --silent $imdsURL)"

    # see https://jarvis.dc.ad.msft.net/?section=b7a73824-bbbf-49fc-8c3e-a97c27a7659e&page=documents&id=66b7e29f-ddd6-4ab9-ad0a-dcd3c2561090

    export MONITORING_GCS_CERT_CERTFILE="$GCS_CERT"   # update for your cert on disk

    export MONITORING_GCS_CERT_KEYFILE="$GCS_KEY"     # update for your private key on disk
    
    # Below are to enable GCS config download
    export MONITORING_GCS_NAMESPACE=$monitoring_namespace
    export MONITORING_CONFIG_VERSION=$config_version
    export MONITORING_USE_GENEVA_CONFIG_SERVICE=true
    export MONITORING_TENANT=$tenant
    export MONITORING_ROLE=$monitoring_role
    export MONITORING_ROLE_INSTANCE=${tenant}_primary
    
    if [ $is_replica = "true" ] || [ $is_replica = "True" ] ; then
    {
	    export MONITORING_ROLE_INSTANCE=${tenant}_replica
    }
    fi
    
EOT

## Run container using Monitoring image, if not running already. Copy above created env variable files to container and start the cron job on running container..
echo -e "Created env variables files for MDM and MDS\n"

echo -e "\n\n###################################### Running and setting up container ########################################\n\n"

MyContainerId="$(sudo docker ps -aqf "name=$container_label")"

#echo $MyContainerId
if [[ ! -z $MyContainerId ]]
then
echo -e "A container with id $MyContainerId is already running. Stopping the container...\n"
sudo docker stop $MyContainerId
fi

MyContainerId="$(sudo docker run -it --privileged --rm -d --network host --name $container_label $container_name)"
  if [[ -z $MyContainerId ]]
  then
    echo "Error : Failed to run monitor container.Exiting the script..."
    exit 1
  fi

  echo -e "\nMonitoring container with Id $MyContainerId has started successfully...\n"
  sudo docker cp EnvVariables.sh $MyContainerId:root/EnvVariables.sh
    
#    if [ -f "$GCS_CERT_WITH_KEY" ]; then
#      echo -e "Creating $GCS_CERT_FOLDER in the monitoring container"   
#      sudo docker exec -itd $MyContainerId bash -c test -d "$GCS_CERT_FOLDER" && sudo rm -f "$GCS_CERT_FOLDER/*" || sudo mkdir "$GCS_CERT_FOLDER" 
    
#      echo -e "Copying cert and key to the monitoring container"
#      sudo docker cp "$GCS_CERT" $MyContainerId:"$GCS_CERT"     
#      sudo docker cp "$GCS_KEY" $MyContainerId:"$GCS_KEY"
#    else 
#       echo -e "Skipping copying of cert and auth file to the container as cert-key file: $GCS_CERT_WITH_KEY doesn't exist."
#   fi
    
    sudo docker cp /tmp/collectd $MyContainerId:/etc/default/collectd
    sudo docker cp /tmp/mdsd $MyContainerId:/etc/default/mdsd
    sudo docker exec  $MyContainerId  bash -c 'source /root/EnvVariables.sh;  ./RunMonAgents/RunMonAgents.sh >> /tmp/crontab.logs'
    sudo docker exec -itd $MyContainerId bash -c '/etc/init.d/cron start'
    
 echo -e "Setting up of Monitoring container is successful.\n"


#echo -e "Cleaning up certs and keys from the VM\n"

# if  [ -f "$GCS_CERT_WITH_KEY" ]; then
#   echo -e "Removing '$GCS_CERT_WITH_KEY' from the host VM"
#   sudo rm -f "$GCS_CERT_WITH_KEY"
# fi

# if [ -f "$GCS_CERT" ]; then
#    echo -e "Cleaning up Geneva agents auth cert file: $GCS_CERT from the host VM"
#    sudo rm -f "$GCS_CERT"
# fi

#if [ -f "$GCS_KEY" ]; then
#    echo -e "Cleaning up Geneva agents auth cert file: $GCS_KEY from the host VM"
#    sudo rm -f "$GCS_KEY"
# fi
