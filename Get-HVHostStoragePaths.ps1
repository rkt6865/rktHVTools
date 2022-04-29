function Get-HVHostStoragePaths {
    <#
.SYNOPSIS
    Retrieve the available storage paths for each LUN of a Hyper-V host.
.DESCRIPTION
    Retrieve the available storage paths for each LUN of a Hyper-V host.
.PARAMETER hostName
    Specifies the name of the Hyper-v host. This parameter is mandatory.
.INPUTS
    System.String.  Get-HVHostStoragePaths accepts a string as the name of the Hyper-V host.
.OUTPUTS
    PSCustomObject. Get-HVHostStoragePaths returns the hostname, MPIO Disk, Number of paths, LUN ID, and volume label.
.EXAMPLE
    PS C:\> Get-HVHostStoragePaths <myVMHostName>
    Retrieves the available storage paths of the Hyper-V host <myVMHostName>.
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
        # This block is to get the volume label by creating a lookup table of the diskid & name
        $storvols = Get-SCStorageVolume -VMHost $hostname | ? { $_.Name -like "C:\Clust*" }
        if ($storvols) {
            # Get CLuster - Check if host is part of cluster - this avoides potential error when creating hashtable
            if ($storvols[0].VMHost.HostCluster) {
                $clusterName = ($storvols[0].VMHost.HostCluster.Name).Split(".")[0]
            }
            else {
                $clusterName = "N/A"
            }

            # Create lookup table to map the "serial number" to the volume label
            $lunIdNameMap = @{}
            foreach ($item in $storvols) {
                $lunID = $item.StorageDisk.SMLunId
                $lunIdNameMap.Add($lunId, $item.VolumeLabel)
            }
        
            # Get the actual path information
            $mpioDriveInfo = (Get-WmiObject -Namespace root\wmi -Class mpio_disk_info -ComputerName $hostname).driveinfo
        
            foreach ($mpioDrive in $mpioDriveInfo) {
                $hshPathProps = [ordered]@{
                    Host    = $hostname
                    Cluster = $clusterName
                    Name    = $mpioDrive.Name
                    Paths   = $mpioDrive.numberpaths
                    LunID   = $mpioDrive.SerialNumber
                    Label   = $lunIdNameMap[$mpioDrive.SerialNumber]
                }
                New-Object -type PSCustomObject -Property $hshPathProps
            }
        }
        else {
            Write-Host "There are no storage volumes available for $hostname" -ForegroundColor Red
            break
        }

    }
    
    end {
    }
}
