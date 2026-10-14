# B4 Trading HQ Discord Bootstrap
# Run locally. Never paste your Discord bot token into chat or commit it to source control.
# Uses Discord API v10. Creates roles, categories, channels, and starter policy posts.
# It does NOT connect Kajabi, grant paid roles automatically, publish trading signals,
# or delete existing channels. Paid signal rooms are locked and hidden from @everyone.

$ErrorActionPreference = "Stop"
$BaseUrl = "https://discord.com/api/v10"

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

function Slug([string]$s) { return $s.ToLowerInvariant() }

Write-Host "`nB4 Trading HQ - Discord Bootstrap" -ForegroundColor Cyan
Write-Host "The bot token stays on this computer. Do not send it to anyone." -ForegroundColor Yellow

$secure = Read-Host "Enter Discord bot token (hidden)" -AsSecureString
$ptr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
try { $token = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($ptr) }
finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($ptr) }
if ([string]::IsNullOrWhiteSpace($token)) { throw "Token not supplied." }

$script:Headers = @{
    Authorization  = "Bot $token"
    "User-Agent"   = "B4-Trading-HQ-Bootstrap/1.0"
}

$guildId   = Read-Required "Enter B4 Trading HQ Server ID"
$bot       = Invoke-Discord GET "/users/@me"
$guild     = Invoke-Discord GET "/guilds/$guildId"
$botMember = Invoke-Discord GET "/guilds/$guildId/members/$($bot.id)"
Write-Host "Authenticated bot: $($bot.username)" -ForegroundColor Green
Write-Host "Target server: $($guild.name)" -ForegroundColor Green

if ($guild.name -ne "B4 Trading HQ") {
    Write-Host "Warning: the target server is named '$($guild.name)', not 'B4 Trading HQ'. Verify the Server ID before continuing." -ForegroundColor Yellow
    $confirm = Read-Required "Type CONTINUE to proceed, or anything else to stop"
    if ($confirm -cne "CONTINUE") { throw "Stopped to protect the wrong server." }
}

# Permission bits:
# VIEW_CHANNEL 1024; SEND_MESSAGES 2048; READ_MESSAGE_HISTORY 65536.
# This script only creates roles; it does not assign them or reorder role hierarchy.
$roleSpecs = @(
    @{ name = "B4 Admin";          color = 15105570; hoist = $true; mentionable = $false },
    @{ name = "B4 Moderator";      color = 3447003;  hoist = $true; mentionable = $false },
    @{ name = "B4 Paid Member";    color = 15844367; hoist = $true; mentionable = $false },
    @{ name = "B4 Free Member";    color = 3066993;  hoist = $true; mentionable = $false },
    @{ name = "B4 Funding Member"; color = 10181046; hoist = $true; mentionable = $false },
    @{ name = "B4 Signals Beta";   color = 15158332; hoist = $true; mentionable = $false }
)

$existingRoles = Invoke-Discord GET "/guilds/$guildId/roles"
$roleMap = @{}
foreach ($r in $existingRoles) { $roleMap[$r.name] = $r }
foreach ($spec in $roleSpecs) {
    if ($roleMap.ContainsKey($spec.name)) {
        Write-Host "Role exists: $($spec.name)"
    } else {
        $r = Invoke-Discord POST "/guilds/$guildId/roles" $spec
        $roleMap[$spec.name] = $r
        Write-Host "Created role: $($spec.name)" -ForegroundColor Green
        Start-Sleep -Milliseconds 300
    }
}

$everyoneId    = $guildId
$paidId        = $roleMap["B4 Paid Member"].id
$fundingId     = $roleMap["B4 Funding Member"].id
$signalsBetaId = $roleMap["B4 Signals Beta"].id

