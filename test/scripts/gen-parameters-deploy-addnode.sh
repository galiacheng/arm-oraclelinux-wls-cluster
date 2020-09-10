#!/bin/bash
#Generate parameters with value for deploying addnode template

parametersPath=$1
adminPasswordOrKey=$2
adminURL=$3
adminUsername=$4
numberOfExistingNodes=$5
skuUrnVersion=$6
storageAccountName=${7}
wlsDomainName=${8}
location=${9}
wlsusername=${10}
wlspassword=${11}
gitUserName=${12}
testbranchName=${13}
managedServerPrefix=${14}

cat <<EOF > ${parametersPath}
{
     "adminPasswordOrKey":{
        "value": "${adminPasswordOrKey}"
      },
      "adminURL": {
        "value": "${adminURL}"
      },
      "adminUsername": {
        "value": "${adminUsername}"
      },
      "numberOfExistingNodes": {
        "value": ${numberOfExistingNodes}
      },
      "numberOfNewNodes": {
        "value": 1
      },
      "location": {
        "value": "${location}"
      },
      "skuUrnVersion": {
        "value": "${skuUrnVersion}"
      },
      "storageAccountName": {
        "value": "${storageAccountName}"
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
        "value": "https://raw.githubusercontent.com/${gitUserName}/arm-oraclelinux-wls-cluster/${testbranchName}/addnode/src/main/"
      },
      "managedServerPrefix": {
        "value": "${managedServerPrefix}"
      }
    }
EOF
