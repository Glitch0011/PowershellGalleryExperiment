# Properties
$moduleName = "Write-Day"
$description = "Writes the day to output"
$company = $null
$functionsToExport = @("Write-Day")
$tags = @("Date", "Write");
$project = "https://github.com/Glitch0011/PowershellGalleryExperiment";
$license = "https://github.com/Glitch0011/PowershellGalleryExperiment/blob/master/LICENSE"

# Generated
$version = "$(Get-Date -Format yy.MM.dd).$($Env:APPVEYOR_BUILD_NUMBER)";
$file = Get-Item -Path ".\src\$($moduleName).*" | Where-Object { $_.Name -match ".*\.(psm1|ps1)" }

New-ModuleManifest -Path ".\src\$($moduleName).psd1" -Description $description -Author "Tom Bonner" -CompanyName $company -ModuleVersion $version -RootModule $file.Name -FunctionsToExport $functionsToExport -ProjectUri $project -LicenseUri $license -Tags $tags

if (Test-Path ".\deploy") {
    Remove-Item ".\deploy" -Force -Recurse
}

$tempNugetRepo = New-Item -ItemType Directory ".\nuget-feed\nuget\v2"
$deployTarget = New-Item -ItemType Directory ".\deploy"

try
{
    Get-PackageProvider -Name NuGet -ForceBootstrap | Out-Null
    
    Register-PSRepository -Name "temp" -SourceLocation $tempNugetRepo.FullName

    $moduleName = (Get-Item "src").GetFiles("*.psd1").FullName

    Publish-Module -Name $moduleName -Repository "temp"

    $package = Get-ChildItem -Filter "*.nupkg" -Recurse

    Move-Item -Path $package.FullName -Destination $deployTarget.FullName
}
finally 
{
    Unregister-PSRepository "temp" -ErrorAction SilentlyContinue
    Remove-Item -Path (Get-Item "nuget-feed") -Recurse -Force
    Remove-Item -Path (Get-Item ".\src\Write-Day.psd1")
}