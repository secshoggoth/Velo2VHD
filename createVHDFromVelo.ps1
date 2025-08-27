<#
.SYNOPSIS
    Creates a dynamically expanding VHD from Velociraptor triage output by copying files into a C directory inside the VHD. The output format mimics the Kape VHD output.
	
.VERSION
    1.0.1 - Initial version.

.PARAMETER TriageOutputDir
    Directory containing Velociraptor triage output structure.

.PARAMETER VhdDir
    Directory to place the VHD file. Default: current directory.

.PARAMETER VhdFileName
    Name of the VHD file. Default is 'drive_C.vhd'.

.PARAMETER VhdSizeGB
    Size of the VHD file in GB. Default is 32.

.PARAMETER Overwrite
    Switch to overwrite the VHD file if it exists.

.PARAMETER Quiet
    Switch to suppress all console output. Informational, warning, and error messages will not appear in the console but will still be logged to file.

.PARAMETER LogPath
    Optional. Full path to log file. If not specified, a log file named '<VhdFileName>_yyyyMMdd_HHmmss_log.txt' is placed in the VHD directory.

.EXAMPLE
    .\CreateVhdFromTriage.ps1 -TriageOutputDir "C:\triage" -VhdDir "C:\output" -VhdFileName "MyDrive.vhd" -Overwrite -VhdSizeGB 64 -Quiet
#>

[CmdletBinding()]
param (
    [Parameter(Mandatory = $true)]
    [string]$TriageOutputDir,

    [Parameter()]
    [string]$VhdDir = (Get-Location).ProviderPath,

    [Parameter()]
    [string]$VhdFileName = "drive_C.vhd",

    [Parameter()]
    [int]$VhdSizeGB = 32,

    [switch]$Overwrite,

    [switch]$Quiet,

    [Parameter()]
    [string]$LogPath
)

# Version variable
$ScriptVersion = '1.0.1'

function Get-ScriptVersion {
    return $ScriptVersion
}

# Compose full VHD path
$VhdPath = Join-Path -Path $VhdDir -ChildPath $VhdFileName

# Generate default LogPath if not provided, including datestamp
if (-not $LogPath) {
    $timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
    $baseName = [IO.Path]::GetFileNameWithoutExtension($VhdFileName)
    $logFileName = "${baseName}_${timestamp}_log.txt"
    $LogPath = Join-Path -Path $VhdDir -ChildPath $logFileName
}

# Open log file stream
$logStream = New-Object System.IO.StreamWriter($LogPath, $true)
$logStream.AutoFlush = $true

function Write-Log {
    param(
        [string]$Message,
        [switch]$IsError,
        [switch]$IsWarning,
        [switch]$IsInfo
    )
    $timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    $prefix = if ($IsError) { "[ERROR]" } elseif ($IsWarning) { "[WARN]" } elseif ($IsInfo) { "[INFO]" } else { "[LOG]" }
    $line = "$timestamp $prefix $Message"

    # Write to log file
    $logStream.WriteLine($line)

    # Write to console only if not quiet
    if (-not $Quiet) {
        if ($IsError) {
            Write-Error $line
        } elseif ($IsWarning) {
            Write-Warning $line
        } elseif ($IsInfo) {
            Write-Host $line -ForegroundColor Cyan
        } else {
            Write-Host $line
        }
    }
}

function Write-Info { param($msg) Write-Log -Message $msg -IsInfo }
function Write-WarningMsg { param($msg) Write-Log -Message $msg -IsWarning }
function Write-ErrorMsg { param($msg) Write-Log -Message $msg -IsError }

