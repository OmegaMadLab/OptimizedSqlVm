[CmdletBinding()]

param (
    
    # Number of data disks
    [Parameter(Mandatory = $true)]
    [int]
    $NumberOfDataDisks,
    
    # If present, all data disks will be striped in a storage pool
    [Parameter(Mandatory = $false)]
    [switch]
    $StripeDataDisks,

    # Number of data disks
    [Parameter(Mandatory = $true)]
    [int]
    $NumberOfLogDisks,
    
    # If present, all data disks will be striped in a storage pool
    [Parameter(Mandatory = $false)]
    [switch]
    $StripeLogDisks,

    # Number of additional disks
    [Parameter(Mandatory = $true)]
    [int]
    $NumberOfAdditionalDisks,
    
    # Type of workload
    [Parameter(Mandatory = $false)]
    [ValidateSet("OLTP","DW", "GENERIC")]
    [string]
    $WorkloadType = "OLTP",

    # SysAdmin
    [Parameter(Mandatory = $true)]
    [string]
    $SysAdminUsername,

    # SysAdmin Password
    [Parameter(Mandatory = $true)]
    [securestring]
    $SysAdminPassword

)

Import-Module .\Optimize-SqlIaasVm-CSE.psm1

$ErrorActionPreference = "Stop"

$CurrentDriveLetter = "F"

