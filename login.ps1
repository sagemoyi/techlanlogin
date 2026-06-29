<#
Dr.COM / EPortal campus auto-login for Windows.
No Python, Selenium, or browser driver required.
Requires Windows PowerShell 5+ or PowerShell 7+.
#>

$ErrorActionPreference = 'Stop'
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ConfigPath = Join-Path $ScriptDir 'config.ini'
$LogPath = Join-Path $ScriptDir 'login.log'

function Write-Log {
    param([string]$Message, [string]$Level = 'INFO')
    $line = '[{0}] {1}  {2}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Level, $Message
    Add-Content -Path $LogPath -Value $line -Encoding UTF8
    Write-Host $line
}

function Read-Ini {
    param([string]$Path)
    if (-not (Test-Path $Path)) { throw "Config file not found: $Path" }
    $ini = @{}
    $section = ''
    foreach ($raw in Get-Content -Path $Path -Encoding UTF8) {
        $line = $raw.Trim()
        if ($line.Length -eq 0 -or $line.StartsWith('#') -or $line.StartsWith(';')) { continue }
        if ($line -match '^\[(.+)\]$') {
            $section = $Matches[1].Trim()
            if (-not $ini.ContainsKey($section)) { $ini[$section] = @{} }
            continue
        }
        if ($line -match '^([^=]+)=(.*)$') {
            $key = $Matches[1].Trim()
            $value = $Matches[2].Trim()
            if ($section -eq '') {
                $section = 'default'
                if (-not $ini.ContainsKey($section)) { $ini[$section] = @{} }
            }
            $ini[$section][$key] = $value
        }
    }
    return $ini
}

function Get-IniValue {
    param($Ini, [string]$Section, [string]$Key, [string]$Default = '')
    if ($Ini.ContainsKey($Section) -and $Ini[$Section].ContainsKey($Key)) { return [string]$Ini[$Section][$Key] }
    return $Default
}

function UrlEncode {
    param([string]$Value)
    return [System.Uri]::EscapeDataString($Value)
}

function Invoke-TextRequest {
    param([string]$Url, [int]$TimeoutSec = 8)
    $req = [System.Net.HttpWebRequest]::Create($Url)
    $req.Method = 'GET'
    $req.Timeout = $TimeoutSec * 1000
    $req.ReadWriteTimeout = $TimeoutSec * 1000
    $req.UserAgent = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) campus-autologin'
    $resp = $req.GetResponse()
    $reader = $null
    $stream = $null
    try {
        $stream = $resp.GetResponseStream()
        $reader = New-Object System.IO.StreamReader($stream, [System.Text.Encoding]::GetEncoding('GB18030'))
        $body = $reader.ReadToEnd()
        return [pscustomobject]@{ StatusCode = [int]$resp.StatusCode; Body = $body; ContentLength = $body.Length }
    } finally {
        if ($reader) { $reader.Dispose() }
        if ($stream) { $stream.Dispose() }
        $resp.Dispose()
    }
}

function Test-Online {
    param([string]$CheckUrl, [string]$Keyword, [int]$TimeoutSec = 5)
    try {
        $result = Invoke-TextRequest -Url $CheckUrl -TimeoutSec $TimeoutSec
        if ($result.Body -match [regex]::Escape($Keyword)) {
            Write-Log "online_check: OK code=$($result.StatusCode) bytes=$($result.ContentLength) url=$CheckUrl"
            return $true
        }
        Write-Log "online_check: FAIL code=$($result.StatusCode) bytes=$($result.ContentLength) url=$CheckUrl keyword_not_found" 'WARN'
        return $false
    } catch {
        Write-Log "online_check: FAIL url=$CheckUrl err=$($_.Exception.Message)" 'WARN'
        return $false
    }
}

function Extract-SingleQuotedValue {
    param([string]$Text, [string]$Key)
    $pattern = [regex]::Escape($Key) + "='([^']*)'"
    $m = [regex]::Match($Text, $pattern)
    if ($m.Success) { return $m.Groups[1].Value.Trim() }
    return ''
}

function Derive-LoginBase {
    param([string]$PortalPage)
    $uri = [Uri]$PortalPage
    return '{0}://{1}:801/eportal/portal/login' -f $uri.Scheme, $uri.Host
}

