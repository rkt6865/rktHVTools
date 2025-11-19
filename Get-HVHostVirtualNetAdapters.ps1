function Get-HVHostVirtualNetAdapters {
    <#
.SYNOPSIS
    Retrieve Virtual Network information of a Hyper-V host.
.DESCRIPTION
    Retrieve Virtual Network information of a Hyper-V host.
.PARAMETER hostName
    Specifies the name of the Hyper-v host. This parameter is mandatory.
.INPUTS
    System.String.  Get-HVHostVirtualNetAdapters accepts a string as the name of the Hyper-V host.
.OUTPUTS
    PSCustomObject. Get-HVHostVirtualNetAdapters returns the hostname, Virtual Network, IP.
.EXAMPLE
    PS C:\> Get-HVHostVirtualNetAdapters <myVMHostName>
    Retrieves the physical NIC information of the Hyper-V host <myVMHostName>.
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
            HelpMessage = 'Please enter a host name.')
        ]
        [String] $hostName
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
        $vHost = Get-SCVMHost $hostName
        if (!$vHost) {
            Write-Warning "There was an issue. Please verify that the hostname, $hostname, is correct."
            break
        }
        $vnics = Get-SCVirtualNetworkAdapter -VMHost $vHost
        foreach ($vnic in $vnics) {
            $hshVnicProperties = [ordered]@{
                Name           = $vHost.ComputerName
                vNetwork       = $vnic.Name
                LogicalSwitch  = $vnic.LogicalSwitch
                VirtaulNetwork = $vnic.VirtualNetwork
                LogicalNetwork = $vnic.LogicalNetwork
                VMNetwork      = $vnic.VMNetwork
                VMSubnet       = $vnic.VMSubnet
                PortProfile    = $vnic.PortClassification
                IPAddress      = [system.version]$vnic.ipv4addresses[0]
            }
            New-Object -type PSCustomObject -Property $hshVnicProperties


        }
    }
    
    end {
    }
}
