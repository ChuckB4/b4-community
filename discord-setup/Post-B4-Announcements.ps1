# B4 Trading HQ - Announcement Loader
# Posts professional launch/Black Friday announcements into the correct channels.
# Run locally. Never paste your Discord bot token into chat or commit it.
# Uses Discord API v10. Idempotent: each post carries a hidden marker and is skipped if already present.
# Does NOT create channels (run Setup-B4-Trading-HQ.ps1 first) and does NOT delete anything.

$ErrorActionPreference = "Stop"
$BaseUrl = "https://discord.com/api/v10"

function Read-Required([string]$Prompt) {
    do { $v = (Read-Host $Prompt).Trim(); if (-not $v) { Write-Host "Required." -ForegroundColor Yellow } } while (-not $v)
    return $v
}

function Invoke-Discord {
    param([string]$Method, [string]$Path, $Body = $null)
    $p = @{ Method = $Method; Uri = "$BaseUrl$Path"; Headers = $script:Headers }
    if ($null -ne $Body) { $p.Body = ($Body | ConvertTo-Json -Depth 20 -Compress) }
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

function Post-ToChannel {
    param([string]$ChannelId, [string]$Marker, [string]$Content)
    # Skip if a message with this marker already exists (idempotent).
    $msgs = Invoke-Discord GET "/channels/$ChannelId/messages?limit=50"
    foreach ($m in $msgs) {
        if ($m.author.id -eq $script:BotId -and $m.content -like "*$Marker*") {
            Write-Host "  Already posted ($Marker); skipping." -ForegroundColor DarkGray
            return
        }
    }
    $full = $Content
    # Split into <= ~1900 char chunks on newlines to respect Discord's 2000-char limit.
    $chunks = @()
    while ($full.Length -gt 1900) {
        $cut = $full.LastIndexOf("`n", 1900)
        if ($cut -lt 500) { $cut = 1900 }
        $chunks += $full.Substring(0, $cut)
        $full = $full.Substring($cut).TrimStart()
    }
    if ($full.Length -gt 0) { $chunks += $full }
    foreach ($chunk in $chunks) {
        Invoke-Discord POST "/channels/$ChannelId/messages" @{ content = $chunk } | Out-Null
        Start-Sleep -Milliseconds 400
    }
    Write-Host "  Posted ($Marker)." -ForegroundColor Green
}

Write-Host "`nB4 Trading HQ - Announcement Loader" -ForegroundColor Cyan
Write-Host "The bot token stays on this computer. Do not send it to anyone." -ForegroundColor Yellow

$secure = Read-Host "Enter Discord bot token (hidden)" -AsSecureString
$ptr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
try { $token = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($ptr) }
finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($ptr) }
if ([string]::IsNullOrWhiteSpace($token)) { throw "Token not supplied." }

$script:Headers = @{
    Authorization  = "Bot $token"
    "Content-Type" = "application/json"
    "User-Agent"   = "B4-Trading-HQ-Announcer/1.0"
}

$guildId = Read-Required "Enter B4 Trading HQ Server ID"
$bot = Invoke-Discord GET "/users/@me"
$script:BotId = $bot.id
$guild = Invoke-Discord GET "/guilds/$guildId"
Write-Host "Authenticated bot: $($bot.username)" -ForegroundColor Green
Write-Host "Target server: $($guild.name)" -ForegroundColor Green

# Map channel names -> ids
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

Write-Host "`nAbout to post announcements to #announcements, #product-updates, #b4-indicator-pro, #funding-overview." -ForegroundColor Cyan
$go = Read-Required "Type POST to continue"
if ($go -cne "POST") { throw "Stopped. Nothing was posted." }

# -------------------- CONTENT --------------------

$mainAnnouncement = @'
B4-ANN-NEXTCHAPTER

@everyone
# 📢 The Next Chapter of B4 — New Websites, New Tools, New Direction

Hey everyone,

First, thank you for your patience. For those who've been with us through the live room, the AMP classes, and the regular sessions — this is a long-overdue update on where B4 is headed.

Due to health reasons, the daily live room and classes have been discontinued. That doesn't mean the work stopped — it means it changed. The focus has shifted toward **automation, connected analytical tools, and more systematic trade evaluation** — technology you can use in your own workflow instead of depending on a daily live session.

Here's what's been built behind the scenes, across three sites:

**📊 B4 Signals — proprietary trading tools**
https://www.b4signals.com/

**🛠️ B4 Indicators — featuring the new B4 Indicator Pro for NinjaTrader 8**
https://b4indicators.com/

**💰 B4 Funding — more competitive evaluations in the works**
https://b4funding.com/

Full breakdowns are posted in **#product-updates**, **#b4-indicator-pro**, and **#funding-overview**. Take a look, explore the sites, and share your feedback.

A note on expectations: automation does not remove risk, and no indicator guarantees profitable trades. The goal is well-designed tools and disciplined process — more context before a decision, not blind signals. Please review **#risk-disclosures** before using any tool.

This is the next chapter of B4. This is just the beginning.

— Chuck
**B4 Trading Tools · B4 Signals · B4 Funding**
'@

$blackFriday = @'
B4-ANN-BLACKFRIDAY

@everyone
# 🖤 Black Friday is Coming to B4

We're preparing our **Black Friday event** across the B4 ecosystem — timed to line up with the upcoming product releases.

**What to expect:**
🔹 Launch pricing on select B4 Signals tools as they become available
🔹 B4 Indicator Pro for NinjaTrader 8
🔹 Updates on the next phase of B4 Funding evaluations

