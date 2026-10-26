$subscriptionId = '57ebfaff-6dc5-476d-84b3-99a5e1297d5a'
az account set --subscription $subscriptionId

$currentSubscription = az account show --query id -o tsv

if($currentSubscription -ne $subscriptionId) {
    throw "Wrong Azure subscription. Expected $subscriptionId but got $currentSubscription."
}
# Define the resource group
$rg = 'brownfield-evals-experiment'

# Retrieve all resources in the resource group
$resources = Get-AzResource -ResourceGroupName $rg

# Stop each resource
foreach ($resource in $resources) {
    if ($resource.ResourceType -eq 'Microsoft.ContainerInstance/containerGroups') {
        Stop-AzContainerGroup -Name $resource.Name -ResourceGroupName $rg
    }
    # Add additional conditions for other resource types as needed
}
