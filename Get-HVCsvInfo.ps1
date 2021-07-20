function Get-HVCsvInfo {
<#
.SYNOPSIS
    Retrieve basic information of a specific Cluster Shared Volume (CSV) contained within the VMM.
.DESCRIPTION
    Retrieves the name, capacity, amount used, free space, and the LUN ID for the CSV.
    The function is dependent on setting the $Env:vmm_server environment variable.  See Notes below.
.PARAMETER CsvName
    Specifies the name (or partial) name of the Cluster Shared Volume of interest. This parameter is mandatory.
.INPUTS
    System.String.  Get-HVCsvInfo accepts a string as the name (or partial name) of the CSV.
.OUTPUTS
    PSCustomObject. Get-HVCsvInfo returns the CSV name, capacity, used space, free space, pct used, and LUN ID of the CSV.
.EXAMPLE
    PS C:\> Get-HVCsvInfo <CsvName>
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
        $vmmServer = $Env:vmm_server
    }
    
    process {
        # The get-scstoragevolume will return a volume for each host in the cluster. Sorting with "-Unique" eliminates that
        $storVols = Get-SCStorageVolume -VMMServer $vmmServer | ? { $_.VolumeLabel -match $csvName } | sort storagevolumeid -Unique
        if (!$storVols) {
            Write-Warning "There are no CSVs with that name."
            return
        }

        foreach ($storVol in $storVols) {
            $used = ($storVol.Capacity / 1GB) - ($storVol.FreeSpace / 1GB)
            $usedPct = ($used / ($storVol.Capacity / 1GB))
            $hshStorVolProps = [ordered]@{
                Name      = $storVol.VolumeLabel
                Cluster   = ($storVol.VMHost.HostCluster.Name).Split(".")[0]
                Capacity  = [math]::Round($storVol.Capacity / 1GB, 2)
                Used      = [math]::round($used, 2)
                Free      = [math]::Round($storVol.Freespace / 1GB, 2)
                UsedPct   = "{0:P0}" -f [math]::round($usedPct, 2)
                LUNId     = $storVol.StorageDisk.SMLunId
            }
            New-Object -type PSCustomObject -Property $hshStorVolProps
        }
            }
    
    end {
    }
}
