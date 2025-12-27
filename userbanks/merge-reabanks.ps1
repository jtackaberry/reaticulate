# Merge all .reabank and .txt files in a given folder, excluding .md files.
# Scott Sadowsky
# Version 0.5
# 
# To be run in PowerShell. You may need to run "Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass"
# in PowerShell in order for the script to run.
#
# Alternatively, you can run "Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned" to allow
# your user to run all scripts.

# Current folder
$folderPath = Get-Location

# Define output file
$outputFile = Join-Path $folderPath "!merged.reabank"

# Remove the output file if it already exists
if (Test-Path $outputFile) {
    Remove-Item $outputFile
}

# Get all .txt and .reabank files in the current folder, excluding .md files and the output file
$files = Get-ChildItem -Path $folderPath -File | Where-Object {
    ($_.Extension -eq ".txt" -or $_.Extension -eq ".reabank") -and
    ($_.Extension -ne ".md") -and
    ($_.FullName -ne $outputFile)
} | Sort-Object Name

# Merge each file with normalized Windows line endings and separators above the file content
foreach ($file in $files) {
    $content = Get-Content -Path $file.FullName -Raw
    # Normalize to CRLF
    $content = $content -replace "(`r`n|`r|`n)", "`r`n"

    # Get parent folder name
    $parentFolder = Split-Path -Leaf $file.DirectoryName

    # Prepend separator block above file content
    $separator = "`r`n`r`n`r`n//==============================================================================================" +
                 "`r`n// Source File: $parentFolder/$($file.Name)" +
                 "`r`n//==============================================================================================" +
                 "`r`n`r`n`r`n"

    $content = $separator + $content

    Add-Content -Path $outputFile -Value $content
}

Write-Host "Merged $($files.Count) files into $outputFile with folder and filename separators above the file contents and Windows line endings, excluding .md files."
