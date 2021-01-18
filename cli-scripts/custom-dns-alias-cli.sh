#!/bin/bash

#
# Description
#  This script deletes managed nodes from an existing WebLogic Cluster and removes related Azure resources.
#  It removes Azure resources including:
#      * Virtual Machines that host deleting managed servers.
#      * Data disks attached to the Virtual Machines
#      * OS disks attached to the Virtual Machines
#      * Network Interfaces added to the Virtual Machines
#      * Public IPs added to the Virtual Machines

# Initialize
script="${BASH_SOURCE[0]}"
scriptDir="$(cd "$(dirname "${script}")" && pwd)"

function usage() {
  ###### U S A G E : Help and ERROR ######
  cat <<EOF
Options:
        --admim-vm-name           (Required)       The name of virtual machine that hosts WebLogic Admin Server
        --admim-console-label     (Required)       Specify a lable to generate the DNS alias for WebLogic Administration Console
        -f   --artifact-location  (Required)       ARM Template URL
        -g   --resource-group     (Required)       The name of resource group that has WebLogic cluster deployed
        -l   --location           (Required)       Location of current cluster resources.
        -z   --zone-name          (Required)       DNS Zone name
        --gateway-label           (Optional)       Specify a lable to generate the DNS alias for Application Gateway
        --identity-id             (Optional)       Specify an Azure Managed User Identify to update DNS Zone
        --zone-resource-group     (Optional)       The name of resource group that has WebLogic cluster deployed
        -h   --help
EOF
}

function validateInput() {
  if [ -z "${resourceGroup}" ]; then
    echo "Option --resource-group is required."
    exit 1
  fi
  if [ -z "${artifactLocation}" ]; then
    echo "Option --artifact-location is required."
    exit 1
  fi

  templateURL="${artifactLocation}nestedtemplates/dnszonesTemplate.json"
  if [ -z "${templateURL}" ]; then
    echo "Option --artifact-location is required."
    exit 1
  else
    if curl --output /dev/null --silent --head --fail "${templateURL}"; then
      echo "ARM Tempalte exists: $templateURL"
    else
      echo "ARM Tempalte does not exist: $templateURL"
      exit 1;
    fi
  fi
  if [ -z "${zoneName}" ]; then
    echo "Option --zone-name is required."
    exit 1
  fi
  if [ -z "${adminVMName}" ]; then
    echo "Option --admim-vm-name is required."
    exit 1
  fi
  if [ -z "${adminLabel}" ]; then
    echo "Option --admim-console-label is required."
    exit 1
  fi

  if [ -n "${gatewayLabel}" ]; then
    enableGateWay=true;
  fi

  if [ -n "${zoneResourceGroup}" ]; then
    hasDNSZone=true;
  fi
}

