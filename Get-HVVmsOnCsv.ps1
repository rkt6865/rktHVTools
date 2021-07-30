function Get-HVVmsOnCsv {
    <#
.SYNOPSIS
    Retrieve the VMs located on a specific Cluster Shared Volume (CSV) contained within the VMM.
.DESCRIPTION
    Retrieves the name, RAM, disk size, and location of each VM on the CSV.
    The function is dependent on setting the $Env:vmm_server environment variable.  See Notes below.
.PARAMETER CsvName
    Specifies the name (or partial) name of the Cluster Shared Volume of interest. This parameter is mandatory.
.INPUTS
    System.String.  Get-HVVmsOnCsv accepts a string as the name (or partial name) of the CSV.
.OUTPUTS
    PSCustomObject. Get-HVVmsOnCsv returns the name, RAM, disk size, and location of each VM on the CSV.
.EXAMPLE
    PS C:\> Get-HVVmsOnCsv <CsvName>
    Retrieves the fields listed in "Outputs" section for the CSV <CsvName>.
.NOTES
    The following Environment variable(s) must be set prior to running:
        $Env:vmm_server = <server>
#>

    [CmdletBinding()]
    param (
        [Parameter(
            Position = 0, 
            Mandatory = $true, 
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true,
            HelpMessage = 'Enter the name (or partial name) of a CSV.')
        ]
        [String] $csvName
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
        $vms = Get-SCVirtualMachine -VMMServer $vmmserver | ? { $_.location -match $csvName } #| select name, @{N="Size";E={[math]::round(($_.TotalSize/1GB),2)}}, location | sort size -Descending
        if (!$vms) {
            Write-Warning "There are no VMs on the CSV or there are no CSVs with that name."
            return
        }

        foreach ($vm in $vms) {
            $hshVMProps = [ordered]@{
                Name     = $vm.Name
                RAM      = [math]::Round($vm.Memory/1KB,0)
                Size     = [math]::Round($vm.TotalSize / 1GB, 2)
                Location = $vm.Location
            }
            New-Object -type PSCustomObject -Property $hshVMProps
        }
    }
    
    end {
    }
}
