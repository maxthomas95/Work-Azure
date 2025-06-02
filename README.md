# Azure Subnet Management Scripts

This directory contains PowerShell scripts for managing and monitoring Azure subnets, particularly focusing on the 10.211.x.x range.

## Scripts Overview

### SeeAllSubnets.ps1

This script connects to Azure and retrieves all subnets from all virtual networks across all subscriptions.

**Functionality:**
- Logs into Azure using Connect-AzAccount
- Iterates through all subscriptions
- For each subscription, retrieves all virtual networks
- For each virtual network, extracts subnet information
- Exports the subnet details to `Output/AzureSubnets.csv`

**Output:**
- A CSV file containing columns for SubscriptionName, VNetName, SubnetName, AddressPrefix, and ResourceGroupName

### Subnets_Reserved.ps1

This script analyzes the subnet data collected by SeeAllSubnets.ps1 and determines the status of all possible /24 subnets in the 10.211.x.x range.

**Functionality:**
- Reads the subnet data from `Output/AzureSubnets.csv`
- Generates all possible /24 subnets in the 10.211.x.x range (256 subnets)
- Checks each subnet against the existing Azure subnets to determine its status:
  - "Reserved": The exact subnet is already in use
  - "Partial": Part of the subnet is in use, or it's part of a larger subnet
  - "Open": The subnet is not in use
- Exports the results to `Output/SubnetsStatus.csv`

**Key Functions:**
- `IsSubnetInRange`: Determines if two subnets overlap
- `IsPartOfLargerSubnet`: Checks if a /24 subnet is part of a larger subnet (e.g., /23)

**Output:**
- A CSV file containing columns for Subnet, Status, SubscriptionName, VNetName, SubnetName, and ResourceGroupName

### Test-SubnetsReserved.ps1

This script tests the Subnets_Reserved.ps1 script with sample data, without requiring an actual Azure connection.

**Functionality:**
- Creates a sample AzureSubnets.csv file with test data
- Tests the subnet overlap detection functions
- Runs the Subnets_Reserved.ps1 script with the test data
- Displays the results for key subnets

## Usage

1. Run `SeeAllSubnets.ps1` to collect current subnet information from Azure
2. Run `Subnets_Reserved.ps1` to analyze the subnet usage and generate the status report

For testing without connecting to Azure, you can use `Test-SubnetsReserved.ps1`.

## Implementation Details

The scripts handle various subnet scenarios, including:
- Exact matches (e.g., 10.211.1.0/24 is already reserved)
- Smaller subnets within a /24 (e.g., 10.211.2.0/28 is part of 10.211.2.0/24)
- Larger subnets spanning multiple /24s (e.g., 10.211.3.0/23 spans both 10.211.3.0/24 and 10.211.4.0/24)

The subnet overlap detection uses IP address manipulation and bitwise operations to accurately determine if subnets overlap.
