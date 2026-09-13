<#
.SYNOPSIS
  Probe iCloud CalDAV with an Apple ID + app-specific password.

.DESCRIPTION
  Talks to iCloud the same way Home Assistant's CalDAV integration does, with HA out of the loop,
  and reports exactly what HA will see:

    1. Do the credentials work?
    2. Which calendars are visible (these become calendar.* entities)?
    3. Which Reminders lists are visible (these become todo.* entities)?
    4. What's actually in them - do upcoming events and open reminders come through?
    5. (-WriteTest) Does a reminder created over CalDAV appear on the phone? This is the
       Module 4 "done" criterion, tested end to end without HA.

  Nothing is modified unless you pass -WriteTest, and that creates one reminder titled
  "CalDAV probe test - safe to delete" and removes it again after you confirm.

.USAGE
  pwsh -File .\tools\icloud-caldav-probe.ps1
  pwsh -File .\tools\icloud-caldav-probe.ps1 -WriteTest
  pwsh -File .\tools\icloud-caldav-probe.ps1 -AppleId you@icloud.com -Days 14

  The app-specific password is prompted for and never written anywhere. Make one at
  https://account.apple.com -> Sign-In and Security -> App-Specific Passwords. Requires 2FA.
#>
[CmdletBinding()]
param(
  [string]$AppleId,
  [switch]$WriteTest,
  [int]$Days = 7,
  [int]$MaxItems = 15,
  [string]$DiscoveryUrl = 'https://caldav.icloud.com/'
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Net.Http -ErrorAction SilentlyContinue

# ---------------------------------------------------------------------------------------------
# HTTP
# ---------------------------------------------------------------------------------------------

function New-DavClient([string]$User, [string]$Password) {
  $handler = [System.Net.Http.HttpClientHandler]::new()
  $handler.AllowAutoRedirect = $false   # PROPFIND/REPORT must survive redirects; we follow by hand
  $client = [System.Net.Http.HttpClient]::new($handler)
  $client.Timeout = [TimeSpan]::FromSeconds(30)
  $token = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes("$User`:$Password"))
  $client.DefaultRequestHeaders.Authorization =
    [System.Net.Http.Headers.AuthenticationHeaderValue]::new('Basic', $token)
  $client.DefaultRequestHeaders.UserAgent.ParseAdd('icloud-caldav-probe/1.0')
  return $client
}

function Invoke-Dav {
  param(
    [System.Net.Http.HttpClient]$Client,
    [string]$Method,
    [string]$Url,
    [string]$Depth,
    [string]$Body,
    [string]$ContentType = 'application/xml; charset=utf-8',
    [hashtable]$Headers = @{}
  )
  $current = $Url
  for ($hop = 0; $hop -lt 6; $hop++) {
    $req = [System.Net.Http.HttpRequestMessage]::new([System.Net.Http.HttpMethod]::new($Method), $current)
    if ($Depth) { $req.Headers.TryAddWithoutValidation('Depth', $Depth) | Out-Null }
    foreach ($k in $Headers.Keys) { $req.Headers.TryAddWithoutValidation($k, $Headers[$k]) | Out-Null }
    if ($null -ne $Body) {
      $req.Content = [System.Net.Http.StringContent]::new($Body, [Text.Encoding]::UTF8)
      $req.Content.Headers.ContentType = [System.Net.Http.Headers.MediaTypeHeaderValue]::Parse($ContentType)
    }
    $resp = $Client.SendAsync($req).GetAwaiter().GetResult()
    $status = [int]$resp.StatusCode
    if ($status -in 301, 302, 307, 308 -and $resp.Headers.Location) {
      $current = [Uri]::new([Uri]$current, $resp.Headers.Location).AbsoluteUri
      $resp.Dispose()
      continue
    }
    $text = $resp.Content.ReadAsStringAsync().GetAwaiter().GetResult()
    $etag = $null; if ($resp.Headers.ETag) { $etag = $resp.Headers.ETag.Tag }
    $resp.Dispose()
    return [pscustomobject]@{ Status = $status; Body = $text; Url = $current; ETag = $etag }
  }
  throw "Too many redirects starting from $Url"
}

function Get-XmlNodes([string]$Xml, [string]$XPath) {
  if ([string]::IsNullOrWhiteSpace($Xml)) { return @() }
  $doc = [xml]$Xml
  return @($doc.SelectNodes($XPath))
}

