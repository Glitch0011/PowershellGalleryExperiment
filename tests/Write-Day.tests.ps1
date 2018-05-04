$targetDirectory = "staging"

if ((Get-ChildItem "src" -ErrorAction SilentlyContinue) -eq $null) { 
    Throw "Could not find .\staging" 
}

$scanFiles = Get-ChildItem -Path $targetDirectory -Recurse -Filter "*.psm1"

Describe "Testing against PSSA rules" {
    $analysis = Invoke-ScriptAnalyzer -Path $targetDirectory

    forEach ($failure in $analysis) {

        It "$($failure.ScriptName)#$($failure.Line) should pass $($failure.RuleName)" {
            $failure.Message | Should Be $null
        }
    }
}