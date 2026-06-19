import Link from "next/link";
import { requireFounder } from "@/lib/auth/requireFounder";

export const metadata = { title: "Snapshots index — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Snap = { href: string; title: string; desc: string; round: string; kpis: number; section: "Demand" | "Supply" | "Money" | "Trust" | "Growth" | "Ops" };

const SURFACES: Snap[] = [
  { href: "/hospitals-snapshot-summary",            title: "Hospitals snapshot",            desc: "AMC coverage + spend + loyalty + geographic reach",            round: "r1169", kpis: 15, section: "Demand" },
  { href: "/hospital-chains-snapshot-summary",      title: "Hospital chains snapshot",      desc: "Chain whale dashboard · AMC coverage + revenue concentration", round: "r1181", kpis: 13, section: "Demand" },
  { href: "/engineers-snapshot-summary",            title: "Engineers snapshot",            desc: "KYC funnel + tier distribution + activity",                    round: "r1168", kpis: 14, section: "Supply" },
  { href: "/supervised-training-snapshot-summary",  title: "Supervised training snapshot",  desc: "Active trainees + pass rate + pipeline depth",                 round: "r1182", kpis: 14, section: "Supply" },
  { href: "/jobs-snapshot-summary",                 title: "Jobs snapshot",                 desc: "Posted/open/in-progress/completed/cancelled marketplace mix",  round: "r1162", kpis: 12, section: "Demand" },
  { href: "/code-red-snapshot-summary",             title: "Code Red snapshot",             desc: "Emergency queue + SLA breach % + responders 30d",              round: "r1165", kpis: 13, section: "Supply" },
  { href: "/amc-snapshot-summary",                  title: "AMC snapshot",                  desc: "Active/paused/expired + MRR + pool health",                    round: "r1161", kpis: 13, section: "Money"  },
  { href: "/payouts-snapshot-summary",              title: "Payouts snapshot",              desc: "Queued/processed/failed/stuck pipeline + INR",                 round: "r1166", kpis: 14, section: "Money"  },
  { href: "/spare-parts-snapshot-summary",          title: "Spare parts snapshot",          desc: "Paid/shipped/delivered/stuck commerce funnel + GMV",           round: "r1167", kpis: 15, section: "Money"  },
  { href: "/escrow-snapshot-summary",               title: "Escrow snapshot",               desc: "Money-in-flight: held/released/refunded/scheduled-release",    round: "r1171", kpis: 18, section: "Money"  },
  { href: "/disputes-snapshot-summary",             title: "Disputes snapshot",             desc: "Mediation queue + resolution % + money at stake",              round: "r1170", kpis: 14, section: "Trust"  },
  { href: "/spot-audits-snapshot-summary",          title: "Spot audits snapshot",          desc: "Invitations + responses + ratings + coverage",                 round: "r1185", kpis: 14, section: "Trust"  },
  { href: "/referrals-snapshot-summary",            title: "Referrals snapshot",            desc: "Growth dashboard · funnel + bounty spend + ROI + stuck",       round: "r1180", kpis: 14, section: "Growth" },
  { href: "/signups-funnel-snapshot-summary",       title: "Signups funnel snapshot",       desc: "Acquisition funnel × role + first-action completion %",        round: "r1184", kpis: 13, section: "Growth" },
  { href: "/notifications-snapshot-summary",        title: "Notifications snapshot",        desc: "Throughput · today/30d · stuck-unread alerts",                 round: "r1183", kpis: 12, section: "Ops"    },
  // r1186 expansion ↑ · r1226 expansion ↓
  // Batch 2 (r1197-r1201)
  { href: "/equipment-category-snapshot",           title: "Equipment category snapshot",   desc: "Taxonomy mix · scope gate · top category by job volume",       round: "r1197", kpis: 13, section: "Demand" },
  { href: "/engineer-certifications-snapshot",      title: "Engineer cert snapshot",        desc: "Cert-ladder tier mix + promo flow + stalled queue",            round: "r1198", kpis: 14, section: "Supply" },
  { href: "/compliance-evidence-snapshot",          title: "Compliance evidence snapshot",  desc: "§65B ledger + DPDP + DSR + NABH + audit log",                  round: "r1199", kpis: 15, section: "Trust"  },
  { href: "/cumulative-rollup-summary",             title: "Cumulative rollup summary",     desc: "Lifetime autobiography · investor-deck row",                   round: "r1200", kpis: 14, section: "Money"  },
  { href: "/regional-state-summary",                title: "Regional state summary",        desc: "Top-3 states by composite activity",                            round: "r1201", kpis: 15, section: "Demand" },
  // Batch 3 (r1202-r1207)
  { href: "/kyc-pipeline-snapshot",                 title: "KYC pipeline snapshot",         desc: "Engineer + buyer pending + rekyc-due + aging buckets",         round: "r1202", kpis: 20, section: "Trust"  },
  { href: "/webhooks-snapshot",                     title: "Webhooks snapshot",             desc: "Razorpay webhook health · success rate + retry queue",         round: "r1203", kpis: 12, section: "Ops"    },
  { href: "/gst-invoice-snapshot",                  title: "GST invoice snapshot",          desc: "Tax-audit-ready · MTD value + dispatch + GSTIN coverage",      round: "r1204", kpis: 12, section: "Money"  },
  { href: "/rfq-marketplace-snapshot",              title: "RFQ marketplace snapshot",      desc: "Vendor RFQs + rental + financing · TAM expansion lane",        round: "r1205", kpis: 14, section: "Demand" },
  { href: "/amc-sla-warranty-snapshot",             title: "AMC SLA warranty snapshot",     desc: "SLA breach + warranty-detected + breach $ exposure",           round: "r1206", kpis: 14, section: "Money"  },
  { href: "/reconciliation-tax-snapshot",           title: "Reconciliation tax snapshot",   desc: "Recon mismatch + TDS MTD + 26AS + gateway drift",              round: "r1207", kpis: 12, section: "Money"  },
  // Batch 4 (r1213-r1218)
  { href: "/chat-moderation-summary",               title: "Chat moderation summary",       desc: "DPDP safety · volume + PII-attempts + repeat offenders",       round: "r1213", kpis: 12, section: "Trust"  },
  { href: "/onboarding-velocity-summary",           title: "Onboarding velocity summary",   desc: "Signup → first-action latency · median + p90 + by role",      round: "r1214", kpis: 12, section: "Growth" },
  { href: "/dsr-data-export-sla-summary",           title: "DSR data export SLA summary",   desc: "DPDP DSR queue + 24h-SLA compliance + breaches",                round: "r1215", kpis: 12, section: "Trust"  },
  { href: "/consent-ledger-summary",                title: "Consent ledger summary",        desc: "DPDP per-purpose grants + revocation velocity",                round: "r1216", kpis: 13, section: "Trust"  },
  { href: "/founder-action-followups-summary",      title: "Founder action followups",      desc: "Untouched items >7d · meta-operational TODO age pulse",        round: "r1217", kpis: 16, section: "Ops"    },
  { href: "/system-throughput-hourly-summary",      title: "System throughput hourly",      desc: "Jobs-per-hour + 24h-load curve · capacity planning",           round: "r1218", kpis: 12, section: "Ops"    },
];

const SEC_TONE: Record<Snap["section"], string> = {
  Demand: "text-[var(--color-info)]",
  Supply: "text-[var(--color-ok)]",
  Money:  "text-[var(--color-warn)]",
  Trust:  "text-[var(--color-danger)]",
  Growth: "text-[var(--color-accent)]",
  Ops:    "text-[var(--color-muted)]",
};

export default async function SnapshotsIndexPage() {
  await requireFounder();
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Snapshots index ★ r1172 · r1226 expansion</h1>
        <span className="text-xs text-[var(--color-muted)]">24th meta-landing · {SURFACES.length} domain snapshot summaries · 12-20 KPIs each, today/30d/all-time mix</span>
      </header>
      <div className="grid grid-cols-1 gap-3 sm:grid-cols-2 lg:grid-cols-3">
        {SURFACES.map((s) => (
          <Link key={s.href} href={s.href}
            className="block rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4 transition hover:border-[var(--color-accent)]">
            <div className="flex items-baseline justify-between">
              <h3 className="text-sm font-semibold">{s.title}</h3>
              <span className="text-xs font-mono text-[var(--color-muted)]">{s.round} · {s.kpis} KPIs</span>
            </div>
            <p className="mt-1 text-xs text-[var(--color-muted)]">{s.desc}</p>
            <span className={`mt-2 inline-block text-[10px] font-medium uppercase tracking-wider ${SEC_TONE[s.section]}`}>{s.section}</span>
          </Link>
        ))}
      </div>
    </div>
  );
}
