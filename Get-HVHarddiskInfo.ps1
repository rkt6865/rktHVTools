function Get-HVHarddiskInfo {
<#
.SYNOPSIS
    Retrieve the hard disk information for a VM.
.DESCRIPTION
    Retrieves the hard disk information such as size, used space, scsi controller, and location for each disk of a VM.
    The function is dependent on setting the $Env:vmm_server environment variable.  See Notes below.
.PARAMETER vmName
    Specifies the name of the VM containting the disks of interest. This parameter is mandatory.
.INPUTS
    System.String.  Get-HVHarddiskInfo accepts a string as the name of the VM.
.OUTPUTS
    PSCustomObject. Get-HVHarddiskInfo returns the hard disk name, scsi/ide controller, disk size, and disk location.
.EXAMPLE
    PS C:\> Get-HVHarddiskInfo <vmname>
    Retrieves the hard disk information in the VM <vmname>.
.EXAMPLE
    PS C:\> Get-SCVirtualMachine myVM | Get-HVHarddiskInfo
    Retrieves the hard disk information in the VM <myVM>.
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
            HelpMessage = 'Enter the name of the VM')
        ]
        [String] $vmname
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
        $vm = Get-SCVirtualMachine -VMMServer $vmmserver $vmname
        if (!$vm) {
            Write-Warning "The VM, $vmname, could not be found."
            return
        }

        $vDiskDrives = Get-SCVirtualDiskDrive -VMMServer $vmmserver -VM $vm
        foreach ($vDiskDrive in $vDiskDrives) {
            $busType = $vDiskDrive.BusType
            $bus = $vDiskDrive.Bus
            $lun = $vDiskDrive.Lun
            $hdisk = $vDiskDrive.VirtualHardDisk
            $locpath = $hdisk.location.Replace(":", "$")
            $hdFilename = "\\" + $hdisk.hostname + "\" + $locpath

            $hshDiskProperties = [ordered]@{
                vmName    = $vm.Name
                HDName    = $hdisk.Name
                CntrlType = $busType
                SCSIID    = "$($bus):$($lun)"
                UsedGB    = [math]::Round($hdisk.Size / 1GB, 2)
                MaxGB     = [math]::Round($hdisk.MaximumSize / 1GB, 2)
                CSV       = $hdisk.HostVolume.Name
                Filename  = $hdFilename
            }
            New-Object -type PSCustomObject -Property $hshDiskProperties
        }
    }
        
    end {
    }
}