# ---------------------------------------------------------------------------------------------
# iCalendar (just enough to read SUMMARY/DTSTART/STATUS out of what iCloud returns)
# ---------------------------------------------------------------------------------------------

function ConvertFrom-Ics([string]$Text) {
  # Unfold continuation lines, then walk components. Returns one object per VEVENT/VTODO with
  # first-seen property values and the set of X- property names present.
  $unfolded = $Text -replace "`r`n[ \t]", '' -replace "`n[ \t]", ''
  $components = New-Object System.Collections.Generic.List[object]
  $stack = New-Object System.Collections.Generic.List[string]
  $current = $null
  foreach ($line in ($unfolded -split "`r?`n")) {
    if ($line -match '^BEGIN:(.+)$') {
      $stack.Add($Matches[1])
      if ($Matches[1] -in 'VEVENT', 'VTODO' -and $null -eq $current) {
        $current = @{ Type = $Matches[1]; Props = @{}; XProps = New-Object System.Collections.Generic.HashSet[string] }
      }
      continue
    }
    if ($line -match '^END:(.+)$') {
      if ($stack.Count) { $stack.RemoveAt($stack.Count - 1) }
      if ($Matches[1] -in 'VEVENT', 'VTODO' -and $null -ne $current -and $current.Type -eq $Matches[1]) {
        $components.Add([pscustomobject]$current); $current = $null
      }
      continue
    }
    if ($null -eq $current) { continue }
    if ($stack[-1] -ne $current.Type) { continue }   # skip VALARM etc. nested inside
    $idx = $line.IndexOf(':'); if ($idx -lt 1) { continue }
    $nameAndParams = $line.Substring(0, $idx); $value = $line.Substring($idx + 1)
    $name = ($nameAndParams -split ';')[0].ToUpperInvariant()
    if ($name -like 'X-*') { $current.XProps.Add($name) | Out-Null }
    if (-not $current.Props.ContainsKey($name)) {
      $current.Props[$name] = $value -replace '\\n', ' ' -replace '\\,', ',' -replace '\\;', ';' -replace '\\\\', '\'
    }
  }
  return $components
}

function Format-IcsDate([string]$Value) {
  if (-not $Value) { return '' }
  if ($Value -match '^(\d{4})(\d{2})(\d{2})T(\d{2})(\d{2})') { return "$($Matches[1])-$($Matches[2])-$($Matches[3]) $($Matches[4]):$($Matches[5])" }
  if ($Value -match '^(\d{4})(\d{2})(\d{2})$') { return "$($Matches[1])-$($Matches[2])-$($Matches[3]) (all day)" }
  return $Value
}

# ---------------------------------------------------------------------------------------------
# CalDAV steps
# ---------------------------------------------------------------------------------------------

function Get-Principal($Client, [string]$Root) {
  $body = '<d:propfind xmlns:d="DAV:"><d:prop><d:current-user-principal/></d:prop></d:propfind>'
  $r = Invoke-Dav -Client $Client -Method PROPFIND -Url $Root -Depth 0 -Body $body
  switch ($r.Status) {
    401 { throw "401 Unauthorized from $($r.Url). The Apple ID or app-specific password is wrong, or the password was revoked. Regenerate one at account.apple.com and try again." }
    403 { throw "403 Forbidden from $($r.Url). iCloud accepted the login but refused CalDAV. Check whether Advanced Data Protection or a Managed Apple ID is in play." }
    207 { }
    default { throw "Unexpected HTTP $($r.Status) from $($r.Url):`n$($r.Body)" }
  }
  $href = (Get-XmlNodes $r.Body "//*[local-name()='current-user-principal']/*[local-name()='href']" | Select-Object -First 1).InnerText
  if (-not $href) { throw "Login worked but iCloud returned no current-user-principal. Body:`n$($r.Body)" }
  return [Uri]::new([Uri]$r.Url, $href).AbsoluteUri
}

function Get-CalendarHome($Client, [string]$Principal) {
  $body = '<d:propfind xmlns:d="DAV:" xmlns:c="urn:ietf:params:xml:ns:caldav"><d:prop><c:calendar-home-set/><d:displayname/></d:prop></d:propfind>'
  $r = Invoke-Dav -Client $Client -Method PROPFIND -Url $Principal -Depth 0 -Body $body
  if ($r.Status -ne 207) { throw "HTTP $($r.Status) reading principal $Principal`n$($r.Body)" }
  $href = (Get-XmlNodes $r.Body "//*[local-name()='calendar-home-set']/*[local-name()='href']" | Select-Object -First 1).InnerText
  if (-not $href) { throw "No calendar-home-set on principal. Body:`n$($r.Body)" }
  return [Uri]::new([Uri]$r.Url, $href).AbsoluteUri
}