if($NumberOfDataDisks -ge 1) {
    ### Create storage configuration for data disks ###
    # Define an array of LUN dedicated to data disks, starting from 0 to $NumberOfDataDisks - 1
    $DataLun = @(0..$($NumberOfDataDisks - 1))

    if($StripeDataDisks -and $NumberOfDataDisks -gt 1) {

        try {
        
            # Create a SQL Optimized striped storage pool 
            New-StoragePoolForSql -LUN $DataLun `
                -StoragePoolFriendlyName "SqlDataPool" `
                -VirtualDiskFriendlyName "SqlDataVdisk" `
                -VolumeLabel "SQLDataDisk" `
                -FileSystem NTFS `
                -DriveLetter $([char]$CurrentDriveLetter) `
                -WorkLoadType $WorkloadType | Out-Null

            Write-Output "Storage pool for SQL Data created with LUN $($DataLun -join ",")"
        }
        catch {
            Write-Output "Error while creating data storage pool:"
            Throw $_
        }

        While(!(Test-Path "$([char]$CurrentDriveLetter):\")) {
            Update-HostStorageCache
            Update-StorageProviderCache
        }

        $DataPath = New-SqlDirectory -DirectoryPath "$([char]$CurrentDriveLetter):\SQLData"

        if($NumberOfLogDisks -eq 0) {
            $LogPath = New-SqlDirectory -DirectoryPath "$([char]$CurrentDriveLetter):\SQLLog"
            $ErrorLogPath = New-SqlDirectory -DirectoryPath "$([char]$CurrentDriveLetter):\SQLErrorLog"
            if($NumberOfAdditionalDisks -eq 0) {
                $BackupPath = New-SqlDirectory -DirectoryPath "$([char]$CurrentDriveLetter):\SQLBackup"
            }
        }

        # Increment drive letter for next drives
        [char]([int][char]$CurrentDriveLetter)++ | Out-Null

    } else {

        
        # Get single disks dedicated to data
        $SingleDisk = Get-PhysicalDisk -FriendlyName 'Msft Virtual Disk' | Where-Object {$_.PhysicalLocation.split(" ")[-1] -In $DataLun } | Get-Disk | Sort-Object Number

        $i = 1
        $SingleDisk | ForEach-Object {

            try {
                # Create a new optimized single disk
                New-SingleDiskForSql -Disk $_ `
                    -VolumeLabel "SqlDataDisk$i" `
                    -FileSystem NTFS `
                    -DriveLetter $([char]$CurrentDriveLetter) `
                    -Force `
                    -SkipClearDisk | Out-Null

                Write-Output "Disk $($_.PhysicalLocation) configured"
            }
            catch {
                Write-Output "Error while creating volume on disk $($_.PhysicalLocation):"
                Throw $_
            }

            While(!(Test-Path "$([char]$CurrentDriveLetter):\")) {
                Update-HostStorageCache
            }

            if($i = 1) {
                $DataPath = New-SqlDirectory -DirectoryPath "$([char]$CurrentDriveLetter):\SQLData"
            } else {
                New-SqlDirectory -DirectoryPath "$([char]$CurrentDriveLetter):\SQLData" | Out-Null
            }

            if($NumberOfLogDisks -eq 0) {
                $LogPath = New-SqlDirectory -DirectoryPath "$([char]$CurrentDriveLetter):\SQLLog"
                $ErrorLogPath = New-SqlDirectory -DirectoryPath "$([char]$CurrentDriveLetter):\SQLErrorLog"
                if($NumberOfAdditionalDisks -eq 0) {
                    $BackupPath = New-SqlDirectory -DirectoryPath "$([char]$CurrentDriveLetter):\SQLBackup"
                }
            }

            # Increment drive letter for next drives
            [char]([int][char]$CurrentDriveLetter)++ | Out-Null
            $i++ | Out-Null
        }
    }
}

### Create storage configuration for log disks ###
if($NumberOfLogDisks -ge 1) {
    # Define an array of LUN dedicated to log disks, starting from $NumberOfDataDisks to ($NumberOfDataDisks + $NumberOfLogDisks - 1)
    $LogLun = @(($NumberOfDataDisks)..($NumberOfDataDisks + $NumberOfLogDisks - 1))

    if($StripeLogDisks -and $NumberOfLogDisks -gt 1) {
        
        try {
            # Create a SQL Optimized striped storage pool 
            New-StoragePoolForSql -LUN $LogLun `
                -StoragePoolFriendlyName "SqlLogPool" `
                -VirtualDiskFriendlyName "SqlLogVdisk" `
                -VolumeLabel "SQLLogDisk" `
                -FileSystem NTFS `
                -DriveLetter $([char]$CurrentDriveLetter) `
                -WorkLoadType $WorkloadType | Out-Null

            Write-Output "Storage pool for SQL Log created with LUN $($DataLun -join ",")"
        }
        catch {
            Write-Output "Error while creating data storage pool:"
            Throw $_
        }
 

        While(!(Test-Path "$([char]$CurrentDriveLetter):\")) {
            Update-HostStorageCache
            Update-StorageProviderCache
        }

        $LogPath = New-SqlDirectory -DirectoryPath "$([char]$CurrentDriveLetter):\SQLLog"
        $ErrorLogPath = New-SqlDirectory -DirectoryPath "$([char]$CurrentDriveLetter):\SQLErrorLog"

        if($NumberOfAdditionalDisks -eq 0) {
            $BackupPath = New-SqlDirectory -DirectoryPath "$([char]$CurrentDriveLetter):\SQLBackup"
        }

        # Increment drive letter for next drives
        [char]([int][char]$CurrentDriveLetter)++ | Out-Null

    } else {

        # Get single disks dedicated to log
        $SingleDisk = Get-PhysicalDisk -FriendlyName 'Msft Virtual Disk' | Where-Object {$_.PhysicalLocation.split(" ")[-1] -In $LogLun } | Get-Disk | Sort-Object Number

        $i = 1
        $SingleDisk | ForEach-Object {

            
            try {

                # Create a new optimized single disk
                New-SingleDiskForSql -Disk $_ `
                    -VolumeLabel "SqlLogDisk$i" `
                    -FileSystem NTFS `
                    -DriveLetter $([char]$CurrentDriveLetter) `
                    -SkipClearDisk `
                    -Force | Out-Null
                
                Write-Output "Disk $($_.PhysicalLocation) configured"
            }
            catch {
                Write-Output "Error while creating volume on disk $($_.PhysicalLocation):"
                Throw $_
            }


            While(!(Test-Path "$([char]$CurrentDriveLetter):\")) {
                Update-HostStorageCache
            }

            
            if($i -eq 1) {
                $LogPath = New-SqlDirectory -DirectoryPath "$([char]$CurrentDriveLetter):\SQLLog"
                $ErrorLogPath = New-SqlDirectory -DirectoryPath "$([char]$CurrentDriveLetter):\SQLErrorLog"
                if($NumberOfAdditionalDisks -eq 0) {
                    $BackupPath = New-SqlDirectory -DirectoryPath "$([char]$CurrentDriveLetter):\SQLBackup"
                }
            } else {
                New-SqlDirectory -DirectoryPath "$([char]$CurrentDriveLetter):\SQLLog" | Out-Null
            }

            # Increment drive letter for next drives
            [char]([int][char]$CurrentDriveLetter)++ | Out-Null
            $i++ | Out-Null
        }
    }
}

### Create storage configuration for additional disks ###
if($NumberOfAdditionalDisks -ge 1) {
    # Define an array of LUN dedicated to additional disks
    $DataAndLogDisks = $NumberOfDataDisks + $NumberOfLogDisks
    $AdditionalLun = @(($DataAndLogDisks)..($DataAndLogDisks + $NumberOfAdditionalDisks - 1))

    # Get single disks
    $SingleDisk = Get-PhysicalDisk -FriendlyName 'Msft Virtual Disk' | Where-Object {$_.PhysicalLocation.split(" ")[-1] -In $AdditionalLun } | Get-Disk | Sort-Object Number

    $i = 1
    $SingleDisk | ForEach-Object {

        try {

            if($_.PartitionStyle -eq 'RAW') {
                $_ | Initialize-Disk -PartitionStyle GPT
            }
    
            $_ | New-Partition -UseMaximumSize -DriveLetter $([char]$CurrentDriveLetter) | Out-Null
            Format-Volume -DriveLetter $([char]$CurrentDriveLetter) `
                -FileSystem NTFS `
                -NewFileSystemLabel "Disk$i" `
                -Force `
                -Confirm:$false | Out-Null

            Write-Output "Disk $($_.PhysicalLocation) configured"
        }
        catch {
            Write-Output "Error while creating volume on disk $($_.PhysicalLocation)"
            Throw $_
        }
 
        if($i -eq 1) {
            While(!(Test-Path "$([char]$CurrentDriveLetter):\")) {
                Update-HostStorageCache
            }
            $BackupPath = New-SqlDirectory -DirectoryPath "$([char]$CurrentDriveLetter):\SQLBackup"
        }
        # Increment drive letter for next drives
        [char]([int][char]$CurrentDriveLetter)++ | Out-Null
        $i++ | Out-Null
    }
    
}

$ScriptBlock = {

    param(
        [string]$DataPath,
        [string]$LogPath,
        [string]$BackupPath,
        [string]$ErrorLogPath,
        [string]$WorkloadType
    )

    Import-Module .\Optimize-SqlIaasVm-CSE.psm1

    $SqlInstanceName = "MSSQLSERVER"

    try {
        Set-SQLServerDefaultPath -SqlInstanceName $SqlInstanceName `
            -DataPath $DataPath `
            -LogPath $LogPath `
            -BackupPath $BackupPath

        Write-Output "New data path:`t$DataPath"
        Write-Output "New log path:`t$LogPath"
        Write-Output "New backup path:`t$BackupPath"
    }
    catch {
        Write-Output "Error while changing SQL Server default paths"
        Throw $_
    }

    try {
        Move-SystemDatabaseAndTrace -SqlInstanceName $SqlInstanceName `
            -DataPath $DataPath `
            -LogPath $LogPath `
            -ErrorLogPath $ErrorLogPath

        Write-Output "System DBs moved to new default paths"
        Write-Output "New ErrorLog path:`t$ErrorLogPath"
    }
    catch {
        Write-Output "Error while changing moving system databases and errorlog:"
        Throw $_
    }

    try {
        #Defining MaxServerMemory value depending on installed memory
        $InstalledMemory = [math]::Round((Get-WmiObject -Class Win32_ComputerSystem).TotalPhysicalMemory/1MB)

        Switch($InstalledMemory) {
            {$_ -le 4096} { $MaxServerMemory = $InstalledMemory - 2048 }
            {$_ -gt 4096 -and $_ -le 8192} { $MaxServerMemory = $InstalledMemory - 3072 }
            {$_ -gt 8192} { $MaxServerMemory = $InstalledMemory - 4096 }
            default { $MaxServerMemory = 2147483647}
        }

        Switch ($WorkloadType) {
            "OLTP" {$traceFlag = @("-T1117", "-T1118")}
            "DW" {$traceFlag = @("-T1117", "-T610")}
        }

        $SqlServerVersion = Get-SqlServerVersion -SqlInstanceName $SqlInstanceName

        if([int]($SqlServerVersion.split(".")[0]) -lt 13) {
            Set-SQLInstanceOptimization -SqlInstanceName $SqlInstanceName `
                -EnableIFI `
                -EnableLockPagesInMemory `
                -TraceFlag $traceFlag `
                -MaxServerMemoryMB $MaxServerMemory
        } else {
            Set-SQLInstanceOptimization -SqlInstanceName $SqlInstanceName `
                -EnableIFI `
                -EnableLockPagesInMemory `
                -MaxServerMemoryMB $MaxServerMemory
        }

        Write-Output "Instant File Initialization enabled for current service SID"
        Write-Output "Locked pages enabled for current service SID"
        Write-Output "Max Server Memory limited to $MaxServerMemory MB"
        if([int]($SqlServerVersion.split(".")[0]) -lt 13) {
            Write-Output "Trace flag $($traceFlag -join ",") enabled"
        }
    }
    catch {
        Write-Output "Error while applying SQL Server optimizations:"
        Throw $_
    }
}

#Execution with different account
Enable-PSRemoting -Force
$credential = New-Object System.Management.Automation.PSCredential("$env:COMPUTERNAME\$SysAdminUsername", $SysAdminPassword)
Invoke-Command -ScriptBlock $ScriptBlock `
    -ArgumentList @($DataPath, $LogPath, $BackupPath, $ErrorLogPath, $WorkloadType) `
    -Credential $credential 

