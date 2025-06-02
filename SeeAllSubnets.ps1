# Define the output path relative to the script location
$outputPath = "Powershell_Scripts/Azure/Output"

# Ensure the output directory exists
if (-not (Test-Path -Path $outputPath)) {
    New-Item -ItemType Directory -Path $outputPath -Force
}

# Login to Azure
Connect-AzAccount

# Get all subscriptions
$subscriptions = Get-AzSubscription

# Initialize an array to store subnet details
$subnetDetails = @()

# Loop through each subscription
foreach ($subscription in $subscriptions) {
    Write-Host "Processing subscription: $($subscription.Name)"
    Set-AzContext -SubscriptionId $subscription.Id

    # Get all virtual networks in the current subscription
    $vNets = Get-AzVirtualNetwork

    # Loop through each virtual network and get subnet details
    foreach ($vNet in $vNets) {
        Write-Host "  Processing VNet: $($vNet.Name)"

        if (-not $vNet.Subnets -or $vNet.Subnets.Count -eq 0) {
            # Add a placeholder to indicate VNet exists but no subnet yet
            $subnetDetails += [PSCustomObject]@{
                SubscriptionName  = $subscription.Name
                VNetName          = $vNet.Name
                SubnetName        = "<NoSubnets>"
                AddressPrefix     = ($vNet.AddressSpace.AddressPrefixes -join ", ")
                ResourceGroupName = $vNet.ResourceGroupName
            }
        } else {
            foreach ($subnet in $vNet.Subnets) {
                $subnetDetails += [PSCustomObject]@{
                    SubscriptionName  = $subscription.Name
                    VNetName          = $vNet.Name
                    SubnetName        = $subnet.Name
                    AddressPrefix     = ($subnet.AddressPrefix -join ", ")
                    ResourceGroupName = $vNet.ResourceGroupName
                }
            }
        }
    }
}

# Output the subnet details
$subnetDetails | Format-Table -AutoSize

# Export the subnets to a CSV file
$subnetDetails | Export-Csv -Path "$outputPath/AzureSubnets.csv" -NoTypeInformation

Write-Host "Azure subnet details have been exported to $outputPath/AzureSubnets.csv"