function Get-Collections($Client, [string]$HomeUrl) {
  $body = @'
<d:propfind xmlns:d="DAV:" xmlns:c="urn:ietf:params:xml:ns:caldav" xmlns:cs="http://calendarserver.org/ns/" xmlns:ic="http://apple.com/ns/ical/">
  <d:prop>
    <d:displayname/><d:resourcetype/><c:supported-calendar-component-set/>
    <d:current-user-privilege-set/><ic:calendar-color/><cs:getctag/>
  </d:prop>
</d:propfind>
'@
  $r = Invoke-Dav -Client $Client -Method PROPFIND -Url $HomeUrl -Depth 1 -Body $body
  if ($r.Status -ne 207) { throw "HTTP $($r.Status) listing $HomeUrl`n$($r.Body)" }
  $homePath = ([Uri]$r.Url).AbsolutePath.TrimEnd('/')
  $out = New-Object System.Collections.Generic.List[object]
  foreach ($resp in (Get-XmlNodes $r.Body "//*[local-name()='multistatus']/*[local-name()='response']")) {
    $href = $resp.SelectSingleNode("*[local-name()='href']").InnerText
    if ($href.TrimEnd('/') -eq $homePath) { continue }
    $isCal = $null -ne $resp.SelectSingleNode(".//*[local-name()='resourcetype']/*[local-name()='calendar']")
    if (-not $isCal) { continue }   # inbox, outbox, notification, etc.
    $nameNode = $resp.SelectSingleNode(".//*[local-name()='displayname']")
    $name = if ($nameNode) { $nameNode.InnerText } else { '' }
    $comps = @($resp.SelectNodes(".//*[local-name()='supported-calendar-component-set']/*[local-name()='comp']") | ForEach-Object { $_.GetAttribute('name') })
    $privs = @($resp.SelectNodes(".//*[local-name()='current-user-privilege-set']/*[local-name()='privilege']/*") | ForEach-Object { $_.LocalName })
    $kind = if ($comps -contains 'VTODO' -and $comps -notcontains 'VEVENT') { 'Reminders list' }
            elseif ($comps -contains 'VEVENT' -and $comps -notcontains 'VTODO') { 'Calendar' }
            elseif ($comps.Count -eq 0) { 'Unknown (no component set)' }
            else { 'Mixed (' + ($comps -join '+') + ')' }
    $out.Add([pscustomobject]@{
      Name     = if ($name) { $name } else { '(unnamed)' }
      Kind     = $kind
      Writable = if ($privs -contains 'write' -or $privs -contains 'write-content' -or $privs -contains 'all') { 'yes' } else { 'read-only' }
      Url      = [Uri]::new([Uri]$r.Url, $href).AbsoluteUri
      Comps    = $comps
    })
  }
  return $out
}

function Get-Events($Client, [string]$CalUrl, [datetime]$From, [datetime]$To) {
  $s = $From.ToUniversalTime().ToString('yyyyMMddTHHmmssZ'); $e = $To.ToUniversalTime().ToString('yyyyMMddTHHmmssZ')
  $body = @"
<c:calendar-query xmlns:d="DAV:" xmlns:c="urn:ietf:params:xml:ns:caldav">
  <d:prop><c:calendar-data/></d:prop>
  <c:filter><c:comp-filter name="VCALENDAR"><c:comp-filter name="VEVENT"><c:time-range start="$s" end="$e"/></c:comp-filter></c:comp-filter></c:filter>
</c:calendar-query>
"@
  $r = Invoke-Dav -Client $Client -Method REPORT -Url $CalUrl -Depth 1 -Body $body
  if ($r.Status -ne 207) { return @{ Error = "HTTP $($r.Status)"; Items = @() } }
  $items = foreach ($n in (Get-XmlNodes $r.Body "//*[local-name()='calendar-data']")) { ConvertFrom-Ics $n.InnerText | Select-Object -First 1 }
  return @{ Error = $null; Items = @($items) }
}

