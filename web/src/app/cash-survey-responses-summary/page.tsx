import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Cash-survey responses summary — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = {
  responses_90d: number;
  asked_cash_90d: number;
  no_cash_90d: number;
  declined_90d: number;
  asked_to_no_ratio_90d: number;
  distinct_reporters_90d: number;
  hospitals_reporting_2plus_90d: number;
  top_reporter_user_id: string | null;
  top_reporter_asked_cash_90d: number;
  engineers_with_repeat_90d: number;
  max_strikes_single_engineer: number;
  engineers_3plus_strikes_90d: number;
  asked_cash_this_week: number;
  asked_cash_prior_week: number;
  asked_cash_wow_delta_pct: number;
  last_response_at: string | null;
};

function fmtTs(s: string | null): string {
  if (!s) return "—";
  try {
    return new Date(s).toLocaleString("en-IN", { timeZone: "Asia/Kolkata" });
  } catch {
    return s;
  }
}

function fmtRatio(n: number | null | undefined): string {
  if (n === null || n === undefined) return "—";
  return `${Number(n).toFixed(3)}×`;
}

function fmtDelta(n: number | null | undefined): string {
  if (n === null || n === undefined) return "—";
  const v = Number(n);
  const sign = v > 0 ? "+" : "";
  return `${sign}${v.toFixed(1)}%`;
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

export default async function CashSurveyResponsesSummaryPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_cash_survey_responses_summary");
  if (error) throw new Error(`founder_cash_survey_responses_summary: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const r: Row = rows[0] ?? ({
    responses_90d: 0,
    asked_cash_90d: 0,
    no_cash_90d: 0,
    declined_90d: 0,
    asked_to_no_ratio_90d: 0,
    distinct_reporters_90d: 0,
    hospitals_reporting_2plus_90d: 0,
    top_reporter_user_id: null,
    top_reporter_asked_cash_90d: 0,
    engineers_with_repeat_90d: 0,
    max_strikes_single_engineer: 0,
    engineers_3plus_strikes_90d: 0,
    asked_cash_this_week: 0,
    asked_cash_prior_week: 0,
    asked_cash_wow_delta_pct: 0,
    last_response_at: null,
  } as Row);

  const askedShare =
    Number(r.responses_90d) > 0
      ? (Number(r.asked_cash_90d) * 100) / Number(r.responses_90d)
      : 0;
  const askedShareTone: "ok" | "warn" | "danger" =
    askedShare >= 10 ? "danger" : askedShare >= 3 ? "warn" : "ok";

  const wowDelta = Number(r.asked_cash_wow_delta_pct) || 0;
  const wowTone: "ok" | "warn" | "danger" =
    wowDelta > 25 ? "danger" : wowDelta > 0 ? "warn" : "ok";

  const max3 = Number(r.max_strikes_single_engineer) || 0;
  const max3Tone: "ok" | "warn" | "danger" =
    max3 >= 5 ? "danger" : max3 >= 3 ? "warn" : "ok";

  const cohort = Number(r.engineers_3plus_strikes_90d) || 0;
  const cohortTone: "ok" | "warn" | "danger" =
    cohort >= 5 ? "danger" : cohort >= 1 ? "warn" : "ok";

  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Cash-survey responses summary</h1>
        <span className="text-xs text-[var(--color-muted)]">
          Response-shape lens on cash_survey_responses (companion to /cash-payment-surveys-summary)
        </span>
      </header>

      <section>
        <h2 className="mb-3 text-xs font-medium uppercase tracking-wide text-[var(--color-muted)]">
          Response mix (90d)
        </h2>
        <div className="grid grid-cols-2 gap-3 md:grid-cols-4">
          <Kpi
            label="Responses 90d"
            value={formatNumber(r.responses_90d)}
            hint="All response kinds"
          />
          <Kpi
            label="Asked-cash 90d"
            value={formatNumber(r.asked_cash_90d)}
            hint={`${askedShare.toFixed(1)}% of responses`}
            tone={askedShareTone}
          />
          <Kpi
            label="No-cash 90d"
            value={formatNumber(r.no_cash_90d)}
            hint="Clean confirmations"
            tone="ok"
          />
          <Kpi
            label="Declined-to-answer 90d"
            value={formatNumber(r.declined_90d)}
            hint="Avoidance signal"
            tone="muted"
          />
        </div>
        <div className="mt-3 grid grid-cols-2 gap-3 md:grid-cols-4">
          <Kpi
            label="Asked / No-cash ratio"
            value={fmtRatio(r.asked_to_no_ratio_90d)}
            hint="Lower is better"
            tone={Number(r.asked_to_no_ratio_90d) >= 0.1 ? "danger" : "ok"}
          />
        </div>
      </section>

      <section>
        <h2 className="mb-3 text-xs font-medium uppercase tracking-wide text-[var(--color-muted)]">
          Reporter concentration (90d, asked-cash only)
        </h2>
        <div className="grid grid-cols-2 gap-3 md:grid-cols-3">
          <Kpi
            label="Distinct reporting hospitals"
            value={formatNumber(r.distinct_reporters_90d)}
            hint="Unique hospital_user_id"
          />
          <Kpi
            label="Hospitals reporting 2+ times"
            value={formatNumber(r.hospitals_reporting_2plus_90d)}
            hint="Repeat reporters (concentration risk if low)"
          />
          <Kpi
            label="Top reporter strikes"
            value={formatNumber(r.top_reporter_asked_cash_90d)}
            hint={r.top_reporter_user_id ? `user ${r.top_reporter_user_id.slice(0, 8)}…` : "no reports yet"}
            tone={Number(r.top_reporter_asked_cash_90d) >= 3 ? "warn" : undefined}
          />
        </div>
      </section>

      <section>
        <h2 className="mb-3 text-xs font-medium uppercase tracking-wide text-[var(--color-muted)]">
          Recidivism cohort (90d)
        </h2>
        <div className="grid grid-cols-2 gap-3 md:grid-cols-3">
          <Kpi
            label="Engineers with repeat (≥2)"
            value={formatNumber(r.engineers_with_repeat_90d)}
            hint="Second-strike pool"
            tone={Number(r.engineers_with_repeat_90d) >= 5 ? "warn" : undefined}
          />
          <Kpi
            label="Engineers ≥ 3 strikes"
            value={formatNumber(r.engineers_3plus_strikes_90d)}
            hint="Auto-suspend eligible cohort"
            tone={cohortTone}
          />
          <Kpi
            label="Max strikes (single engineer)"
            value={formatNumber(r.max_strikes_single_engineer)}
            hint="Worst-case streak holder"
            tone={max3Tone}
          />
        </div>
      </section>

      <section>
        <h2 className="mb-3 text-xs font-medium uppercase tracking-wide text-[var(--color-muted)]">
          Temporal signal
        </h2>
        <div className="grid grid-cols-2 gap-3 md:grid-cols-3">
          <Kpi
            label="Asked-cash this week"
            value={formatNumber(r.asked_cash_this_week)}
            hint="Last 7 days"
          />
          <Kpi
            label="Asked-cash prior week"
            value={formatNumber(r.asked_cash_prior_week)}
            hint="7–14 days ago"
          />
          <Kpi
            label="Week-over-week delta"
            value={fmtDelta(r.asked_cash_wow_delta_pct)}
            hint="Positive = trending up = bad"
            tone={wowTone}
          />
        </div>
      </section>

      <section>
        <h2 className="mb-3 text-xs font-medium uppercase tracking-wide text-[var(--color-muted)]">
          Last response
        </h2>
        <div className="grid grid-cols-2 gap-3 md:grid-cols-3">
          <Kpi
            label="Last response submitted"
            value={fmtTs(r.last_response_at)}
            hint="IST (any response kind)"
          />
        </div>
      </section>

      <footer className="rounded-md border border-[var(--color-border)] bg-[var(--color-surface)] p-3 text-[11px] text-[var(--color-muted)]">
        <p>
          {`Companion view to /cash-payment-surveys-summary — that surface focuses on the leakage rate and offender list; this one focuses on response-mix shape, reporter concentration, recidivism cohort sizing, and week-over-week trend. Asked-cash share ≥ 10% across 90d = systemic leakage; ≥ 3 max strikes on a single engineer = auto-suspend pipeline target; WoW delta > +25% = escalating.`}
        </p>
      </footer>
    </div>
  );
}
