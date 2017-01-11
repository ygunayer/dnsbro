param(
    [string]$version=(Get-Content ../VERSION)
)

$replacements = @{
    "VERSION" = $version;
    "CONFIG_FILE_CONTENTS" = Get-Content ..\src\config.json;
    "BUILD_DATE" = Get-Date -UFormat "%Y-%m-%d %H:%M:%S";
}

$script = Get-Content ../src/win/dnsbro.ps1

Function GetFullPath($rel) {
    [System.IO.Path]::GetFullPath((Join-Path (pwd) $rel))
}

Function ReplaceTerm($in, $key, $value) {
    $lookupKey = "{{" + $key + "}}"
    Return $in -replace $lookupKey, $value
}

$replacements.GetEnumerator() | % { $script = (ReplaceTerm $script $_.Key $_.Value) }

if (!(Test-Path bin)) {
    mkdir bin
}

$scriptPath = GetFullPath ".\bin\dnsbro.ps1"

$script | Out-File $scriptPath

Write-Host "Build successful ->" $scriptPath
