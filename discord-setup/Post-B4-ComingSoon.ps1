# B4 Trading HQ - "Coming Soon" Hype Loader
# Posts teaser/coming-soon announcements for the integrated B4 system:
#   B4 DOM + B4 Scanner + B4 Tape + B4 Quantum (one connected platform), and the new B4 Indicator Pro.
# Run locally. Never paste your Discord bot token into chat or commit it.
# Uses Discord API v10. Idempotent via per-post markers. Creates/deletes nothing.

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
    $msgs = Invoke-Discord GET "/channels/$ChannelId/messages?limit=50"
    foreach ($m in $msgs) {
        if ($m.author.id -eq $script:BotId -and $m.content -like "*$Marker*") {
            Write-Host "  Already posted ($Marker); skipping." -ForegroundColor DarkGray
            return
        }
    }
    $full = $Content
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

Write-Host "`nB4 Trading HQ - Coming Soon Hype Loader" -ForegroundColor Cyan
Write-Host "The bot token stays on this computer. Do not send it to anyone." -ForegroundColor Yellow

$secure = Read-Host "Enter Discord bot token (hidden)" -AsSecureString
$ptr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
try { $token = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($ptr) }
finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($ptr) }
if ([string]::IsNullOrWhiteSpace($token)) { throw "Token not supplied." }