try {
    $ini = Read-Ini -Path $ConfigPath
    $portalPage = Get-IniValue $ini 'login' 'url'
    if (-not $portalPage) { $portalPage = Get-IniValue $ini 'login' 'portal_page' }
    $loginBase = Get-IniValue $ini 'login' 'login_base'
    if (-not $loginBase) { $loginBase = Derive-LoginBase -PortalPage $portalPage }
    $username = Get-IniValue $ini 'login' 'username'
    $password = Get-IniValue $ini 'login' 'password'
    $isp = Get-IniValue $ini 'login' 'isp' '@cmcc'
    $accountPrefix = Get-IniValue $ini 'login' 'account_prefix' ',0,'
    $checkUrl = Get-IniValue $ini 'settings' 'check_url' 'http://www.baidu.com'
    $checkKeyword = Get-IniValue $ini 'settings' 'check_keyword' 'baidu'
    $startupDelay = [int](Get-IniValue $ini 'settings' 'startup_delay' '0')
    $retryCount = [int](Get-IniValue $ini 'settings' 'retry_count' '3')
    $retryDelay = [int](Get-IniValue $ini 'settings' 'retry_delay' '5')
    $postLoginWait = [int](Get-IniValue $ini 'settings' 'post_login_wait' '3')

    if (-not $portalPage -or -not $username -or -not $password) { throw 'Missing required config: url/username/password' }

    Write-Log ('=' * 45)
    Write-Log 'Campus auto-login started: Dr.COM JSONP mode, no browser'

    if ($startupDelay -gt 0) {
        Write-Log "Waiting $startupDelay seconds for network adapter..."
        Start-Sleep -Seconds $startupDelay
    }

    if (Test-Online -CheckUrl $checkUrl -Keyword $checkKeyword) {
        Write-Log 'Already online, skip login'
        Write-Log ('=' * 45)
        exit 0
    }

    for ($attempt = 1; $attempt -le $retryCount; $attempt++) {
        Write-Log "Attempt $attempt/$retryCount"
        try {
            $portal = Invoke-TextRequest -Url $portalPage -TimeoutSec 8
            Write-Log "portal_fetch: code=$($portal.StatusCode) bytes=$($portal.ContentLength) page=$portalPage"
            $wlanIp = Extract-SingleQuotedValue -Text $portal.Body -Key 'v46ip'
            if (-not $wlanIp) { $wlanIp = Extract-SingleQuotedValue -Text $portal.Body -Key 'ss5' }
            $wlanMac = Extract-SingleQuotedValue -Text $portal.Body -Key 'ss4'
            if (-not $wlanMac) { $wlanMac = '000000000000' }
            Write-Log "portal_params: wlan_user_ip=$wlanIp, wlan_user_mac=$wlanMac"

            $account = $accountPrefix + $username + $isp
            $parts = New-Object System.Collections.Generic.List[string]
            [void]$parts.Add('callback=dr1003')
            [void]$parts.Add('login_method=1')
            [void]$parts.Add('user_account=' + (UrlEncode $account))
            [void]$parts.Add('user_password=' + (UrlEncode $password))
            [void]$parts.Add('wlan_user_ip=' + (UrlEncode $wlanIp))
            [void]$parts.Add('wlan_user_ipv6=')
            [void]$parts.Add('wlan_user_mac=' + (UrlEncode $wlanMac))
            [void]$parts.Add('wlan_ac_ip=')
            [void]$parts.Add('wlan_ac_name=')
            [void]$parts.Add('jsVersion=4.1.3')
            [void]$parts.Add('terminal_type=1')
            [void]$parts.Add('lang=zh-cn')
            [void]$parts.Add('v=' + (Get-Random -Minimum 1000 -Maximum 9999))
            [void]$parts.Add('lang=zh')
            $query = [string]::Join([string][char]38, $parts.ToArray())
            $loginUrl = $loginBase + '?' + $query
            $login = Invoke-TextRequest -Url $loginUrl -TimeoutSec 10
            Write-Log "login_submit: code=$($login.StatusCode) bytes=$($login.ContentLength) method=GET_JSONP password_logged=no"
            $summary = ($login.Body -replace "`r|`n", ' ')
            if ($summary.Length -gt 240) { $summary = $summary.Substring(0, 240) }
            Write-Log "response_head: $summary"

            Start-Sleep -Seconds $postLoginWait
            if (Test-Online -CheckUrl $checkUrl -Keyword $checkKeyword) {
                Write-Log 'Login success'
                Write-Log ('=' * 45)
                exit 0
            }
            Write-Log 'Login submitted, but online check still failed' 'WARN'
        } catch {
            Write-Log "Attempt $attempt failed: $($_.Exception.Message)" 'ERROR'
        }

        if ($attempt -lt $retryCount) {
            Write-Log "Retry after $retryDelay seconds..."
            Start-Sleep -Seconds $retryDelay
        }
    }

    Write-Log 'All retries failed, check login.log' 'ERROR'
    Write-Log ('=' * 45)
    exit 1
} catch {
    Write-Log "Fatal error: $($_.Exception.Message)" 'ERROR'
    exit 1
}
