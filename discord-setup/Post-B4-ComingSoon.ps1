# B4 Trading HQ - "Coming Soon" Hype Loader (RICH EMBEDS)
# Posts beautiful embed teasers for the integrated B4 system:
#   B4 DOM + Scanner + Tape + Quantum (one connected platform), CoPilot Pro & B4 Algo Pro, next Indicator Pro.
# Run locally. Never paste your Discord bot token into chat or commit it.
# Uses Discord API v10. Idempotent via per-post markers (hidden in embed footer). Creates/deletes nothing.
#
# ADD YOUR IMAGES: fill in the URLs in the $IMG block below (direct image links ending in
# .png/.jpg/.webp - right-click an image on your site and choose "Copy image address").
# Leave a value as "" to skip that image. Everything still works with no images set.

$ErrorActionPreference = "Stop"
$BaseUrl = "https://discord.com/api/v10"

# ------------------------------------------------------------------
# IMAGE CONFIG - paste direct image URLs here (optional). Example:
#   SignalsBanner = "https://www.b4signals.com/images/hero.png"
# ------------------------------------------------------------------
$IMG = @{
    RevealBanner    = ""   # big integrated-system reveal (announcements)
    DomScannerTape  = ""   # DOM/Scanner/Tape post
    Quantum         = ""   # B4 Quantum post
    CopilotAlgo     = ""   # CoPilot Pro / B4 Algo Pro post
    IndicatorPro    = ""   # next B4 Indicator Pro post
    Logo            = ""   # small logo shown as thumbnail on every embed (optional)
}

# Brand colors (decimal)
$C_PURPLE = 10181046   # quantum / reveal
$C_BLUE   = 3447003    # dom/scanner/tape
$C_GOLD   = 15844367   # copilot/algo
$C_RED    = 15158332   # indicator pro

function Read-Required([string]$Prompt) {
    do { $v = (Read-Host $Prompt).Trim(); if (-not $v) { Write-Host "Required." -ForegroundColor Yellow } } while (-not $v)
    return $v
}

function Invoke-Discord {
    param([string]$Method, [string]$Path, $Body = $null)
    $p = @{ Method = $Method; Uri = "$BaseUrl$Path"; Headers = $script:Headers }
    if ($null -ne $Body) {
        # Encode as UTF-8 bytes so emoji/non-ASCII survive on Windows PowerShell 5.1.
        $json = ($Body | ConvertTo-Json -Depth 20 -Compress)
        $p.Body = [System.Text.Encoding]::UTF8.GetBytes($json)
        $p.ContentType = "application/json; charset=utf-8"
    }
    for ($attempt = 1; $attempt -le 5; $attempt++) {
        try { return Invoke-RestMethod @p }
        catch {
            $resp = $_.Exception.Response
            if ($resp -and [int]$resp.StatusCode -eq 429) {
                $retry = 2
                try { $retry = [double]($resp.Headers["Retry-After"]) } catch {}
                Write-Host "Rate limited. Waiting $retry s..." -ForegroundColor Yellow
                Start-Sleep -Seconds ([Math]::Ceiling($retry))
                continue
            }
            $detail = $_.ErrorDetails.Message
            if (-not $detail) { $detail = $_.Exception.Message }
            throw "Discord API error ($Method $Path): $detail"
        }
    }
    throw "Discord API error ($Method $Path): exceeded retry attempts."
}

# Build and post a rich embed. Idempotent: marker is stored in the embed footer text.
function Post-Embed {
    param(
        [string]$ChannelId,
        [string]$Marker,
        [string]$Title,
        [string]$Url,
        [string]$Description,
        [int]$Color,
        [array]$Fields = @(),
        [string]$Image = "",
        [string]$Content = ""   # optional plain text above the embed (e.g. @everyone)
    )
    # Skip if an embed with this marker footer already exists.
    $msgs = Invoke-Discord GET "/channels/$ChannelId/messages?limit=50"
    foreach ($m in $msgs) {
        if ($m.author.id -eq $script:BotId) {
            foreach ($e in $m.embeds) {
                if ($e.footer -and $e.footer.text -like "*$Marker*") {
                    Write-Host "  Already posted ($Marker); skipping." -ForegroundColor DarkGray
                    return
                }
            }
        }
    }

    $embed = @{
        title       = $Title
        description = $Description
        color       = $Color
        footer      = @{ text = "B4 Trading HQ | $Marker" }
    }
    if ($Url)  { $embed.url = $Url }
    if ($Fields.Count -gt 0) { $embed.fields = $Fields }
    if ($Image) { $embed.image = @{ url = $Image } }
    if ($IMG.Logo) { $embed.thumbnail = @{ url = $IMG.Logo } }

    $payload = @{ embeds = @($embed) }
    if ($Content) { $payload.content = $Content }

    Invoke-Discord POST "/channels/$ChannelId/messages" $payload | Out-Null
    Start-Sleep -Milliseconds 500
    Write-Host "  Posted embed ($Marker)." -ForegroundColor Green
}

