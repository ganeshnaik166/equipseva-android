import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Cash-payment surveys summary — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = {
  surveys_total: number;
  surveys_90d: number;
  surveys_30d: number;
  surveys_7d: number;
  asked_cash_90d: number;
  no_cash_90d: number;
  declined_90d: number;
  asked_cash_rate_pct_90d: number;
  asked_cash_rate_pct_30d: number;
  declined_rate_pct_90d: number;
  distinct_flagged_engineers_90d: number;
  engineers_over_threshold_90d: number;
  last_asked_cash_at: string | null;
  top_offender_name: string | null;
  top_offender_asked_cash_90d: number;
  top_offender_engineer_id: string | null;
  top_hotspot_state: string | null;
  top_hotspot_state_asked_cash: number;
  pending_surveys_7d: number;
  completed_jobs_7d: number;
};

function fmtPct(n: number | null | undefined): string {
  if (n === null || n === undefined) return "—";
  return `${Number(n).toFixed(1)}%`;
}

function fmtTs(s: string | null): string {
  if (!s) return "—";
  try {
    return new Date(s).toLocaleString("en-IN", { timeZone: "Asia/Kolkata" });
  } catch {
    return s;
  }
}

function Kpi({
  label,
  value,
  hint,
  tone,
}: {
  label: string;
  value: string;
  hint?: string;
  tone?: "ok" | "warn" | "danger" | "muted";
}) {
  const toneClass =
    tone === "danger"
      ? "text-[var(--color-danger)]"
      : tone === "warn"
      ? "text-[var(--color-warn)]"
      : tone === "ok"
      ? "text-[var(--color-ok)]"
      : "";
  return (
    <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4">
      <div className="text-[10px] font-medium uppercase tracking-wide text-[var(--color-muted)]">
        {label}
      </div>
      <div className={`mt-1 text-2xl font-semibold tabular-nums ${toneClass}`}>{value}</div>
      {hint ? (
        <div className="mt-1 text-[11px] text-[var(--color-muted)]">{hint}</div>
      ) : null}
    </div>
  );
}

export default async function CashPaymentSurveysSummaryPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_cash_payment_surveys_summary");
  if (error) throw new Error(`founder_cash_payment_surveys_summary: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const r: Row = rows[0] ?? ({
    surveys_total: 0,
    surveys_90d: 0,
    surveys_30d: 0,
    surveys_7d: 0,
    asked_cash_90d: 0,
    no_cash_90d: 0,
    declined_90d: 0,
    asked_cash_rate_pct_90d: 0,
    asked_cash_rate_pct_30d: 0,
    declined_rate_pct_90d: 0,
    distinct_flagged_engineers_90d: 0,
    engineers_over_threshold_90d: 0,
    last_asked_cash_at: null,
    top_offender_name: null,
    top_offender_asked_cash_90d: 0,
    top_offender_engineer_id: null,
    top_hotspot_state: null,
    top_hotspot_state_asked_cash: 0,
    pending_surveys_7d: 0,
    completed_jobs_7d: 0,
  } as Row);

  const coverageDenom = Number(r.completed_jobs_7d) || 0;
  const coverageMissing = Number(r.pending_surveys_7d) || 0;
  const coveragePct =
    coverageDenom > 0
      ? Math.max(0, Math.min(100, ((coverageDenom - coverageMissing) / coverageDenom) * 100))
      : 0;

  const askedRate90 = Number(r.asked_cash_rate_pct_90d) || 0;
  const askedRateTone: "ok" | "warn" | "danger" =
    askedRate90 >= 10 ? "danger" : askedRate90 >= 3 ? "warn" : "ok";

  const overThreshold = Number(r.engineers_over_threshold_90d) || 0;
  const overThreshTone: "ok" | "warn" | "danger" =
    overThreshold >= 5 ? "danger" : overThreshold >= 1 ? "warn" : "ok";

  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Cash-payment surveys summary</h1>
        <span className="text-xs text-[var(--color-muted)]">
          Engineer cash-collection confessions · 3 strikes in 90d = auto-suspend signal
        </span>
      </header>

      <section>
        <h2 className="mb-3 text-xs font-medium uppercase tracking-wide text-[var(--color-muted)]">
          Volume
        </h2>
        <div className="grid grid-cols-2 gap-3 md:grid-cols-4">
          <Kpi label="Total surveys" value={formatNumber(r.surveys_total)} hint="All time" />
          <Kpi label="Surveys 90d" value={formatNumber(r.surveys_90d)} />
          <Kpi label="Surveys 30d" value={formatNumber(r.surveys_30d)} />
          <Kpi label="Surveys 7d" value={formatNumber(r.surveys_7d)} />
        </div>
      </section>

      <section>
        <h2 className="mb-3 text-xs font-medium uppercase tracking-wide text-[var(--color-muted)]">
          Leakage signal (90d window)
        </h2>
        <div className="grid grid-cols-2 gap-3 md:grid-cols-4">
          <Kpi
            label="Asked-cash rate 90d"
            value={fmtPct(r.asked_cash_rate_pct_90d)}
            hint={`${formatNumber(r.asked_cash_90d)} of ${formatNumber(r.surveys_90d)} responses`}
            tone={askedRateTone}
          />
          <Kpi
            label="Asked-cash rate 30d"
            value={fmtPct(r.asked_cash_rate_pct_30d)}
            hint="Recent trend"
          />
          <Kpi
            label="Declined-to-answer 90d"
            value={fmtPct(r.declined_rate_pct_90d)}
            hint="Soft signal (avoidance)"
            tone="muted"
          />
          <Kpi
            label="Last cash flag"
            value={fmtTs(r.last_asked_cash_at)}
            hint="IST"
          />
        </div>
      </section>

      <section>
        <h2 className="mb-3 text-xs font-medium uppercase tracking-wide text-[var(--color-muted)]">
          Offending engineers (90d)
        </h2>
        <div className="grid grid-cols-2 gap-3 md:grid-cols-3">
          <Kpi
            label="Distinct flagged engineers"
            value={formatNumber(r.distinct_flagged_engineers_90d)}
            hint="Have ≥ 1 asked-cash confession"
          />
          <Kpi
            label={`Over auto-suspend threshold (${"≥"} 3)`}
            value={formatNumber(r.engineers_over_threshold_90d)}
            hint="Eligible for cash-auto-suspend"
            tone={overThreshTone}
          />
          <Kpi
            label="Top offender 90d"
            value={r.top_offender_name ?? "—"}
            hint={`${formatNumber(r.top_offender_asked_cash_90d)} cash flags`}
            tone={Number(r.top_offender_asked_cash_90d) >= 3 ? "danger" : undefined}
          />
        </div>
      </section>

      <section>
        <h2 className="mb-3 text-xs font-medium uppercase tracking-wide text-[var(--color-muted)]">
          Geography & coverage
        </h2>
        <div className="grid grid-cols-2 gap-3 md:grid-cols-3">
          <Kpi
            label="Top hotspot state"
            value={r.top_hotspot_state ?? "—"}
            hint={`${formatNumber(r.top_hotspot_state_asked_cash)} hospitals reporting cash asks`}
          />
          <Kpi
            label="Survey coverage 7d"
            value={fmtPct(coveragePct)}
            hint={`${formatNumber(coverageDenom - coverageMissing)} of ${formatNumber(coverageDenom)} eligible jobs answered`}
            tone={coveragePct >= 60 ? "ok" : coveragePct >= 30 ? "warn" : "danger"}
          />
          <Kpi
            label="Pending surveys 7d"
            value={formatNumber(coverageMissing)}
            hint="Eligible (24h–7d) completed jobs with no response"
            tone={coverageMissing > 0 ? "warn" : "ok"}
          />
        </div>
      </section>

      <footer className="rounded-md border border-[var(--color-border)] bg-[var(--color-surface)] p-3 text-[11px] text-[var(--color-muted)]">
        <p>
          {`Surveys ping the hospital 24h after a repair job hits 'completed'; window closes at 7 days. `}
          {`Three 'asked_cash' confessions on the same engineer in 90d trigger the cash-auto-suspend pipeline. `}
          {`Asked-cash rate ${"≥"} 10% across 90d = systemic off-platform leakage problem; investigate immediately.`}
        </p>
      </footer>
    </div>
  );
}
