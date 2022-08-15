function Get-HVHostMPIOSettings {
    <#
.SYNOPSIS
    Retrieve the MPIO settings of a Hyper-V host.
.DESCRIPTION
    Retrieve the MPIO settings of a Hyper-V host.
.PARAMETER hostName
    Specifies the name of the Hyper-v host. This parameter is mandatory.
.INPUTS
    System.String.  Get-HVHostMPIOSettings accepts a string as the name of the Hyper-V host.
.OUTPUTS
    PSCustomObject. Get-HVHostMPIOSettings returns the MPIO settings of the Hyper-V host.
.EXAMPLE
    PS C:\> Get-HVHostMPIOSettings <myVMHostName>
    Retrieves the MPIO settings of the Hyper-V host <myVMHostName>.
.EXAMPLE
    PS C:\> Get-SCVMHostCluster <clustername> | Get-SCVMHost | Get-HVHostMPIOSettings | Out-GridView
    Retrieves the MPIO settings of all of the Hyper-V hosts in the cluster <clustername>.
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
        $hvHost = Get-SCVMHost -VMMServer $vmmserver -ComputerName $hostName -ErrorAction SilentlyContinue
        if (!$hvHost) {
            Write-Warning "There was an issue. Please verify that the hostname, $hostname, is correct."
            break
        }

        # Script block to run on remote host(s)
        $remoteMPIOblock = {
            $mpiox = Get-MPIOSetting
            $arrvendor = Get-MSDSMSupportedHW | ? { $_.vendorid -eq "PURE" }
            $mpiox | Add-Member -NotePropertyName LoadBal -NotePropertyValue (Get-MSDSMGlobalDefaultLoadBalancePolicy)
            $mpiox | Add-Member -NotePropertyName VendorID -NotePropertyValue ($arrvendor.vendorid)
            $mpiox | Add-Member -NotePropertyName ProductID -NotePropertyValue ($arrvendor.productid)

            $mpiox
        }
        # Retrieve the MPIO settings from the host
        #$mpiosettings = Invoke-Command -ComputerName $($hvHost.Name) -Credential $pscred -ScriptBlock $remoteMPIOblock
        $mpiosettings = Invoke-Command -ComputerName $($hvHost.Name) -ScriptBlock $remoteMPIOblock
        $mpiosettings.psobject.properties.Remove('RunspaceId')
    
        $hshMPIOProperties = [ordered]@{}
        $mpiosettings.psobject.properties | Foreach { $hshMPIOProperties[$_.Name] = $_.Value }
        New-Object -type PSCustomObject -Property $hshMPIOProperties
    }
    
    end {
    }
}
