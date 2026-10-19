# Define the resource group
$rg = 'brownfield-evals-experiment'

# Retrieve all resources in the resource group
$resources = Get-AzResource -ResourceGroupName $rg

# Start each resource
foreach ($resource in $resources) {
    if ($resource.ResourceType -eq 'Microsoft.ContainerInstance/containerGroups') {
        Start-AzContainerGroup -Name $resource.Name -ResourceGroupName $rg
    }
    # Add additional conditions for other resource types as needed
}
