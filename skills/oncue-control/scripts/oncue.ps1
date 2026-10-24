# Use OS streams (not PowerShell pipeline records) to preserve JSON and stderr.
# Run in a separate powershell.exe/pwsh process when capturing output in PowerShell.
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
[string[]]$forwardArgs = @($args)

function Test-OnCueExecutable {
  param([AllowEmptyString()][string]$Path)
  # Reject relative and drive-relative paths; never resolve against PATH or CWD.
  return ($Path -match '^(?:[A-Za-z]:[\\/]|\\\\[^\\/]+[\\/][^\\/]+[\\/])' -and
    [System.IO.Path]::GetExtension($Path) -ieq '.exe' -and
    [System.IO.File]::Exists($Path))
}

function Resolve-OnCueExecutable {
  $explicit = [Environment]::GetEnvironmentVariable('ONCUE_BIN')
  if ($null -ne $explicit) {
    if (-not (Test-OnCueExecutable $explicit)) {
      throw 'ONCUE_BIN must name an existing trusted absolute .exe path.'
    }
    return [System.IO.Path]::GetFullPath($explicit)
  }

  $candidates = @()
  foreach ($root in @($env:LOCALAPPDATA, $env:ProgramFiles, ${env:ProgramFiles(x86)})) {
    if (-not [string]::IsNullOrEmpty($root)) {
      $candidates += [System.IO.Path]::Combine($root, 'OnCue', 'oncue.exe')
      $candidates += [System.IO.Path]::Combine($root, 'Programs', 'OnCue', 'oncue.exe')
    }
  }
  foreach ($candidate in $candidates) {
    if (Test-OnCueExecutable $candidate) { return $candidate }
  }

  # Read only installation records, not arbitrary command strings or disk trees.
  foreach ($key in @(
    'HKCU:\Software\Microsoft\Windows\CurrentVersion\App Paths\oncue.exe',
    'HKLM:\Software\Microsoft\Windows\CurrentVersion\App Paths\oncue.exe',
    'HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\App Paths\oncue.exe'
  )) {
    $record = Get-Item -LiteralPath $key -ErrorAction SilentlyContinue
    if ($null -ne $record) {
      $candidate = [string]$record.GetValue('')
      if (Test-OnCueExecutable $candidate) { return $candidate }
    }
  }
  foreach ($root in @(
    'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall',
    'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall',
    'HKCU:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall',
    'HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall'
  )) {
    foreach ($key in @(Get-ChildItem -LiteralPath $root -ErrorAction SilentlyContinue)) {
      $record = Get-ItemProperty -LiteralPath $key.PSPath -ErrorAction SilentlyContinue
      if ($null -eq $record) { continue }
      $name = $record.PSObject.Properties['DisplayName']
      $location = $record.PSObject.Properties['InstallLocation']
      if ($null -ne $name -and $name.Value -ieq 'OnCue' -and $null -ne $location) {
        $candidate = [System.IO.Path]::Combine([string]$location.Value, 'oncue.exe')
        if (Test-OnCueExecutable $candidate) { return $candidate }
      }
    }
  }
  throw 'OnCue was not found in standard installation directories or installation records. Install a CLI-capable App or set ONCUE_BIN to its trusted absolute .exe path; PATH is not searched.'
}

function ConvertTo-OnCueArgument {
  param([AllowEmptyString()][string]$Value)
  # Windows PowerShell 5.1 has no ProcessStartInfo.ArgumentList. Quote one argv
  # element using Windows CRT rules: 2n+1 slashes before quotes, 2n at the end.
  $quoted = New-Object System.Text.StringBuilder
  [void]$quoted.Append('"')
  $slashes = 0
  foreach ($character in $Value.ToCharArray()) {
    if ($character -eq '\') {
      $slashes += 1
      continue
    }
    if ($character -eq '"') {
      [void]$quoted.Append(('\' * (2 * $slashes + 1)))
    } else {
      [void]$quoted.Append(('\' * $slashes))
    }
    [void]$quoted.Append($character)
    $slashes = 0
  }
  [void]$quoted.Append(('\' * (2 * $slashes)))
  [void]$quoted.Append('"')
  return $quoted.ToString()
}

try {
  $binary = Resolve-OnCueExecutable
} catch {
  [Console]::Error.WriteLine('oncue helper: ' + $_.Exception.Message)
  exit 127
}

$process = New-Object System.Diagnostics.Process
$exitCode = 126
try {
  $start = New-Object System.Diagnostics.ProcessStartInfo
  $start.FileName = $binary
  $encodedArgs = @(foreach ($argument in $forwardArgs) { ConvertTo-OnCueArgument $argument })
  $start.Arguments = [string]::Join(' ', [string[]]$encodedArgs)
  $start.UseShellExecute = $false
  $start.CreateNoWindow = $true
  $start.RedirectStandardOutput = $true
  $start.RedirectStandardError = $true
  $process.StartInfo = $start
  [void]$process.Start()
  # Drain both pipes concurrently before waiting, including large diagnostics.
  # Copy bytes so PowerShell's legacy encoding cannot corrupt UTF-8 JSON.
  $stdout = $process.StandardOutput.BaseStream.CopyToAsync([Console]::OpenStandardOutput())
  $stderr = $process.StandardError.BaseStream.CopyToAsync([Console]::OpenStandardError())
  $process.WaitForExit()
  $stdout.GetAwaiter().GetResult()
  $stderr.GetAwaiter().GetResult()
  $exitCode = $process.ExitCode
} catch {
  [Console]::Error.WriteLine('oncue helper: Could not execute or forward OnCue output: ' + $_.Exception.Message)
} finally {
  $process.Dispose()
}
exit $exitCode
