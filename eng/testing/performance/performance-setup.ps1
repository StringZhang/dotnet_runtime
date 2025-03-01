Param(
    [string] $SourceDirectory=$env:BUILD_SOURCESDIRECTORY,
    [string] $CoreRootDirectory,
    [string] $BaselineCoreRootDirectory,
    [string] $Architecture="x64",
    [string] $Framework="net5.0",
    [string] $CompilationMode="Tiered",
    [string] $Repository=$env:BUILD_REPOSITORY_NAME,
    [string] $Branch=$env:BUILD_SOURCEBRANCH,
    [string] $CommitSha=$env:BUILD_SOURCEVERSION,
    [string] $BuildNumber=$env:BUILD_BUILDNUMBER,
    [string] $RunCategories="Libraries Runtime",
    [string] $Csproj="src\benchmarks\micro\MicroBenchmarks.csproj",
    [string] $Kind="micro",
    [switch] $LLVM,
    [switch] $MonoInterpreter,
    [switch] $MonoAOT, 
    [switch] $Internal,
    [switch] $Compare,
    [string] $MonoDotnet="",
    [string] $Configurations="CompilationMode=$CompilationMode RunKind=$Kind",
    [string] $LogicalMachine="",
    [switch] $AndroidMono,
    [switch] $iOSMono,
    [switch] $NoPGO,
    [switch] $DynamicPGO,
    [switch] $FullPGO,
    [switch] $iOSLlvmBuild,
    [string] $MauiVersion
)

$RunFromPerformanceRepo = ($Repository -eq "dotnet/performance") -or ($Repository -eq "dotnet-performance")
$UseCoreRun = ($CoreRootDirectory -ne [string]::Empty)
$UseBaselineCoreRun = ($BaselineCoreRootDirectory -ne [string]::Empty)

$PayloadDirectory = (Join-Path $SourceDirectory "Payload")
$PerformanceDirectory = (Join-Path $PayloadDirectory "performance")
$WorkItemDirectory = (Join-Path $SourceDirectory "workitem")
$ExtraBenchmarkDotNetArguments = "--iterationCount 1 --warmupCount 0 --invocationCount 1 --unrollFactor 1 --strategy ColdStart --stopOnFirstError true"
$Creator = $env:BUILD_DEFINITIONNAME
$PerfLabArguments = ""
$HelixSourcePrefix = "pr"

$Queue = ""

if ($Internal) {
    switch ($LogicalMachine) {
        "perftiger" { $Queue = "Windows.10.Amd64.19H1.Tiger.Perf"  }
        "perfowl" { $Queue = "Windows.10.Amd64.20H2.Owl.Perf"  }
        "perfsurf" { $Queue = "Windows.10.Arm64.Perf.Surf"  }
        "perfpixel4a" { $Queue = "Windows.10.Amd64.Pixel.Perf" }
        "perfampere" { $Queue = "Windows.Server.Arm64.Perf" }
        Default { $Queue = "Windows.10.Amd64.19H1.Tiger.Perf" }
    }
    $PerfLabArguments = "--upload-to-perflab-container"
    $ExtraBenchmarkDotNetArguments = ""
    $Creator = ""
    $HelixSourcePrefix = "official"
}
else {
    $Queue = "Windows.10.Amd64.ClientRS4.DevEx.15.8.Open"
}

if($MonoInterpreter)
{
    $ExtraBenchmarkDotNetArguments = "--category-exclusion-filter NoInterpreter"
}

if($MonoDotnet -ne "")
{
    $Configurations += " LLVM=$LLVM MonoInterpreter=$MonoInterpreter MonoAOT=$MonoAOT"
    if($ExtraBenchmarkDotNetArguments -eq "")
    {
        #FIX ME: We need to block these tests as they don't run on mono for now
        $ExtraBenchmarkDotNetArguments = "--exclusion-filter *Perf_Image* *Perf_NamedPipeStream*"
    }
    else
    {
        #FIX ME: We need to block these tests as they don't run on mono for now
        $ExtraBenchmarkDotNetArguments += " --exclusion-filter *Perf_Image* *Perf_NamedPipeStream*"
    }
}

if($NoPGO)
{
    $Configurations += " PGOType=nopgo"
}
elseif($DynamicPGO)
{
    $Configurations += " PGOType=dynamicpgo"
}
elseif($FullPGO)
{
    $Configurations += " PGOType=fullpgo"
}

if ($iOSMono) {
    $Configurations += " iOSLlvmBuild=$iOSLlvmBuild"
}

# FIX ME: This is a workaround until we get this from the actual pipeline
$CleanedBranchName = "main"
if($Branch.Contains("refs/heads/release"))
{
    $CleanedBranchName = $Branch.replace('refs/heads/', '')
}
$CommonSetupArguments="--channel $CleanedBranchName --queue $Queue --build-number $BuildNumber --build-configs $Configurations --architecture $Architecture"
$SetupArguments = "--repository https://github.com/$Repository --branch $Branch --get-perf-hash --commit-sha $CommitSha $CommonSetupArguments"

if($NoPGO)
{
    $SetupArguments = "$SetupArguments --no-pgo"
}
elseif($DynamicPGO)
{
    $SetupArguments = "$SetupArguments --dynamic-pgo"
}
elseif($FullPGO)
{
    $SetupArguments = "$SetupArguments --full-pgo"
}

if ($RunFromPerformanceRepo) {
    $SetupArguments = "--perf-hash $CommitSha $CommonSetupArguments"
    
    robocopy $SourceDirectory $PerformanceDirectory /E /XD $PayloadDirectory $SourceDirectory\artifacts $SourceDirectory\.git
}
else {
    git clone --branch main --depth 1 --quiet https://github.com/dotnet/performance $PerformanceDirectory
}

