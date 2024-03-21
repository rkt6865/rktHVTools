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
        $vhostname = Get-SCVMHostCluster $clusterName | Get-SCVMHost | select computername -ExpandProperty computername | Get-Random
        # Script block to add and configure a new disk on remote host(s)  -- Think "Disk Manager" on the host
        $remoteDiskblock = {
            $newdisk = Get-Disk | ? { ($_.PartitionStyle -eq "RAW") -and ($_.SerialNumber -eq $using:diskSerialNo) }
            if (!($newdisk)) {
                Write-Host "That disk does not exist. Please verify the VMM you're connected to and that the cluster and disk serial number are correct." -ForegroundColor Yellow
                return 1
                Exit
            }
            $diskNum = $newdisk.Number
            # Online the disk
            if ($newdisk.IsOffline) {
                Set-Disk -Number $diskNum -IsOffline $false
            }
            # Initialize and format the disk
            $d1 = Get-Disk -Number $diskNum | `
                Initialize-Disk -PartitionStyle GPT -PassThru | `
                New-Partition -AssignDriveLetter -UseMaximumSize 
        
            Format-Volume -DriveLetter $d1.Driveletter -FileSystem NTFS -NewFileSystemLabel $using:diskLabel -AllocationUnitSize 65536 -Confirm:$false -ErrorAction SilentlyContinue
        }
        
        $diskRslt = Invoke-Command -ComputerName $vHostName -ScriptBlock $remoteDiskblock
        if ($diskRslt -eq 1) {return}
        
        #####################################################################
        
        # Script block to add a new disk to the cluster and CSV -- Think "Failover CLuster Manager" on the host
        $remoteCSVblock = {
            $availDisk = Get-ClusterAvailableDisk
            $availDiskName = $availDisk.name
            $availDisk | Add-ClusterDisk
            Add-ClusterSharedVolume -Name $availDiskName

            # Rename the CSV from "Cluster Disk 1" to it's proper name    
            (Get-ClusterSharedVolume -Name $availDiskName).Name = $using:diskLabel
            Get-ClusterSharedVolume -Name $using:diskLabel | ft -AutoSize # Display to user

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
            Get-ChildItem -Path $parentPath -Directory | ?{$_.name -eq $using:diskLabel} | ft -AutoSize # Display to user
        }
        
        Invoke-Command -ComputerName $vHostName -ScriptBlock $remoteCSVblock
    }
            
    end {
    }
}
