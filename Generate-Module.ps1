if (Test-Path ".\deploy") {
    Remove-Item ".\deploy" -Force -Recurse
}

if (Test-Path ".\src\*.psd1") {
    Remove-Item ".\src\*.psd1" -Force
}

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

Write-Output "Generating manifest"
New-ModuleManifest -Path ".\src\$($moduleName).psd1" -Description $description -Author "Tom Bonner" -CompanyName $company -ModuleVersion $version -RootModule $file.Name -FunctionsToExport $functionsToExport -ProjectUri $project -LicenseUri $license -Tags $tags

$tempNugetRepo = New-Item -ItemType Directory ".\nuget-feed\nuget\v2"
$deployTarget = New-Item -ItemType Directory ".\deploy"

try
{
    Write-Output "Bootstrapping NuGet"
    Get-PackageProvider -Name NuGet -ForceBootstrap | Out-Null
    
    Write-Output "Registering temp repository"    
    Register-PSRepository -Name "temp" -SourceLocation $tempNugetRepo.FullName

    $moduleName = (Get-Item "src").GetFiles("*.psd1").FullName

    Write-Output "Publishing module to temp repository"
    Publish-Module -Name $moduleName -Repository "temp"

    $package = Get-ChildItem -Filter "*.nupkg" -Recurse

    Write-Output "Moving package to output"
    Move-Item -Path $package.FullName -Destination $deployTarget.FullName
}
finally 
{
    Unregister-PSRepository "temp" -ErrorAction SilentlyContinue
    Remove-Item -Path (Get-Item "nuget-feed") -Recurse -Force
}