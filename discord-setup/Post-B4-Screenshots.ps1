# B4 Trading HQ - Screenshot Announcement Loader (uploads REAL product images)
# Publishes branded embeds for B4 Tape, B4 Tape Teaching, and B4 L2 DOM Pro,
# attaching the actual NinjaTrader 8 screenshots from your PC.
#
# PREREQUISITES
#   1) Run Setup-B4-Trading-HQ.ps1 first (creates channels/roles/permissions).
#   2) Save the three screenshots to C:\Users\<you>\b4-images\ with EXACT names:
#        b4-tape-news-sentiment.png
#        b4-tape-teaching.png
#        b4-l2-dom-pro.png
#   3) The bot needs: View Channels, Send Messages, Embed Links, Attach Files
#      in the target channels.
#
# SECURITY: the bot token is read locally at a hidden prompt OR from the
# environment variable B4_BOT_TOKEN. It is never written into this script.
# Compatible with Windows PowerShell 5.1 (manual multipart upload).

$ErrorActionPreference = "Stop"
$BaseUrl = "https://discord.com/api/v10"

# ---- Where the screenshots live and which post each belongs to ----
$ImageFolder = Join-Path $HOME "b4-images"
$Posts = @(
    @{
        Marker  = "B4-SHOT-TAPE-NEWS"
        Channel = "product-updates"
        File    = "b4-tape-news-sentiment.png"
        Color   = 3447003
        Title   = "$([char]::ConvertFromUtf32(0x1F39E))$([char]::ConvertFromUtf32(0xFE0F)) B4 Tape $([char]::ConvertFromUtf32(0x2014)) News & Sentiment"
        Url     = "https://b4signals.com/"
        Desc    = "**Read the order flow as it happens.** B4 Tape for NinjaTrader 8 brings time & sales, a volume-profile ladder, delta/effort-vs-result, and integrated **news & sentiment** (FinBERT) into one view $([char]::ConvertFromUtf32(0x2014)) with event memory (unfinished auction / poor high) and a structured trade-decision readout.`n`n$([char]::ConvertFromUtf32(0x26A1)) Speed, press & spread meters $([char]::ConvertFromUtf32(0xB7)) $([char]::ConvertFromUtf32(0x1F9E0)) Event memory $([char]::ConvertFromUtf32(0xB7)) $([char]::ConvertFromUtf32(0x1F4CA)) Volume at price $([char]::ConvertFromUtf32(0xB7)) $([char]::ConvertFromUtf32(0x1F5E3))$([char]::ConvertFromUtf32(0xFE0F)) Voice/teach modes`n`n*Enhanced visualization based on a NinjaTrader 8 screen (simulation). Not a live trading result.*`n`n$([char]::ConvertFromUtf32(0x26A0))$([char]::ConvertFromUtf32(0xFE0F)) Tools provide context, not certainty. No indicator or system guarantees profits. See #risk-disclosures."
    },
    @{
        Marker  = "B4-SHOT-TAPE-TEACH"
        Channel = "product-updates"
        File    = "b4-tape-teaching.png"
        Color   = 15844367
        Title   = "$([char]::ConvertFromUtf32(0x1F393)) B4 Tape $([char]::ConvertFromUtf32(0x2014)) Teaching Mode"
        Url     = "https://b4signals.com/"
        Desc    = "**Learn to read the tape while you watch it.** B4 Tape Teaching walks through structured lessons $([char]::ConvertFromUtf32(0x2014)) who trades and where, volume profile, Point of Control, Value Area (VAH/VAL), reading a footprint row, size tiers & whales, and tape speed/spikes $([char]::ConvertFromUtf32(0x2014)) alongside the live value-edge-at-POC readout.`n`n$([char]::ConvertFromUtf32(0x1F4DA)) Staged lesson tracks $([char]::ConvertFromUtf32(0xB7)) $([char]::ConvertFromUtf32(0x1F3AF)) Value-edge initiative @ POC $([char]::ConvertFromUtf32(0xB7)) $([char]::ConvertFromUtf32(0x25B6))$([char]::ConvertFromUtf32(0xFE0F)) Play / Pause / Replay`n`n*Enhanced visualization based on a NinjaTrader 8 screen (simulation). Not a live trading result.*`n`n$([char]::ConvertFromUtf32(0x26A0))$([char]::ConvertFromUtf32(0xFE0F)) Educational context only $([char]::ConvertFromUtf32(0x2014)) not individualized advice or a recommendation. See #rules-and-terms and #risk-disclosures."
    },
    @{
        Marker  = "B4-SHOT-DOM-PRO"
        Channel = "product-updates"
        File    = "b4-l2-dom-pro.png"
        Color   = 10181046
        Title   = "$([char]::ConvertFromUtf32(0x1FA9C)) B4 L2 DOM Pro"
        Url     = "https://b4signals.com/"
        Desc    = "**Depth-of-market, reimagined for B4.** The L2 DOM Pro ladder shows bid/ask, pull/stack, volume, and B4 levels (VP POC, VAH, VAL, swing hi/lo, Algo R2, TPO signal) right on the price axis $([char]::ConvertFromUtf32(0x2014)) with full trade management: Move Stop (BE/BE+/Bump), Lock Profit/R, Trail, Stop-to-Level, and a Smart Stop suggestion that only ever tightens risk.`n`n$([char]::ConvertFromUtf32(0x1FA9C)) B4 levels on the ladder $([char]::ConvertFromUtf32(0xB7)) $([char]::ConvertFromUtf32(0x1F6E1))$([char]::ConvertFromUtf32(0xFE0F)) Smart Stop (never adds risk) $([char]::ConvertFromUtf32(0xB7)) $([char]::ConvertFromUtf32(0x1F512)) Lock profit in R $([char]::ConvertFromUtf32(0xB7)) $([char]::ConvertFromUtf32(0x1F3AF)) Stop-to-Level`n`n*Enhanced visualization based on a NinjaTrader 8 screen (simulation). Not a live trading result.*`n`n$([char]::ConvertFromUtf32(0x26A0))$([char]::ConvertFromUtf32(0xFE0F)) Order & risk controls are tools; you remain responsible for every order and setting. See #risk-disclosures."
    }
)

