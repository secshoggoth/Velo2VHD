# createVHDFromVelo.ps1

## Overview

`createVHDFromVelo.ps1` is a PowerShell script designed to process Velociraptor triage output directories and package the contents into a dynamically expanding Virtual Hard Disk (VHD) file. The script:

- Validates presence of required Velociraptor triage output folders
- Creates and mounts a dynamically expanding VHD (default 32GB, configurable)
- Initializes, partitions, and formats the VHD with NTFS
- Copies triage data into a directory named `C` inside the mounted VHD
- Supports renaming of certain NTFS metadata files per Velociraptor's output format
- Provides options for logging, quiet mode, overwrite control, and customizable VHD location and size

---

## Requirements

- Windows 10 or later with Hyper-V feature installed and enabled
- PowerShell 5.1 or later with Hyper-V module available
- Script must be run with Administrator privileges

---

## Parameters

| Parameter       | Type    | Required | Default                 | Description                                                           |
|-----------------|---------|----------|-------------------------|-----------------------------------------------------------------------|
| `-TriageOutputDir` | String  | Yes      |                         | Path to Velociraptor triage output directory                          |
| `-VhdDir`       | String  | No       | Current directory (`.\`) | Directory where the VHD file will be created                          |
| `-VhdFileName`  | String  | No       | `drive_C.vhd`           | Name of the VHD file to create                                        |
| `-VhdSizeGB`    | Int     | No       | 32                      | Size in GB of the dynamically expanding VHD                          |
| `-Overwrite`    | Switch  | No       |                         | Overwrite existing VHD file if it exists                             |
| `-Quiet`        | Switch  | No       |                         | Suppress console output; logs still recorded to the log file          |
| `-LogPath`      | String  | No       | `<VhdDir>\<VhdFileName>_yyyMMdd_HHmmss_log.txt` | Full path to the log file. Defaults to timestamped log file next to VHD |

---

## Usage Examples

```powershell
# Basic usage with mandatory triage directory; defaults used
.\createVHDFromVelo.ps1 -TriageOutputDir "C:\triage_output"

# Specify custom VHD directory, file name, and size (64GB), with overwrite and quiet mode
.\createVHDFromVelo.ps1 -TriageOutputDir "C:\triage_output" -VhdDir "D:\VHDs" -VhdFileName "MyCDrive.vhd" -VhdSizeGB 64 -Overwrite -Quiet

# Specify a custom log file location
.\createVHDFromVelo.ps1 -TriageOutputDir "C:\triage_output" -LogPath "C:\logs\velo_export.log"

---

## Logging

- The script writes detailed info, warning, and error messages to a log file.
- The default log file is saved next to the VHD file with the naming format: <VhdFileName>_yyyMMdd_HHmmss_log.txt
- Use the -Quiet switch to suppress all console output while still writing to the log.

## Notes

- The script must be run with Administrator privileges because it creates, mounts, partitions, and formats VHD files.
- Ensure Hyper-V is installed and the PowerShell Hyper-V module is available (Import-Module Hyper-V).
- The VHD is formatted with NTFS and the triage files are copied into a root-level C directory inside the VHD.
- Some NTFS metadata files are renamed during copy to accommodate Velociraptor's naming conventions.
- The script performs validation on input directories and the VHD file overwrite behavior.

## Contact/Support

Feel free to open issues or pull requests if you encounter problems or want to contribute improvements.
