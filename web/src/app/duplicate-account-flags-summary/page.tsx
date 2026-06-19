import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Duplicate account flags summary — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = {
  total_flags: number;
  open_flags: number;
  investigating_flags: number;
  confirmed_flags: number;
  false_positive_flags: number;
  resolved_flags: number;
  open_critical: number;
  open_high: number;
  open_medium: number;
  open_low: number;
  shared_aadhaar_total: number;
  shared_pan_total: number;
  shared_phone_total: number;
  shared_phone_norm_total: number;
  shared_email_domain_total: number;
  name_fuzzy_total: number;
  shared_device_id_total: number;
  confirmed_rate_pct: number;
  oldest_open_age_days: number;
  flags_last_7d: number;
  flags_last_30d: number;
  confirmed_last_30d: number;
  snapshot_at: string;
};

function Kpi({ label, value, tone, hint }: { label: string; value: string; tone?: string; hint?: string }) {
  return (
    <div className="rounded border border-[var(--color-border)] bg-[var(--color-surface)] p-3">
      <div className="text-[10px] uppercase tracking-wide text-[var(--color-muted)]">{label}</div>
      <div className={`mt-1 text-lg font-semibold tabular-nums ${tone ?? ""}`}>{value}</div>
      {hint && <div className="mt-0.5 text-[10px] text-[var(--color-muted)]">{hint}</div>}
    </div>
  );
}

export default async function DuplicateAccountFlagsSummaryPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_duplicate_account_flags_summary");
  if (error) throw new Error(`founder_duplicate_account_flags_summary: ${error.message}`);
  const row = (Array.isArray(data) ? data[0] : data) as Row | undefined;

  if (!row) {
    return (
      <div className="space-y-6">
        <header>
          <h1 className="text-xl font-semibold">Duplicate account flags summary</h1>
        </header>
        <div className="text-xs text-[var(--color-muted)]">No flags recorded.</div>
      </div>
    );
  }

  const openActionable = Number(row.open_flags) + Number(row.investigating_flags);
  const queueTone =
    Number(row.open_critical) > 0
      ? "text-[var(--color-danger)]"
      : Number(row.open_high) > 0
      ? "text-[var(--color-warn)]"
      : "text-[var(--color-ok)]";
  const ageTone =
    Number(row.oldest_open_age_days) > 14
      ? "text-[var(--color-danger)]"
      : Number(row.oldest_open_age_days) > 7
      ? "text-[var(--color-warn)]"
      : "text-[var(--color-ok)]";
  const confRate = Number(row.confirmed_rate_pct);
  const confTone =
    confRate >= 50 ? "text-[var(--color-danger)]" : confRate >= 25 ? "text-[var(--color-warn)]" : "text-[var(--color-ok)]";

  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Duplicate account flags summary</h1>
        <span className="text-xs text-[var(--color-muted)]">
          referral-bounty + AMC-credit fraud detector · alert-only
        </span>
      </header>

      <section>
        <h2 className="mb-2 text-xs font-semibold uppercase tracking-wide text-[var(--color-muted)]">
          Actionable queue
        </h2>
        <div className="grid grid-cols-2 gap-2 md:grid-cols-4">
          <Kpi label="Open + investigating" value={formatNumber(openActionable)} tone={queueTone} />
          <Kpi label="Open · critical" value={formatNumber(row.open_critical)} tone="text-[var(--color-danger)]" />
          <Kpi label="Open · high" value={formatNumber(row.open_high)} tone="text-[var(--color-warn)]" />
          <Kpi label="Oldest open" value={`${formatNumber(row.oldest_open_age_days)}d`} tone={ageTone} hint="age of oldest unresolved flag" />
        </div>
      </section>

      <section>
        <h2 className="mb-2 text-xs font-semibold uppercase tracking-wide text-[var(--color-muted)]">
          Lifecycle (all-time)
        </h2>
        <div className="grid grid-cols-2 gap-2 md:grid-cols-4">
          <Kpi label="Total flags" value={formatNumber(row.total_flags)} />
          <Kpi label="Confirmed" value={formatNumber(row.confirmed_flags)} tone="text-[var(--color-danger)]" />
          <Kpi label="False positive" value={formatNumber(row.false_positive_flags)} tone="text-[var(--color-muted)]" />
          <Kpi
            label="Confirmed rate"
            value={`${confRate}%`}
            tone={confTone}
            hint="confirmed / (confirmed + FP)"
          />
        </div>
      </section>

      <section>
        <h2 className="mb-2 text-xs font-semibold uppercase tracking-wide text-[var(--color-muted)]">
          Signal mix
        </h2>
        <div className="grid grid-cols-2 gap-2 md:grid-cols-4">
          <Kpi label="Shared Aadhaar" value={formatNumber(row.shared_aadhaar_total)} tone="text-[var(--color-danger)]" hint="CRITICAL" />
          <Kpi label="Shared PAN" value={formatNumber(row.shared_pan_total)} tone="text-[var(--color-danger)]" hint="CRITICAL" />
          <Kpi label="Shared phone" value={formatNumber(Number(row.shared_phone_total) + Number(row.shared_phone_norm_total))} tone="text-[var(--color-warn)]" hint="raw + normalized" />
          <Kpi label="Shared device id" value={formatNumber(row.shared_device_id_total)} tone="text-[var(--color-warn)]" hint="HIGH" />
          <Kpi label="Email domain" value={formatNumber(row.shared_email_domain_total)} hint="MEDIUM" />
          <Kpi label="Name fuzzy match" value={formatNumber(row.name_fuzzy_total)} hint="MEDIUM" />
        </div>
      </section>

      <section>
        <h2 className="mb-2 text-xs font-semibold uppercase tracking-wide text-[var(--color-muted)]">
          Recency
        </h2>
        <div className="grid grid-cols-2 gap-2 md:grid-cols-4">
          <Kpi label="New flags · 7d" value={formatNumber(row.flags_last_7d)} />
          <Kpi label="New flags · 30d" value={formatNumber(row.flags_last_30d)} />
          <Kpi label="Confirmed · 30d" value={formatNumber(row.confirmed_last_30d)} tone="text-[var(--color-danger)]" />
        </div>
      </section>

      <footer className="text-[10px] text-[var(--color-muted)]">
        Snapshot at {new Date(row.snapshot_at).toLocaleString("en-IN", { timeZone: "Asia/Kolkata" })} IST · source:
        public.duplicate_account_flags (r501)
      </footer>
    </div>
  );
}