$groups = @(
    @{ name = "START HERE"; channels = @(
        @{ name = "welcome";          topic = "Welcome to B4 Trading HQ. Start here and review the rules and risk disclosures."; access = "public" },
        @{ name = "announcements";    topic = "Official B4 Trading HQ and product announcements."; access = "public" },
        @{ name = "rules-and-terms";  topic = "Community rules and terms of use. Read before participating."; access = "public" },
        @{ name = "risk-disclosures"; topic = "Trading risk and educational-use disclosures."; access = "public" },
        @{ name = "server-guide";     topic = "Channel map, roles, and how to participate."; access = "public" },
        @{ name = "introductions";    topic = "Introduce yourself. Do not post private financial or account information."; access = "public" }
    )},
    @{ name = "FREE COMMUNITY"; channels = @(
        @{ name = "free-market-education"; topic = "General market education and scenario analysis; not trade instructions."; access = "public" },
        @{ name = "free-b4-discussion";    topic = "Public B4 product discussion and general questions."; access = "public" },
        @{ name = "free-chart-review";     topic = "Educational chart review. No live trade calls."; access = "public" },
        @{ name = "free-questions";        topic = "General educational Q&A."; access = "public" },
        @{ name = "free-community-chat";   topic = "Respectful community conversation."; access = "public" }
    )},
    @{ name = "B4 SIGNALS & EDUCATION"; channels = @(
        @{ name = "b4-algo";                  topic = "B4 Algo product education and concepts."; access = "paid" },
        @{ name = "copilot-pro";              topic = "B4 CoPilot Pro product discussion and workflows."; access = "paid" },
        @{ name = "footprint-volume-profile"; topic = "Footprint, volume profile, TPO, and auction-context education."; access = "paid" },
        @{ name = "ichimoku-market-structure"; topic = "Ichimoku and market-structure education."; access = "paid" },
        @{ name = "risk-management";          topic = "Position sizing, drawdown control, and process."; access = "paid" },
        @{ name = "trade-journal-review";     topic = "Review completed trades, execution, mistakes, and repeatable strengths."; access = "paid" },
        @{ name = "premium-education";        topic = "Premium member education and resources."; access = "paid" }
    )},
    @{ name = "B4 INDICATORS"; channels = @(
        @{ name = "b4-indicator-pro";          topic = "B4 Indicator Pro: squeeze intelligence, trend confluence, and setup evaluation."; access = "paid" },
        @{ name = "squeeze-and-trend-bands";   topic = "Squeeze conditions, MACD-BB trend bands, and setup context."; access = "paid" },
        @{ name = "divergence-and-confirmation"; topic = "Indicator confirmation and divergence education."; access = "paid" },
        @{ name = "ninjatrader-8";             topic = "NinjaTrader 8 installation, configuration, and platform support."; access = "paid" },
        @{ name = "indicator-support";         topic = "B4 Indicators product support. Never post license keys or credentials."; access = "paid" }
    )},
    @{ name = "B4 FUNDING"; channels = @(
        @{ name = "funding-overview";    topic = "Funding-program information. Verify current official program terms."; access = "funding" },
        @{ name = "evaluation-rules";    topic = "Questions about evaluation rules and restrictions; verify with the official provider."; access = "funding" },
        @{ name = "drawdown-and-risk";   topic = "Drawdown and risk-control education."; access = "funding" },
        @{ name = "payout-questions";    topic = "Funding payout process questions; no payout guarantees."; access = "funding" },
        @{ name = "funding-support";     topic = "Funding-related support and resources."; access = "funding" }
    )},
    @{ name = "FUTURE AUTOMATED SIGNALS - LOCKED"; channels = @(
        @{ name = "signals-status";                   topic = "Future automated signal system status and release notices. Locked until launch."; access = "signals" },
        @{ name = "automated-signals";                topic = "Reserved for future automated signal output. Not active. No signals are currently promised."; access = "signals" },
        @{ name = "signal-history-and-methodology";   topic = "Reserved for documented signal history, methodology, and limitations."; access = "signals" },
        @{ name = "signal-system-alerts";             topic = "Reserved for service status, outages, and delivery alerts."; access = "signals" }
    )},
    @{ name = "PLATFORM SUPPORT & COMMUNITY"; channels = @(
        @{ name = "installation-help";  topic = "Installation and configuration support."; access = "public" },
        @{ name = "bug-reports";        topic = "Reproducible bug reports. Remove tokens, license keys, and personal data."; access = "public" },
        @{ name = "feature-requests";   topic = "Product improvement requests with a clear use case."; access = "public" },
        @{ name = "product-updates";    topic = "Verified release notes and product status."; access = "public" },
        @{ name = "resources";          topic = "Documentation and educational resources."; access = "public" }
    )}
)