# Recursive copy function with error handling
function Copy-WithErrors {
    param(
        [Parameter(Mandatory = $true)]
        [string]$SourcePath,

        [Parameter(Mandatory = $true)]
        [string]$DestinationPath
    )

    if (-not (Test-Path $SourcePath)) {
        Write-WarningMsg "Source path '$SourcePath' does not exist. Skipping."
        return
    }
    if (-not (Test-Path $DestinationPath)) {
        try {
            New-Item -ItemType Directory -Path $DestinationPath -Force | Out-Null
        }
        catch {
            Write-ErrorMsg "Failed to create destination directory '$DestinationPath': $_"
            throw
        }
    }
    try {
        $items = Get-ChildItem -LiteralPath $SourcePath -Force -ErrorAction Stop
    }
    catch {
        Write-WarningMsg "Failed to enumerate items in '$SourcePath': $_"
        return
    }

    foreach ($item in $items) {
        # Perform replacements on the item's name:
        $newName = $item.Name
        $newName = $newName -replace '(?i)%3A', ':'     # Replace %3A with :
        $newName = $newName -replace '(?i)%25', '%'     # Replace %25 with %
        $newName = $newName -replace '(?i)%2E', '.'     # Replace %2E with .

        # Compose destination path with the replaced name
        $dest = Join-Path $DestinationPath $newName

        try {
            if ($item.PSIsContainer) {
                # Recursively copy with renamed folder name
                Copy-WithErrors -SourcePath $item.FullName -DestinationPath $dest
            }
            else {
                # Copy file with renamed name
                Copy-Item -LiteralPath $item.FullName -Destination $dest -Force -ErrorAction Stop
                Write-Info "Copied file: $($item.FullName) to $dest"
            }
        }
        catch {
            Write-WarningMsg "Failed to copy item '$($item.FullName)': $_"
        }
    }
}

