function Get-HVHostNicVMQ {
    <#
.SYNOPSIS
    Retrieve the VMQ status (enabled/disabled) of a physical NIC of a Hyper-V host.
.DESCRIPTION
    Retrieve the VMQ status (enabled/disabled) of a physical NIC of a Hyper-V host.
.PARAMETER hostName
    Specifies the name of the Hyper-v host. This parameter is mandatory.
.INPUTS
    System.String.  Get-HVHostNicVMQ accepts a string as the name of the Hyper-V host.
.OUTPUTS
    PSCustomObject. Get-HVHostNicVMQ returns the hostname, NIC, VMQ values.
.EXAMPLE
    PS C:\> Get-HVHostNicVMQ <myVMHostName>
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
        $vHost = Get-SCVMHost -VMMServer $vmmserver -ComputerName $hostName -ErrorAction SilentlyContinue
        if (!$vHost) {
            Write-Warning "There was an issue. Please verify that the hostname, $hostname, is correct."
            break
        }
        # Check is host is part of cluster - this avoides potential error when creating hashtable
        if ($vhost.HostCluster) {
            $clusterName = ($vHost.HostCluster.Name).Split(".")[0]
        }
        else {
            $clusterName = "N/A"
        }
        $cimSession = New-CimSession -ComputerName $hostName
        if (!$cimSession) {
            Write-Warning "There was an issue. Please verify that the hostname, $hostname, is correct."
            break
        }
        $nics = Get-NetAdapter -Physical -CimSession $cimsession
        foreach ($nic in $nics) {
            $nicVmq = Get-NetAdapterVmq -CimSession $cimSession -Name $nic.Name

            $hshNICStatsProperties = [ordered]@{
                Name             = $nic.PSComputerName
                Cluster          = $clusterName
                NIC              = $nicStats.Name
                MAC              = $nic.MacAddress
                Connection       = $nic.MediaConnectionState
                Status           = $nic.Status
                VMQEnabled       = $nicVmq.Enabled
                MaxProcessors    = $nicvmq.MaxProcessors
                NumReceiveQueues = $nicVmq.NumberOfReceiveQueues
                Description      = $nic.InterfaceDescription
            }
            New-Object -type PSCustomObject -Property $hshNICStatsProperties
        }
        Remove-CimSession -CimSession $cimSession

    }
    
    end {
    }
}