function Get-Todos($Client, [string]$ListUrl) {
  $body = @'
<c:calendar-query xmlns:d="DAV:" xmlns:c="urn:ietf:params:xml:ns:caldav">
  <d:prop><c:calendar-data/></d:prop>
  <c:filter><c:comp-filter name="VCALENDAR"><c:comp-filter name="VTODO"/></c:comp-filter></c:filter>
</c:calendar-query>
'@
  $r = Invoke-Dav -Client $Client -Method REPORT -Url $ListUrl -Depth 1 -Body $body
  if ($r.Status -ne 207) { return @{ Error = "HTTP $($r.Status)"; Items = @() } }
  $items = foreach ($n in (Get-XmlNodes $r.Body "//*[local-name()='calendar-data']")) { ConvertFrom-Ics $n.InnerText }
  return @{ Error = $null; Items = @($items) }
}

function Invoke-WriteTest($Client, $List) {
  $uid = [guid]::NewGuid().ToString().ToUpperInvariant()
  $now = (Get-Date).ToUniversalTime().ToString('yyyyMMddTHHmmssZ')
  $ics = @(
    'BEGIN:VCALENDAR', 'VERSION:2.0', 'PRODID:-//LaytonFamilyCommandCenter//caldav-probe//EN',
    'BEGIN:VTODO', "UID:$uid", "DTSTAMP:$now", "CREATED:$now", "LAST-MODIFIED:$now",
    'SUMMARY:CalDAV probe test - safe to delete', 'STATUS:NEEDS-ACTION',
    'END:VTODO', 'END:VCALENDAR', ''
  ) -join "`r`n"
  $url = $List.Url.TrimEnd('/') + "/$uid.ics"
  Write-Host "`nPUT $url" -ForegroundColor DarkGray
  $put = Invoke-Dav -Client $Client -Method PUT -Url $url -Body $ics -ContentType 'text/calendar; charset=utf-8' -Headers @{ 'If-None-Match' = '*' }
  if ($put.Status -notin 200, 201, 204) {
    Write-Host "  WRITE FAILED: HTTP $($put.Status)" -ForegroundColor Red
    if ($put.Body) { Write-Host $put.Body -ForegroundColor DarkGray }
    return
  }
  Write-Host "  Created (HTTP $($put.Status))." -ForegroundColor Green
  Write-Host "`n  >>> Open Reminders on a phone and look in '$($List.Name)' for:" -ForegroundColor Yellow
  Write-Host "      'CalDAV probe test - safe to delete'" -ForegroundColor Yellow
  Write-Host "      It should be there within seconds. That is the whole Module 4 round-trip." -ForegroundColor Yellow
  Read-Host "`n  Press Enter to delete it again (Ctrl+C to keep it)" | Out-Null
  $del = Invoke-Dav -Client $Client -Method DELETE -Url $url
  if ($del.Status -in 200, 204) { Write-Host "  Deleted (HTTP $($del.Status)). Confirm it vanished from the phone." -ForegroundColor Green }
  else { Write-Host "  DELETE returned HTTP $($del.Status) - delete it by hand on the phone." -ForegroundColor Red }
}

# ---------------------------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------------------------

