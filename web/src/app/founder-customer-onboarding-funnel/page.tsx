import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Founder customer onboarding funnel — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type SummaryRow = {
  total_runs: number;
  lead_count: number;
  qualified_count: number;
  contract_signed_count: number;
  kyc_complete_count: number;
  first_visit_scheduled_count: number;
  first_visit_completed_count: number;
  active_count: number;
  dormant_count: number;
  churned_count: number;
  conversion_pct_lead_to_active: number;
  conversion_pct_contract_to_active: number;
  median_days_lead_to_active: number;
  blocked_count: number;
  top_lead_source: string | null;
  generated_at: string;
};

type RunRow = {
  id: string;
  hospital_org_id: string | null;
  hospital_name: string | null;
  hospital_city: string | null;
  funnel_stage: string;
  stage_entered_at: string | null;
  lead_source: string | null;
  kyc_completed_at: string | null;
  contract_signed_at: string | null;
  first_visit_completed_at: string | null;
  activated_at: string | null;
  churned_at: string | null;
  blocker_reason: string | null;
  notes: string | null;
  age_days: number | null;
  created_at: string;
  updated_at: string;
};

const STAGES: { key: string; label: string }[] = [
  { key: "lead",                  label: "Lead" },
  { key: "qualified",             label: "Qualified" },
  { key: "contract_signed",       label: "Contract signed" },
  { key: "kyc_complete",          label: "KYC complete" },
  { key: "first_visit_scheduled", label: "First visit scheduled" },
  { key: "first_visit_completed", label: "First visit completed" },
  { key: "active",                label: "Active" },
  { key: "dormant",               label: "Dormant" },
  { key: "churned",               label: "Churned" },
];

const STAGE_TONE: Record<string, string> = {
  lead:                  "text-[var(--color-muted)]",
  qualified:             "text-[var(--color-info)]",
  contract_signed:       "text-[var(--color-info)]",
  kyc_complete:          "text-[var(--color-info)]",
  first_visit_scheduled: "text-[var(--color-warn)]",
  first_visit_completed: "text-[var(--color-warn)]",
  active:                "text-[var(--color-ok)]",
  dormant:               "text-[var(--color-warn)]",
  churned:               "text-[var(--color-danger)]",
};

function Card({ label, value, tone, sub }: { label: string; value: string | number; tone?: string; sub?: string }) {
  return (
    <div className={`rounded-lg border ${tone ?? "border-[var(--color-border)]"} bg-[var(--color-surface)] p-4`}>
      <div className="text-[10px] uppercase tracking-wider text-[var(--color-muted)]">{label}</div>
      <div className="mt-1 text-2xl font-bold tabular-nums">{value}</div>
      {sub ? <div className="mt-1 text-[10px] text-[var(--color-muted)]">{sub}</div> : null}
    </div>
  );
}

function activeTone(pct: number): string {
  if (pct >= 40) return "border-[var(--color-ok)]";
  if (pct >= 20) return "border-[var(--color-warn)]";
  return "border-[var(--color-danger)]";
}

function blockedTone(n: number): string {
  if (n === 0) return "border-[var(--color-ok)]";
  if (n <= 5)  return "border-[var(--color-warn)]";
  return "border-[var(--color-danger)]";
}

function medianTone(d: number): string {
  if (d === 0)  return "border-[var(--color-border)]";
  if (d <= 14)  return "border-[var(--color-ok)]";
  if (d <= 45)  return "border-[var(--color-warn)]";
  return "border-[var(--color-danger)]";
}

function bar(count: number, max: number): string {
  if (max <= 0) return "";
  const w = Math.round((count / max) * 30);
  return "█".repeat(Math.max(w, count > 0 ? 1 : 0));
}

