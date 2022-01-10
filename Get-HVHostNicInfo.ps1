function Get-HVHostNicInfo {
    <#
.SYNOPSIS
    Retrieve physical NIC information of a Hyper-V host.
.DESCRIPTION
    Retrieve physical NIC information of a Hyper-V host.
.PARAMETER hostName
    Specifies the name of the Hyper-v host. This parameter is mandatory.
.INPUTS
    System.String.  Get-HVHostNicInfo accepts a string as the name of the Hyper-V host.
.OUTPUTS
    PSCustomObject. Get-HVHostNicInfo returns the hostname, NIC, NIC description, MAC, speed, and status.
.EXAMPLE
    PS C:\> Get-HVHostNicInfo <myVMHostName>
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
        $cimSession = New-CimSession -ComputerName $hostName
        if (!$cimSession) {
            Write-Warning "There was an issue. Please verify that the hostname, $hostname, is correct."
            break
        }
        $nics = Get-NetAdapter -Physical -CimSession $cimsession
        Remove-CimSession -CimSession $cimSession
        foreach ($nic in $nics) {
            $hshNICProperties = [ordered]@{
                Name       = $hostName
                NIC        = $nic.Name
                NICDesc    = $nic.InterfaceDescription
                MAC        = $nic.MacAddress
                MTU        = $nic.MtuSize
                Speed      = $nic.LinkSpeed
                Connection = $nic.MediaConnectionState
                Status     = $nic.Status
            }
            New-Object -type PSCustomObject -Property $hshNICProperties


        }
    }
    
    end {
    }
}
