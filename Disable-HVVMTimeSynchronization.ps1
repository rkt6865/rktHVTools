function Disable-HVVMTimeSynchronization {
    <#
.SYNOPSIS
    Disables the Time Synchronization within the VMIntegrationService of a VM.
.DESCRIPTION
    Disables the Time Synchronization within the VMIntegrationService of a VM.
    The function is dependent on setting the $Env:vmm_server environment variable.  See Notes below.
.PARAMETER CsvName
    Specifies the name of the VM. This parameter is mandatory.
.INPUTS
    System.String.  Disable-HVVMTimeSynchronization accepts a string as the name VM.
.OUTPUTS
    Status of the Time Synchronization service (enabled/disabled).
.EXAMPLE
    PS C:\> Disable-HVVMTimeSynchronization <VMName>
    Disables Time Synchronization for the VM <VMName>.
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
        $timesync = Get-VMIntegrationService -CimSession $cimsession -VMName $vm.Name | ?{$_.name -eq "Time Synchronization"}
        if ($timesync.Enabled) {
            Write-Host "Disabling Time Synchronization for $($vm.name)... " #-NoNewLine
            Disable-VMIntegrationService -CimSession $cimsession -VMName $vm.Name  -Name "Time Synchronization"
            $timesync = Get-VMIntegrationService -CimSession $cimsession -VMName $vm.Name | ?{$_.name -eq "Time Synchronization"}
            Write-Host "Time Synchronization has been disabled."
            $hshTimeSyncProps = [ordered]@{
                VMName  = $vm.Name
                Name    = $timesync.Name
                Enabled = $timesync.Enabled
            }
            New-Object -type PSCustomObject -Property $hshTimeSyncProps
    
        } else {
            Write-Host "Time Synchronization has already been disabled on this VM."
        }
        
    }
    
    end {
    }
}