function Read-Required([string]$Prompt) {
    do { $v = (Read-Host $Prompt).Trim(); if (-not $v) { Write-Host "Required." -ForegroundColor Yellow } } while (-not $v)
    return $v
}

function Invoke-DiscordJson {
    param([string]$Method, [string]$Path)
    $uri = "$BaseUrl$Path"
    for ($attempt = 1; $attempt -le 5; $attempt++) {
        try { return Invoke-RestMethod -Method $Method -Uri $uri -Headers $script:Headers }
        catch {
            $resp = $_.Exception.Response
            if ($resp -and [int]$resp.StatusCode -eq 429) {
                $retry = 2; try { $retry = [double]($resp.Headers["Retry-After"]) } catch {}
                Write-Host "Rate limited. Waiting $retry s..." -ForegroundColor Yellow
                Start-Sleep -Seconds ([Math]::Ceiling($retry)); continue
            }
            $d = $_.ErrorDetails.Message; if (-not $d) { $d = $_.Exception.Message }
            throw "Discord API error ($Method $Path): $d"
        }
    }
    throw "Discord API error ($Method $Path): exceeded retries."
}

# Upload a message with one embed + one image attachment via multipart/form-data (PS 5.1 compatible).
function Send-EmbedWithImage {
    param([string]$ChannelId, [string]$FilePath, [string]$FileName, [hashtable]$Embed)

    # The embed references the attachment by name.
    $Embed.image = @{ url = "attachment://$FileName" }
    $payloadJson = @{ embeds = @($Embed); attachments = @(@{ id = 0; filename = $FileName }) } | ConvertTo-Json -Depth 20 -Compress

    $boundary = "----B4Boundary" + [Guid]::NewGuid().ToString("N")
    $LF = "`r`n"
    $fileBytes = [System.IO.File]::ReadAllBytes($FilePath)
    $enc = [System.Text.Encoding]::UTF8

    $pre = "--$boundary$LF" +
           "Content-Disposition: form-data; name=`"payload_json`"$LF" +
           "Content-Type: application/json$LF$LF" +
           "$payloadJson$LF" +
           "--$boundary$LF" +
           "Content-Disposition: form-data; name=`"files[0]`"; filename=`"$FileName`"$LF" +
           "Content-Type: image/png$LF$LF"
    $post = "$LF--$boundary--$LF"

    $ms = New-Object System.IO.MemoryStream
    $preBytes  = $enc.GetBytes($pre)
    $postBytes = $enc.GetBytes($post)
    $ms.Write($preBytes, 0, $preBytes.Length)
    $ms.Write($fileBytes, 0, $fileBytes.Length)
    $ms.Write($postBytes, 0, $postBytes.Length)
    $bodyBytes = $ms.ToArray(); $ms.Dispose()

    $uri = "$BaseUrl/channels/$ChannelId/messages"
    for ($attempt = 1; $attempt -le 5; $attempt++) {
        try {
            return Invoke-RestMethod -Method POST -Uri $uri -Headers $script:Headers `
                   -ContentType "multipart/form-data; boundary=$boundary" -Body $bodyBytes
        }
        catch {
            $resp = $_.Exception.Response
            if ($resp -and [int]$resp.StatusCode -eq 429) {
                $retry = 2; try { $retry = [double]($resp.Headers["Retry-After"]) } catch {}
                Write-Host "Rate limited. Waiting $retry s..." -ForegroundColor Yellow
                Start-Sleep -Seconds ([Math]::Ceiling($retry)); continue
            }
            $d = $_.ErrorDetails.Message; if (-not $d) { $d = $_.Exception.Message }
            throw "Discord upload error (POST /channels/$ChannelId/messages): $d"
        }
    }
    throw "Discord upload error: exceeded retries."
}

Write-Host "`nB4 Trading HQ - Screenshot Announcement Loader" -ForegroundColor Cyan
Write-Host "The bot token stays on this computer. Do not send it to anyone." -ForegroundColor Yellow

# Token from env var if present, else hidden prompt.
if ($env:B4_BOT_TOKEN) {
    $token = $env:B4_BOT_TOKEN
    Write-Host "Using token from environment variable B4_BOT_TOKEN." -ForegroundColor DarkGray
} else {
    $secure = Read-Host "Enter Discord bot token (hidden)" -AsSecureString
    $ptr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
    try { $token = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($ptr) }
    finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($ptr) }
}
if ([string]::IsNullOrWhiteSpace($token)) { throw "Token not supplied." }
$script:Headers = @{ Authorization = "Bot $token"; "User-Agent" = "B4-Trading-HQ-Screenshots/1.0" }

$guildId = Read-Required "Enter B4 Trading HQ Server ID"
$bot = Invoke-DiscordJson GET "/users/@me"
$script:BotId = $bot.id
$guild = Invoke-DiscordJson GET "/guilds/$guildId"
Write-Host "Authenticated bot: $($bot.username)" -ForegroundColor Green
Write-Host "Target server: $($guild.name)" -ForegroundColor Green

# Verify images exist before touching Discord.
Write-Host "`nChecking image folder: $ImageFolder" -ForegroundColor Cyan
$missing = @()
foreach ($p in $Posts) {
    $full = Join-Path $ImageFolder $p.File
    if (Test-Path $full) { Write-Host "  Found: $($p.File)" -ForegroundColor Green }
    else { Write-Host "  MISSING: $($p.File)" -ForegroundColor Red; $missing += $p.File }
}
if ($missing.Count -gt 0) {
    throw "Missing image(s) in $ImageFolder : $($missing -join ', '). Save them with the exact names and re-run."
}

# Map channels.
$channels = Invoke-DiscordJson GET "/guilds/$guildId/channels"
$byName = @{}
foreach ($c in $channels) { if ($c.type -eq 0) { $byName[$c.name] = $c.id } }

Write-Host "`nAbout to publish 3 screenshot embeds to #product-updates." -ForegroundColor Cyan
$go = Read-Required "Type POST to continue"
if ($go -cne "POST") { throw "Stopped. Nothing was posted." }

foreach ($p in $Posts) {
    if (-not $byName.ContainsKey($p.Channel)) {
        Write-Host "Channel #$($p.Channel) not found; skipping $($p.Marker). Run Setup-B4-Trading-HQ.ps1 first." -ForegroundColor Yellow
        continue
    }
    $chId = $byName[$p.Channel]

    # Idempotent: skip if an embed with this marker footer already exists.
    $existing = Invoke-DiscordJson GET "/channels/$chId/messages?limit=50"
    $already = $false
    foreach ($m in $existing) {
        if ($m.author.id -eq $script:BotId) {
            foreach ($e in $m.embeds) {
                if ($e.footer -and $e.footer.text -like "*$($p.Marker)*") { $already = $true; break }
            }
        }
        if ($already) { break }
    }
    if ($already) { Write-Host "$($p.Marker): already posted; skipping." -ForegroundColor DarkGray; continue }

    $embed = @{
        title       = $p.Title
        url         = $p.Url
        description = $p.Desc
        color       = $p.Color
        footer      = @{ text = "B4 Trading HQ | $($p.Marker)" }
    }
    $full = Join-Path $ImageFolder $p.File
    Send-EmbedWithImage -ChannelId $chId -FilePath $full -FileName $p.File -Embed $embed | Out-Null
    Write-Host "Posted $($p.Title) with $($p.File)" -ForegroundColor Green
    Start-Sleep -Milliseconds 600
}

Write-Host "`nScreenshot announcements complete." -ForegroundColor Cyan
Write-Host "Tip: Pin these in #product-updates so new members see the real B4 interfaces first." -ForegroundColor Yellow
