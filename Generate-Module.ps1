if (Test-Path ".\deploy") {
    Add-AppveyorMessage "Deleting previous deployment directory"        
    Remove-Item ".\deploy" -Force -Recurse
}

if (Test-Path ".\staging") {
    Add-AppveyorMessage "Deleting previous staging directory"    
    Remove-Item ".\staging" -Force -Recurse
}

# Properties
$company = $null
$functionsToExport = $Env:FunctionsToExport -split ";"
$tags = $Env:Tags -split ";"

# Generated
$version = $Env:APPVEYOR_BUILD_VERSION

$staging = New-Item ".\staging" -ItemType Directory -Force

Add-AppveyorMessage "Installing Formatter"
Install-Module PSScriptAnalyzer -Scope CurrentUser -Force

Add-AppveyorMessage "Copying and cleaning code"
Get-ChildItem -Path "src" -Filter "*.psm1" | ForEach-Object {
    Invoke-Formatter -ScriptDefinition (Get-Content $_.FullName -Raw) >> (Join-Path -Path $staging.FullName $_.Name) 
}

$file = Get-ChildItem -Path $staging -Filter "psm1"

Add-AppveyorMessage "Generating manifest"
$psdFile = Join-Path -Path $staging -ChildPath "$($Env:ModuleName).psd1"
New-ModuleManifest -Path $psdFile -Description $Env:Description -Author $Env:Author -CompanyName $Env:Company -ModuleVersion $version -RootModule $file.Name -FunctionsToExport $functionsToExport -ProjectUri $Env:ProjectUri -LicenseUri $Env:LicenseUri -Tags $tags

Add-AppveyorMessage "Copying misc files"
Copy-Item -Path "LICENSE" -Destination $staging
Copy-Item -Path "README.md" -Destination $staging
Add-AppveyorMessage "Generating documentation"
Install-Module -Name platyPS -Scope CurrentUser -Force
New-ExternalHelp .\docs -OutputPath en-GB\
Copy-Item -Path "en-GB" -Destination $stagingDirectory

# Removed because when it isn't signed, it cases the install-module to fail
#Add-AppveyorMessage "Generating catalog"
#New-FileCatalog -Path $staging -CatalogFilePath (Join-Path -Path $staging -ChildPath "$($Env:ModuleName).cat")

$tempNugetRepo = New-Item -ItemType Directory ".\nuget-feed\nuget\v2"
$deployTarget = New-Item -ItemType Directory ".\deploy"

try
{
    Add-AppveyorMessage "Bootstrapping NuGet"
    Get-PackageProvider -Name NuGet -ForceBootstrap | Out-Null
    
    Add-AppveyorMessage "Registering temp repository"    
    Register-PSRepository -Name "temp" -SourceLocation $tempNugetRepo.FullName

    Add-AppveyorMessage "Publishing module to temp repository"
    Publish-Module -Name $psdFile -Repository "temp"

    $package = Get-ChildItem -Filter "*.nupkg" -Recurse

    Add-AppveyorMessage "Moving package to output"
    Move-Item -Path $package.FullName -Destination $deployTarget.FullName
}
finally 
{
    Add-AppveyorMessage "Deleting temp resources"
    Unregister-PSRepository "temp" -ErrorAction SilentlyContinue
    Remove-Item -Path (Get-Item "nuget-feed") -Recurse -Force
}