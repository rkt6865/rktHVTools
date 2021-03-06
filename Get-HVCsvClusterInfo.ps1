function Get-HVCsvClusterInfo {
    <#
.SYNOPSIS
    Retrieve basic information of the Clustered Shared Volumes (CSVs) in a cluster.
.DESCRIPTION
    Retrieves the name, capacity, amount used, and amount free for each CSV in a Hyper-V compute cluster.
    The function is dependent on setting the $Env:vmm_server environment variable.  See Notes below.
.PARAMETER ClusterName
    Specifies the name of the Hyper-V cluster containting the storage of interest. This parameter is mandatory.
.INPUTS
    System.String.  Get-HVCsvClusterInfo accepts a string as the name of the cluster.
.OUTPUTS
    PSCustomObject. Get-HVCsvClusterInfo returns the CSV name, capacity, used space, free space, and amount used percentage for each CSV in the cluster.
.EXAMPLE
    PS C:\> Get-HVCsvClusterInfo <myClusterName>
    Retrieves the capacity, used space, free space for each CSV in the cluster <myClusterName>.
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
            HelpMessage = 'Enter the Cluster name.')
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
        $clstr = Get-SCVMHostCluster -VMMServer $vmmserver -Name $clusterName -ErrorAction SilentlyContinue
        if (!$clstr) {
            Write-Warning "The cluster, $clusterName, could not found!"
            return
        }
        $csvs = Get-ClusterSharedVolume -Cluster $clstr
        foreach ($csv in $csvs) {
            $partitionInfo = $csv.SharedVolumeInfo[0].Partition
            $used = ($partitionInfo.Size / 1GB) - ($partitionInfo.FreeSpace / 1GB)
            $usedPct = ($used / ($partitionInfo.Size / 1GB))
            $hshCsvProps = [ordered]@{
                Name     = $csv.Name
                Owner    = $csv.OwnerNode.Name
                Capacity = [math]::Round($partitionInfo.Size / 1GB, 2)
                Used     = [math]::round($used, 2)
                Free     = [math]::Round($partitionInfo.Freespace / 1GB, 2)
                UsedPct  = "{0:P0}" -f [math]::round($usedPct, 2)
            }
            New-Object -type PSCustomObject -Property $hshCsvProps
        }
    }
    
    end {
    }
}
