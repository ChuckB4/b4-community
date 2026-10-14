# B4 Trading HQ — Discord Setup Kit

A PowerShell bootstrap that builds the **B4 Trading HQ** Discord server structure
(B4 Signals · B4 Indicators · B4 Funding) through the official Discord API.

## What this kit does
- Creates the B4 Trading HQ channel categories and text channels.
- Creates starter roles: B4 Admin, B4 Moderator, B4 Paid Member, B4 Free Member, B4 Funding Member, B4 Signals Beta.
- Publishes starter rules, terms, risk disclosures, server guide, and product-specific messages.
- Restricts paid education, funding, and future signals channels from `@everyone`.
- Keeps the future automated-signal rooms **reserved and locked** — it does not generate or publish signals.
- Does **not** delete existing channels and does **not** automate subscription entitlement.

## Server layout it creates

```
START HERE
  #welcome · #announcements · #rules-and-terms · #risk-disclosures · #server-guide · #introductions

FREE COMMUNITY
  #free-market-education · #free-b4-discussion · #free-chart-review · #free-questions · #free-community-chat

B4 SIGNALS & EDUCATION   (B4 Paid Member)
  #b4-algo · #copilot-pro · #footprint-volume-profile · #ichimoku-market-structure
  #risk-management · #trade-journal-review · #premium-education

B4 INDICATORS            (B4 Paid Member)
  #b4-indicator-pro · #squeeze-and-trend-bands · #divergence-and-confirmation
  #ninjatrader-8 · #indicator-support

B4 FUNDING               (B4 Funding Member)
  #funding-overview · #evaluation-rules · #drawdown-and-risk · #payout-questions · #funding-support

FUTURE AUTOMATED SIGNALS — LOCKED   (B4 Signals Beta, posting denied until launch)
  #signals-status · #automated-signals · #signal-history-and-methodology · #signal-system-alerts

PLATFORM SUPPORT & COMMUNITY
  #installation-help · #bug-reports · #feature-requests · #product-updates · #resources
```

No live-trading / trade-call rooms are created, by design.

## Run it

1. Create a Discord application and bot in the official Discord Developer Portal.
2. Invite the bot to the B4 Trading HQ server with: **Manage Channels, Manage Roles, View Channels, Send Messages, Read Message History** (add Manage Messages if you want to pin posts later). Do not grant Administrator unless you have a separate reason.
3. Enable Developer Mode in Discord: User Settings → Advanced → Developer Mode.
4. Right-click the server icon → Copy Server ID.
5. Open PowerShell in this folder and run the command at the bottom of this file.
6. Enter the bot token at the hidden prompt, then enter the Server ID.

## Important limitations
- Does **not** connect Kajabi/PayPal or automatically grant/revoke paid roles. That requires a separate authenticated membership integration.
- Discord **role hierarchy** matters: the bot's role must be above the roles it manages. This kit creates roles but does not assign them or reorder the bot role.
- On a rerun it reuses matching categories/channels and skips starter posts that already contain the setup marker. It does not remove obsolete channels.
- The legal content is a **general template, not legal advice**. Regulatory obligations depend on actual services, products, compensation, and jurisdictions. Get qualified counsel to review paid educational content and any future automated signal service.

## Token safety
Never send the bot token in chat, email, screenshots, or source control. If it leaks, reset it immediately in the Discord Developer Portal. The token is entered locally at a hidden prompt and is never saved to the script or summary file.

---

Run from this folder:

```powershell
Set-ExecutionPolicy -Scope Process Bypass -Force; .\Setup-B4-Trading-HQ.ps1
```