try {
	# On start, display version info
    Write-Info "Starting script version $($ScriptVersion)."
	
    # Check admin rights
    $IsAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltinRole] "Administrator")
    if (-not $IsAdmin) {
        Write-ErrorMsg "Script must be run as Administrator. Please run PowerShell with elevated privileges."
        exit 1
    }

    # Import Hyper-V module
    try {
        Import-Module Hyper-V -ErrorAction Stop
        Write-Info "Loaded Hyper-V PowerShell module."
    }
    catch {
        Write-ErrorMsg "Failed to load Hyper-V module. Ensure Hyper-V is installed and enabled."
        exit 1
    }

    Write-Info "Starting process."

    # Resolve and validate TriageOutputDir
    try {
        $TriageOutputDirFull = (Resolve-Path -LiteralPath $TriageOutputDir -ErrorAction Stop).ProviderPath
        Write-Info "Resolved triage output directory: $TriageOutputDirFull"
    } catch {
        Write-ErrorMsg "TriageOutputDir '$TriageOutputDir' does not exist."
        exit 1
    }

    # Check VHD file existence
    if (Test-Path $VhdPath) {
        if ($Overwrite) {
            Write-WarningMsg "Overwriting existing VHD file: $VhdPath"
            Remove-Item -LiteralPath $VhdPath -Force -ErrorAction Stop
        }
        else {
            Write-ErrorMsg "VHD file '$VhdPath' already exists. Use -Overwrite to replace."
            exit 1
        }
    }

    # Prepare source directories
    $autoDir = Join-Path $TriageOutputDirFull 'auto'
    $ntfsDir = Join-Path $TriageOutputDirFull 'ntfs\%5C%5C.%5CC%3A'

    if (-not (Test-Path (Join-Path $autoDir 'C%3A'))) {
        Write-ErrorMsg "Required directory 'auto\C%3A' missing under '$autoDir'."
        exit 1
    }
    if (-not (Test-Path $ntfsDir)) {
        Write-ErrorMsg "Required directory 'ntfs\%5C%5C.%5CC%3A' missing."
        exit 1
    }

    Write-Info "Creating VHD: $VhdPath with size ${VhdSizeGB} GB (dynamic)."
    $vhdSizeBytes = $VhdSizeGB * 1GB
    New-VHD -Path $VhdPath -Dynamic -SizeBytes $vhdSizeBytes -ErrorAction Stop | Out-Null

    Write-Info "Mounting VHD."
    $vhd = Mount-VHD -Path $VhdPath -PassThru -ErrorAction Stop

    Start-Sleep -Seconds 2

    $diskNumber = $vhd.DiskNumber
    Write-Info "Mounted VHD as disk number $diskNumber."

    $disk = Get-Disk -Number $diskNumber -ErrorAction Stop
    if ($disk.PartitionStyle -eq 'RAW') {
        Write-Info "Initializing disk $diskNumber with MBR partition."
        Initialize-Disk -Number $diskNumber -PartitionStyle MBR -PassThru | Out-Null
    }
    else {
        Write-Info "Disk $diskNumber already initialized."
    }

    Write-Info "Creating partition on disk $diskNumber and assigning drive letter."
    $partition = New-Partition -DiskNumber $diskNumber -UseMaximumSize -AssignDriveLetter -ErrorAction Stop

    $driveLetter = $partition.DriveLetter
    if (-not $driveLetter) {
        throw "Failed to retrieve drive letter after partition creation."
    }
    $mountDrive = "${driveLetter}:\"
    Write-Info "Drive letter assigned: $mountDrive"

    Write-Info "Formatting volume ${driveLetter}:."
    Format-Volume -DriveLetter $driveLetter -FileSystem NTFS -NewFileSystemLabel 'C' -Confirm:$false -ErrorAction Stop | Out-Null

    $targetC = Join-Path $mountDrive 'C'
    if (-not (Test-Path $targetC)) {
        Write-Info "Creating directory $targetC in VHD."
        New-Item -ItemType Directory -Path $targetC -Force | Out-Null
    }

    Write-Info "Copying contents of auto\C%3A to VHD C directory..."
    Copy-WithErrors -SourcePath (Join-Path $autoDir 'C%3A') -DestinationPath $targetC

    $autoSpecialEncoded = Join-Path $autoDir '%5C%5C.%5CC%3A'
    if (Test-Path $autoSpecialEncoded) {
        Write-Info "Copying contents of auto\%5C%5C.%5CC%3A to VHD C directory (merged)..."
        Copy-WithErrors -SourcePath $autoSpecialEncoded -DestinationPath $targetC
    }
    else {
        Write-WarningMsg "Optional directory 'auto\%5C%5C.%5CC%3A' not found; skipping."
    }

    Write-Info "Copying NTFS metadata files from ntfs\%5C%5C.%5CC%3A to VHD C directory..."
	Write-Host "Starting"
    Get-ChildItem -LiteralPath $ntfsDir -Recurse | ForEach-Object {
        $relativePath = $_.FullName.Substring($ntfsDir.Length).TrimStart('\','/')
        $destRelativePath = $relativePath

        # Rename special files as requested
        if ($relativePath -like '$Secure%3A$SDS' -or $relativePath -like '$Secure:$SDS') {
            $destRelativePath = $relativePath -replace '[:%]3A', '_'
        }
        elseif ($relativePath -like '$Extend\$UsnJrnl%3A$J' -or $relativePath -like '$Extend\$UsnJrnl:$J') {
            $destRelativePath = $relativePath -replace '\\\$UsnJrnl(%3A|:)', '\'
        }
        elseif ($relativePath -like '$Extend\$UsnJrnl%3A$Max' -or $relativePath -like '$Extend\$UsnJrnl:$Max') {
            $destRelativePath = $relativePath -replace '\\\$UsnJrnl(%3A|:)', '\'
        }		


        $destFullPath = Join-Path $targetC $destRelativePath
        $destDir = Split-Path $destFullPath -Parent

        if (-not (Test-Path $destDir)) {
            try {
                New-Item -ItemType Directory -Path $destDir -Force | Out-Null
            }
            catch {
                Write-WarningMsg "Failed to create directory '$destDir': $_"
                return
            }
        }

        try {
            Copy-Item -LiteralPath $_.FullName -Destination $destFullPath -Force -ErrorAction Stop
            Write-Info "Copied NTFS metadata file: $destRelativePath"
        }
        catch {
            Write-WarningMsg "Failed to copy NTFS metadata file '$($_.FullName)': $_"
        }
    }

    Write-Info "All files copied to VHD C directory. Dismounting VHD."
    Dismount-VHD -Path $VhdPath -ErrorAction Stop
    Write-Info "Process complete. VHD created at: $VhdPath"

    # Close log stream
    $logStream.Dispose()
}
catch {
    Write-ErrorMsg "Exception encountered: $_"
    if ($logStream) { $logStream.Dispose() }
    exit 1
}
