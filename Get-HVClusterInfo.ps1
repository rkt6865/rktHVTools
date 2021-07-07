function Get-HVClusterInfo {
<#
.SYNOPSIS
    Get real time memory/CPU stats for each host in a cluster.
.DESCRIPTION
    Retrieve the amount of VMs, memory and CPU usage for each VMHost in a particular cluster.
    The function is dependent on setting the $Env:vmm_server environment variable.  See Notes below.
.PARAMETER ClusterName
    Specifies the name of the cluster of interest. This parameter is mandatory.
.INPUTS
    System.String.  Get-HVClusterInfo accepts a string as the name of the cluster.
.OUTPUTS
    PSCustomObject. Get-HVClusterInfo returns the host name, number of VMs, total memory, memory used,
    memory available, memory used percentage, and CPU used percentage.
.EXAMPLE
    PS C:\> Get-HVClusterInfo <myClusterName>
    Retrieves memory/cpu information for the cluster <myClusterName>.
.NOTES
    The following Environment variable(s) must be set prior to running:
        $Env:vmm_server = <server>
#>

[CmdletBinding()]
    param (
        [Parameter(
            Position = 0, 
            Mandatory = $true, 
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true,
            HelpMessage = 'Please enter a Cluster name.')
        ]
        [String] $clusterName
    )
    
    begin {
        if (!(Test-Path Env:\vmm_server)) {
            Write-Host "The following Environment variable needs to be set prior to running the script:" -ForegroundColor Yellow
            Write-Host "`$Env:vmm_server = <vmm server>" -ForegroundColor Yellow
            break
        }
        $vmm_server = $Env:vmm_server
    }
    
    process {
        $clstr = Get-SCVMHostCluster -VMMServer $vmm_server -Name $clusterName -ErrorAction Stop
        if (!$clstr) {
            Write-Warning "The cluster, $clusterName, could not found!"
            return
        }

        $hosts = Get-SCVMHost -VMHostCluster $clstr | sort name
        foreach ($h in $hosts) {
            $memTot = $h.TotalMemory / 1gb
            $memAvail = $h.AvailableMemory / 1kb
            $memUsage = $memTot - $memAvail

            $hshHostProps = [ordered]@{
                Host = $h.Name
                VMs = ($h.VMs | ? {$_.Status -eq "Running"} | measure-object).count
                MemTotalGB = [math]::round($memTot, 2)
                MemUsageGB = [math]::round($memUsage, 2)
                MemAvailGB = [math]::round($memAvail, 2)
                MemPct = "{0:P0}" -f ($memUsage/$memTot)
                CPUPct = $h.cpuutilization
            }
            New-Object -type PSCustomObject -Property $hshHostProps


        }
    }
    
    end {
    }
}

