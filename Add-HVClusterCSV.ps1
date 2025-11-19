function Add-HVClusterCSV {
    <#
    .SYNOPSIS
        Add a new CSV to a cluster.
    .DESCRIPTION
        Add a new disk to a host and then make that disk a CSV in the cluster.
    .PARAMETER clusterName
        Specifies the name of the cluster where the CSV will be located. This parameter is mandatory.
    .PARAMETER disklabel
        Specifies the name of the new CSV. This parameter is mandatory.
    .PARAMETER diskSerialNo
        Specifies the UUID of the lun. Supplied by the storage group. This parameter is mandatory.
    .INPUTS
        System.String.  Add-HVClusterCSV accepts a strings for all paramaters.
    .OUTPUTS
        New CSV.
    .EXAMPLE
        PS C:\> Add-HVClusterCSV <clusterName> <disklabel> <diskSerialNo>
    .NOTES
        The following Environment variable(s) must be set prior to running:
            $Env:vmm_server = <server>
    #>
    [CmdletBinding()]
    param (
        [Parameter(
            Mandatory = $true, 
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true,
            HelpMessage = 'Enter the cluster name:')
        ]
        [String] $clusterName,
        [Parameter(
            Mandatory = $true, 
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true,
            HelpMessage = 'Enter the name of the CSV:')
        ]
        [String] $disklabel,
        [Parameter(
            Mandatory = $true, 
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true,
            HelpMessage = 'Enter the UUID/SerialNumber of the lun/disk:')
        ]
        [String] $diskSerialNo
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
        # Validate Cluster
        $clstr = Get-SCVMHostCluster -VMMServer $vmmserver -Name $clusterName -ErrorAction SilentlyContinue
        if (!$clstr) {
            Write-Warning "The cluster, $clusterName, could not found. Please verify the VMM you're connected to and the cluster name."
            return
        }
        $vhostname = $clstr | Get-SCVMHost | select computername -ExpandProperty computername | Get-Random
        # Script block to add and configure a new disk on remote host(s)  -- Think "Disk Manager" on the host
        $remoteDiskblock = {
            Write-Host "Adding, initializing, and formatting disk..." -ForegroundColor Yellow
            $newdisk = Get-Disk | ? { ($_.PartitionStyle -eq "RAW") -and ($_.SerialNumber -eq $using:diskSerialNo) }
            if (! $newdisk) {
                Write-Host "That disk does not exist. Please verify that the cluster and disk serial number are correct." -ForegroundColor Yellow
                $retVal = 1
                return $retVal
                #Exit
            }
            $diskNum = $newdisk.Number
            # Online the disk
            if ($newdisk.IsOffline) {
                Set-Disk -Number $diskNum -IsOffline $false
            }
            # Initialize and format the disk
            try {
                Get-Disk -Number $diskNum -ErrorAction Stop | `
                    Initialize-Disk -PartitionStyle GPT -PassThru -ErrorAction Stop | `
                    New-Partition -AssignDriveLetter -UseMaximumSize -ErrorAction Stop | `
                    Format-Volume -FileSystem NTFS -NewFileSystemLabel $using:diskLabel -AllocationUnitSize 65536 -Confirm:$false -ErrorAction Stop | Out-Null
                
            }
            catch {
                Write-Host "The following error occurred:" -ForegroundColor Yellow
                return $_
            }
        
        }
        
        $diskRslt = Invoke-Command -ComputerName $vHostName -ScriptBlock $remoteDiskblock
        if ($diskRslt) {
            $diskRslt
            return
        }

        #####################################################################
        
        # Script block to add a new disk to the cluster and CSV -- Think "Failover CLuster Manager" on the host
        $remoteCSVblock = {
            Write-Host "Make disk a CSV and rename cluster shared storage..." -ForegroundColor Yellow
            try {
                $availDisk = Get-ClusterAvailableDisk -ErrorAction Stop
                $availDiskName = $availDisk.name
                $availDisk | Add-ClusterDisk -ErrorAction Stop | Out-Null  # ft -AutoSize
                Add-ClusterSharedVolume -Name $availDiskName -ErrorAction Stop | Out-Null
            }
            catch {
                Write-Host "The following error occurred:" -ForegroundColor Yellow
                return $_
            }

            # Rename the CSV from "Cluster Disk 1" to it's proper name    
            (Get-ClusterSharedVolume -Name $availDiskName).Name = $using:diskLabel
            # Get-ClusterSharedVolume -Name $using:diskLabel | ft -AutoSize # Display to user

            # Rename directory in cluster shared storage directory from "Volume1" to it's proper name
            $csv = Get-ClusterSharedVolume -Name $using:diskLabel
            $volName = ($csv.SharedVolumeInfo[0].FriendlyVolumeName).Split("\")[-1]
            $parentPath = Split-Path -Parent $csv.SharedVolumeInfo[0].FriendlyVolumeName
        
            Get-ChildItem -Path $parentPath -Directory | `
                ForEach-Object {
                if ($_.Name -match $volName) {
                    Rename-Item -Path $_.FullName -NewName ($_.Name -replace $volName, $using:diskLabel)
                }
            }
            Get-ChildItem -Path $parentPath -Directory | ? { $_.name -eq $using:diskLabel } | ft -AutoSize # Display to user
        }
        
        $csvRslt = Invoke-Command -ComputerName $vHostName -ScriptBlock $remoteCSVblock
        if ($csvRslt) {
            $csvRslt
            return
        }

    }
            
    end {
    }
}
