function Get-HVVMInfo {
    <#
.SYNOPSIS
    Retrieve basic VM resource information.
.DESCRIPTION
    Retrieves the VM Name, CPUs, Memory, total disk storage, and location of the VM.
    The function is dependent on setting the $Env:vmm_server environment variable.  See Notes below.
.PARAMETER CsvName
    Specifies the name of the VM. This parameter is mandatory.
.INPUTS
    System.String.  Get-HVVMInfo accepts a string as the name VM.
.OUTPUTS
    PSCustomObject. Get-HVVMInfo returns the VM Name, CPUs, Memory, total disk storage, and location of the VM.
.EXAMPLE
    PS C:\> Get-HVVMInfo <VMName>
    Retrieves the fields listed in "Outputs" section for the VM <VMName>.
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
            HelpMessage = 'Enter the VM name:')
        ]
        [String] $vmName
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
        $vm = Get-SCVirtualMachine -VMMServer $vmmserver -Name $vmName
        if (!$vm) {
            Write-Warning "There is no VM with that name."
            return
        }

        #foreach ($vm in $vms) {
        $hDisks = Get-SCVirtualHardDisk -VM $vm
        $hshVMProps = [ordered]@{
            Name     = $vm.Name
            CPU      = $vm.CPUCount
            MemGB   = [math]::Round($vm.Memory / 1KB, 0)
            Size     = [math]::Round($vm.TotalSize / 1GB, 2)
            HDSizeGB = [math]::Round((($hDisks | Measure-Object -Property MaximumSize -Sum).sum) / 1GB, 2)
            Location = $vm.Location
        }
        New-Object -type PSCustomObject -Property $hshVMProps
        #}
    }
    
    end {
    }
}