export default async function Page() {
  await requireFounder();
  const sb = await getSupabaseServerClient();

  const [summaryRes, recentRes] = await Promise.all([
    sb.rpc("founder_customer_onboarding_funnel_summary"),
    sb.rpc("founder_customer_onboarding_funnel_recent", { p_stage: null, p_limit: 100 }),
  ]);

  const s: SummaryRow | null = (summaryRes.data?.[0] as SummaryRow) ?? null;
  const runs: RunRow[] = (recentRes.data as RunRow[] | null) ?? [];

  const stageCounts: Record<string, number> = s ? {
    lead:                  s.lead_count,
    qualified:             s.qualified_count,
    contract_signed:       s.contract_signed_count,
    kyc_complete:          s.kyc_complete_count,
    first_visit_scheduled: s.first_visit_scheduled_count,
    first_visit_completed: s.first_visit_completed_count,
    active:                s.active_count,
    dormant:               s.dormant_count,
    churned:               s.churned_count,
  } : {};
  const maxStage = Math.max(1, ...Object.values(stageCounts));

  return (
    <main className="mx-auto max-w-7xl px-4 py-6 text-[var(--color-text)]">
      <header className="mb-4 flex items-center justify-between gap-2">
        <div>
          <h1 className="text-xl font-bold">Customer onboarding funnel</h1>
          <p className="mt-1 text-xs text-[var(--color-muted)]">
            Per-hospital lifecycle · lead {"→"} qualified {"→"} contract {"→"} KYC {"→"} first visit {"→"} active
          </p>
        </div>
        <div className="text-[10px] text-[var(--color-muted)]">
          {s?.generated_at ? new Date(s.generated_at).toLocaleString() : "no data"}
        </div>
      </header>

      {!s ? (
        <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-6 text-sm text-[var(--color-muted)]">
          No funnel data yet. Register hospitals via{" "}
          <code className="rounded bg-[var(--color-bg)] px-1">log_founder_onboarding_register</code>{" "}
          and advance via{" "}
          <code className="rounded bg-[var(--color-bg)] px-1">log_founder_onboarding_advance</code>.
        </div>
      ) : (
        <>
          {/* 16 KPI cards */}
          <section className="grid grid-cols-2 gap-3 sm:grid-cols-3 md:grid-cols-4">
            <Card label="Total runs"               value={formatNumber(s.total_runs)} />
            <Card label="Lead"                     value={formatNumber(s.lead_count)} />
            <Card label="Qualified"                value={formatNumber(s.qualified_count)} />
            <Card label="Contract signed"          value={formatNumber(s.contract_signed_count)} />
            <Card label="KYC complete"             value={formatNumber(s.kyc_complete_count)} />
            <Card label="First visit scheduled"    value={formatNumber(s.first_visit_scheduled_count)} />
            <Card label="First visit completed"    value={formatNumber(s.first_visit_completed_count)} />
            <Card label="Active"                   value={formatNumber(s.active_count)} tone={activeTone(s.conversion_pct_lead_to_active)} />
            <Card label="Dormant"                  value={formatNumber(s.dormant_count)} />
            <Card label="Churned"                  value={formatNumber(s.churned_count)} />
            <Card label="Lead → active %"          value={`${s.conversion_pct_lead_to_active}%`}     tone={activeTone(s.conversion_pct_lead_to_active)} sub="of all runs" />
            <Card label="Contract → active %"      value={`${s.conversion_pct_contract_to_active}%`} sub="of contracted hospitals" />
            <Card label="Median days to active"    value={`${s.median_days_lead_to_active}d`} tone={medianTone(s.median_days_lead_to_active)} sub="lead → activated_at" />
            <Card label="Blocked"                  value={formatNumber(s.blocked_count)} tone={blockedTone(s.blocked_count)} sub="blocker_reason set" />
            <Card label="Top lead source"          value={s.top_lead_source ?? "—"} sub="highest run count" />
            <Card label="Generated"                value={new Date(s.generated_at).toLocaleTimeString()} sub="server now()" />
          </section>

          {/* 9-stage funnel bars */}
          <section className="mt-8">
            <h2 className="text-sm font-semibold uppercase tracking-wide text-[var(--color-muted)]">
              Funnel by stage
            </h2>
            <div className="mt-3 overflow-x-auto rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4">
              <pre className="font-mono text-[11px] leading-5 text-[var(--color-text)]">
                {STAGES.map((st) => {
                  const c = stageCounts[st.key] ?? 0;
                  const pad = " ".repeat(Math.max(0, 24 - st.label.length));
                  const num = String(c).padStart(5, " ");
                  return `${st.label}${pad}${num}  ${bar(c, maxStage)}\n`;
                }).join("")}
              </pre>
            </div>
          </section>

          {/* 100-row ledger */}
          <section className="mt-8">
            <h2 className="text-sm font-semibold uppercase tracking-wide text-[var(--color-muted)]">
              Recent runs ({runs.length})
            </h2>
            <div className="mt-3 overflow-x-auto rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)]">
              <table className="min-w-full text-[12px]">
                <thead className="border-b border-[var(--color-border)] text-left text-[10px] uppercase tracking-wider text-[var(--color-muted)]">
                  <tr>
                    <th className="px-3 py-2">Hospital</th>
                    <th className="px-3 py-2">City</th>
                    <th className="px-3 py-2">Stage</th>
                    <th className="px-3 py-2">Source</th>
                    <th className="px-3 py-2 text-right">Age (d)</th>
                    <th className="px-3 py-2">Stage entered</th>
                    <th className="px-3 py-2">Blocker</th>
                  </tr>
                </thead>
                <tbody>
                  {runs.map((r) => (
                    <tr key={r.id} className="border-b border-[var(--color-border)]/40 last:border-0">
                      <td className="px-3 py-2 font-medium">{r.hospital_name ?? r.hospital_org_id?.slice(0, 8) ?? "—"}</td>
                      <td className="px-3 py-2 text-[var(--color-muted)]">{r.hospital_city ?? "—"}</td>
                      <td className={`px-3 py-2 font-semibold ${STAGE_TONE[r.funnel_stage] ?? ""}`}>{r.funnel_stage}</td>
                      <td className="px-3 py-2 text-[var(--color-muted)]">{r.lead_source ?? "—"}</td>
                      <td className="px-3 py-2 text-right tabular-nums">{r.age_days ?? "—"}</td>
                      <td className="px-3 py-2 text-[var(--color-muted)]">
                        {r.stage_entered_at ? new Date(r.stage_entered_at).toLocaleDateString() : "—"}
                      </td>
                      <td className="px-3 py-2 text-[var(--color-muted)]">
                        {r.blocker_reason ? <span className="text-[var(--color-danger)]">{r.blocker_reason}</span> : "—"}
                      </td>
                    </tr>
                  ))}
                  {runs.length === 0 ? (
                    <tr>
                      <td className="px-3 py-6 text-center text-[var(--color-muted)]" colSpan={7}>
                        No runs yet.
                      </td>
                    </tr>
                  ) : null}
                </tbody>
              </table>
            </div>
          </section>

          {/* Notes */}
          <section className="mt-8 rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4 text-[12px] text-[var(--color-muted)]">
            <h3 className="text-[10px] font-semibold uppercase tracking-wider text-[var(--color-muted)]">
              Onboarding SLA
            </h3>
            <ul className="mt-2 list-disc space-y-1 pl-5">
              <li>Lead {"→"} qualified target: {"≤"} 3 days (auto-mark dormant after 14 days no contact).</li>
              <li>Contract {"→"} KYC target: {"≤"} 5 business days (Udyam + GSTIN + bank).</li>
              <li>KYC {"→"} first visit scheduled: {"≤"} 7 days; first-visit-completed: {"≤"} 14 days.</li>
              <li>Median lead {"→"} active target: {"≤"} 21 days; flagged red if {"≥"} 45 days.</li>
              <li>Any run with blocker_reason set for {"≥"} 7 days escalates to founder action center.</li>
              <li>Lead-source mix informs r1361 acquisition attribution spend allocation.</li>
            </ul>
          </section>
        </>
      )}
    </main>
  );
}
