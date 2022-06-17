function Get-HVHostLastBootUpTime {
    <#
.SYNOPSIS
    Retrieve the time a Hyper-V host last rebooted.
.DESCRIPTION
    Retrieve the time a Hyper-V host last rebooted.
.PARAMETER hostName
    Specifies the name of the Hyper-v host. This parameter is mandatory.
.INPUTS
    System.String.  Get-HVHostLastBootUpTime accepts a string as the name of the Hyper-V host.
.OUTPUTS
    PSCustomObject. Get-HVHostLastBootUpTime returns the name, cluster, and the time the server last rebooted.
.EXAMPLE
    PS C:\> Get-HVHostLastBootUpTime <myVMHostName>
    Retrieves the time that the Hyper-V host <myVMHostName> was last rebooted.
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
        $cimSession = New-CimSession -ComputerName $hostName
        if (!$cimSession) {
            Write-Warning "There was an issue. Please verify that the hostname, $hostname, is correct."
            break
        }
        $os = Get-CimInstance -ClassName win32_operatingsystem -CimSession $cimSession -Property csname, lastbootuptime
        Remove-CimSession -CimSession $cimSession

        # Check is host is part of cluster - this avoides potential error when creating hashtable
        if ($vhost.HostCluster) {
            $clusterName = ($vHost.HostCluster.Name).Split(".")[0]
        } else {
            $clusterName = "N/A"
        }
        $hshOsProperties = [ordered]@{
            Name         = $os.CSName
            Cluster      = $clusterName
            LastBootUpTime = $os.LastBootUpTime
        }
        New-Object -type PSCustomObject -Property $hshOsProperties

    }
    
    end {
    }
}
