param(
    [Parameter(Mandatory = $true)][string]$Installer,
    [string]$OutputDirectory = (Join-Path $env:TEMP 'Tribes QA João')
)
$ErrorActionPreference = 'Stop'
# Run in a clean Windows test account or VM. Never overwrite an existing player install.
if (Test-Path 'HKCU:\Software\felipealx\TribesOfFire') {
    throw 'Use a clean test account: an existing installation is registered.'
}
$UserData = Join-Path $env:APPDATA 'Godot\app_userdata\Tribes of Fire'
if (Test-Path $UserData) { throw 'Use a clean test account: existing player data was found.' }
$Installer = (Resolve-Path $Installer).Path
$InstallDirectory = Join-Path $OutputDirectory 'Game installed with spaces'
if (Test-Path $InstallDirectory) { throw 'Choose an unused output directory.' }
New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
$Results = New-Object System.Collections.Generic.List[object]
function Check([bool]$Condition, [string]$Name) {
    $Results.Add([pscustomobject]@{ Check = $Name; Result = $(if ($Condition) { 'Passed' } else { 'Failed' }) })
    if (-not $Condition) { throw $Name }
}
try {
    $Process = Start-Process -FilePath $Installer -ArgumentList @('/S', "/D=$InstallDirectory") -Wait -PassThru
    Check ($Process.ExitCode -eq 0) 'Installer exits successfully'
    $Executable = Join-Path $InstallDirectory 'TribesOfFire.exe'
    Check (Test-Path $Executable) 'Game executable installed'
    $Desktop = [Environment]::GetFolderPath('Desktop')
    $ShortcutPath = Join-Path $Desktop 'Tribes of Fire.lnk'
    Check (Test-Path $ShortcutPath) 'Desktop shortcut created by default'
    $Shell = New-Object -ComObject WScript.Shell
    $Shortcut = $Shell.CreateShortcut($ShortcutPath)
    Check ($Shortcut.TargetPath -eq $Executable) 'Shortcut points to the installed game'
    Check ($Shortcut.WorkingDirectory.TrimEnd('\') -eq $InstallDirectory.TrimEnd('\')) 'Shortcut working directory is correct'
    $Programs = [Environment]::GetFolderPath('Programs')
    Check (Test-Path (Join-Path $Programs 'Tribes of Fire\Tribes of Fire.lnk')) 'Start menu shortcut created'
    $WorldDirectory = Join-Path $OutputDirectory 'Persistent world João'
    $Log = Join-Path $OutputDirectory 'game-export.log'
    $Arguments = '--log-file "' + $Log + '" -- --play --save-dir="' + $WorldDirectory + '" --quit-after-seconds=3'
    $Process = Start-Process -FilePath $Executable -WorkingDirectory $InstallDirectory -ArgumentList $Arguments -PassThru
    if (-not $Process.WaitForExit(30000)) { Stop-Process -Id $Process.Id; throw 'Game startup timed out.' }
    Check ($Process.ExitCode -eq 0) 'Exported Windows game starts and exits'
    $Text = Get-Content -LiteralPath $Log -Raw
    Check ($Text.Contains('GAME_READY') -and -not $Text.Contains('SCRIPT ERROR') -and -not $Text.Contains('ERROR:')) 'Resources and main scene initialize without script errors'
    $Snapshots = @(Get-ChildItem -LiteralPath $WorldDirectory -Filter 'world.*.json')
    Check ($Snapshots.Count -gt 0) 'Unicode path with spaces saves a world'
    $Snapshot = $Snapshots[0].FullName
    $Hash = (Get-FileHash -LiteralPath $Snapshot -Algorithm SHA256).Hash
    $Process = Start-Process -FilePath $Installer -ArgumentList @('/S', "/D=$InstallDirectory") -Wait -PassThru
    Check ($Process.ExitCode -eq 0) 'Install over the previous version succeeds'
    Check ((Get-FileHash -LiteralPath $Snapshot -Algorithm SHA256).Hash -eq $Hash) 'Update preserves the saved world'
    New-Item -ItemType Directory -Path $UserData -Force | Out-Null
    $Sentinel = Join-Path $UserData 'qa-preserve.txt'
    'Keep personal data' | Set-Content -LiteralPath $Sentinel
    $Process = Start-Process -FilePath (Join-Path $InstallDirectory 'Uninstall.exe') -ArgumentList '/S' -Wait -PassThru
    $Deadline = (Get-Date).AddSeconds(15)
    while ((Test-Path $Executable) -and (Get-Date) -lt $Deadline) { Start-Sleep -Milliseconds 200 }
    Check (-not (Test-Path $Executable)) 'Uninstaller removes application files'
    Check (-not (Test-Path $ShortcutPath)) 'Uninstaller removes desktop shortcut'
    Check (Test-Path $Sentinel) 'Uninstaller preserves personal data'
    Check ((Get-FileHash -LiteralPath $Snapshot -Algorithm SHA256).Hash -eq $Hash) 'Uninstaller preserves the saved world'
} finally {
    $Results | Export-Csv -NoTypeInformation -Encoding UTF8 -LiteralPath (Join-Path $OutputDirectory 'windows-results.csv')
    [pscustomobject]@{
        System = [Environment]::OSVersion.VersionString
        ExecutedChecks = $Results
        ManualPending = @('Installer language chooser and all six languages', 'Launch through the desktop shortcut without arguments', 'First-run game language selection', 'Character creation and persistence', 'Microphone and speakers', 'Multiplayer with real remote peers', 'Windows 10 and Windows 11 separate machines', 'Target hardware benchmark')
    } | ConvertTo-Json -Depth 5 | Set-Content -Encoding UTF8 -LiteralPath (Join-Path $OutputDirectory 'windows-report.json')
}