$script:Headers = @{
    Authorization  = "Bot $token"
    "Content-Type" = "application/json"
    "User-Agent"   = "B4-Trading-HQ-ComingSoon/1.0"
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

Write-Host "`nAbout to post COMING SOON teasers to #announcements, #product-updates, #signals-status." -ForegroundColor Cyan
$go = Read-Required "Type POST to continue"
if ($go -cne "POST") { throw "Stopped. Nothing was posted." }

# -------------------- CONTENT --------------------

$bigReveal = @'
B4-CS-INTEGRATED-REVEAL

@everyone
# 🚀 COMING SOON: The Integrated B4 Trading System

This is the one we've been building toward.

Not four separate tools — **one connected system**, where market depth, order flow, scanning, and advanced analytics talk to each other and feed a single, structured decision process.

## 🔗 Four pillars. One platform.

🪜 **B4 DOM** — a next-generation depth-of-market ladder for reading resting liquidity, order placement, and execution context in real time.

📡 **B4 Scanner** — continuously scans your markets for B4 conditions and setups, so opportunities come to you instead of you hunting across charts.

🎞️ **B4 Tape** — real-time tape / time-and-sales order-flow reading: aggression, speed, and who's in control at the point of trade.

🔮 **B4 Quantum** — our research-grade analytical engine (strategy mining, validation, and risk gating) sitting underneath it all, turning raw market data into structured context.

## ⚡ Why "integrated" is the whole point
The DOM shows you depth. The Tape shows you aggression. The Scanner finds the setup. Quantum frames the context. And **B4 CoPilot Pro & B4 Algo** (both being improved) are built to act on it with configurable, rule-based logic. Together they aim to give you **one coherent read of the market** — not a handful of disconnected windows fighting for your attention.

👀 Sneak peeks will drop in **#product-updates** and **#signals-status**. Turn on notifications for this server so you don't miss them.

⚠️ **Reality check:** these are in active development — no release dates promised, no performance guarantees, and automation never removes risk. Nothing here is a signal, recommendation, or claim of profitability. Please read **#risk-disclosures**.

This is the next generation of B4. Buckle up. 🖤

— Chuck · **B4 Trading Tools**
'@

$domScannerTape = @'
B4-CS-DOM-SCANNER-TAPE

# 🪜📡🎞️ Coming Soon: B4 DOM · Scanner · Tape — Built to Work Together

**🪜 B4 DOM — Depth-of-Market, reimagined**
A fast, readable order-book ladder for following resting liquidity, order placement, and execution context in real time. Designed to pair directly with B4 order-flow context — not to live in isolation.

**📡 B4 Scanner — your setups, found for you**
A multi-market scanner that watches for B4 conditions across your instruments and surfaces what matters. The goal: stop flipping through charts and let the setups come to you — then confirm them with the rest of the B4 toolkit.

**🎞️ B4 Tape — read the order flow as it happens**
Real-time tape / time-and-sales reading focused on aggression, pace, and buying vs. selling pressure right at the point of trade — the context behind the candle.

## 🧩 The integration story
Scanner **finds** → Tape + DOM **confirm the flow and depth** → Quantum **frames the context**. One pipeline, one read of the market.

More detail and previews coming to **#signals-status**.

⚠️ In development. No dates, no guarantees. Not a signal or recommendation. See **#risk-disclosures**.
'@

$quantum = @'
B4-CS-QUANTUM

# 🔮 Coming Soon: B4 Quantum — the engine under the hood

B4 Quantum is the research-grade analytical core being built to power the connected B4 system.

Under development behind the scenes:
🔹 **Strategy mining & concept research** — systematically exploring and screening ideas rather than guessing.
🔹 **Walk-forward validation** — testing concepts across time to pressure-test robustness before anything is trusted.
🔹 **Risk gating & execution readiness** — structured checks that evaluate whether conditions are suitable before an idea graduates toward live use.
🔹 **Market sentiment analysis** — incorporating sentiment signals into the broader context.
🔹 **NinjaTrader 8 integration path** — designed so validated research can connect to the tools you already use.

The vision: a disciplined pipeline from **idea → validation → risk-gated readiness**, feeding the DOM, Scanner, and Tape with structured context.

👀 Follow progress in **#signals-status**.

⚠️ **Important:** B4 Quantum is research and development. It is not a product you can buy today, not a signal service, and makes no claim of accuracy or profitability. Research results and backtests do not guarantee future outcomes. Review **#risk-disclosures**.
'@

$proTeaser = @'
B4-CS-INDICATORPRO-NEXT

# 🛠️⚡ Coming Soon: The Next B4 Indicator Pro

B4 Indicator Pro for NinjaTrader 8 keeps evolving. The next phase is designed to connect tighter with the broader B4 system — so the squeeze intelligence, Trend Cloud confluence, momentum, and signal context you already know can line up with the DOM, Tape, and Scanner.

Already announced and in packaging:
⚡ Squeeze Intelligence · 🦈 Shark Fin Momentum · ☁️ Trend Cloud Confluence
🎯 Original IFT vertical-line signal + 1-2-3 setup · 🔄 New Curl signals · 📍 Six customizable reference zones

What's coming: deeper integration with the connected B4 platform and continued refinement.

🌐 https://b4indicators.com/  ·  Watch **#announcements** and **#b4-indicator-pro** for the drop.

⚠️ No indicator guarantees profitable trades; signals provide context, not certainty. See **#risk-disclosures**.
'@

$copilotAlgoPro = @'
B4-CS-COPILOT-ALGO-PRO

# 🤖⚙️ Being Improved: B4 CoPilot Pro & B4 Algo — the automation layer

The engine finds and frames the setup — and **B4 CoPilot Pro and B4 Algo are getting major improvements** to act on it inside the connected B4 system.

🤖 **B4 CoPilot Pro — being improved**
Our advanced NinjaTrader 8 trade automation and management tool is getting enhanced. The improvements are designed to plug tighter into the integrated platform, so DOM, Tape, Scanner, and Quantum context can inform configurable, rule-based execution and position management.

⚙️ **B4 Algo — being improved**
The B4 Algo analytical framework — evaluating trend conditions, market structure, and potential opportunities — is being upgraded to share context with the rest of the connected B4 toolkit and work more seamlessly across the system.

## 🧩 How it fits
Scanner **finds** → DOM + Tape **confirm** → Quantum **frames** → **CoPilot Pro / ALGO Pro act** on it with configurable, rule-based logic. One connected workflow, from idea to execution.

👀 Progress updates in **#product-updates** and **#signals-status**.

⚠️ In active development — no dates, no guarantees. Automation does not remove risk; you remain responsible for every order and setting. Nothing here is a signal, recommendation, or claim of profitability. See **#risk-disclosures**.
'@

# -------------------- POST --------------------

Write-Host "`n#announcements" -ForegroundColor Cyan
$c = Need "announcements"
if ($c) { Post-ToChannel $c "B4-CS-INTEGRATED-REVEAL" $bigReveal }

Write-Host "#product-updates" -ForegroundColor Cyan
$c = Need "product-updates"
if ($c) {
    Post-ToChannel $c "B4-CS-DOM-SCANNER-TAPE" $domScannerTape
    Post-ToChannel $c "B4-CS-COPILOT-ALGO-PRO" $copilotAlgoPro
    Post-ToChannel $c "B4-CS-INDICATORPRO-NEXT" $proTeaser
}

Write-Host "#signals-status" -ForegroundColor Cyan
$c = Need "signals-status"
if ($c) { Post-ToChannel $c "B4-CS-QUANTUM" $quantum }

Write-Host "`nComing-soon teasers complete." -ForegroundColor Cyan
Write-Host "Tip: Pin the big reveal in #announcements and publish it if the channel is an announcement channel." -ForegroundColor Yellow
