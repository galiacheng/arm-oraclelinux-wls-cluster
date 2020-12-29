#!/bin/bash

export resourceGroup=$1
export zoneName=$2
export recordSetNames=$3
export targetResources=$4
export lenRecordset=$5
export lenTargets=$6
export ttl=${7}

if [[ ${lenRecordset} != ${lenTargets} ]]; then
    echo "Error: number of record set names is not equal to that of target resources."
    exit 1
fi

# check if the zone exist
az network dns zone show -g ${resourceGroup} -n ${zoneName}

# query name server for testing
nsforTest=$(az network dns record-set ns show -g ${resourceGroup} -z ${zoneName} -n @ --query "nsRecords"[0].nsdname -o tsv)
echo name server: ${nsforTest}

recordSetNamesArr=$(echo $recordSetNames | tr "," "\n")
targetResourcesArr=$(echo $targetResources | tr "," "\n")

index=0
for record in $recordSetNamesArr; do
    count=0
    for target in $targetResourcesArr; do
        if [ $count -eq $index ]; then
            echo Create record with name: $record, target IP: $target
            az network dns record-set a create \
                -g ${resourceGroup} \
                -z ${zoneName} \
                -n ${record} \
                --target-resource ${target} \
                --ttl ${ttl}

            nslookup ${record}.${zoneName} ${nsforTest}
            if [ $? -eq 1 ];then
                echo Error: failed to create record with name: $record, target Id: $target
            fi
        fi

        count=$((count + 1))
    done

    index=$((index + 1))
done
