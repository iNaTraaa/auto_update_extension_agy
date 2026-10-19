
$ErrorActionPreference = 'Stop'

$exe = Join-Path $env:USERPROFILE '.gemini\bin\agy.exe'
$manifestUrl = 'https://antigravity-cli-auto-updater-974169037036.us-central1.run.app/manifests/windows_amd64.json'

try {
    Write-Host 'Read current version...'

    if (!(Test-Path $exe)) {
        throw "Not found: $exe"
    }

    $output = (& $exe --version 2>&1 | Out-String)
    Write-Host ('Output: ' + $output.Trim())

    if ($output -notmatch '\d+\.\d+\.\d+') {
        throw 'Unable to read version agy'
    }

    $localVersion = [version]$Matches[0]

    Write-Host 'Get manifest...'
    $m = Invoke-RestMethod -Uri $manifestUrl -TimeoutSec 30

    $remoteVersion = [version]$m.version

    Write-Host ('Current: ' + $localVersion + ' | Newest: ' + $remoteVersion)

    if ($remoteVersion -le $localVersion) {
        Write-Host 'The newest version.' -ForegroundColor Green
    }
    else {
        if (!$m.url -or $m.sha512 -notmatch '^[a-fA-F0-9]{128}$') {
            throw 'Manifest invalid'
        }

        Write-Host 'Downloading new version...'

        $tmp = $exe + '.download'
        $backup = $exe + '.backup'

        Invoke-WebRequest -UseBasicParsing -Uri $m.url -OutFile $tmp -TimeoutSec 300

        Write-Host 'Verify SHA512...'

        $actual = (Get-FileHash $tmp -Algorithm SHA512).Hash

        if ($actual -ine $m.sha512) {
            Remove-Item $tmp -Force -ErrorAction SilentlyContinue
            throw 'SHA512 invalid'
        }

        Write-Host 'SHA512 verified successfully.' -ForegroundColor Green

        if (Test-Path $backup) {
            Remove-Item $backup -Force
        }

        Move-Item $exe $backup

        try {
            Move-Item $tmp $exe -Force
        }
        catch {
            if (Test-Path $backup) {
                Move-Item $backup $exe -Force
            }
            throw
        }

        Write-Host ('Update version successful: ' + $remoteVersion) -ForegroundColor Green
        Write-Host ('Backup: ' + $backup)
    }
}
catch {
    Write-Host ''
    Write-Host ('Err: ' + $_.Exception.Message) -ForegroundColor Red
}
finally {
    Write-Host ''
    Write-Host 'Press any key to exit...'
    try {
        $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
    }
    catch {
        Read-Host 'Press Enter to exit'
    }
}
