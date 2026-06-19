import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { formatNumber, formatRupees } from "@/lib/format";

export const metadata = { title: "Customer health score — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Summary = {
  total_active_hospitals: number | null;
  healthy_count: number | null;
  watch_count: number | null;
  at_risk_count: number | null;
  critical_count: number | null;
  avg_health_score: number | null;
  top_health_hospital_name: string | null;
  top_health_score: number | null;
  lowest_health_hospital_name: string | null;
  lowest_health_score: number | null;
  hospitals_improved_30d: number | null;
  hospitals_declined_30d: number | null;
  nps_promoter_count: number | null;
  nps_detractor_count: number | null;
};

type Row = {
  hospital_org_id: string;
  hospital_name: string;
  amc_tier: string | null;
  monthly_fee_rupees: number | null;
  days_active: number | null;
  last_visit_at: string | null;
  days_since_last_visit: number | null;
  open_codered_count: number | null;
  open_dispute_count: number | null;
  sla_breach_count_180d: number | null;
  nps_latest_score: number | null;
  latest_nps_category: string | null;
  health_score: number | null;
  health_band: string | null;
};

function fmtNum(n: number | null | undefined): string {
  if (n === null || n === undefined) return "—";
  return formatNumber(Number(n));
}

function fmtScore(n: number | null | undefined): string {
  if (n === null || n === undefined) return "—";
  return Number(n).toFixed(1);
}

function fmtDate(s: string | null | undefined): string {
  if (!s) return "—";
  return new Date(s).toISOString().slice(0, 10);
}

function bandTone(b: string | null | undefined): string {
  if (b === "healthy") return "text-[var(--color-ok)]";
  if (b === "watch") return "text-[var(--color-warn)]";
  if (b === "at_risk") return "text-[var(--color-warn)]";
  if (b === "critical") return "text-[var(--color-danger)]";
  return "text-[var(--color-muted)]";
}

function bandBg(b: string | null | undefined): string {
  if (b === "critical") return "bg-[var(--color-danger)]/5";
  if (b === "at_risk") return "bg-[var(--color-warn)]/5";
  return "";
}

function npsTone(c: string | null | undefined): string {
  if (c === "promoter") return "text-[var(--color-ok)]";
  if (c === "detractor") return "text-[var(--color-danger)]";
  if (c === "passive") return "text-[var(--color-warn)]";
  return "text-[var(--color-muted)]";
}

