function Get-HVVMTimeSynchronization {
    <#
.SYNOPSIS
    Checks whether the VMIntegrationService Time Synchronization is enabled on a VM.
.DESCRIPTION
    Checks whether the VMIntegrationService Time Synchronization is enabled on a VM.
    The function is dependent on setting the $Env:vmm_server environment variable.  See Notes below.
.PARAMETER CsvName
    Specifies the name of the VM. This parameter is mandatory.
.INPUTS
    System.String.  Get-HVVMTimeSynchronization accepts a string as the name VM.
.OUTPUTS
    Status of the Time Synchronization service (enabled/disabled).
.EXAMPLE
    PS C:\> Get-HVVMTimeSynchronization <VMName>
    Retrieves the Time Synchronization value for the VM <VMName>.
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

        #create a new cimsession to the host running the VM
        $cimsession = New-CimSession $vm.HostName
        $timesync = Get-VMIntegrationService -CimSession $cimsession -VMName $vm.Name | ? { $_.name -eq "Time Synchronization" }
        $hshTimeSyncProps = [ordered]@{
            VMName  = $vm.Name
            Name    = $timesync.Name
            Enabled = $timesync.Enabled
        }
        New-Object -type PSCustomObject -Property $hshTimeSyncProps
        
    }
    
    end {
    }
}
