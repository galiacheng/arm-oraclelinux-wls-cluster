#!/bin/bash
#Generate parameters with value for deploying elk template independently

parametersPath=$1
adminVMName=$2
elasticsearchPassword=$3
elasticsearchURI=$4
elasticsearchUserName=$5
location=$6
numberOfInstances=$7
wlsDomainName=$8
wlsusername=$9
wlspassword=${10}
gitUserName=${11}
testbranchName=${12}
managedServerPrefix=${13}

elasticsearchPort=${elasticsearchURI#*:}
elasticsearchURI=${elasticsearchURI%%:*}
echo "elasticsearchPort: ${elasticsearchPort}"
echo "elasticsearchURI: ${elasticsearchURI}"


cat <<EOF > ${parametersPath}
{
     "adminVMName":{
        "value": "${adminVMName}"
      },
      "elasticsearchPassword": {
        "value": "elasticsearchPassword"
      },
      "elasticsearchPort": {
        "value": "${elasticsearchPort}"
      },
      "elasticsearchURI": {
        "value": "${elasticsearchURI}"
      },
      "elasticsearchUserName": {
        "value": "${elasticsearchUserName}"
      },
      "location": {
        "value": "${location}"
      },
      "numberOfInstances": {
        "value": ${numberOfInstances}
      },
      "wlsDomainName": {
        "value": "${wlsDomainName}"
      },
      "wlsPassword": {
        "value": "${wlsPassword}"
      },
      "wlsUserName": {
        "value": "${wlsUserName}"
      },
      "_artifactsLocation":{
        "value": "https://raw.githubusercontent.com/${gitUserName}/arm-oraclelinux-wls-cluster/${testbranchName}/arm-oraclelinux-wls-cluster/src/main/arm/"
      },
      "managedServerPrefix": {
        "value": "${managedServerPrefix}"
      }
    }
EOF
