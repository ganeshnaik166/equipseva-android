import { requireFounder } from "@/lib/auth/requireFounder";
import { PrintButton } from "./PrintButton";
import { ShareTokensSection } from "./ShareTokensSection";

type ShareTokenRow = {
  id: string;
  label: string;
  status: string;
  expires_at: string;
  max_views: number;
  view_count: number;
  revoked_at: string | null;
  revoke_reason: string | null;
  created_at: string;
};
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { StatCard } from "@/components/StatCard";
import { CohortBars, type CohortDatum } from "@/components/charts/CohortBars";
import { DisputeTrend, type DisputeTrendDatum } from "@/components/charts/DisputeTrend";
import { formatNumber, formatPct, formatRupees } from "@/lib/format";
import { currentFiscalYear } from "@/lib/fy";

export const metadata = { title: "Investor brief — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type HeroKpis = {
  gmv_7d_rupees: number | null;
  gmv_wow_pct: number | null;
  completed_jobs_7d: number | null;
  active_engineers_30d: number | null;
  open_disputes: number | null;
  total_escrow_held_rupees: number | null;
  amc_contracts_active: number | null;
};

type VerticalRow = {
  equipment_type: string;
  job_count: number | null;
  gmv_rupees: number | null;
};

type EngineerLtv = {
  engineer_user_id: string;
  total_jobs_completed: number | null;
  total_gross_rupees: number | null;
  total_net_paid_rupees: number | null;
  avg_rating: number | null;
};

type GstRow = {
  fiscal_year: string;
  invoice_count: number | null;
  taxable_total_rupees: number | null;
};

