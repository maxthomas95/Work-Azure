# Login to Azure
Connect-AzAccount

# Get all subscriptions
$subscriptions = Get-AzSubscription

# Initialize a dictionary to store subnet details by address prefix
$subnetDict = @{}

# Loop through each subscription
foreach ($subscription in $subscriptions) {
    Set-AzContext -SubscriptionId $subscription.Id
    Write-Output "Processing subscription: $($subscription.Name)"
    
    # Get all virtual networks in the current subscription
    $vNets = Get-AzVirtualNetwork
    
    # Loop through each virtual network and get subnet details
    foreach ($vNet in $vNets) {
        foreach ($subnet in $vNet.Subnets) {
            foreach ($prefix in $subnet.AddressPrefix) {
                $subnetDict[$prefix] = [PSCustomObject]@{
                    SubscriptionName = $subscription.Name
                    VNetName         = $vNet.Name
                    SubnetName       = $subnet.Name
                    ResourceGroupName = $vNet.ResourceGroupName
                }
                Write-Output "Added subnet: $($subnet.Name) with prefix: $prefix in VNet: $($vNet.Name) under subscription: $($subscription.Name)"
            }
        }
    }
}

# Initialize an array to store all /24 subnets within the /16 range
$allSubnets = @()

# Generate all /24 subnets within the /16 range
for ($i = 0; $i -lt 256; $i++) {
    $subnet = "10.xxx.$i.0/24"  #CHANGE ME FOR YOUR AZURE ENV
    $allSubnets += [PSCustomObject]@{
        Subnet             = $subnet
        Status             = "Open"
        SubscriptionName   = $null
        VNetName           = $null
        SubnetName         = $null
        ResourceGroupName  = $null
    }
}

# Function to validate and parse IP address and mask
function ParseIPAddressAndMask($cidr) {
    if ($cidr -match "^(\d{1,3}\.){3}\d{1,3}/\d{1,2}$") {
        $ip, $mask = $cidr.Split('/')
        if ([System.Net.IPAddress]::TryParse($ip, [ref]$null) -and $mask -ge 0 -and $mask -le 32) {
            return [PSCustomObject]@{ IP = $ip; Mask = $mask }
        }
    }
    return $null
}

# Function to check if a subnet is within a /24 range
function IsSubnetInRange($subnet, $range) {
    $subnetParsed = ParseIPAddressAndMask $subnet
    $rangeParsed = ParseIPAddressAndMask $range

    if ($subnetParsed -and $rangeParsed) {
        $subnetIP = [System.Net.IPAddress]::Parse($subnetParsed.IP)
        $subnetMask = [int]$subnetParsed.Mask
        $rangeIP = [System.Net.IPAddress]::Parse($rangeParsed.IP)
        $rangeMask = [int]$rangeParsed.Mask

        $subnetPrefix = [BitConverter]::ToUInt32($subnetIP.GetAddressBytes(), 0) -shl (32 - $subnetMask)
        $rangePrefix = [BitConverter]::ToUInt32($rangeIP.GetAddressBytes(), 0) -shl (32 - $rangeMask)

        $subnetSize = [math]::Pow(2, (32 - $subnetMask))
        $rangeSize = [math]::Pow(2, (32 - $rangeMask))

        return ($subnetPrefix -band $rangePrefix) -eq $rangePrefix -and $subnetSize -le $rangeSize
    } else {
        Write-Error "Invalid IP address or mask: $subnet or $range"
        return $false
    }
}

# Loop through each /24 subnet and check if any part of it is used
foreach ($allSubnet in $allSubnets) {
    $isPartial = $false
    foreach ($prefix in $subnetDict.Keys) {
        $subnetDetails = $subnetDict[$prefix]
        if ($prefix -like "10.211.*") {
            if (IsSubnetInRange $prefix $allSubnet.Subnet) {
                $isPartial = $true
                Write-Output "Matching $prefix with $($allSubnet.Subnet)"
                Write-Output "Before update: Subscription: $($allSubnet.SubscriptionName), VNet: $($allSubnet.VNetName), Subnet: $($allSubnet.SubnetName)"
                Write-Output "Updating with: Subscription: $($subnetDetails.SubscriptionName), VNet: $($subnetDetails.VNetName), Subnet: $($subnetDetails.SubnetName)"
                $allSubnet.SubscriptionName = $subnetDetails.SubscriptionName
                $allSubnet.VNetName = $subnetDetails.VNetName
                $allSubnet.SubnetName = $subnetDetails.SubnetName
                $allSubnet.ResourceGroupName = $subnetDetails.ResourceGroupName
                Write-Output "After update: Subscription: $($allSubnet.SubscriptionName), VNet: $($allSubnet.VNetName), Subnet: $($allSubnet.SubnetName)"
                if ($prefix -eq $allSubnet.Subnet) {
                    $allSubnet.Status = "Reserved"
                    break
                }
            }
        }
        if ($allSubnet.Status -eq "Reserved") {
            break
        }
    }
    if ($isPartial -and $allSubnet.Status -ne "Reserved") {
        $allSubnet.Status = "Partial"
    }
}

# Output the subnets with their status
$allSubnets | Format-Table -AutoSize

# Export the subnets with their status to a CSV file
$allSubnets | Export-Csv -Path "SubnetsStatus.csv" -NoTypeInformation
