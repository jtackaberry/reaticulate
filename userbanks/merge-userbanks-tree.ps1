# merge-userbanks-tree.ps1
# Scott Sadowsky
# Version 0.8
#
# This is a Windows PowerShell script to merge all .reabank files in the entire Github userbank folder 
# structure. This excludes .md, .BAK, !merged.reabank files (these are created by the merge-reabanks.ps1 script).
#
# The purpose of this script is to allow you to easily keep up with modifications and additions to the 
# Reabank Github repository, thus it will regenerate your Reaticulate.reabank from the Github tree.
#
# It will: 
#	(a) Merge all .reabank folders under the folder you run it in (which should be the 
#	    \reaticulate\userbanks\ folder downloaded from Github), noting the source folder and file 
#	    of each.
#	(b) Rename your current Reaticulate.reabank file to Reaticulate.reabank.BAK. If the backup file
#	    already exists, the new one will have an incremental number appended (e.g. .BAK01).
# 	(c) Save the new Reaticulate.reabank file to Reaper's Data folder.
#	(d) Normalize all line endings to CR/LF and eliminate extra newlines, except for before and after
#	    the source file indicator.
#
# INSTRUCTIONS
# 1. Download the Reaticulate Github tree.
# 2. Navigate to the \reaticulate\userbanks\ folder.
# 3. Open PowerShell
# 4. Run the script (this assumes you have (i) added this script's folder to your path, (ii) aliased it 
#    in PowerShell as "merge-userbanks", and (iii) obtained permission to run PowerShell scripts. For 
#    (iii) you will need to run "Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass" in PowerShell. 
#    Alternatively, you can run "Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned" to 
#    allow your user to run all scripts.

# Merge all .reabank files in the current directory and subdirectories into Reaticulate.reabank
# Backup existing Reaticulate.reabank before saving
# Scott Sadowsky
# Version 0.9

# Merge all .reabank files in the current directory and subdirectories into Reaticulate.reabank
# Backup existing Reaticulate.reabank before saving, using incremental BAK numbering
# Scott Sadowsky
# Version 1.1

# Get current user
$CURRENTUSER = $env:USERNAME

# Define Reaper Reaticulate paths
$reaperDataFolder = "C:\Users\$CURRENTUSER\AppData\Roaming\REAPER\Data"
$outputFile = Join-Path $reaperDataFolder "Reaticulate.reabank"

# Backup existing file if it exists
if (Test-Path $outputFile) {
    $i = 1
    do {
        $suffix = "{0:D2}" -f $i
        $backupFile = Join-Path $reaperDataFolder "Reaticulate.reabank.BAK$suffix"
        $i++
    } while (Test-Path $backupFile)

    Rename-Item -Path $outputFile -NewName (Split-Path $backupFile -Leaf) -Force
    Write-Host "Existing Reaticulate.reabank backed up to $(Split-Path $backupFile -Leaf)"
}

# Get all .reabank files in the current folder and subfolders, excluding any .BAK files and !merged.reabank
$files = Get-ChildItem -Path (Get-Location) -Recurse -File -Filter "*.reabank" | Where-Object {
    ($_.Extension -eq ".reabank") -and
    ($_.Name -notlike "*.BAK*") -and
    ($_.Name -ne "!merged.reabank")
} | Sort-Object FullName

# Merge each file with separator block above the content
$mergedContent = ""

foreach ($file in $files) {
    $content = Get-Content -Path $file.FullName -Raw

    # Normalize all line endings to CRLF
    $content = $content -replace "(`r`n|`r|`n)", "`r`n"

    # Collapse multiple consecutive CRLFs into a single CRLF
    $content = [regex]::Replace($content, "(\r\n){2,}", "`r`n")

    # Get parent folder name
    $parentFolder = Split-Path -Leaf $file.DirectoryName

    # Separator block above file content
    $separator = "`r`n`r`n`r`n//===============================================" +
                 "`r`n// Source File: $parentFolder/$($file.Name)" +
                 "`r`n//===============================================" +
                 "`r`n`r`n`r`n"

    # Prepend separator to content
    $mergedContent += $separator + $content
}

# Ensure the Reaper Data folder exists
if (!(Test-Path $reaperDataFolder)) {
    New-Item -ItemType Directory -Path $reaperDataFolder -Force
}

# Save merged content to Reaticulate.reabank
Set-Content -Path $outputFile -Value $mergedContent -Encoding UTF8

Write-Host "Merged $($files.Count) files into $outputFile with separators above each file, normalized line endings, excluding existing BAK files and !merged.reabank."