$starter = @{
"welcome" = @'
**Welcome to B4 Trading HQ**
B4 Trading HQ brings together B4 Signals, B4 Indicators, and B4 Funding resources.

**Start here**
1. Read **#rules-and-terms**.
2. Review **#risk-disclosures**.
3. Check **#server-guide** and use the appropriate channels.
4. Never share passwords, broker credentials, API secrets, license keys, or private account documents.

Free and paid areas are separated. Paid access and future signal access require verified authorization.
'@
"rules-and-terms" = @'
**B4 TRADING HQ - COMMUNITY RULES & TERMS**

**1. Educational use.** General discussion, software demonstrations, charts, and commentary are educational information, not individualized investment, legal, tax, or financial advice or a recommendation to buy or sell an instrument.

**2. No live-trading room.** Do not use this server for live entry/exit calls, copy trading, or instructions to blindly follow a trade. Future automated-signal access, if released, will be governed by separate product terms and disclosures.

**3. Risk.** Trading stocks, options, futures, forex, and digital assets involves risk. Leverage can magnify losses; futures losses may exceed the initial margin deposited; options can expire worthless. Trade only after independently evaluating suitability and risk.

**4. No guarantees.** No guaranteed profits, risk-free claims, fabricated track records, or misleading testimonials. Backtests and hypothetical results do not guarantee future outcomes.

**5. Lawful conduct.** No market manipulation, pump-and-dump schemes, insider-trading encouragement, or unlawful activity.

**6. Privacy.** No doxxing or posting private information. Never share passwords, API keys, authentication codes, brokerage credentials, account numbers, or license keys.

**7. Promotions.** No unsolicited ads, spam, paid signal selling, or unsolicited direct-message solicitations. Obtain moderator approval before promotion.

**8. Respect and moderation.** No harassment, threats, impersonation, or attempts to evade moderation. Moderators may remove content or restrict access for violations.

**9. Access.** Free, paid, funding, and future signal permissions may differ. Do not share paid content with unauthorized users. Access may be changed when eligibility changes.

**10. Responsibility.** You are responsible for independently verifying information, complying with applicable law and broker/platform terms, and making your own decisions. Participation does not create an advisory or fiduciary relationship.

**11. Updates.** Rules may change. This is a general community policy template, not legal advice. Qualified counsel should review it against the actual services, compensation, products, and jurisdictions.
'@
"risk-disclosures" = @'
**TRADING RISK & REGULATORY DISCLOSURE**

Trading securities, options, futures, forex, digital assets, and leveraged products involves substantial risk. You may lose some or all of your capital. Futures and margin trading can result in losses exceeding initial deposits. Options may expire worthless. Volatility, slippage, liquidity gaps, outages, commissions, delayed data, and execution differences affect results.

B4 community content and tools are general information and education, not individualized investment advice or a recommendation or solicitation to transact. Indicators and automated systems can produce false, late, missing, or conflicting outputs and may behave differently by settings, data feed, market conditions, and implementation.

Past performance, simulations, backtests, and hypothetical results do not guarantee future outcomes. Independently verify data, contract specifications, margin, and order status. Test software in simulation and use appropriate risk controls.

Do not assume B4 or any member is registered as an investment adviser, broker-dealer, CTA, CPO, or other regulated professional. Applicable requirements depend on actual activities, compensation, and jurisdiction. A disclaimer alone does not determine regulatory status.

Future automated signals, if released, may have separate terms, limitations, service-status notices, and risk controls. This server does not promise that signals are available, accurate, profitable, continuous, or suitable for any user.

This template is not legal advice. Obtain qualified legal review before offering paid recommendations, signals, or regulated services.
'@
"server-guide" = @'
**B4 TRADING HQ - SERVER GUIDE**

- **START HERE:** welcome, rules, risk disclosures, and announcements.
- **FREE COMMUNITY:** general education, public B4 discussion, chart review, and questions.
- **B4 SIGNALS & EDUCATION:** paid-member educational resources.
- **B4 INDICATORS:** product-specific indicator and NinjaTrader support.
- **B4 FUNDING:** funding-related resources; always verify current official program terms.
- **FUTURE AUTOMATED SIGNALS:** reserved and locked until the signal system is tested, reviewed, and officially released.
- **PLATFORM SUPPORT:** installation help, bug reports, feature requests, and product updates.

**Chart-review template:** instrument/timeframe, market context, setup hypothesis, invalidation, risk factors, and lesson learned. Do not post live trade calls.
'@
"announcements" = "Official B4 Trading HQ announcements. Beware of impersonators and unsolicited DMs. B4 staff will never need your password, API secret, or authentication code."
"b4-indicator-pro" = "Use this channel for B4 Indicator Pro education, including squeeze conditions, trend-band context, signal interpretation, and 1-2-3 setup discussion. Indicators are contextual tools, not guarantees or absolute top/bottom predictors."
"automated-signals" = "**COMING SOON - NOT ACTIVE**`n`nThis channel is reserved for a future automated-signal system. No live signal service is being offered here at this time. Do not rely on this channel for trade decisions until B4 publishes an official release and applicable terms."
"bug-reports" = "**Bug Report Template**`n`nProduct/version:`nNinjaTrader version:`nOperating system:`nSteps to reproduce:`nExpected behavior:`nActual behavior:`nError text:`n`nRemove tokens, license keys, account identifiers, and private data."
}

