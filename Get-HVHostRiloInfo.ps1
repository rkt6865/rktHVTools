function Get-HVHostRiloInfo {
    <#
.SYNOPSIS
    Retrieve iLo/iDRAC location and address of a Hyper-V host.
.DESCRIPTION
    Retrieves the iLo/iDRAC location and address of a Hyper-V host.
.PARAMETER hostName
    Specifies the name of the Hyper-v host. This parameter is mandatory.
.INPUTS
    System.String.  Get-HVHostRiloInfo accepts a string as the name of the Hyper-V host.
.OUTPUTS
    PSCustomObject. Get-HVHostRiloInfo returns the iLo/iDRAC location and address.
.EXAMPLE
    PS C:\> Get-HVHostRiloInfo <myVMHostName>
    Retrieves the iLo/iDRAC location and address of the Hyper-V host <myVMHostName>.
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

        $hshRiloProperties = [ordered]@{
            Name         = $vHost.ComputerName
            Location      = $vHost.CustomProperty.Get_Item("Location")
            Rilo      = $vHost.CustomProperty.Get_Item("Rilo")
        }
        New-Object -type PSCustomObject -Property $hshRiloProperties

    }
    
    end {
    }
}
