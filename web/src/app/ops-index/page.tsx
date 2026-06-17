import Link from "next/link";
import { requireFounder } from "@/lib/auth/requireFounder";

export const metadata = { title: "Ops index — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type OpsLink = { href: string; title: string; desc: string; round: string };

const SECTIONS: { label: string; links: OpsLink[] }[] = [
  {
    label: "Executive",
    links: [
      { href: "/platform-pulse", title: "Platform pulse", desc: "12 KPIs at a glance · executive snapshot", round: "r700★" },
      { href: "/dashboard", title: "Hero dashboard", desc: "Top-line KPIs + today vs yesterday", round: "r597+" },
    ],
  },
  {
    label: "Database health",
    links: [
      { href: "/db-storage", title: "DB storage", desc: "Per-table size · WoW growth", round: "r600+" },
      { href: "/index-health", title: "Index health", desc: "Unused + seq-scan-heavy", round: "r605" },
      { href: "/long-queries", title: "Long-running queries", desc: ">5s queries · idle-in-tx", round: "r604" },
      { href: "/slow-rpcs", title: "Slow RPCs", desc: "pg_stat_statements top 50", round: "r610" },
    ],
  },
  {
    label: "Security & audit",
    links: [
      { href: "/rls-coverage", title: "RLS coverage", desc: "Per-table RLS + grants + risk", round: "r603" },
      { href: "/audit", title: "Founder action log", desc: "Append-only audit ledger", round: "r482+" },
      { href: "/admin-actions-trend", title: "Admin actions trend", desc: "Daily founder_action_log volume", round: "r672" },
      { href: "/admin-top-ops", title: "Admin top ops", desc: "Most-used founder ops · 30d", round: "r673" },
      { href: "/pending-kyc", title: "Pending KYC", desc: "Engineer verification queue", round: "r664" },
      { href: "/open-disputes", title: "Open disputes", desc: "Submitted packs awaiting decision", round: "r665" },
      { href: "/spot-audits-summary", title: "Spot audits", desc: "Invitations · responses · ratings", round: "r682" },
      { href: "/spot-audit-rating-distribution", title: "Spot audit ratings", desc: "Per-rating histogram (180d)", round: "r822" },
      { href: "/integrity-events", title: "Integrity events", desc: "Play Integrity + client self-report audit", round: "r846" },
      { href: "/security-overview", title: "Security overview ★", desc: "Anti-mod layer status + dirty events", round: "r850" },
    ],
  },
  {
    label: "Cash flow & integrations",
    links: [
      { href: "/escrow-aging", title: "Escrow aging", desc: "Live escrow by age × status", round: "r607" },
      { href: "/escrow-balance-rollup", title: "Escrow balance rollup", desc: "Per-status totals + oldest", round: "r650" },
      { href: "/escrow-stuck", title: "Escrow stuck >30d", desc: "Pending/held/dispute aged out", round: "r662" },
      { href: "/escrow-velocity", title: "Escrow velocity", desc: "Created → released p50/p90", round: "r674" },
      { href: "/webhooks", title: "Webhook health", desc: "Razorpay + payouts success", round: "r606" },
      { href: "/payouts", title: "Engineer payouts", desc: "Queue · dead-letter · ops", round: "r428+" },
      { href: "/payout-latency", title: "Payout latency", desc: "Queued → processed time", round: "r624" },
      { href: "/payout-volume-30d", title: "Payout volume 30d", desc: "Per-status rupees", round: "r651" },
      { href: "/payouts-by-day-trend", title: "Payouts by day", desc: "Daily paid + failed (14d)", round: "r686" },
      { href: "/payouts-pending-list", title: "Payouts pending list", desc: "Top 100 pending oldest-first", round: "r837" },
      { href: "/payouts-failed-list", title: "Payouts failed list", desc: "Last 100 failed (30d)", round: "r838" },
      { href: "/payout-fail-reasons", title: "Payout fail reasons", desc: "RazorpayX status distribution", round: "r666" },
      { href: "/engineers-missing-payout", title: "Engineers missing payout", desc: "Earned 30d but no verified VPA · outreach queue", round: "r726" },
      { href: "/payout-method-coverage", title: "Payout method coverage", desc: "% of earning engineers with verified VPA · 7/30/90d", round: "r791" },
      { href: "/refunds", title: "Refunds", desc: "Refund authorizations + history", round: "—" },
      { href: "/commission-revenue-30d", title: "Commission revenue (30d)", desc: "Daily platform take (est)", round: "r663" },
      { href: "/amc-revenue-trend", title: "AMC revenue trend", desc: "Daily AMC paid orders (14d)", round: "r656" },
      { href: "/amc-revenue-by-tier", title: "AMC revenue by tier", desc: "Per-tier MRR + ARR", round: "r688" },
      { href: "/amc-payment-orders-status", title: "AMC payment orders status", desc: "Pending/paid/failed/refunded", round: "r667" },
      { href: "/amc-payment-success-rate", title: "AMC payment success rate", desc: "paid / (paid+failed) 7/30/90d", round: "r714" },
    ],
  },
  {
    label: "Growth & engagement",
    links: [
      { href: "/signups", title: "Signups + active users", desc: "Funnel + DAU/WAU/MAU", round: "r608+" },
      { href: "/weekly-kpis", title: "Weekly KPIs", desc: "WoW snapshot · 7 metrics", round: "r625" },
      { href: "/tiers", title: "Engineer tiers", desc: "Tier distribution + threshold", round: "r550+" },
      { href: "/tier-history", title: "Tier history", desc: "Promotion/demotion ledger", round: "r593+" },
      { href: "/tier-distribution-trend", title: "Tier distribution trend", desc: "Current + 30d delta", round: "r632" },
      { href: "/tier-climbers", title: "Tier climbers", desc: "Non-gold close to promotion", round: "r676" },
      { href: "/demand-signals", title: "Demand signals", desc: "Market intel + priority", round: "r571+" },
      { href: "/demand-signal-status", title: "Demand signal status", desc: "Open by priority + resolved", round: "r677" },
      { href: "/demand-by-brand", title: "Demand by brand", desc: "Top 50 brands by 90d demand", round: "r712" },
      { href: "/demand-by-model", title: "Demand by model", desc: "Top 50 models by 90d demand", round: "r713" },
      { href: "/training", title: "Supervised training", desc: "Pending + active assignments", round: "r576+" },
      { href: "/supervised-active", title: "Supervised active", desc: "Pending + active list", round: "r684" },
      { href: "/supervised-outcomes", title: "Supervised outcomes", desc: "Lifetime status distribution", round: "r685" },
      { href: "/supervision-funnel", title: "Supervision funnel", desc: "Request → success conversion", round: "r623" },
      { href: "/profile-completeness", title: "Profile completeness", desc: "Per-field coverage", round: "r620" },
      { href: "/referral-funnel", title: "Referral funnel", desc: "90d cohort signed → paid", round: "r646" },
      { href: "/referral-volume-trend", title: "Referral volume trend", desc: "Daily referrals/first-jobs", round: "r668" },
      { href: "/referrers-leaderboard", title: "Referrers leaderboard", desc: "Top 50 by first-job conversions", round: "r680" },
      { href: "/retention-cohort", title: "Retention cohort", desc: "Engineer signup-week × active", round: "r647" },
      { href: "/hospital-retention-cohort", title: "Hospital retention cohort", desc: "Hospital signup-week × posted 30d", round: "r836" },
    ],
  },
  {
    label: "Engineers",
    links: [
      { href: "/engineer-utilization", title: "Utilization", desc: "Verified active 7/30/90d", round: "r628" },
      { href: "/engineer-tenure", title: "Tenure", desc: "Verified by signup age", round: "r629" },
      { href: "/engineer-onboarding-funnel", title: "Onboarding funnel", desc: "Signup → first job", round: "r630" },
      { href: "/engineer-referral-coverage", title: "Referral coverage", desc: "% engineers who referred ≥1", round: "r827" },
      { href: "/bidder-engagement", title: "Bidder engagement", desc: "% verified engineers placing ≥1 bid", round: "r832" },
      { href: "/engineer-dormancy", title: "Dormancy", desc: "Past completers idle >30d", round: "r631" },
      { href: "/engineer-geo", title: "Geo", desc: "Top 50 cities + verification", round: "r633" },
      { href: "/engineer-specialization-coverage", title: "Specialization coverage", desc: "Per-category counts", round: "r634" },
      { href: "/top-engineers-7d", title: "Top earners (7d)", desc: "Top 25 by 7d gross", round: "r615" },
      { href: "/top-engineers-30d", title: "Top earners (30d)", desc: "Top 50 by 30d gross", round: "r635" },
      { href: "/top-engineers-90d", title: "Top earners (90d)", desc: "Top 50 by 90d gross (long loyalists)", round: "r818" },
      { href: "/engineer-acceptance-rate", title: "Acceptance rate", desc: "30d bid → accepted %", round: "r636" },
      { href: "/engineer-payout-history", title: "Payout history", desc: "30/90d/lifetime per engineer", round: "r658" },
      { href: "/engineer-rating-distribution", title: "Rating distribution", desc: "180d histogram", round: "r671" },
      { href: "/lead-scoring", title: "Lead scoring", desc: "≥10 bids, 0 completions", round: "r670" },
    ],
  },
  {
    label: "Hospitals",
    links: [
      { href: "/hospital-utilization", title: "Utilization", desc: "Posting jobs 7/30/90d", round: "r637" },
      { href: "/hospital-repeat-rate", title: "Repeat rate", desc: "Lifetime job count buckets", round: "r638" },
      { href: "/hospital-onboarding-funnel", title: "Onboarding funnel", desc: "Hospital signup → AMC (90d cohort)", round: "r828" },
      { href: "/hospital-geo", title: "Geo", desc: "Top 50 cities", round: "r639" },
      { href: "/hospital-spend-30d", title: "Spend (30d)", desc: "Top 50 spenders + AMC flag", round: "r659" },
      { href: "/hospital-amc-coverage", title: "AMC coverage", desc: "With vs without active AMC", round: "r675" },
      { href: "/top-hospitals-30d", title: "Top hospitals (30d)", desc: "Top 25 by 30d posts", round: "r616" },
      { href: "/top-hospitals-90d", title: "Top hospitals (90d)", desc: "Top 50 by 90d posts", round: "r819" },
      { href: "/top-amc-spenders",  title: "Top AMC spenders",   desc: "Top 50 by 90d pool credits",  round: "r817" },
    ],
  },
  {
    label: "Repair jobs",
    links: [
      { href: "/repair-job-funnel", title: "Funnel", desc: "30d posted → completed", round: "r641" },
      { href: "/repair-jobs-status", title: "Status snapshot", desc: "All-time status distribution", round: "r692" },
      { href: "/job-fee-distribution", title: "Fee distribution", desc: "90d gross by bucket", round: "r642" },
      { href: "/job-bid-counts", title: "Bid counts", desc: "Bids-per-job histogram", round: "r643" },
      { href: "/unmatched-jobs", title: "Unmatched >7d", desc: "Posted >7d ago · zero bids", round: "r661" },
      { href: "/jobs-by-hour-of-day", title: "Jobs by hour", desc: "30d hour-of-day distribution", round: "r690" },
      { href: "/jobs-by-day-of-week", title: "Jobs by weekday", desc: "90d weekday distribution", round: "r691" },
    ],
  },
  {
    label: "Spare parts",
    links: [
      { href: "/parts-demand-supply", title: "Demand vs supply", desc: "90d demand vs bonded stock", round: "r644" },
      { href: "/parts-vendor-share", title: "Vendor share", desc: "Top 50 bonded suppliers", round: "r645" },
      { href: "/bonded-inventory", title: "Bonded inventory", desc: "SKU rollup · in-stock", round: "r619" },
      { href: "/bonded-by-supplier-tier", title: "By supplier tier", desc: "OEM/AUTHORIZED/VERIFIED rollup", round: "r708" },
      { href: "/bonded-dispatch-status", title: "Dispatch status", desc: "All-time dispatch status dist", round: "r709" },
    ],
  },
  {
    label: "Operations latency",
    links: [
      { href: "/kyc-aging", title: "KYC aging", desc: "Pending/rejected age buckets", round: "r612" },
      { href: "/dispute-aging", title: "Dispute aging", desc: "Evidence pack age buckets", round: "r613" },
      { href: "/dispute-resolution-latency", title: "Dispute resolution latency", desc: "Submitted → decision p50/p90", round: "r648" },
      { href: "/dispute-outcomes", title: "Dispute outcomes", desc: "Accepted vs rejected + avg stake", round: "r715" },
      { href: "/bid-latency", title: "Bid acceptance latency", desc: "Posted → accepted (p50/p90)", round: "r617" },
      { href: "/dsr-latency", title: "DSR sign-off latency", desc: "Engineer → hospital signed", round: "r618" },
      { href: "/code-red-sla", title: "Code Red SLA", desc: "Emergency accept rate", round: "r622" },
      { href: "/code-red-by-hour", title: "Code Red by hour", desc: "90d hourly distribution", round: "r716" },
    ],
  },
  {
    label: "Business health",
    links: [
      { href: "/amc-churn", title: "AMC churn", desc: "Rolling 30/90/180d churn %", round: "r614" },
      { href: "/amc-renewal-pipeline", title: "AMC renewal pipeline", desc: "Expiring 30/60/90d · MRR/ARR", round: "r627" },
      { href: "/amc-near-expiry", title: "AMC near expiry", desc: "Expiring within 30d list", round: "r660" },
      { href: "/amc-tier-distribution", title: "AMC tier distribution", desc: "Per-tier active + MRR", round: "r640" },
      { href: "/amc-categories-coverage", title: "AMC categories coverage", desc: "Equipment categories rolled up", round: "r689" },
      { href: "/amc-visits-cadence", title: "AMC visits cadence", desc: "Completed vs scheduled %", round: "r649" },
      { href: "/amc-pool-health", title: "AMC pool health", desc: "Balance distribution buckets", round: "r678" },
      { href: "/amc-pool-low-balance", title: "AMC pool low balance", desc: "Active AMCs below 2× monthly fee · outreach queue", round: "r724" },
      { href: "/amc-paused", title: "AMC paused", desc: "Paused contracts · MRR frozen", round: "r679" },
      { href: "/amc-cancellations", title: "AMC cancellations 30d", desc: "Cancelled/failed/expired list", round: "r683" },
      { href: "/chains-health", title: "Chains health", desc: "Per-chain AMC % + jobs", round: "r621" },
      { href: "/chains-leaderboard", title: "Chains leaderboard", desc: "Top 50 by member count", round: "r681" },
    ],
  },
  {
    label: "Daily trends (14d)",
    links: [
      { href: "/signups-by-day-trend", title: "Signups", desc: "Daily + engineer breakdown", round: "r652" },
      { href: "/bid-volume-trend", title: "Bids", desc: "Placed + accepted + engineers", round: "r653" },
      { href: "/jobs-volume-trend", title: "Jobs", desc: "Posted + completed + gross", round: "r654" },
      { href: "/demand-signals-trend", title: "Demand signals", desc: "Daily + distinct SKUs + reporters", round: "r655" },
      { href: "/referral-volume-trend", title: "Referrals", desc: "Daily referrals + first-jobs", round: "r668" },
      { href: "/code-red-volume-trend", title: "Code Red", desc: "Daily opened + timed-out", round: "r669" },
      { href: "/payouts-by-day-trend", title: "Payouts", desc: "Daily paid + rupees + failed", round: "r686" },
      { href: "/amc-pool-credits-trend", title: "AMC pool credits", desc: "Daily ledger credit/debit/refund", round: "r693" },
      { href: "/bonded-intake-trend", title: "Bonded intake", desc: "Daily intake rows + qty + cost", round: "r706" },
      { href: "/bonded-dispatch-trend", title: "Bonded dispatch", desc: "Daily dispatches + qty + installed", round: "r707" },
    ],
  },
  {
    label: "Monthly trends (12mo)",
    links: [
      { href: "/repair-jobs-by-month", title: "Repair jobs", desc: "Posted / completed / cancelled / gross", round: "r694" },
      { href: "/signups-by-month", title: "Signups", desc: "Total + engineer subset", round: "r695" },
      { href: "/amc-contracts-by-month", title: "AMC contracts", desc: "New AMCs + new MRR", round: "r696" },
      { href: "/payouts-by-month", title: "Engineer payouts", desc: "Paid count / rupees / failed", round: "r697" },
      { href: "/disputes-by-month", title: "Disputes", desc: "Submitted / accepted / rejected", round: "r698" },
      { href: "/referrals-by-month", title: "Referrals", desc: "Referrals / first jobs / bounties", round: "r699" },
      { href: "/demand-signals-by-month", title: "Demand signals", desc: "Signals / SKUs / resolved", round: "r701" },
      { href: "/code-red-by-month", title: "Code Red", desc: "Opened / resolved / timed-out", round: "r702" },
      { href: "/escrow-by-month", title: "Escrow", desc: "Released vs refunded", round: "r703" },
      { href: "/tier-changes-by-month", title: "Tier changes", desc: "Promotions / demotions", round: "r704" },
      { href: "/spot-audits-by-month", title: "Spot audits", desc: "Invitations / responses / rating", round: "r705" },
      { href: "/supervised-by-month", title: "Supervised", desc: "Assigned / successful / failed", round: "r710" },
      { href: "/amc-payment-by-month", title: "AMC payments", desc: "Paid count / rupees / failed", round: "r711" },
    ],
  },
  {
    label: "Weekly trends (13wk)",
    links: [
      { href: "/jobs-by-week",            title: "Jobs",            desc: "Posted/completed/cancelled/gross", round: "r735" },
      { href: "/signups-by-week",         title: "Signups",         desc: "Total + engineer subset",          round: "r736" },
      { href: "/amc-contracts-by-week",   title: "AMC contracts",   desc: "New AMCs + new MRR",               round: "r737" },
      { href: "/payouts-by-week",         title: "Engineer payouts", desc: "Paid count + rupees + failed",    round: "r738" },
      { href: "/disputes-by-week",        title: "Disputes",        desc: "Submitted/accepted/rejected",      round: "r739" },
      { href: "/referrals-by-week",       title: "Referrals",       desc: "Referrals/first-jobs/bounties",    round: "r740" },
      { href: "/demand-signals-by-week",  title: "Demand signals",  desc: "Signals/SKUs/resolved",            round: "r741" },
      { href: "/code-red-by-week",        title: "Code Red",        desc: "Opened/resolved/timed-out",        round: "r742" },
      { href: "/escrow-by-week",          title: "Escrow",          desc: "Released vs refunded",             round: "r743" },
      { href: "/tier-changes-by-week",    title: "Tier changes",    desc: "Promotions/demotions",             round: "r744" },
      { href: "/supervised-by-week",      title: "Supervised",      desc: "Assigned/successful/failed",       round: "r745" },
      { href: "/spot-audits-by-week",     title: "Spot audits",     desc: "Invitations/responses/rating",     round: "r746" },
      { href: "/amc-payment-by-week",     title: "AMC payments",    desc: "Paid count + rupees + failed",     round: "r747" },
    ],
  },
  {
    label: "Time patterns",
    links: [
      { href: "/signups-by-hour",         title: "Signups by hour", desc: "90d hourly distribution",          round: "r748" },
      { href: "/bids-by-hour",            title: "Bids by hour",    desc: "90d hourly distribution",          round: "r749" },
      { href: "/payouts-by-hour",         title: "Payouts by hour", desc: "90d queued_at distribution",       round: "r750" },
      { href: "/signups-by-day-of-week",  title: "Signups weekday", desc: "90d weekday distribution",         round: "r751" },
      { href: "/bids-by-day-of-week",     title: "Bids weekday",    desc: "90d weekday distribution",         round: "r752" },
      { href: "/code-red-by-day-of-week", title: "Code Red weekday", desc: "90d weekday distribution",        round: "r753" },
      { href: "/payouts-by-day-of-week",  title: "Payouts weekday", desc: "90d weekday distribution",         round: "r754" },
      { href: "/amc-by-day-of-week",      title: "AMC weekday",     desc: "180d signup weekday",              round: "r755" },
    ],
  },
  {
    label: "Cross-cuts & revenue",
    links: [
      { href: "/at-risk-revenue",         title: "At-risk revenue", desc: "6-category leak roll-up",          round: "r756" },
      { href: "/jobs-completion-rate",    title: "Completion rate", desc: "Posted-to-completed weekly funnel", round: "r757" },
      { href: "/amc-churn-monthly",       title: "AMC churn %",     desc: "12-month churn %",                 round: "r758" },
      { href: "/top-suppliers-30d",       title: "Top suppliers",   desc: "Top 25 by 30d intake",             round: "r759" },
      { href: "/bid-amount-distribution", title: "Bid amounts",     desc: "90d bid rupee buckets",            round: "r760" },
      { href: "/bid-vs-contract-spread",  title: "Bid vs contract", desc: "Negotiation stretch p7/30/90d",    round: "r761" },
      { href: "/jobs-by-equipment-type",  title: "Jobs by equipment", desc: "90d category breakdown",         round: "r762" },
      { href: "/commission-vs-payout",    title: "Commission vs payout", desc: "12mo GMV vs paid vs net",     round: "r779" },
      { href: "/pulse-extended",          title: "Pulse extended ★",desc: "10 KPIs WoW (r780 milestone)",     round: "r780" },
    ],
  },
  {
    label: "Cumulative (12mo growth)",
    links: [
      { href: "/verified-engineer-growth", title: "Verified engineers", desc: "Cumulative verified base",     round: "r763" },
      { href: "/amc-base-growth",          title: "AMC base",        desc: "Cumulative AMCs + MRR",           round: "r764" },
      { href: "/signups-cumulative",       title: "Signups",         desc: "Cumulative user base",            round: "r765" },
      { href: "/payouts-cumulative",       title: "Engineer payouts", desc: "Cumulative paid count + rupees", round: "r766" },
      { href: "/gmv-cumulative",           title: "GMV",             desc: "Cumulative GMV + jobs",           round: "r767" },
      { href: "/commission-cumulative",    title: "Commission",      desc: "Cumulative platform take",        round: "r768" },
      { href: "/escrow-cumulative",        title: "Escrow",          desc: "Cumulative released + refunded",  round: "r769" },
      { href: "/amc-revenue-cumulative",   title: "AMC revenue",     desc: "Cumulative AMC payment orders",   round: "r770" },
      { href: "/referrals-cumulative",     title: "Referrals",       desc: "Cumulative referrals + first-jobs", round: "r771" },
      { href: "/demand-signals-cumulative", title: "Demand signals", desc: "Cumulative signals + resolved",   round: "r772" },
      { href: "/disputes-cumulative",      title: "Disputes",        desc: "Cumulative disputes",             round: "r773" },
      { href: "/code-red-cumulative",      title: "Code Red",        desc: "Cumulative Code Red",             round: "r774" },
      { href: "/supervised-cumulative",    title: "Supervised",      desc: "Cumulative supervised",           round: "r775" },
      { href: "/spot-audits-cumulative",   title: "Spot audits",     desc: "Cumulative spot audits",          round: "r776" },
      { href: "/tier-changes-cumulative",  title: "Tier changes",    desc: "Cumulative promo/demo",           round: "r777" },
      { href: "/bonded-intake-cumulative", title: "Bonded intake",   desc: "Cumulative bonded rows/qty/cost", round: "r778" },
    ],
  },
  {
    label: "Health rates",
    links: [
      { href: "/amc-pool-coverage",            title: "AMC pool coverage",       desc: "Active AMCs by buffer buckets",                 round: "r793" },
      { href: "/jobs-fill-rate",               title: "Jobs fill rate",          desc: "% jobs that got bid within 7d",                 round: "r794" },
      { href: "/jobs-time-to-complete",        title: "Jobs time-to-complete",   desc: "Posted → completed p50/p90 hours",              round: "r795" },
      { href: "/escrow-release-rate",          title: "Escrow release rate",     desc: "% completed jobs whose escrow released",        round: "r796" },
      { href: "/amc-payment-collection-rate",  title: "AMC payment collection",  desc: "% AMC payment orders paid · 7/30/90d",          round: "r797" },
      { href: "/payouts-success-rate",         title: "Payouts success rate",    desc: "% engineer payouts processed vs failed",        round: "r798" },
      { href: "/dispute-resolution-rate",      title: "Dispute resolution rate", desc: "% disputes mediator decided",                   round: "r799" },
      { href: "/amc-renewal-rate",             title: "AMC renewal rate",        desc: "% renewal attempts succeeded · 30/90/365d",     round: "r800" },
      { href: "/supervised-success-rate",      title: "Supervised success rate", desc: "% supervised jobs marked successful",           round: "r801" },
      { href: "/jobs-cancellation-rate",       title: "Jobs cancellation rate",  desc: "% repair jobs ending in cancellation",          round: "r802" },
      { href: "/spot-audit-pass-rate",         title: "Spot audit pass rate",    desc: "% spot audit responses rated ≥4★",              round: "r803" },
      { href: "/hospital-retention-rate",      title: "Hospital retention rate", desc: "% active hospitals with ≥2 jobs · 30/90/180d",  round: "r805" },
      { href: "/engineer-retention-rate",      title: "Engineer retention rate", desc: "% engineers with ≥2 completions · 30/90/180d",  round: "r806" },
      { href: "/bids-acceptance-rate-platform", title: "Bid acceptance (platform)", desc: "% all bids accepted · 7/30/90d",              round: "r807" },
      { href: "/code-red-resolution-rate",     title: "Code Red resolution rate", desc: "% emergency requests resolved · 7/30/90d",      round: "r825" },
    ],
  },
  {
    label: "Aging surfaces",
    links: [
      { href: "/pending-payouts-aging",     title: "Pending payouts aging",    desc: "engineer_payouts pending bucketed by age",   round: "r809" },
      { href: "/pending-amc-orders-aging",  title: "Pending AMC orders aging", desc: "amc_payment_orders pending bucketed by age", round: "r810" },
      { href: "/repair-jobs-stuck",         title: "Repair jobs stuck >14d",   desc: "Non-terminal repair jobs older than 14d",    round: "r811" },
      { href: "/amc-renewal-failures-aging", title: "Renewal failures aging",  desc: "renewal_failed by days since end_date",      round: "r820" },
      { href: "/amc-renewal-failures",       title: "Renewal failures list",   desc: "renewal_failed outreach queue",              round: "r821" },
    ],
  },
  {
    label: "Geo & dimension breakdowns",
    links: [
      { href: "/amc-revenue-by-city",   title: "AMC revenue by city (90d)",   desc: "Top 50 cities by 90d AMC paid rupees",       round: "r812" },
      { href: "/jobs-revenue-by-city",  title: "Jobs revenue by city (90d)",  desc: "Top 50 cities by 90d completed-jobs gross",   round: "r813" },
      { href: "/signups-by-city",       title: "Signups by city (90d)",       desc: "Top 50 cities by 90d new accounts",           round: "r814" },
      { href: "/payouts-by-bank",       title: "Payouts by bank (90d)",       desc: "Top 50 banks · processed vs failed",          round: "r815" },
      { href: "/demand-by-city",        title: "Demand by city (90d)",        desc: "Top 50 cities by 90d demand signals",         round: "r824" },
      { href: "/chains-revenue-rollup", title: "Chains revenue rollup (90d)", desc: "Top 50 chains by AMC + jobs revenue",         round: "r826" },
      { href: "/amc-payments-by-tier",  title: "AMC payments by tier (90d)",  desc: "Paid rupees rolled up by AMC tier",           round: "r829" },
      { href: "/amc-pool-balance-by-hospital", title: "AMC pool balance by hospital", desc: "Top 50 by active-contract pool balance", round: "r831" },
      { href: "/amc-pool-balance-by-city", title: "AMC pool balance by city",        desc: "Top 50 cities by active-contract balance", round: "r841" },
      { href: "/payouts-by-engineer-tier", title: "Payouts by engineer tier",  desc: "90d processed payouts by cert tier",          round: "r833" },
      { href: "/jobs-by-engineer-tier", title: "Jobs by engineer tier",        desc: "90d completed jobs by cert tier",             round: "r834" },
    ],
  },
  {
    label: "Cron & periodic jobs",
    links: [
      { href: "/cron-status", title: "Cron status", desc: "pg_cron last-run + failures", round: "r599" },
    ],
  },
];

export default async function OpsIndexPage() {
  await requireFounder();

  return (
    <div className="space-y-8">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Ops index</h1>
        <span className="text-xs text-[var(--color-muted)]">
          r599–r850 sprint · all founder ops surfaces in one place
        </span>
      </header>

      {SECTIONS.map((section) => (
        <section key={section.label}>
          <h2 className="mb-2 text-xs font-medium uppercase tracking-wider text-[var(--color-muted)]">
            {section.label}
          </h2>
          <div className="grid grid-cols-1 gap-3 md:grid-cols-2 lg:grid-cols-3">
            {section.links.map((link) => (
              <Link
                key={link.href}
                href={link.href}
                className="rounded border border-[var(--color-border)] bg-white p-3 transition-colors hover:border-[var(--color-fg)]"
              >
                <div className="flex items-baseline justify-between">
                  <h3 className="text-sm font-semibold">{link.title}</h3>
                  <span className="text-[10px] text-[var(--color-muted)]">
                    {link.round}
                  </span>
                </div>
                <p className="mt-1 text-xs text-[var(--color-muted)]">{link.desc}</p>
              </Link>
            ))}
          </div>
        </section>
      ))}

      <section className="rounded border border-[var(--color-border)] bg-white p-3 text-xs text-[var(--color-muted)]">
        <strong>r717 ops index.</strong> Third autonomous 30-ship chain
        (r688-r717) on top of r628-r657 + r658-r687. 115+ founder ops surfaces
        spanning 14 sections. Featured: r700 milestone (<a href="/platform-pulse" className="underline">/platform-pulse</a>)
        is the single-page executive snapshot — start there for daily founder review.
      </section>
    </div>
  );
}