function queryAdminIPId(){
  nicId=$(az graph query -q "Resources 
    | where type =~ 'microsoft.compute/virtualmachines' 
    | where name=~ '${adminVMName}' 
    | where resourceGroup =~ '${resourceGroup}' 
    | extend nics=array_length(properties.networkProfile.networkInterfaces) 
    | mv-expand nic=properties.networkProfile.networkInterfaces 
    | where nics == 1 or nic.properties.primary =~ 'true' or isempty(nic) 
    | project nicId = tostring(nic.id)" -o tsv);
  
  if [ -z "${nicId}" ];then
    echo "Please make sure admin VM '${adminVMName}' exists in resource group '${resourceGroup}'. "
    exit 1;
  fi

  export adminIPId=$(az graph query -q "Resources 
    | where type =~ 'microsoft.network/networkinterfaces' 
    | where id=~ '${nicId}' 
    | extend ipConfigsCount=array_length(properties.ipConfigurations) 
    | mv-expand ipconfig=properties.ipConfigurations 
    | where ipConfigsCount == 1 or ipconfig.properties.primary =~ 'true' 
    | project  publicIpId = tostring(ipconfig.properties.publicIPAddress.id)" -o tsv)

  if [ -z "${adminIPId}" ];then
    echo "Can not query public IP of admin VM. Please make sure admin VM '${adminVMName}' exists in resource group '${resourceGroup}'. "
    exit 1;
  fi
}

function queryAppgatewayAlias(){
  gatewayIPId=$(az graph query -q "Resources 
    | where type =~ 'microsoft.network/applicationGateways' 
    | where name=~ 'myAppGateway' 
    | where resourceGroup =~ '${resourceGroup}'
    | extend ipConfigsCount=array_length(properties.frontendIPConfigurations) 
    | mv-expand ipconfig=properties.frontendIPConfigurations 
    | where ipConfigsCount == 1 or ipconfig.properties.primary =~ 'true' 
    | project  publicIpId = tostring(ipconfig.properties.publicIPAddress.id)" -o tsv)
  
  if [ -z "${gatewayIPId}" ];then
    echo "Can not query public IP of gateway. Please make sure Application Gateway is enabled in resource group '${resourceGroup}'. "
    exit 1;
  fi

  export gatewayAlias=$(az network public-ip show \
              --id ${gatewayIPId} \
              --query dnsSettings.fqdn -o tsv)
}

function generateParameterFile(){
  export parametersPath=parameters.json;
  cat <<EOF > ${parametersPath}
{
    "\$schema": "https://schema.management.azure.com/schemas/2015-01-01/deploymentParameters.json#",
    "contentVersion": "1.0.0.0",
    "parameters": {
        "_artifactsLocation": {
            "value": "${artifactLocation}"
        },
        "_artifactsLocationSasToken": {
            "value": ""
        },
        "dnszonesARecordSetNames": {
            "value": [
              "$adminLabel"
            ]
        },
EOF


  if [ "${enableGateWay}" == "true" ];then
    echo "${enableGateWay} ....."
cat <<EOF >>${parametersPath}
        "dnszonesCNAMEAlias": {
            "value": [
              "${gatewayAlias}"
            ]
        },
        "dnszonesCNAMERecordSetNames": {
            "value": [
              "${gatewayLabel}"
            ]
        },
EOF
  else
cat <<EOF >>${parametersPath}
        "dnszonesCNAMEAlias": {
            "value": [
            ]
        },
        "dnszonesCNAMERecordSetNames": {
            "value": [
            ]
        },
EOF
  fi

cat <<EOF >>${parametersPath}
        "dnszoneName": {
            "value": "${zoneName}"
        },
        "hasDNSZones": {
            "value": ${hasDNSZone}
        },
        "identity": {
            "value": {
              "type": "UserAssigned",
              "userAssignedIdentities": {
                "${identity}": {}
              }
            }
        },
        "location": {
            "value": "${location}"
        },
        "resourceGroup": {
            "value": "${zoneResourceGroup}"
        },
        "targetResources": {
            "value": [
              "${adminIPId}"
            ]
        }
    }
}
EOF
}

function invoke(){
  
  az deployment group validate --verbose \
    --resource-group ${resourceGroup} \
    --parameters @${parametersPath} \
    --template-uri ${templateURL}

  az deployment group create --verbose \
    --resource-group ${resourceGroup} \
    --parameters @${parametersPath} \
    --template-uri ${templateURL} \
    --name "configure-custom-dns-alias-$(date +"%s")"

    if [ $? -eq 1 ];then
      exit 1;
    fi
}

function cleanup(){
  rm -f ${parametersPath}
}

function printSummary(){
  echo ""
  echo ""
  echo "
DONE!
  "
  if [ "${hasDNSZone}" == "false" ];then
  nameServers=$(az network dns zone show -g ${resourceGroup} --name ${zoneName} --query nameServers)
  echo "
Action required:
  Complete Azure DNS delegation to make the alias accessible.
  Reference: https://aka.ms/dns-domain-delegatio
  Name servers:
  ${nameServers}
  "
  fi

  echo "
Custom DNS alias:
    Resource group: ${resourceGroup}
    WebLogic Server Administration Console URL: http://${adminLabel}.${zoneName}:7001/console
    WebLogic Server Administration Console secured URL: https://${adminLabel}.${zoneName}:7002/console
  "

  if [ "${enableGateWay}" == "true" ];then
    echo "
    Application Gateway URL: http://${gatewayLabel}.${zoneName}
    Application Gateway secured URL: https://${gatewayLabel}.${zoneName}
"
  fi
}

# main script start from here
# default value
export enableGateWay=false
export hasDNSZone=false
export identity=/subscriptions/subscriptionId/resourceGroups/TestResourceGroup/providers/Microsoft.ManagedIdentity/userAssignedIdentities/TestUserIdentity1

# Transform long options to short ones
for arg in "$@"; do
  shift
  case "$arg" in
  "--help") set -- "$@" "-h" ;;
  "--resource-group") set -- "$@" "-g" ;;
  "--artifact-location") set -- "$@" "-f" ;;
  "--zone-name") set -- "$@" "-z" ;;
  "--admim-vm-name") set -- "$@" "-m" ;;
  "--admim-console-label") set -- "$@" "-c" ;;
  "--gateway-label") set -- "$@" "-w" ;;
  "--zone-resource-group") set -- "$@" "-r" ;;
  "--identity-id") set -- "$@" "-i" ;;
  "--location") set -- "$@" "-l" ;;
  "--"*)
    set -- usage
    exit 2
    ;;
  *) set -- "$@" "$arg" ;;
  esac
done

# Parse short options
OPTIND=1
while getopts "hg:f:z:m:c:w:r:i:l:" opt; do
  case "$opt" in
  "g") resourceGroup="$OPTARG" ;;
  "f") artifactLocation="$OPTARG" ;;
  "h")
    usage
    exit 0
    ;;
  "z") zoneName="$OPTARG" ;;
  "m") adminVMName="$OPTARG" ;;
  "c") adminLabel="$OPTARG" ;;
  "w") gatewayLabel="$OPTARG" ;;
  "r") zoneResourceGroup="$OPTARG" ;;
  "i") identity="$OPTARG" ;;
  "l") location="$OPTARG" ;;
  esac
done
shift $(expr $OPTIND - 1) # remove options from positional parameters

validateInput
cleanup
queryAdminIPId
if [ ${enableGateWay} ];then
  queryAppgatewayAlias
fi
generateParameterFile
invoke
cleanup
printSummary
	

