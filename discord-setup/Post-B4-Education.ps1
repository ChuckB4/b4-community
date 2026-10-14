# B4 Trading HQ - Education Promo Loader (PURE ASCII SOURCE - download-safe)
# Posts education-side announcements to the FREE side to promote the ecosystem and drive upgrades:
#   - B4 AMP (free, study at your own pace) - available now
#   - B4 Tape: Your AI Trading Coach - promo/ad with upgrade CTA; coaching features framed as COMING SOON
#
# This file contains NO non-ASCII characters, so it cannot be corrupted by any download/encoding.
# Emoji are built at runtime from Unicode code points via the E() helper below.
#
# Run locally. Token: hidden prompt OR environment variable B4_BOT_TOKEN. Never stored in this file.
# Uses Discord API v10. Idempotent via marker in embed footer. Creates/deletes nothing.

$ErrorActionPreference = "Stop"
$BaseUrl = "https://discord.com/api/v10"

$C_GREEN = 3066993    # free / AMP
$C_GOLD  = 15844367   # paid promo

# Build a string from Unicode code points so the SOURCE stays pure ASCII.
# Usage: E 0x1F4DA  ->  the book emoji. Accepts multiple code points.
function E { param([int[]]$cp) -join ($cp | ForEach-Object { [char]::ConvertFromUtf32($_) }) }

# Named emoji (code points) used in the posts.
$BOOK   = E 0x1F4DA   # books
$FREE   = E 0x1F193   # FREE button
$COMPASS= E 0x1F9ED   # compass
$MIC    = E 0x1F399   # studio microphone
$BRAIN  = E 0x1F9E0   # brain
$CHART  = E 0x1F4C8   # chart increasing
$HAND   = E 0x1F91D   # handshake
$LOCK   = E 0x1F513   # unlocked
$GRAD   = E 0x1F393   # graduation cap
$BULB   = E 0x1F4A1   # light bulb
$WARN   = E 0x26A0    # warning sign
$DASH   = [char]0x2014 # em dash

function Read-Required([string]$Prompt) {
    do { $v = (Read-Host $Prompt).Trim(); if (-not $v) { Write-Host "Required." -ForegroundColor Yellow } } while (-not $v)
    return $v
}