export default async function FounderCustomerHealthScorePage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();

  const [summaryRes, rowsRes] = await Promise.all([
    supabase.rpc("founder_customer_health_score_summary"),
    supabase.rpc("founder_customer_health_score_by_hospital", { p_limit: 100 }),
  ]);

  if (summaryRes.error) throw new Error(`founder_customer_health_score_summary: ${summaryRes.error.message}`);
  if (rowsRes.error) throw new Error(`founder_customer_health_score_by_hospital: ${rowsRes.error.message}`);

  const s: Summary = (Array.isArray(summaryRes.data) ? summaryRes.data[0] : summaryRes.data) ?? ({} as Summary);
  const rows = ((rowsRes.data ?? []) as Row[]);

  const cards: { label: string; value: string; tone?: string }[] = [
    { label: "Active hospitals", value: fmtNum(s.total_active_hospitals) },
    { label: "Healthy (≥ 80)", value: fmtNum(s.healthy_count), tone: "text-[var(--color-ok)]" },
    { label: "Watch (60 · 79)", value: fmtNum(s.watch_count), tone: "text-[var(--color-warn)]" },
    { label: "At risk (30 · 59)", value: fmtNum(s.at_risk_count), tone: "text-[var(--color-warn)]" },
    { label: "Critical (< 30)", value: fmtNum(s.critical_count), tone: "text-[var(--color-danger)]" },
    { label: "Avg health score", value: fmtScore(s.avg_health_score) },
    { label: "Top hospital", value: s.top_health_hospital_name ?? "—" },
    { label: "Top score", value: fmtScore(s.top_health_score), tone: "text-[var(--color-ok)]" },
    { label: "Lowest hospital", value: s.lowest_health_hospital_name ?? "—" },
    { label: "Lowest score", value: fmtScore(s.lowest_health_score), tone: "text-[var(--color-danger)]" },
    { label: "Improved 30d", value: fmtNum(s.hospitals_improved_30d), tone: "text-[var(--color-muted)]" },
    { label: "Declined 30d", value: fmtNum(s.hospitals_declined_30d), tone: "text-[var(--color-muted)]" },
    { label: "NPS promoters", value: fmtNum(s.nps_promoter_count), tone: "text-[var(--color-ok)]" },
    { label: "NPS detractors", value: fmtNum(s.nps_detractor_count), tone: "text-[var(--color-danger)]" },
  ];

  const cols: Column<Row>[] = [
    {
      key: "h",
      header: "Hospital",
      render: (r) => (
        <span className={"text-xs font-medium " + bandBg(r.health_band)}>{r.hospital_name}</span>
      ),
    },
    {
      key: "t",
      header: "Tier",
      render: (r) => <span className="text-xs uppercase tracking-wide text-[var(--color-muted)]">{r.amc_tier ?? "—"}</span>,
    },
    {
      key: "m",
      header: "MRR",
      render: (r) => <span className="text-xs tabular-nums">{r.monthly_fee_rupees ? formatRupees(Number(r.monthly_fee_rupees)) : "—"}</span>,
    },
    {
      key: "da",
      header: "Days active",
      render: (r) => <span className="text-xs tabular-nums">{fmtNum(r.days_active)}</span>,
    },
    {
      key: "lv",
      header: "Last visit",
      render: (r) => <span className="text-xs tabular-nums">{fmtDate(r.last_visit_at)}</span>,
    },
    {
      key: "dslv",
      header: "Days since",
      render: (r) => {
        const d = Number(r.days_since_last_visit ?? 0);
        const tone = d >= 90 ? "text-[var(--color-danger)]" : d >= 45 ? "text-[var(--color-warn)]" : "text-[var(--color-muted)]";
        return <span className={"text-xs tabular-nums " + tone}>{fmtNum(d)}</span>;
      },
    },
    {
      key: "cr",
      header: "Code-red",
      render: (r) => {
        const v = Number(r.open_codered_count ?? 0);
        return <span className={"text-xs tabular-nums " + (v > 0 ? "text-[var(--color-danger)]" : "text-[var(--color-muted)]")}>{fmtNum(v)}</span>;
      },
    },
    {
      key: "dp",
      header: "Disputes",
      render: (r) => {
        const v = Number(r.open_dispute_count ?? 0);
        return <span className={"text-xs tabular-nums " + (v > 0 ? "text-[var(--color-warn)]" : "text-[var(--color-muted)]")}>{fmtNum(v)}</span>;
      },
    },
    {
      key: "sla",
      header: "SLA 180d",
      render: (r) => {
        const v = Number(r.sla_breach_count_180d ?? 0);
        return <span className={"text-xs tabular-nums " + (v >= 3 ? "text-[var(--color-danger)]" : v > 0 ? "text-[var(--color-warn)]" : "text-[var(--color-muted)]")}>{fmtNum(v)}</span>;
      },
    },
    {
      key: "nps",
      header: "NPS",
      render: (r) => (
        <span className={"text-xs tabular-nums " + npsTone(r.latest_nps_category)}>
          {r.nps_latest_score === null || r.nps_latest_score === undefined ? "—" : r.nps_latest_score}
          {r.latest_nps_category ? " · " + r.latest_nps_category : ""}
        </span>
      ),
    },
    {
      key: "hs",
      header: "Score",
      render: (r) => <span className={"text-xs font-semibold tabular-nums " + bandTone(r.health_band)}>{fmtScore(r.health_score)}</span>,
    },
    {
      key: "b",
      header: "Band",
      render: (r) => <span className={"text-xs uppercase tracking-wide " + bandTone(r.health_band)}>{r.health_band ?? "—"}</span>,
    },
  ];

  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Customer health score</h1>
        <span className="text-xs text-[var(--color-muted)]">
          Composite hospital health · activity · code-red · disputes · SLA · NPS · 0 to 100 · riskiest first
        </span>
      </header>

      <section className="grid grid-cols-2 gap-3 sm:grid-cols-3 lg:grid-cols-4 xl:grid-cols-7">
        {cards.map((c) => (
          <div key={c.label} className="rounded border border-[var(--color-border)] bg-[var(--color-surface)] p-3">
            <div className="text-[10px] uppercase tracking-wide text-[var(--color-muted)]">{c.label}</div>
            <div className={"mt-1 text-base font-semibold tabular-nums " + (c.tone ?? "")}>{c.value}</div>
          </div>
        ))}
      </section>

      <section className="rounded border border-[var(--color-border)] bg-[var(--color-surface)] p-4 text-xs text-[var(--color-muted)] leading-relaxed">
        <div className="font-semibold text-[var(--color-fg)]">Formula · 0 to 100</div>
        <div className="mt-1">
          base 100 · minus days_since_last_visit / 90 × 25 (cap 25) · minus open_codered × 15 (cap 30) ·
          minus open_disputes × 10 (cap 20) · minus sla_breach_180d × 5 (cap 25) ·
          plus 10 promoter · minus 15 detractor · clamp 0 to 100.
        </div>
        <div className="mt-2 font-semibold text-[var(--color-fg)]">Intervention priorities</div>
        <ul className="mt-1 list-disc pl-5 space-y-0.5">
          <li>Critical (under 30) — founder call this week · winback + service-credit offer.</li>
          <li>At risk (30 to 59) — ops outreach · spot-audit visit + escalation review.</li>
          <li>Watch (60 to 79) — scheduled QBR · check NPS detractor signal.</li>
          <li>Healthy (≥ 80) — protect retention · upsell to higher AMC tier.</li>
        </ul>
        <div className="mt-2 font-semibold text-[var(--color-fg)]">Bands</div>
        <div className="mt-1">healthy ≥ 80 · watch ≥ 60 · at_risk ≥ 30 · critical {"<"} 30.</div>
      </section>

      <DataTable
        columns={cols}
        rows={rows}
        rowKey={(r) => r.hospital_org_id}
        emptyMessage="No active AMC hospitals."
      />
    </div>
  );
}
