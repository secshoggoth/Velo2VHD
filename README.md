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

