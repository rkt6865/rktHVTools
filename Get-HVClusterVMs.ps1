function Get-HVClusterVMs {
    <#
    .SYNOPSIS
        Return all VMs in a cluster.
    .DESCRIPTION
        Return all VMs in a particular cluster.
        The function is dependent on setting the $Env:vmm_server environment variable.  See Notes below.
    .PARAMETER ClusterName
        Specifies the name of the cluster of interest. This parameter is mandatory.
    .INPUTS
        System.String.  Get-HVClusterVMs accepts a string as the name of the cluster.
    .OUTPUTS
        Microsoft.SystemCenter.VirtualMachineManager.VM. Get-HVClusterVMs returns the VM objects of the specified host.
    .EXAMPLE
        PS C:\> Get-HVClusterVMs <myClusterName>
        Retrieves all of the VMs in the cluster <myClusterName>.
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
        $vmmserver = Get-SCVMMServer $Env:vmm_server
    }
        
    process {
        $clstr = Get-SCVMHostCluster -VMMServer $vmmserver -Name $clusterName -ErrorAction Stop
        if (!$clstr) {
            Write-Warning "The cluster, $clusterName, could not found!"
            return
        }
    
        $clusterVMs = Get-SCVirtualMachine -VMMServer $vmmserver -All | ? { $_.vmhost.hostcluster.name -eq $clstr }
        return $clusterVMs
    }
        
    end {
    }
}
