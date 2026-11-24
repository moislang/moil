$ErrorActionPreference = 'Stop'

$Repository = 'moislang/moil'
$Version = $env:MOIL_VERSION
if ([string]::IsNullOrWhiteSpace($Version)) {
    $Release = Invoke-RestMethod -Uri "https://api.github.com/repos/$Repository/releases?per_page=1"
    if ($Release.Count -gt 0) {
        $Version = $Release[0].tag_name -replace '^v', ''
    }
}
if ([string]::IsNullOrWhiteSpace($Version)) {
    throw 'Could not determine the latest Moil release. Set $env:MOIL_VERSION and try again.'
}
$Version = $Version -replace '^v', ''

$Architecture = [System.Runtime.InteropServices.RuntimeInformation]::OSArchitecture.ToString()
$Platform = switch ($Architecture) {
    'X64' { 'windows-x86_64' }
    'Arm64' { 'windows-aarch64' }
    default { throw "No Moil CLI package for Windows $Architecture." }
}

$Archive = "moil-$Version-$Platform.zip"
$BaseUrl = "https://github.com/$Repository/releases/download/v$Version/$Archive"
$TemporaryDirectory = Join-Path ([System.IO.Path]::GetTempPath()) ([guid]::NewGuid().ToString())
$InstallDirectory = if ([string]::IsNullOrWhiteSpace($env:MOIL_INSTALL_DIR)) {
    Join-Path $env:LOCALAPPDATA 'Moislang\bin'
} else {
    $env:MOIL_INSTALL_DIR
}

try {
    New-Item -ItemType Directory -Force -Path $TemporaryDirectory, $InstallDirectory | Out-Null
    $ArchivePath = Join-Path $TemporaryDirectory $Archive
    $ChecksumPath = "$ArchivePath.sha256"
    Invoke-WebRequest -Uri $BaseUrl -OutFile $ArchivePath
    Invoke-WebRequest -Uri "$BaseUrl.sha256" -OutFile $ChecksumPath

    $ExpectedHash = (Get-Content -Raw $ChecksumPath).Trim().Split(' ')[0].ToLowerInvariant()
    $ActualHash = (Get-FileHash -Algorithm SHA256 $ArchivePath).Hash.ToLowerInvariant()
    if ($ActualHash -ne $ExpectedHash) {
        throw "Checksum verification failed for $Archive."
    }

    Expand-Archive -LiteralPath $ArchivePath -DestinationPath $TemporaryDirectory -Force
    Copy-Item -Force (Join-Path $TemporaryDirectory 'moil.exe') (Join-Path $InstallDirectory 'moil.exe')

    $UserPath = [Environment]::GetEnvironmentVariable('Path', 'User')
    $PathEntries = @($UserPath -split ';' | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    if (-not ($PathEntries | Where-Object { $_.TrimEnd('\') -ieq $InstallDirectory.TrimEnd('\') })) {
        $UpdatedPath = (@($PathEntries) + $InstallDirectory) -join ';'
        [Environment]::SetEnvironmentVariable('Path', $UpdatedPath, 'User')
    }
    if (($env:Path -split ';' | Where-Object { $_.TrimEnd('\') -ieq $InstallDirectory.TrimEnd('\') }).Count -eq 0) {
        $env:Path = "$InstallDirectory;$env:Path"
    }
    Write-Host "Installed Moil $Version at $(Join-Path $InstallDirectory 'moil.exe')"
    Write-Host 'Run: moil --version'
} finally {
    Remove-Item -Recurse -Force $TemporaryDirectory -ErrorAction SilentlyContinue
}