Write-Host "`nB4 Trading HQ - Coming Soon Hype Loader (embeds)" -ForegroundColor Cyan
Write-Host "The bot token stays on this computer. Do not send it to anyone." -ForegroundColor Yellow

$secure = Read-Host "Enter Discord bot token (hidden)" -AsSecureString
$ptr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
try { $token = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($ptr) }
finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($ptr) }
if ([string]::IsNullOrWhiteSpace($token)) { throw "Token not supplied." }

$script:Headers = @{
    Authorization = "Bot $token"
    "User-Agent"  = "B4-Trading-HQ-ComingSoon/2.0"
}

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

Write-Host "`nAbout to post COMING SOON embed teasers to #announcements, #product-updates, #signals-status." -ForegroundColor Cyan
$go = Read-Required "Type POST to continue"
if ($go -cne "POST") { throw "Stopped. Nothing was posted." }

# ======================= POSTS =======================

# --- 1) Big integrated reveal (#announcements) ---
$c = Need "announcements"
if ($c) {
    Write-Host "`n#announcements" -ForegroundColor Cyan
    $fields = @(
        @{ name = "🪜 B4 DOM";     value = "Next-gen depth-of-market ladder for reading resting liquidity, order placement, and execution context in real time."; inline = $true },
        @{ name = "📡 B4 Scanner"; value = "Continuously scans your markets for B4 conditions so opportunities come to you."; inline = $true },
        @{ name = "🎞️ B4 Tape";    value = "Real-time tape / time-and-sales order-flow reading: aggression, pace, and who's in control."; inline = $true },
        @{ name = "🔮 B4 Quantum"; value = "Research-grade analytical engine (strategy mining, validation, risk gating) turning raw data into structured context."; inline = $true },
        @{ name = "🤖 Automation"; value = "**B4 CoPilot Pro** (improved) and the new **B4 Algo Pro** act on it with configurable, rule-based logic."; inline = $true },
        @{ name = "⚠️ Reality check"; value = "In active development. No release dates, no performance guarantees. Automation never removes risk. Nothing here is a signal or recommendation. See #risk-disclosures."; inline = $false }
    )
    $desc = "This is the one we've been building toward.`n`nNot separate tools — **one connected system**, where market depth, order flow, scanning, and advanced analytics talk to each other and feed a single, structured decision process.`n`n👀 Sneak peeks will drop in **#product-updates** and **#signals-status**. Turn on notifications so you don't miss them.`n`nThis is the next generation of B4. Buckle up. 🖤 — Chuck"
    Post-Embed -ChannelId $c -Marker "B4-CS-INTEGRATED-REVEAL" -Title "🚀 COMING SOON: The Integrated B4 Trading System" -Url "https://b4signals.com/" -Description $desc -Color $C_PURPLE -Fields $fields -Image $IMG.RevealBanner -Content "@everyone"
}