function Main {
  if (-not $AppleId) { $AppleId = Read-Host 'Apple ID (email)' }
  $plain = $env:ICLOUD_APP_PASSWORD   # non-interactive escape hatch only; prefer the prompt
  if (-not $plain) {
    $secure = Read-Host 'App-specific password (xxxx-xxxx-xxxx-xxxx)' -AsSecureString
    $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
    try { $plain = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr) }
    finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr) }
  }
  $client = New-DavClient -User $AppleId -Password $plain
  $plain = $null
  try {
    Write-Host "`n[1/5] Login + principal discovery via $DiscoveryUrl" -ForegroundColor Cyan
    $principal = Get-Principal $client $DiscoveryUrl
    Write-Host "  OK  principal: $principal" -ForegroundColor Green

    Write-Host "`n[2/5] Calendar home" -ForegroundColor Cyan
    $homeUrl = Get-CalendarHome $client $principal
    Write-Host "  OK  home: $homeUrl" -ForegroundColor Green
    Write-Host "      (HA will end up talking to $(([Uri]$homeUrl).Host))" -ForegroundColor DarkGray

    Write-Host "`n[3/5] Collections - each of these becomes an HA entity" -ForegroundColor Cyan
    $cols = Get-Collections $client $homeUrl
    if (-not $cols.Count) { Write-Host "  NONE FOUND. Login works but the account exposes no calendars over CalDAV." -ForegroundColor Red; return }
    $cols | Sort-Object Kind, Name | Format-Table Name, Kind, Writable -AutoSize | Out-Host
    $cals = @($cols | Where-Object Comps -contains 'VEVENT')
    $lists = @($cols | Where-Object Comps -contains 'VTODO')
    Write-Host "  $($cals.Count) calendar(s) -> calendar.* entities;  $($lists.Count) Reminders list(s) -> todo.* entities"
    if (-not $lists.Count) {
      Write-Host "  NO REMINDERS LISTS. Most likely cause: Advanced Data Protection is on for this Apple ID" -ForegroundColor Red
      Write-Host "  (Reminders is end-to-end encrypted under ADP; Calendar is not). Second guess: the lists live on" -ForegroundColor Red
      Write-Host "  someone else's Apple ID and sharing does not cross CalDAV. Re-run with the owner's account." -ForegroundColor Red
    }

    Write-Host "`n[4/5] Contents - next $Days days of events, and open reminders" -ForegroundColor Cyan
    $from = (Get-Date).Date; $to = $from.AddDays($Days)
    foreach ($c in $cals) {
      $res = Get-Events $client $c.Url $from $to
      if ($res.Error) { Write-Host "  $($c.Name): $($res.Error)" -ForegroundColor Red; continue }
      Write-Host "  Calendar '$($c.Name)': $($res.Items.Count) event(s) in range" -ForegroundColor White
      foreach ($ev in ($res.Items | Sort-Object { $_.Props['DTSTART'] } | Select-Object -First $MaxItems)) {
        $flag = if ($ev.Props.ContainsKey('RRULE')) { ' (recurring - shows series start here; HA expands it)' } else { '' }
        Write-Host ("    {0,-18} {1}{2}" -f (Format-IcsDate $ev.Props['DTSTART']), $ev.Props['SUMMARY'], $flag)
      }
    }
    $allX = New-Object System.Collections.Generic.HashSet[string]
    foreach ($l in $lists) {
      $res = Get-Todos $client $l.Url
      if ($res.Error) { Write-Host "  $($l.Name): $($res.Error)" -ForegroundColor Red; continue }
      $open = @($res.Items | Where-Object { $_.Props['STATUS'] -ne 'COMPLETED' })
      $sub = @($res.Items | Where-Object { $_.Props.ContainsKey('RELATED-TO') })
      Write-Host "  Reminders '$($l.Name)': $($res.Items.Count) item(s), $($open.Count) open, $($sub.Count) subtask(s)" -ForegroundColor White
      foreach ($t in ($open | Select-Object -First $MaxItems)) {
        $due = if ($t.Props['DUE']) { 'due ' + (Format-IcsDate $t.Props['DUE']) } else { '' }
        $pfx = if ($t.Props.ContainsKey('RELATED-TO')) { '    - ' } else { '    ' }
        Write-Host ("{0}{1}  {2}" -f $pfx, $t.Props['SUMMARY'], $due)
      }
      foreach ($t in $res.Items) { foreach ($x in $t.XProps) { $allX.Add($x) | Out-Null } }
    }
    if ($allX.Count) {
      Write-Host "`n  Apple-private properties seen on reminders (sections/tags/etc. ride in these, HA ignores them):" -ForegroundColor DarkGray
      Write-Host "  $(($allX | Sort-Object) -join ', ')" -ForegroundColor DarkGray
    }

    Write-Host "`n[5/5] Write test" -ForegroundColor Cyan
    if (-not $WriteTest) { Write-Host "  Skipped. Re-run with -WriteTest to create+delete one reminder and watch it hit the phone."; return }
    $writable = @($lists | Where-Object Writable -eq 'yes')
    if (-not $writable.Count) { Write-Host "  No writable Reminders list to test against." -ForegroundColor Red; return }
    for ($i = 0; $i -lt $writable.Count; $i++) { Write-Host ("  [{0}] {1}" -f ($i + 1), $writable[$i].Name) }
    $pick = Read-Host "  Which list? (1-$($writable.Count), Enter = 1)"
    $idx = 0; if ($pick -match '^\d+$' -and [int]$pick -ge 1 -and [int]$pick -le $writable.Count) { $idx = [int]$pick - 1 }
    Invoke-WriteTest $client $writable[$idx]
  }
  finally { $client.Dispose() }
}

if ($MyInvocation.InvocationName -ne '.') { Main }