function Invoke-Discord {
    param([string]$Method, [string]$Path, $Body = $null)
    $p = @{ Method = $Method; Uri = "$BaseUrl$Path"; Headers = $script:Headers }
    if ($null -ne $Body) {
        $json = ($Body | ConvertTo-Json -Depth 20 -Compress)
        $p.Body = [System.Text.Encoding]::UTF8.GetBytes($json)
        $p.ContentType = "application/json; charset=utf-8"
    }
    for ($attempt = 1; $attempt -le 5; $attempt++) {
        try { return Invoke-RestMethod @p }
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

function Post-Embed {
    param([string]$ChannelId, [string]$Marker, [string]$Title, [string]$Url,
          [string]$Description, [int]$Color, [array]$Fields = @(), [string]$Content = "")
    $msgs = Invoke-Discord GET "/channels/$ChannelId/messages?limit=50"
    foreach ($m in $msgs) {
        if ($m.author.id -eq $script:BotId) {
            foreach ($e in $m.embeds) {
                if ($e.footer -and $e.footer.text -like "*$Marker*") {
                    Write-Host "  Already posted ($Marker); skipping." -ForegroundColor DarkGray; return
                }
            }
        }
    }
    $embed = @{ title = $Title; description = $Description; color = $Color; footer = @{ text = "B4 Trading HQ | $Marker" } }
    if ($Url) { $embed.url = $Url }
    if ($Fields.Count -gt 0) { $embed.fields = $Fields }
    $payload = @{ embeds = @($embed) }
    if ($Content) { $payload.content = $Content }
    Invoke-Discord POST "/channels/$ChannelId/messages" $payload | Out-Null
    Start-Sleep -Milliseconds 500
    Write-Host "  Posted embed ($Marker)." -ForegroundColor Green
}

Write-Host "`nB4 Trading HQ - Education Promo Loader" -ForegroundColor Cyan
Write-Host "The bot token stays on this computer. Do not send it to anyone." -ForegroundColor Yellow

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
$script:Headers = @{ Authorization = "Bot $token"; "User-Agent" = "B4-Trading-HQ-Education/2.0" }

$guildId = Read-Required "Enter B4 Trading HQ Server ID"
$bot = Invoke-Discord GET "/users/@me"
$script:BotId = $bot.id
$guild = Invoke-Discord GET "/guilds/$guildId"
Write-Host "Authenticated bot: $($bot.username)" -ForegroundColor Green
Write-Host "Target server: $($guild.name)" -ForegroundColor Green

$channels = Invoke-Discord GET "/guilds/$guildId/channels"
$byName = @{}
foreach ($c in $channels) { if ($c.type -eq 0) { $byName[$c.name] = $c.id } }
function Need([string]$name) {
    if (-not $byName.ContainsKey($name)) {
        Write-Host "  Channel #$name not found; skipping. Run Setup-B4-Trading-HQ.ps1 first." -ForegroundColor Yellow
        return $null
    }
    return $byName[$name]
}

$freeChannel = "free-market-education"
Write-Host "`nAbout to post education promos to #$freeChannel." -ForegroundColor Cyan
$go = Read-Required "Type POST to continue"
if ($go -cne "POST") { throw "Stopped. Nothing was posted." }

$c = Need $freeChannel
if ($c) {
    # 1) B4 AMP - free, available now
    $ampFields = @(
        @{ name = "$BOOK Study at your own pace"; value = "Work through B4 trading education on your schedule $DASH no live-session requirement."; inline = $false },
        @{ name = "$COMPASS Foundations covered"; value = "Market structure, volume profile, order flow, and the thinking behind the B4 approach."; inline = $false },
        @{ name = "$FREE Free to the community"; value = "Open to free members. A great starting point before exploring the paid B4 toolkit."; inline = $false }
    )
    $ampDesc = "New to B4 or want to sharpen the fundamentals? **B4 AMP** is our free, self-paced education track $DASH learn the concepts behind the B4 approach whenever it suits you.`n`n$WARN Educational information only $DASH not individualized advice or a recommendation. See #rules-and-terms and #risk-disclosures."
    Post-Embed -ChannelId $c -Marker "B4-EDU-AMP" -Title "$FREE$BOOK B4 AMP - Study at Your Own Pace (Free)" -Url "https://b4signals.com/" -Description $ampDesc -Color $C_GREEN -Fields $ampFields

    # 2) B4 Tape AI Coach - promo on free side, coaching features COMING SOON, upgrade CTA
    $tapeFields = @(
        @{ name = "$MIC Live + Replay coaching"; value = "Designed to coach you in real time and in replay mode $DASH review the session and learn from how it unfolded."; inline = $false },
        @{ name = "$BRAIN Learns YOUR setups"; value = "Built to recognize the setups you actually trade and track how they perform for you."; inline = $false },
        @{ name = "$CHART Win rate and missed opportunities"; value = "Aims to surface your win rate and flag opportunities you missed, so you can see patterns in your own trading."; inline = $false },
        @{ name = "$HAND Mentors your edge"; value = "The goal: help you position yourself around your most successful trades $DASH leaning into what works for you."; inline = $false },
        @{ name = "$LOCK How to get it"; value = "B4 Tape is part of the **paid** B4 toolkit. Free members: this is what is waiting on the paid side $DASH upgrade to unlock when it is ready."; inline = $false }
    )
    $tapeDesc = "B4 Tape isn't just a tool $DASH it's being built to **coach and mentor you**. Live and in replay, it's designed to learn your setups, track your win rate, flag missed opportunities, and help you lean into your most successful trades.`n`n$BULB **Why you'll want it:** most traders lose money repeating the same mistakes. B4 Tape's coaching is designed to show you *your own* edge and help you trade it more consistently.`n`n$LOCK Part of the **paid** B4 toolkit $DASH free members, this is your preview of what's coming. Keep an eye on #announcements for the launch.`n`n$WARN **Coming soon / in development** $DASH no release date promised, and no coaching tool guarantees profitable trades or any win rate. Enhanced visualizations shown elsewhere are NinjaTrader 8 simulations, not live trading results. See #risk-disclosures."
    Post-Embed -ChannelId $c -Marker "B4-EDU-TAPE-COACH" -Title "$GRAD Coming Soon: B4 Tape - Your AI Trading Coach" -Url "https://b4signals.com/" -Description $tapeDesc -Color $C_GOLD -Fields $tapeFields
}

Write-Host "`nEducation promos complete." -ForegroundColor Cyan
Write-Host "Tip: Pin the B4 Tape coach promo in #$freeChannel so free members always see the upgrade path." -ForegroundColor Yellow
