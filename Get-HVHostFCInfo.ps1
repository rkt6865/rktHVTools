function Get-HVHostFCInfo {
    <#
.SYNOPSIS
    Retrieve the FC information of a physical FC of a Hyper-V host.
.DESCRIPTION
    Retrieve the FC information of a physical FC of a Hyper-V host.
.PARAMETER hostName
    Specifies the name of the Hyper-v host. This parameter is mandatory.
.INPUTS
    System.String.  Get-HVHostFCInfo accepts a string as the name of the Hyper-V host.
.OUTPUTS
    PSCustomObject. Get-HVHostFCInfo returns the hostname, manufacturer, model, driver information.
.EXAMPLE
    PS C:\> Get-HVHostFCInfo <myVMHostName>
    Retrieves the physical FC information of the Hyper-V host <myVMHostName>.
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
        $vHost = Get-SCVMHost -VMMServer $vmmserver -ComputerName $hostName -ErrorAction SilentlyContinue
        if (!$vHost) {
            Write-Warning "There was an issue. Please verify that the hostname, $hostname, is correct."
            break
        }
        # Check is host is part of cluster - this avoides potential error when creating hashtable
        if ($vhost.HostCluster) {
            $clusterName = ($vHost.HostCluster.Name).Split(".")[0]
        }
        else {
            $clusterName = "N/A"
        }
        $fcAdapters = Invoke-Command -ComputerName $hostName -ScriptBlock { Get-WmiObject -Class MSFC_FCAdapterHBAAttributes -Namespace root\WMI }
        foreach ($fcAdapter in $fcAdapters) {

            $hshFCProperties = [ordered]@{
                Name             = $hostName.Split(".")[0]
                Cluster          = $clusterName
                Active           = $fcAdapter.Active
                Manufacturer     = $fcAdapter.Manufacturer
                Model            = $fcAdapter.Model
                Modeldescription = $fcAdapter.ModelDescription
                DriverName       = $fcAdapter.DriverName
                DriverVersion    = $fcAdapter.DriverVersion
            }
            New-Object -type PSCustomObject -Property $hshFCProperties
        }

    }
    
    end {
    }
}