export default async function InvestorPage() {
  await requireFounder();
  const fy = currentFiscalYear();
  const supabase = await getSupabaseServerClient();

  const [hero, verticals90, cohorts, dispute, top, gst, shareTokens] = await Promise.all([
    supabase.rpc("founder_hero_kpis"),
    supabase.rpc("founder_gmv_by_equipment_type", { p_days: 90 }),
    supabase.rpc("founder_hospital_cohort_retention", { p_months: 12 }),
    supabase.rpc("founder_dispute_rate_monthly", { p_months: 12 }),
    supabase.rpc("founder_engineer_ltv_ranked", { p_limit: 10 }),
    supabase.rpc("founder_gst_summary", { p_fiscal_year: fy }),
    supabase.rpc("founder_list_investor_share_tokens", { p_limit: 50 }),
  ]);

  for (const r of [hero, verticals90, cohorts, dispute, top, gst]) {
    if (r.error) throw new Error(`RPC failed: ${r.error.message}`);
  }
  const tokens = (shareTokens.error ? [] : (shareTokens.data ?? [])) as ShareTokenRow[];

  const k: HeroKpis = (Array.isArray(hero.data) ? hero.data[0] : hero.data) ?? ({} as HeroKpis);
  const verticalsRows = (verticals90.data ?? []) as VerticalRow[];
  const cohortRows = (cohorts.data ?? []) as CohortDatum[];
  const disputeRows = (dispute.data ?? []) as DisputeTrendDatum[];
  const topEngineers = (top.data ?? []) as EngineerLtv[];
  const gstRows = (gst.data ?? []) as GstRow[];

  const totalVerticalGmv = verticalsRows.reduce((s, r) => s + (r.gmv_rupees ?? 0), 0);
  const totalVerticalJobs = verticalsRows.reduce((s, r) => s + (r.job_count ?? 0), 0);
  const top3Verticals = [...verticalsRows]
    .sort((a, b) => (b.gmv_rupees ?? 0) - (a.gmv_rupees ?? 0))
    .slice(0, 3);
  const ytdGstTaxable = gstRows.reduce((s, r) => s + (r.taxable_total_rupees ?? 0), 0);
  const ytdGstInvoices = gstRows.reduce((s, r) => s + (r.invoice_count ?? 0), 0);
  const topEngineerGross = topEngineers.reduce((s, r) => s + (r.total_gross_rupees ?? 0), 0);
  const topEngineerJobs = topEngineers.reduce((s, r) => s + (r.total_jobs_completed ?? 0), 0);

  const generatedAt = new Date().toLocaleString("en-IN", {
    timeZone: "Asia/Kolkata",
    dateStyle: "long",
    timeStyle: "short",
  });

  return (
    <div className="space-y-10 pb-12 print:space-y-6">
      <header className="space-y-1">
        <div className="flex items-center justify-between print:hidden">
          <p className="text-xs uppercase tracking-widest text-[var(--color-muted)]">
            EquipSeva · Investor brief
          </p>
          <PrintButton />
        </div>
        <p className="hidden text-xs uppercase tracking-widest text-[var(--color-muted)] print:block">
          EquipSeva · Investor brief
        </p>
        <h1 className="text-3xl font-semibold tracking-tight">
          India&rsquo;s biomedical equipment service network.
        </h1>
        <p className="max-w-3xl text-sm text-[var(--color-muted)]">
          A two-sided marketplace: hospitals post repair + AMC contracts, vetted engineers bid,
          escrowed payments + NABH-grade evidence settle every job. Numbers below are
          auto-rendered from production data at request time.
        </p>
        <p className="text-xs text-[var(--color-muted)]">
          Generated {generatedAt} IST · FY {fy}
        </p>
      </header>

      <section>
        <h2 className="mb-3 text-sm font-semibold uppercase tracking-wider text-[var(--color-muted)]">
          Traction — last 7 days
        </h2>
        <div className="grid grid-cols-2 gap-3 md:grid-cols-4">
          <StatCard
            label="GMV (7d)"
            value={formatRupees(k.gmv_7d_rupees)}
            subtext={k.gmv_wow_pct != null ? `${formatPct(k.gmv_wow_pct)} WoW` : undefined}
            tone={k.gmv_wow_pct != null && k.gmv_wow_pct >= 0 ? "ok" : "warn"}
          />
          <StatCard
            label="Completed jobs (7d)"
            value={formatNumber(k.completed_jobs_7d)}
          />
          <StatCard
            label="Active engineers (30d)"
            value={formatNumber(k.active_engineers_30d)}
          />
          <StatCard
            label="AMC contracts"
            value={formatNumber(k.amc_contracts_active)}
            subtext="active"
          />
        </div>
      </section>

      <section>
        <h2 className="mb-3 text-sm font-semibold uppercase tracking-wider text-[var(--color-muted)]">
          Vertical mix — last 90 days
        </h2>
        <p className="mb-2 max-w-3xl text-sm text-[var(--color-muted)]">
          Dental anchor strategy: tier-2/3 clinics ({formatNumber(totalVerticalJobs)} jobs ·{" "}
          {formatRupees(totalVerticalGmv)} GMV across the window).
        </p>
        <div className="grid grid-cols-1 gap-3 md:grid-cols-3">
          {top3Verticals.map((v) => (
            <div key={v.equipment_type} className="rounded border border-[var(--color-border)] bg-white p-4">
              <div className="text-xs uppercase tracking-wider text-[var(--color-muted)]">
                {v.equipment_type}
              </div>
              <div className="mt-1 text-2xl font-semibold tabular-nums">
                {formatRupees(v.gmv_rupees)}
              </div>
              <div className="text-xs text-[var(--color-muted)]">
                {formatNumber(v.job_count)} jobs ·{" "}
                {formatPct(
                  totalVerticalGmv > 0 ? ((v.gmv_rupees ?? 0) / totalVerticalGmv) * 100 : 0,
                )}{" "}
                of GMV
              </div>
            </div>
          ))}
        </div>
      </section>

      <section>
        <h2 className="mb-3 text-sm font-semibold uppercase tracking-wider text-[var(--color-muted)]">
          Hospital retention — monthly cohorts
        </h2>
        <p className="mb-2 max-w-3xl text-sm text-[var(--color-muted)]">
          Of hospitals signed up in each month, % that completed at least one job in the trailing N-day window.
        </p>
        <div className="rounded border border-[var(--color-border)] bg-white p-3">
          <CohortBars data={cohortRows} />
        </div>
      </section>

      <section>
        <h2 className="mb-3 text-sm font-semibold uppercase tracking-wider text-[var(--color-muted)]">
          Quality — dispute rate (monthly)
        </h2>
        <p className="mb-2 max-w-3xl text-sm text-[var(--color-muted)]">
          Disputed jobs as % of completed in each month. Lower is better. v0.3 introduced
          §65B evidence vault + AMC affidavit gate — note the inflection.
        </p>
        <div className="rounded border border-[var(--color-border)] bg-white p-3">
          <DisputeTrend data={disputeRows} />
        </div>
      </section>

      <section>
        <h2 className="mb-3 text-sm font-semibold uppercase tracking-wider text-[var(--color-muted)]">
          Engineer economics — top 10
        </h2>
        <div className="grid grid-cols-2 gap-3 md:grid-cols-4">
          <StatCard label="Top-10 jobs done" value={formatNumber(topEngineerJobs)} />
          <StatCard label="Top-10 gross" value={formatRupees(topEngineerGross)} />
          <StatCard
            label="Avg jobs / top engineer"
            value={
              topEngineers.length > 0
                ? formatNumber(Math.round(topEngineerJobs / topEngineers.length))
                : "—"
            }
          />
          <StatCard
            label="Avg gross / top engineer"
            value={
              topEngineers.length > 0
                ? formatRupees(Math.round(topEngineerGross / topEngineers.length))
                : "—"
            }
          />
        </div>
      </section>

      <section>
        <h2 className="mb-3 text-sm font-semibold uppercase tracking-wider text-[var(--color-muted)]">
          Working capital + compliance
        </h2>
        <div className="grid grid-cols-2 gap-3 md:grid-cols-4">
          <StatCard
            label="Escrow held"
            value={formatRupees(k.total_escrow_held_rupees)}
            subtext="trust capital float"
          />
          <StatCard
            label="GST invoices (YTD)"
            value={formatNumber(ytdGstInvoices)}
            subtext={`FY ${fy}`}
          />
          <StatCard
            label="GST taxable (YTD)"
            value={formatRupees(ytdGstTaxable)}
            subtext={`FY ${fy}`}
          />
          <StatCard
            label="Open disputes"
            value={formatNumber(k.open_disputes)}
            tone={(k.open_disputes ?? 0) > 0 ? "warn" : "ok"}
          />
        </div>
      </section>

      <section className="rounded border border-[var(--color-border)] bg-white p-5 text-sm">
        <h2 className="text-sm font-semibold">Defensibility</h2>
        <ul className="mt-2 list-disc space-y-1 pl-5 text-[var(--color-muted)]">
          <li>
            §65B Indian Evidence Act chain-of-custody on every service report —
            court-admissible.
          </li>
          <li>
            NABH 5th-edition COP-6 compliance bundle (one-click ZIP export for hospital
            auditors).
          </li>
          <li>
            DPDP Act 2023 — self-hosted analytics ledger (no PII to US vendors), 90-day
            retention sweep, grievance officer queue.
          </li>
          <li>
            §194-O TDS auto-deduction + RCM-aware GST invoicing — every payout already
            tax-compliant.
          </li>
          <li>
            Bonded parts provenance (OEM/authorized/verified tiers + tamper-evident QR
            chain) closes counterfeit-parts criminal liability (BNS §304A).
          </li>
          <li>
            CDSCO Class A/B in-scope-only equipment taxonomy hard-gate. Class C/D imaging /
            life-support + AERB-licensed radiology fall out of scope by design — risk floor,
            not ceiling.
          </li>
        </ul>
      </section>

      <ShareTokensSection tokens={tokens} />

      <footer className="border-t border-[var(--color-border)] pt-6 text-xs text-[var(--color-muted)]">
        Numbers are live, generated at request time from production RPCs. Source code, audit
        log, and security posture available on request.
      </footer>
    </div>
  );
}