# Final go/no-go before touching an existing live server. Nothing is deleted either way.
Write-Host "`nAbout to ADD roles, categories, channels, and starter posts to:" -ForegroundColor Cyan
Write-Host "  Server: $($guild.name)   (ID: $guildId)" -ForegroundColor Cyan
Write-Host "Existing content is NOT deleted. Items that already exist are skipped." -ForegroundColor Green
$go = Read-Required "Type BUILD to continue"
if ($go -cne "BUILD") { throw "Stopped. No changes were made." }

$existingChannels = Invoke-Discord GET "/guilds/$guildId/channels"
$categoryMap = @{}
$channelMap  = @{}
foreach ($c in $existingChannels) {
    if ($c.type -eq 4) { $categoryMap[$c.name] = $c }
    elseif ($c.type -eq 0) { $channelMap[$c.name] = $c }
}
$created = 0
$reused  = 0
$allChannels = @()

foreach ($group in $groups) {
    $catName = Slug $group.name
    if ($categoryMap.ContainsKey($catName)) {
        $cat = $categoryMap[$catName]; $reused++
    } else {
        $cat = Invoke-Discord POST "/guilds/$guildId/channels" @{ name = $catName; type = 4 }
        $categoryMap[$catName] = $cat; $created++
        Start-Sleep -Milliseconds 300
    }
    foreach ($spec in $group.channels) {
        $name = $spec.name
        if ($channelMap.ContainsKey($name)) {
            $ch = $channelMap[$name]
            $ch = Invoke-Discord PATCH "/channels/$($ch.id)" @{ topic = $spec.topic; parent_id = $cat.id }
            $reused++
        } else {
            $ch = Invoke-Discord POST "/guilds/$guildId/channels" @{
                name = $name; type = 0; topic = $spec.topic; parent_id = $cat.id
            }
            $channelMap[$name] = $ch; $created++
            Start-Sleep -Milliseconds 300
        }

        # Lock paid/funding/signal channels from @everyone and grant access to the relevant role.
        if ($spec.access -in @("paid", "funding", "signals")) {
            $overwrites = @()
            $overwrites += @{ id = $everyoneId; type = 0; deny = "1024"; allow = "0" }
            $targetRole = switch ($spec.access) {
                "paid"    { $paidId }
                "funding" { $fundingId }
                "signals" { $signalsBetaId }
            }
            if ($spec.access -eq "signals") {
                # View + read history allowed, posting denied (locked until launch).
                $overwrites += @{ id = $targetRole; type = 0; allow = "67584"; deny = "2048" }
            } else {
                $overwrites += @{ id = $targetRole; type = 0; allow = "67584"; deny = "0" }
            }
            foreach ($ow in $overwrites) {
                try { Invoke-Discord PUT "/channels/$($ch.id)/permissions/$($ow.id)" $ow | Out-Null }
                catch { Write-Host "Permission overwrite failed for #$name. Check Manage Channels and role hierarchy." -ForegroundColor Yellow }
            }
        }
        $allChannels += [PSCustomObject]@{ Name = $name; Id = $ch.id; Category = $catName; Access = $spec.access }
    }
}

