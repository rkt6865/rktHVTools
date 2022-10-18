function Get-HVNetworkVlans {
    <#
.SYNOPSIS
    Retrieve the network names and VLANs of a Hyper-V Logical Network.
.DESCRIPTION
    Retrieve the network names and VLANs of a Hyper-V Logical Network.
.PARAMETER logicalNetwork
    Specifies the name of the Hyper-v Logical Network. This parameter is mandatory.
.INPUTS
    System.String.  Get-HVNetworkVlans accepts a string as the name of the Hyper-V Logical Network.
.OUTPUTS
    PSCustomObject. Get-HVNetworkVlans returns the network name and VLAN ID for each network.
.EXAMPLE
    PS C:\> Get-HVNetworkVlans <myLogicalNetworkName>
    Retrieves the network name and VLAN ID of the Hyper-V Logical Network <myLogicalNetworkName>.
.NOTES
    None.
#>
    [CmdletBinding()]
    param (
        [Parameter(
            Position = 0, 
            Mandatory = $true, 
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true,
            HelpMessage = 'Please logical network name (ie. internal, dmz, etc).')
        ]
        [String] $lNetworkName
    )
    
    begin {
        if (!(Test-Path Env:\vmm_server)) {
            Write-Host "The following Environment variable needs to be set prior to running the script:" -ForegroundColor Yellow
            Write-Host "`$Env:vmm_server = <vmm server>" -ForegroundColor Yellow
            break
        }
        $vmmserver = Get-SCVMMServer $Env:vmm_server
    }
    
    process {
        $lNetwork = Get-SCLogicalNetwork -ErrorAction SilentlyContinue | ? { $_.name -match $lNetworkName }
        if (!$lNetwork) {
            Write-Warning "There was an issue. Please verify that the logical network name, $lNetworkName, is correct."
            break
        }
        $networkDef = Get-SCLogicalNetworkDefinition -LogicalNetwork $lNetwork
        $subnets = $networkDef.SubnetVLans
        foreach ($subnet in $subnets) {
            $hshSubnetProperties = [ordered]@{
                LogicalNetwork = $networkDef.LogicalNetwork
                Subnet = $subnet.Subnet
                VLANID = $subnet.VLanID
            }
            New-Object -type PSCustomObject -Property $hshSubnetProperties
        }

    }
    
    end {
    }
}
