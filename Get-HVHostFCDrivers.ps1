function Get-HVHostFCDrivers {
    <#
.SYNOPSIS
    Retrieve the FC driver information of a physical FC of a Hyper-V host.
.DESCRIPTION
    Retrieve the FC driver information of a physical FC of a Hyper-V host.
.PARAMETER hostName
    Specifies the name of the Hyper-v host. This parameter is mandatory.
.INPUTS
    System.String.  Get-HVHostFCDrivers accepts a string as the name of the Hyper-V host.
.OUTPUTS
    PSCustomObject. Get-HVHostFCDrivers returns the hostname, cluster, FC, driver information.
.EXAMPLE
    PS C:\> Get-HVHostFCDrivers <myVMHostName>
    Retrieves the physical FC driver information of the Hyper-V host <myVMHostName>.
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
        $fcAdapters = Invoke-Command -ComputerName $hostName -ScriptBlock { Get-WmiObject Win32_PnPSignedDriver | ? { $_.devicename -like "*fibre*" } }
        foreach ($fcAdapter in $fcAdapters) {

            $hshFCDriverProperties = [ordered]@{
                Name           = $hostName.Split(".")[0]
                Cluster        = $clusterName
                FC             = $fcAdapter.DeviceName
                DriverProvider = $fcAdapter.DriverProviderName
                DriverVersion  = $fcAdapter.DriverVersion
                DriverDate     = (($fcAdapter.DriverDate.split(".")[0]).substring(0,8)).Insert(4,'-').Insert(7,'-')
                #DriverFileName = $nic.DriverFileName
            }
            New-Object -type PSCustomObject -Property $hshFCDriverProperties
        }

    }
    
    end {
    }
}
