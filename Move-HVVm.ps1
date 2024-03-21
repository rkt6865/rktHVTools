function Move-HVVM {
    <#
    .SYNOPSIS
        Migrate VM to a different host in the same cluster.
    .DESCRIPTION
        Migrate VM to a different host in the same cluster.
    .PARAMETER vmName
        Specifies the name of the VM to be migrated. This parameter is mandatory.
    .PARAMETER vmHostName
        Specifies the name of the host to migrate the VM to. This parameter is mandatory.
    .INPUTS
        System.String.  Move-HVVM accepts a strings for both paramaters.
    .OUTPUTS
        VirtualMachine object.
    .EXAMPLE
        PS C:\> Move-HVVM <vmname> <vmhostname>
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
            HelpMessage = 'Enter the VM name')
        ]
        [String] $vmName,
        [Parameter(
            Mandatory = $true, 
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true,
            HelpMessage = 'Enter the hostname to migrate to')
        ]
        [String] $vmHostName
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
        $vm = Get-SCVirtualMachine $vmName
        if (!$vm) {
            Write-Warning "The VM, $vmName, could not be found."
            return
        }
    
        $destVmHost = Get-SCVMHost $vmHostName
        # Verify if host is part of the same cluster
        $currentVmHost = $vm.VMHost
        if ($currentVmHost.name -eq $destVmHost.Name) {
            Write-Warning "The current host, $($currentVmHost.computername), is the same as the destination host, $($destVmHost.computerName)"
            return
        }
        $availHosts = $vm.VMHost.HostCluster.Nodes | select Name -ExpandProperty Name | sort
        if ($availHosts -contains $destVmHost.Name) {
            Write-Host "Moving VM....."
            Move-SCVirtualMachine -VM $vm -VMHost $destVmHost
        }
        else {
            Write-Error "$vmHostName does not exist in the same cluster"
            return
        }
    }
            
    end {
    }
}
