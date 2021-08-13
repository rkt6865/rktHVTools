function Get-HVHostHardware {
    <#
.SYNOPSIS
    Retrieve hardware information of a Hyper-V host.
.DESCRIPTION
    Retrieves the name, manufacturer, model, memory and CPUs for a Hyper-V host.
.PARAMETER hostName
    Specifies the name of the Hyper-v host. This parameter is mandatory.
.INPUTS
    System.String.  Get-HVHostHardware accepts a string as the name of the Hyper-V host.
.OUTPUTS
    PSCustomObject. Get-HVHostHardware returns the name, cluster, manufacturer, model, memory, CPU sockets, and total CPUs.
.EXAMPLE
    PS C:\> Get-HVHostHardware <myVMHostName>
    Retrieves the hardware information of the Hyper-V host <myVMHostName>.
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
        $sys = Get-CimInstance -ClassName Win32_ComputerSystem -ComputerName $hostName -ErrorAction SilentlyContinue
        $sn = (Get-CimInstance -ClassName Win32_bios -ComputerName $hostName).SerialNumber
        if ($sys -eq $null) {
            Write-Warning "There was an issue. Please verify that the hostname, $hostname, is correct."
            break
        }

        $hshSysProperties = [ordered]@{
            Name         = $sys.Name
            Cluster      = ($vHost.HostCluster.Name).Split(".")[0]
            Manufacturer = $sys.Manufacturer
            Model        = $sys.Model
            SerialNo     = $sn
            Mem          = [math]::Round($sys.TotalPhysicalMemory / 1gb, 0)
            Sockets      = $sys.NumberOfProcessors
            TotProcs     = $sys.NumberOfLogicalProcessors
        }
        New-Object -type PSCustomObject -Property $hshSysProperties

    }
    
    end {
    }
}
