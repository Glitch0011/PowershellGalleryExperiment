if (Test-Path ".\deploy") {
    Remove-Item ".\deploy" -Force -Recurse
}

if (Test-Path ".\staging") {
    Remove-Item ".\staging" -Force -Recurse
}

# Properties
$company = $null
$functionsToExport = $Env:FunctionsToExport -split ";"
$tags = $Env:Tags -split ";"

# Generated
$version = "$(Get-Date -Format yy.MM.dd).$($Env:APPVEYOR_BUILD_NUMBER)";

$staging = New-Item ".\staging" -ItemType Directory

Write-Output "Installing Formatter"
Install-Module PSScriptAnalyzer -Scope CurrentUser -Force

Write-Output "Copying and cleaning code"
Get-ChildItem -Path "src" -Filter "*.psm1" | ForEach-Object {
    Invoke-Formatter -ScriptDefinition (Get-Content $_.FullName -Raw) >> (Join-Path -Path $staging.FullName $_.Name) 
}

$file = Get-ChildItem -Path $staging -Filter "psm1"

Write-Output "Generating manifest"
$psdFile = Join-Path -Path $staging -ChildPath $($Env:ModuleName).psd1
New-ModuleManifest -Path $psdFile -Description $Env:Description -Author $Env:Author -CompanyName $Env:Company -ModuleVersion $version -RootModule $file.Name -FunctionsToExport $functionsToExport -ProjectUri $Env:ProjectUri -LicenseUri $Env:LicenseUri -Tags $tags

Write-Output "Copying misc files"
Copy-Item -Path "LICENSE" -Destination $staging
Copy-Item -Path "README.md" -Destination $staging

Write-Output "Generating catalog"
New-FileCatalog -Path $staging -CatalogFilePath (Join-Path -Path $staging -ChildPath "$($Env:ModuleName)).cat")

$tempNugetRepo = New-Item -ItemType Directory ".\nuget-feed\nuget\v2"
$deployTarget = New-Item -ItemType Directory ".\deploy"

try
{
    Write-Output "Bootstrapping NuGet"
    Get-PackageProvider -Name NuGet -ForceBootstrap | Out-Null
    
    Write-Output "Registering temp repository"    
    Register-PSRepository -Name "temp" -SourceLocation $tempNugetRepo.FullName

    Write-Output "Publishing module to temp repository"
    Publish-Module -Name $psdFile -Repository "temp"

    $package = Get-ChildItem -Filter "*.nupkg" -Recurse

    Write-Output "Moving package to output"
    Move-Item -Path $package.FullName -Destination $deployTarget.FullName
}
finally 
{
    Unregister-PSRepository "temp" -ErrorAction SilentlyContinue
    Remove-Item -Path (Get-Item "nuget-feed") -Recurse -Force
}