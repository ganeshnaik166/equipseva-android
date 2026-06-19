import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "AMC admin escalations summary — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = {
  total_escalations: number;
  open_escalations: number;
  resolved_escalations: number;
  open_pct: number;
  created_last_7d: number;
  created_last_30d: number;
  resolved_last_30d: number;
  reason_no_engineers_available: number;
  reason_rotation_exhausted: number;
  reason_manual: number;
  unique_contracts_affected: number;
  oldest_open_age_days: number;
};

function Kpi({ label, value, hint, tone }: { label: string; value: string; hint?: string; tone?: "ok" | "warn" | "danger" | "muted" }) {
  const color =
    tone === "ok" ? "text-[var(--color-ok)]" :
    tone === "warn" ? "text-[var(--color-warn)]" :
    tone === "danger" ? "text-[var(--color-danger)]" :
    tone === "muted" ? "text-[var(--color-muted)]" :
    "";
  return (
    <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4">
      <div className="text-[10px] uppercase tracking-wide text-[var(--color-muted)]">{label}</div>
      <div className={`mt-1 text-lg font-semibold tabular-nums ${color}`}>{value}</div>
      {hint ? <div className="mt-0.5 text-[10px] text-[var(--color-muted)]">{hint}</div> : null}
    </div>
  );
}

export default async function AmcAdminEscalationsSummaryPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_amc_admin_escalations_summary");
  if (error) throw new Error(`founder_amc_admin_escalations_summary: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const r: Row = rows[0] ?? {
    total_escalations: 0,
    open_escalations: 0,
    resolved_escalations: 0,
    open_pct: 0,
    created_last_7d: 0,
    created_last_30d: 0,
    resolved_last_30d: 0,
    reason_no_engineers_available: 0,
    reason_rotation_exhausted: 0,
    reason_manual: 0,
    unique_contracts_affected: 0,
    oldest_open_age_days: 0,
  };

  const openTone: "ok" | "warn" | "danger" =
    r.open_escalations === 0 ? "ok" :
    r.open_escalations <= 5 ? "warn" : "danger";

  const ageTone: "ok" | "warn" | "danger" =
    r.oldest_open_age_days === 0 ? "ok" :
    r.oldest_open_age_days <= 3 ? "warn" : "danger";

  const totalReason = r.reason_no_engineers_available + r.reason_rotation_exhausted + r.reason_manual;
  const pct = (n: number) => totalReason > 0 ? Math.round((n / totalReason) * 1000) / 10 : 0;

  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">AMC admin escalations summary</h1>
        <span className="text-xs text-[var(--color-muted)]">
          Ops triage queue: open backlog, reason mix, oldest unresolved, weekly intake
        </span>
      </header>

      <section>
        <h2 className="mb-3 text-[11px] font-semibold uppercase tracking-wide text-[var(--color-muted)]">Queue state</h2>
        <div className="grid grid-cols-1 gap-3 sm:grid-cols-2 lg:grid-cols-4">
          <Kpi label="Total escalations" value={formatNumber(r.total_escalations)} hint="all-time logged" />
          <Kpi label="Open" value={formatNumber(r.open_escalations)} tone={openTone} hint="unresolved" />
          <Kpi label="Resolved" value={formatNumber(r.resolved_escalations)} tone="ok" />
          <Kpi label="% open" value={`${r.open_pct}%`} tone={r.open_pct <= 20 ? "ok" : r.open_pct <= 50 ? "warn" : "danger"} />
        </div>
      </section>

      <section>
        <h2 className="mb-3 text-[11px] font-semibold uppercase tracking-wide text-[var(--color-muted)]">Velocity</h2>
        <div className="grid grid-cols-1 gap-3 sm:grid-cols-2 lg:grid-cols-4">
          <Kpi label="Created last 7d" value={formatNumber(r.created_last_7d)} hint="weekly intake" />
          <Kpi label="Created last 30d" value={formatNumber(r.created_last_30d)} />
          <Kpi label="Resolved last 30d" value={formatNumber(r.resolved_last_30d)} tone="ok" />
          <Kpi
            label="Oldest open age"
            value={`${r.oldest_open_age_days}d`}
            tone={ageTone}
            hint="days since created"
          />
        </div>
      </section>

      <section>
        <h2 className="mb-3 text-[11px] font-semibold uppercase tracking-wide text-[var(--color-muted)]">Reason mix &amp; scope</h2>
        <div className="grid grid-cols-1 gap-3 sm:grid-cols-2 lg:grid-cols-4">
          <Kpi
            label="No engineers available"
            value={formatNumber(r.reason_no_engineers_available)}
            hint={`${pct(r.reason_no_engineers_available)}% of total`}
            tone={r.reason_no_engineers_available > 0 ? "warn" : "muted"}
          />
          <Kpi
            label="Rotation exhausted"
            value={formatNumber(r.reason_rotation_exhausted)}
            hint={`${pct(r.reason_rotation_exhausted)}% of total`}
            tone={r.reason_rotation_exhausted > 0 ? "warn" : "muted"}
          />
          <Kpi
            label="Manual"
            value={formatNumber(r.reason_manual)}
            hint={`${pct(r.reason_manual)}% of total`}
            tone="muted"
          />
          <Kpi
            label="Contracts affected"
            value={formatNumber(r.unique_contracts_affected)}
            hint="distinct AMC contracts"
          />
        </div>
      </section>

      <p className="text-[11px] text-[var(--color-muted)]">
        Source: <code>public.amc_admin_escalations</code> (v21 engineer rotation). Logged by <code>assign_next_available_amc_engineer</code>
        when rotation cannot place a visit. Ops-only RLS (admin / founder). Resolution timestamps captured on triage close.
      </p>
    </div>
  );
}
