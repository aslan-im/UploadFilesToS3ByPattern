<#
.SYNOPSIS
    Script for uploading files to S3 bucket
.DESCRIPTION
    Script checks the target path for files with the prefix and uploads them to the S3 bucket
.INPUTS
    There is no input in the template
    Script uses config file for getting the configuration variables
.OUTPUTS
    The output will be the log file by default
.NOTES
    Version: 0.4.1
    Owner: Aslan Imanalin 
    Github: @aslan-im
#>


#Requires -Module Logging, AWS.Tools.Common, AWS.Tools.S3
Import-Module Logging AWS.Tools.Common, AWS.Tools.S3


[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
#region CommonVariables
$WorkingDirectory = Switch ($Host.name) {
    'Visual Studio Code Host' { 
        split-path $psEditor.GetEditorContext().CurrentFile.Path 
    }
    'Windows PowerShell ISE Host' {
        Split-Path -Path $psISE.CurrentFile.FullPath
    }
    'ConsoleHost' {
        $PSScriptRoot 
    }
}

$CurrentDate = Get-Date
$ConfigPath = "$WorkingDirectory\config\config.json"
$RegistryFile = "$WorkingDirectory\Registry.csv"
$RegistrySelectionList = @(
    'Name',
    @{L = 'Size (KB)'; E = { $($_.Length / 1KB).ToString("0.00") } } ,
    @{L = 'UploadTime'; E = { Get-Date } }
)

#endregion

#region LoggingConfiguration
$LogFilePath = "$WorkingDirectory\logs\log_$($CurrentDate.ToString("yyyy-MM-dd")).log"
Set-LoggingDefaultLevel -Level 'Info'
Add-LoggingTarget -Name File -Configuration @{
    Path      = $LogFilePath
    PrintBody = $false
    Append    = $true
    Encoding  = 'ascii'
}

Add-LoggingTarget -Name Console -Configuration @{}
#endregion

Write-Log "Checking config file"
$ConfigFileExists = Test-Path $ConfigPath

if ($ConfigFileExists) {
    Write-Log "Getting config file content"
    try {
        $Config = Get-Content $ConfigPath -ErrorAction Stop | ConvertFrom-Json
        Write-Log "Config file has been successfull read"
    }
    catch {
        Write-Log "Unable to read the config file. $($_.Exception.Message)" -Level ERROR
        throw "Unable to read the config file. $($_.Exception.Message)"
        break
    }
}
else {
    Write-Log -Level ERROR "Config file doesn't exist. Please check the path: $ConfigPath"
    throw "Unable to read the config file. $($_.Exception.Message)"
    exit 1
}

#region ScriptConfiguration variables
$Prefixes = $Config.main.filePrefixes
$BucketName = $Config.main.S3BucketName
$TargetPath = $Config.main.drivePath
#endregion


#region MainLogic
Write-Log "Checking target path: $TargetPath"
try {
    $IsTargetPathCorrect = Test-path $TargetPath -ErrorAction Stop
    if ($IsTargetPathCorrect) {
        Write-Log "Target path is correct"
    }
    else {
        Write-Log "Target path is incorrect. Please check the path: '$TargetPath'" -Level ERROR
        exit 1
    }

}
catch {
    Write-Log "Target path is incorrect. Please check the path: '$TargetPath'. $($_.Exception)" -Level ERROR
    exit 1
}

Write-Log "Reading file list from the target path"
try {
    $FileList = Get-ChildItem $TargetPath -Recurse -File -ErrorAction Stop
    Write-Log "Files have been read from the target path"
}
catch {
    Write-Log "Unable to read the file list. $($_.Exception.Message)" -Level ERROR
    exit 1
}
$PrefixesString = $Prefixes -join ', '
Write-Log "Filtering files by the prefixes: $PrefixesString"
$TargetFiles = @()
foreach ($Prefix in $Prefixes) {
    Write-Log "Checking files with the prefix: $Prefix"
    $Result = $FileList | Where-Object { $_.Name -like "$Prefix*" }
    $ResultCount = $Result.Count
    if ($ResultCount -gt 0) {
        Write-Log "There are $ResultCount files with the prefix: '$Prefix'."
        $TargetFiles += $Result
    }
    else {
        Write-Log "There is no files with the prefix: '$Prefix'."
    }
}

$TargetFilesCount = $TargetFiles.Count

if ($TargetFilesCount -eq 0) {
    Write-Log "There are no files after filtering using prefixes" -Level WARNING
    exit 1
}
else {
    Write-Log "Total files after filtering using prefixes: $TargetFilesCount"
}

Write-Log "Checking Registry file"
$IsRegistryFileExists = Test-Path $RegistryFile
if ($IsRegistryFileExists) {
    Write-Log "Registry file has been validated"
    try {
        $Registry = Import-csv -delimiter ";" $registryFile -ErrorAction Stop
        $RegistryRecordsCount = $Registry.Count
        Write-Log "Registry records count: $RegistryRecordsCount"
    }
    catch {
        Write-Log "Unable to read the registry file. $($_.Exception.Message)" -Level ERROR
        exit 1
    }

    $FilesToUpload = $TargetFiles | Where-Object { $Registry.Name -notcontains $_.Name }
    $FilesToUploadCount = $FilesToUpload.Count
    Write-Log "Files to upload count: $FilesToUploadCount"
}
else {
    Write-Log "Registry file doesn't exist. New registry will be created" -level WARNING
    $FilesToUpload = $TargetFiles
}
if ($FilesToUpload.Count -eq 0) {
    Write-Log "There are no files to upload. Exiting the script" -Level INFO
    exit 0
}

foreach ($File in $FilesToUpload) {
    Write-Log "Working with file: $($File.Name)"
    $FileName = $File.Name
    $FilePath = $File.FullName
    try {
        Write-Log "Uploading file: $FileName. File size: $(($File.Length/1KB).ToString("0.00")) KB"
        
        Write-S3Object -BucketName "$BucketName" -File $FilePath -ErrorAction STOp
        # aws s3 cp $FilePath s3://$BucketName/$FileName --sse AES256 --acl bucket-owner-full-control
        Write-Log "File '$($FileName)' has been successfully uploaded"

        $ExportSplat = @{
            Path              = $RegistryFile
            Delimiter         = ';'
            NoTypeInformation = $true
            Append            = $true
        }
        $File | Select-Object $RegistrySelectionList | Export-csv @ExportSplat
    }
    catch {
        Write-Log "Unable to upload the file $FileName. $($_.Exception.Message)" -Level ERROR
    }
}
#endregion