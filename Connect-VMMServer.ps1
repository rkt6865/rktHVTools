function Connect-VMMServer {
<#
.SYNOPSIS
    Connect to System Center Virtual Machine Manager.
.DESCRIPTION
    Establish a connection to a specific Virtual Machine Manager (VMM) server.
    This could be a local or remote VMM. The function is dependent on some Environment variables.  See Notes below.
.INPUTS
    None.
.OUTPUTS
    None.
.EXAMPLE
    PS C:\> Connect-VMMServer
    Connects to a VMM server specified in the $Env:vmm_server variable.
.EXAMPLE
    PS C:\> $VMMServer = Connect-VMMServer
    Create a variable containing the VMM server connetion.
.NOTES
    The following Environment variable(s) must be set prior to running:
        $Env:vmm_username = <username>
        $Env:vmm_password = <password>
        $Env:vmm_server = <server>
#>

[CmdletBinding()]
    param (
    )
    
    begin {
    }

    process {
        # Check if username/password Environment variables have been set
        if (!(Test-Path Env:\vmm_username) -or !(Test-Path Env:\vmm_password) -or !(Test-Path Env:\vmm_server)) {
            Write-Host "The following Environment variables need to be set prior to connect to the VMM server" -ForegroundColor Yellow
            Write-Host "`$Env:vmm_username = <username>" -ForegroundColor Yellow
            Write-Host "`$Env:vmm_password = <password>" -ForegroundColor Yellow
            Write-Host "`$Env:vmm_server = <server>" -ForegroundColor Yellow
            break
        }

        $vmm_username = $env:vmm_username
        $vmm_password = $env:vmm_password
        $vmmserver = $env:vmm_server

        # Create SecureString object needed to create PSCredential object
        $secureString = ConvertTo-SecureString -AsPlainText -Force -String $vmm_password
        # Create PSCredential
        $creds = New-Object System.Management.Automation.PSCredential ($vmm_username, $secureString)

        Get-SCVMMServer -ComputerName $vmmserver -Credential $creds
    }
    
    end {
    }
}
