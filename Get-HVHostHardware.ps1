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
    PSCustomObject. Get-HVHostHardware returns the name, manufacturer, model, memory, CPU sockets, and total CPUs.
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
            HelpMessage = 'Enter the host name.')
        ]
        [String] $hostName
    )
    
    begin {
    }
    
    process {
        $sys = Get-CimInstance -ClassName Win32_ComputerSystem -ComputerName $hostName -ErrorAction SilentlyContinue
        if ($sys -eq $null) {
            Write-Warning "There was an issue. Please verify that the hostname, $hostname, is correct."
            break
        }

        $hshSysProperties = [ordered]@{
            Name         = $sys.Name
            Manufacturer = $sys.Manufacturer
            Model        = $sys.Model
            Mem          = [math]::Round($sys.TotalPhysicalMemory / 1gb, 0)
            Sockets      = $sys.NumberOfProcessors
            TotProcs  = $sys.NumberOfLogicalProcessors
        }
        New-Object -type PSCustomObject -Property $hshSysProperties

    }
    
    end {
    }
}