if($MonoDotnet -ne "")
{
    $UsingMono = "true"
    $MonoDotnetPath = (Join-Path $PayloadDirectory "dotnet-mono")
    Move-Item -Path $MonoDotnet -Destination $MonoDotnetPath
}

if ($UseCoreRun) {
    $NewCoreRoot = (Join-Path $PayloadDirectory "Core_Root")
    Move-Item -Path $CoreRootDirectory -Destination $NewCoreRoot
}
if ($UseBaselineCoreRun) {
    $NewBaselineCoreRoot = (Join-Path $PayloadDirectory "Baseline_Core_Root")
    Move-Item -Path $BaselineCoreRootDirectory -Destination $NewBaselineCoreRoot
}

if($MauiVersion -ne "")
{
    $SetupArguments = "$SetupArguments --maui-version $MauiVersion"
}

if ($AndroidMono) {
    if(!(Test-Path $WorkItemDirectory))
    {
        mkdir $WorkItemDirectory
    }

    Copy-Item -path "$SourceDirectory\androidHelloWorld\HelloAndroid.apk" $PayloadDirectory -Verbose      
    Copy-Item -path "$SourceDirectory\MauiAndroidDefault.apk" $PayloadDirectory -Verbose
    Copy-Item -path "$SourceDirectory\MauiAndroidPodcast.apk" $PayloadDirectory -Verbose
    $SetupArguments = $SetupArguments -replace $Architecture, 'arm64'
}

if ($iOSMono) {
    if(!(Test-Path $WorkItemDirectory))
    {
        mkdir $WorkItemDirectory
    }
    if($iOSLlvmBuild) {
        Copy-Item -path "$SourceDirectory\iosHelloWorld\llvm" $PayloadDirectory\iosHelloWorld\llvm -Recurse
    } else {
        Copy-Item -path "$SourceDirectory\iosHelloWorld\nollvm" $PayloadDirectory\iosHelloWorld\nollvm -Recurse
        Copy-Item -path "$SourceDirectory\MauiiOSDefaultIPA" $PayloadDirectory\MauiiOSDefaultIPA -Recurse
        Copy-Item -path "$SourceDirectory\MauiMacCatalystDefault\MauiMacCatalystDefault.app" $PayloadDirectory\MauiMacCatalystDefault -Recurse
        Copy-Item -path "$SourceDirectory\MauiiOSPodcastIPA" $PayloadDirectory\MauiiOSPodcastIPA -Recurse
    }

    $SetupArguments = $SetupArguments -replace $Architecture, 'arm64'
}

$DocsDir = (Join-Path $PerformanceDirectory "docs")
robocopy $DocsDir $WorkItemDirectory

# Set variables that we will need to have in future steps
$ci = $true

. "$PSScriptRoot\..\..\common\pipeline-logging-functions.ps1"

# Directories
Write-PipelineSetVariable -Name 'PayloadDirectory' -Value "$PayloadDirectory" -IsMultiJobVariable $false
Write-PipelineSetVariable -Name 'PerformanceDirectory' -Value "$PerformanceDirectory" -IsMultiJobVariable $false
Write-PipelineSetVariable -Name 'WorkItemDirectory' -Value "$WorkItemDirectory" -IsMultiJobVariable $false

# Script Arguments
Write-PipelineSetVariable -Name 'Python' -Value "py -3" -IsMultiJobVariable $false
Write-PipelineSetVariable -Name 'ExtraBenchmarkDotNetArguments' -Value "$ExtraBenchmarkDotNetArguments" -IsMultiJobVariable $false
Write-PipelineSetVariable -Name 'SetupArguments' -Value "$SetupArguments" -IsMultiJobVariable $false
Write-PipelineSetVariable -Name 'PerfLabArguments' -Value "$PerfLabArguments" -IsMultiJobVariable $false
Write-PipelineSetVariable -Name 'BDNCategories' -Value "$RunCategories" -IsMultiJobVariable $false
Write-PipelineSetVariable -Name 'TargetCsproj' -Value "$Csproj" -IsMultiJobVariable $false
Write-PipelineSetVariable -Name 'Kind' -Value "$Kind" -IsMultiJobVariable $false
Write-PipelineSetVariable -Name 'Architecture' -Value "$Architecture" -IsMultiJobVariable $false
Write-PipelineSetVariable -Name 'UseCoreRun' -Value "$UseCoreRun" -IsMultiJobVariable $false
Write-PipelineSetVariable -Name 'UseBaselineCoreRun' -Value "$UseBaselineCoreRun" -IsMultiJobVariable $false
Write-PipelineSetVariable -Name 'RunFromPerfRepo' -Value "$RunFromPerformanceRepo" -IsMultiJobVariable $false
Write-PipelineSetVariable -Name 'Compare' -Value "$Compare" -IsMultiJobVariable $false
Write-PipelineSetVariable -Name 'MonoDotnet' -Value "$UsingMono" -IsMultiJobVariable $false
Write-PipelineSetVariable -Name 'iOSLlvmBuild' -Value "$iOSLlvmBuild" -IsMultiJobVariable $false

# Helix Arguments
Write-PipelineSetVariable -Name 'Creator' -Value "$Creator" -IsMultiJobVariable $false
Write-PipelineSetVariable -Name 'Queue' -Value "$Queue" -IsMultiJobVariable $false
Write-PipelineSetVariable -Name 'HelixSourcePrefix' -Value "$HelixSourcePrefix" -IsMultiJobVariable $false
Write-PipelineSetVariable -Name '_BuildConfig' -Value "$Architecture.$Kind.$Framework" -IsMultiJobVariable $false

exit 0