**Heads up on timing:** B4 Signals products are temporarily unavailable for purchase while releases are finalized and packaged — expected back within the next few days. We're prioritizing getting things done right over rushing them out.

⏰ Watch **#announcements** and **#product-updates** for the official go-live and offer details. Turn on notifications for this server so you don't miss the drop.

No purchase is required to participate in the community. All offers will include their terms at release. See **#rules-and-terms** and **#risk-disclosures**.

— Team B4
'@

$productUpdates = @'
B4-ANN-PRODUCTS

# 📊 B4 Signals — Proprietary Trading Tools
🌐 https://www.b4signals.com/

The B4 ecosystem is being built around a systematic approach to market analysis, signal interpretation, trade execution, and risk management. The vision: move beyond isolated indicators toward a connected environment where compatible tools share context and support structured decisions.

**The toolset includes:**

🔹 **B4 CoPilot Pro** — advanced NinjaTrader 8 trade automation and management designed to work with compatible signals, configurable conditions, and execution rules.

🔹 **B4 Footprint Pro** — order-flow analysis for bid/ask volume, delta, imbalances, and buying/selling pressure at individual price levels.

🔹 **B4 Algo** — a proprietary analytical framework for evaluating trend conditions, market structure, and potential opportunities. *(Being upgraded — releasing soon as B4 Algo Pro.)*

🔹 **B4 Squeeze, B4 KISS, B4 Shoyu, B4 Volume Profile, and more** — resources to help evaluate momentum, consolidation, trend context, volume, and changing conditions.

**📦 Availability update:** B4 Signals products are temporarily unavailable for purchase while releases are packaged and prepared — expected back within the next few days. Watch **#announcements** for the go-live.

⚠️ Automation does not remove risk and no tool guarantees profits. Review **#risk-disclosures** before use.
'@

$indicatorPro = @'
B4-ANN-INDICATORPRO

# 🛠️ Introducing B4 Indicator Pro for NinjaTrader 8
🌐 https://b4indicators.com/

**Squeeze Intelligence. Trend Confluence. Smarter Entries.**

B4 Indicator Pro brings multiple analytical perspectives into one lower chart panel — squeeze intelligence, momentum, trend confluence, and potential reversal conditions. The objective: recognize the setup, evaluate the conditions, and prepare for the move.

⚡ **Squeeze Intelligence** — monitor volatility compression and potential transitions to expansion, with adjustable squeeze-release settings.

🦈 **Shark Fin Momentum** — momentum waves offering another perspective on directional pressure as conditions develop.

☁️ **Trend Cloud Confluence** — evaluate bullish/bearish alignment, watch dark-cloud transitions, and get alerts when a new Trend Cloud appears.

🎯 **Original IFT Vertical-Line Signal + 1-2-3 Setup** — a reference point for a structured entry setup. Important: the IFT vertical-line signal provides **entry context**, not absolute tops/bottoms.

🔄 **New Curl Signals** — information for evaluating potential turning-point conditions (possible swing highs/lows) without claiming to predict exact tops or bottoms.

📍 **Six Customizable Reference Zones** — Overbought, Trail Top, Turbulence Top, Turbulence Bottom, Trail Bottom, Oversold — combined with trading bands, momentum histogram, RSI w/ Inverse Fisher Transform, Fib SuperTrend, squeeze visualization, and Trend Cloud.

**The goal isn't more signals — it's more context before a decision.**

Built exclusively for NinjaTrader 8. The separate B4 Indicator is also on TradingView:
📈 https://www.tradingview.com/script/c2eOT36G-B4Signals-Indicator/

The Pro release is currently being packaged for availability through B4 Signals. Watch **#announcements**.

⚠️ No indicator guarantees profitable trades. See **#risk-disclosures**.
'@

$funding = @'
B4-ANN-FUNDING

# 💰 B4 Funding — Preparing More Competitive Evaluations
🌐 https://b4funding.com/

We're preparing the next phase of B4 Funding. We're currently negotiating terms with our funding partners to bring back **more competitive evaluation offers** — rather than reopen with terms that don't meet our standards, we're working through the details first.

The objective is to give traders better opportunities to pursue funded trading while clearly understanding the **evaluation requirements, drawdown rules, account restrictions, and risk controls** associated with each program.

B4 Funding will reopen once negotiations are settled and the new offers are ready. More details to come as terms are finalized.

⚠️ Funded/evaluation trading involves rules and risk. Always verify current official program terms before participating. See **#risk-disclosures**.
'@

# -------------------- POST --------------------

Write-Host "`n#announcements" -ForegroundColor Cyan
$c = Need "announcements"
if ($c) {
    Post-ToChannel $c "B4-ANN-NEXTCHAPTER" $mainAnnouncement
    Post-ToChannel $c "B4-ANN-BLACKFRIDAY" $blackFriday
}

Write-Host "#product-updates" -ForegroundColor Cyan
$c = Need "product-updates"
if ($c) { Post-ToChannel $c "B4-ANN-PRODUCTS" $productUpdates }

Write-Host "#b4-indicator-pro" -ForegroundColor Cyan
$c = Need "b4-indicator-pro"
if ($c) { Post-ToChannel $c "B4-ANN-INDICATORPRO" $indicatorPro }

Write-Host "#funding-overview" -ForegroundColor Cyan
$c = Need "funding-overview"
if ($c) { Post-ToChannel $c "B4-ANN-FUNDING" $funding }

Write-Host "`nAnnouncements complete." -ForegroundColor Cyan
Write-Host "Tip: in Discord, you can 'Publish' posts in announcement-type channels and Pin the key ones." -ForegroundColor Yellow