# --- 2) DOM / Scanner / Tape (#product-updates) ---
$c = Need "product-updates"
if ($c) {
    Write-Host "#product-updates" -ForegroundColor Cyan
    $fields = @(
        @{ name = "🪜 B4 DOM — Depth-of-Market, reimagined"; value = "A fast, readable order-book ladder for following resting liquidity, order placement, and execution context in real time. Built to pair with B4 order-flow context."; inline = $false },
        @{ name = "📡 B4 Scanner — your setups, found for you"; value = "Watches for B4 conditions across your instruments and surfaces what matters. Stop flipping charts — let the setups come to you, then confirm with the B4 toolkit."; inline = $false },
        @{ name = "🎞️ B4 Tape — read the flow as it happens"; value = "Real-time tape / time-and-sales focused on aggression, pace, and buying vs. selling pressure right at the point of trade."; inline = $false },
        @{ name = "🧩 The integration story"; value = "Scanner **finds** → Tape + DOM **confirm** → Quantum **frames** the context. One pipeline, one read of the market."; inline = $false }
    )
    Post-Embed -ChannelId $c -Marker "B4-CS-DOM-SCANNER-TAPE" -Title "🪜📡🎞️ Coming Soon: B4 DOM · Scanner · Tape — Built to Work Together" -Url "https://b4signals.com/" -Description "The connected building blocks of the B4 system — designed to work together, not in isolation.`n`n⚠️ In development. No dates, no guarantees. See #risk-disclosures." -Color $C_BLUE -Fields $fields -Image $IMG.DomScannerTape

    Write-Host "#product-updates (automation)" -ForegroundColor Cyan
    $fields = @(
        @{ name = "🤖 B4 CoPilot Pro — being improved"; value = "Advanced NinjaTrader 8 trade automation & management, enhanced to plug tighter into the integrated platform so DOM, Tape, Scanner, and Quantum context can inform configurable, rule-based execution and position management."; inline = $false },
        @{ name = "⚙️ B4 Algo → releasing as B4 Algo Pro"; value = "The B4 Algo framework (trend conditions, market structure, opportunities) upgraded and relaunching as **B4 Algo Pro**, built to share context across the connected B4 toolkit."; inline = $false },
        @{ name = "🧩 How it fits"; value = "Scanner **finds** → DOM + Tape **confirm** → Quantum **frames** → **CoPilot Pro / B4 Algo Pro act** with configurable, rule-based logic."; inline = $false }
    )
    Post-Embed -ChannelId $c -Marker "B4-CS-COPILOT-ALGO-PRO" -Title "🤖⚙️ The Automation Layer: B4 CoPilot Pro & B4 Algo Pro" -Url "https://b4signals.com/" -Description "The engine finds and frames the setup — the automation layer is getting a major upgrade to act on it inside the connected B4 system.`n`n⚠️ In active development. Automation does not remove risk; you remain responsible for every order and setting. Not a signal or recommendation. See #risk-disclosures." -Color $C_GOLD -Fields $fields -Image $IMG.CopilotAlgo

    Write-Host "#product-updates (indicator pro)" -ForegroundColor Cyan
    Post-Embed -ChannelId $c -Marker "B4-CS-INDICATORPRO-NEXT" -Title "🛠️⚡ Coming Soon: The Next B4 Indicator Pro" -Url "https://b4indicators.com/" -Description "B4 Indicator Pro for NinjaTrader 8 keeps evolving — the next phase connects tighter with the broader B4 system so squeeze intelligence, Trend Cloud confluence, momentum, and signal context line up with the DOM, Tape, and Scanner.`n`n⚡ Squeeze Intelligence · 🦈 Shark Fin Momentum · ☁️ Trend Cloud Confluence`n🎯 IFT vertical-line + 1-2-3 setup · 🔄 Curl signals · 📍 Six customizable reference zones`n`n🌐 https://b4indicators.com/ · Watch **#b4-indicator-pro** for the drop.`n`n⚠️ No indicator guarantees profitable trades; signals provide context, not certainty. See #risk-disclosures." -Color $C_RED -Image $IMG.IndicatorPro
}

# --- 3) Quantum (#signals-status) ---
$c = Need "signals-status"
if ($c) {
    Write-Host "#signals-status" -ForegroundColor Cyan
    $fields = @(
        @{ name = "🔹 Strategy mining & concept research"; value = "Systematically exploring and screening ideas rather than guessing."; inline = $false },
        @{ name = "🔹 Walk-forward validation"; value = "Testing concepts across time to pressure-test robustness before anything is trusted."; inline = $false },
        @{ name = "🔹 Risk gating & execution readiness"; value = "Structured checks on whether conditions are suitable before an idea graduates toward live use."; inline = $false },
        @{ name = "🔹 Market sentiment analysis"; value = "Incorporating sentiment signals into the broader context."; inline = $false },
        @{ name = "🔹 NinjaTrader 8 integration path"; value = "Designed so validated research can connect to the tools you already use."; inline = $false }
    )
    Post-Embed -ChannelId $c -Marker "B4-CS-QUANTUM" -Title "🔮 Coming Soon: B4 Quantum — the engine under the hood" -Url "https://b4signals.com/" -Description "B4 Quantum is the research-grade analytical core being built to power the connected B4 system. The vision: a disciplined pipeline from **idea → validation → risk-gated readiness**, feeding the DOM, Scanner, and Tape with structured context.`n`n⚠️ **Important:** B4 Quantum is research & development — not a product you can buy today, not a signal service, and makes no claim of accuracy or profitability. Research results and backtests do not guarantee future outcomes. See #risk-disclosures." -Color $C_PURPLE -Fields $fields -Image $IMG.Quantum
}

Write-Host "`nComing-soon embeds complete." -ForegroundColor Cyan
Write-Host "Add image URLs in the \$IMG block at the top of this script to show pictures, then re-run after deleting old posts if you want them replaced." -ForegroundColor Yellow