foreach ($record in $allChannels) {
    if (-not $starter.ContainsKey($record.Name)) { continue }
    $chId = $record.Id
    $msgs = Invoke-Discord GET "/channels/$chId/messages?limit=50"
    $marker = "B4 TRADING HQ SETUP"
    $found = $false
    foreach ($m in $msgs) {
        if ($m.author.id -eq $bot.id -and $m.content -like "*$marker*") { $found = $true; break }
    }
    if ($found) { Write-Host "Starter post exists in #$($record.Name); skipping."; continue }

    $content = "$marker`n`n" + $starter[$record.Name]
    $chunks = @()
    while ($content.Length -gt 1850) {
        $cut = $content.LastIndexOf("`n", 1850)
        if ($cut -lt 400) { $cut = 1850 }
        $chunks += $content.Substring(0, $cut)
        $content = $content.Substring($cut).TrimStart()
    }
    if ($content.Length -gt 0) { $chunks += $content }
    foreach ($chunk in $chunks) {
        Invoke-Discord POST "/channels/$chId/messages" @{ content = $chunk } | Out-Null
        Start-Sleep -Milliseconds 300
    }
    Write-Host "Posted starter content in #$($record.Name)" -ForegroundColor Green
}

$summary = [ordered]@{
    Server               = $guild.name
    ServerId             = $guildId
    Bot                  = $bot.username
    CreatedItems         = $created
    ReusedOrUpdatedItems = $reused
    PlannedCategories    = $groups.Count
    PlannedChannels      = ($groups | ForEach-Object { $_.channels.Count } | Measure-Object -Sum).Sum
    PaidRole             = "B4 Paid Member"
    FundingRole          = "B4 Funding Member"
    FutureSignalsRole    = "B4 Signals Beta"
    CompletedAt          = (Get-Date).ToString("s")
    Notes                = @(
        "Kajabi membership automation is not connected by this bootstrap.",
        "Assign roles only after verifying member eligibility.",
        "Future automated-signal channels are reserved and restricted; the bot should not post signals until launch approval.",
        "Review permissions and legal terms before inviting members."
    )
}
$summary | ConvertTo-Json -Depth 6 | Set-Content -Encoding UTF8 ".\B4-Trading-HQ-setup-summary.json"
$summary | Format-List
Write-Host "`nSetup complete. See B4-Trading-HQ-setup-summary.json" -ForegroundColor Cyan
Write-Host "Manual checks required: role hierarchy, staff permissions, announcement permissions, paid-role entitlement, and legal review." -ForegroundColor Yellow
