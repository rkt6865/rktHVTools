function Connect-VMMServer {
    <#
    .SYNOPSIS
        Connect to System Center Virtual Machine Manager.
    .DESCRIPTION
        Establish a connection to a specific Virtual Machine Manager (VMM) server.
        This could be a local or remote VMM. The function is dependent on some Environment variables.  See Notes below.
    .PARAMETER vmm_server
        Specifies the name/fqdn of the VMM server. This parameter is mandatory.
    .INPUTS
        None.
    .OUTPUTS
        None.
    .EXAMPLE
        PS C:\> Connect-VMMServer <vmm_server>
        Connects to a VMM server specified in the $Env:vmm_server variable.
    .EXAMPLE
        PS C:\> $VMMServer = Connect-VMMServer <vmm_server>
        Create a variable containing the VMM server connetion.
    .NOTES
        The following Environment variable(s) will be used if configured:
            $Env:vmm_username = <username>
            $Env:vmm_password = <password>
    #>
    
    [CmdletBinding()]
    param (
        [Parameter(
            Position = 0, 
            Mandatory = $true, 
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true,
            HelpMessage = 'Please enter the name (fqdn) of the VMM Server to connect to.')
        ]
        [String] $vmm_server
    )
        
    begin {
    }
    
    process {
        # Check if username/password Environment variables have been set.  If not, prompt for creds.
        if (!(Test-Path Env:\vmm_username) -or !(Test-Path Env:\vmm_password)) {
            $creds = Get-Credential -Message "Please enter Domain credentials for $vmm_server"
            $vmm_username = $creds.GetNetworkCredential().username
            $vmm_password = $creds.GetNetworkCredential().password
        }
        else {
            $vmm_username = $Env:vmm_username
            $vmm_password = $Env:vmm_password
        }
    
        # Create SecureString object needed to create PSCredential object
        $secureString = ConvertTo-SecureString -AsPlainText -Force -String $vmm_password
        # Create PSCredential
        $creds = New-Object System.Management.Automation.PSCredential ($vmm_username, $secureString)
            
        # Set ErrorActionPreference variable to prevent error from displaying when connecting to VMM server
        $ErrorActionPreference = 'SilentlyContinue'
        # Attempt to create a connection to the VMM server
        $vmmServer = Get-SCVMMServer -ComputerName $vmm_server -Credential $creds
        if (!$vmmServer) {
            Write-Warning "There was an issue. Please verify that the VMM server name, <$vmm_server>, and your credentials are correct."
            break
        }
    
        # Save credentials to an environment variable for possible later use.
        Set-Item ENV:vmm_username $vmm_username
        Set-Item ENV:vmm_password $vmm_password

        # Save $vmm_server to an environment variable for use it other scripts which require it
        Set-Item ENV:vmm_server $vmm_server
        return $vmmServer
    }
        
    end {
    }
}
