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

        function ExpressServiceCode {
            param ([string]$serviceTag)
            $Alphabet = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ"
            $ca = $ServiceTag.ToUpper().ToCharArray()
            [System.Array]::Reverse($ca)
            [System.Int64]$ExpressServiceCode = 0
        
            $i = 0
            foreach ($c in $ca) {
                $ExpressServiceCode += $Alphabet.IndexOf($c) * [System.Int64][System.Math]::Pow(36, $i)
                $i += 1
            }
            $ExpressServiceCode
        }
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
        $sys = Get-CimInstance -ClassName Win32_ComputerSystem -CimSession $cimSession -Property Manufacturer, Model, TotalPhysicalMemory
        $sn = (Get-CimInstance -ClassName Win32_bios -CimSession $cimSession).SerialNumber
        $proc = Get-CimInstance -ClassName Win32_Processor -CimSession $cimSession
        Remove-CimSession -CimSession $cimSession

        # Check is host is part of cluster - this avoides potential error when creating hashtable
        if ($vhost.HostCluster) {
            $clusterName = ($vHost.HostCluster.Name).Split(".")[0]
        }
        else {
            $clusterName = "N/A"
        }
        $hshSysProperties = [ordered]@{
            Name               = $sys.Name
            Cluster            = $clusterName
            Manufacturer       = $sys.Manufacturer
            Model              = $sys.Model
            SerialNo           = $sn
            ExpressServiceCode = if ($sys.Manufacturer -like "Dell*") { expressServiceCode($sn) } else { "N/A" }
            Mem                = [math]::Round($sys.TotalPhysicalMemory / 1gb, 0)
            Sockets            = $proc.Count
            Cores              = $proc[0].NumberOfCores
            TotProcs           = ($proc.Count) * ($proc[0].NumberOfLogicalProcessors)
            Processor          = $proc[0].Name
        }
        New-Object -type PSCustomObject -Property $hshSysProperties

    }
    
    end {
    }
}
