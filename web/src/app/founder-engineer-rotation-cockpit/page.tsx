import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Founder engineer rotation cockpit — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type SummaryRow = {
  total_engineers_active: number;
  engineers_frozen_now: number;
  engineers_unfrozen_30d: number;
  engineers_with_recent_invite: number;
  engineers_ignored_invite_count_30d: number;
  engineers_responded_invite_count_30d: number;
  response_rate_pct_30d: number | null;
  avg_rating_30d: number | null;
  repeat_low_rating_engineers: number;
  frozen_avg_age_days: number | null;
  newest_freeze_engineer_id: string | null;
  newest_freeze_engineer_label: string | null;
  newest_freeze_age_days: number;
  last_audit_run_at: string | null;
};

type FrozenRow = {
  engineer_user_id: string;
  engineer_label: string;
  invitations_sent: number;
  responses_received: number;
  ignored_in_90d: number;
  rotation_frozen_at: string | null;
  age_days: number;
  last_invite_at: string | null;
  last_invite_age_days: number;
};

type AtRiskRow = {
  engineer_user_id: string;
  engineer_label: string;
  invitations_sent: number;
  responses_received: number;
  ignored_in_90d: number;
  last_invite_at: string | null;
  last_invite_age_days: number;
  response_rate_pct: number | null;
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

function fmtPct(n: number | null | undefined): string {
  if (n === null || n === undefined) return "—";
  return `${Number(n).toFixed(1)}%`;
}

function fmtNum(n: number | null | undefined, digits = 2): string {
  if (n === null || n === undefined) return "—";
  return Number(n).toFixed(digits);
}

function fmtDate(iso: string | null): string {
  if (!iso) return "—";
  return new Date(iso).toISOString().slice(0, 10);
}

export default async function Page() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();

  const [summaryRes, frozenRes, atRiskRes] = await Promise.all([
    supabase.rpc("founder_engineer_rotation_cockpit_summary"),
    supabase.rpc("founder_engineer_rotation_cockpit_frozen", { p_limit: 50 }),
    supabase.rpc("founder_engineer_rotation_cockpit_at_risk", { p_limit: 50 }),
  ]);

  const summary = (summaryRes.data?.[0] ?? null) as SummaryRow | null;
  const frozen = (frozenRes.data ?? []) as FrozenRow[];
  const atRisk = (atRiskRes.data ?? []) as AtRiskRow[];

  const errors = [summaryRes.error, frozenRes.error, atRiskRes.error].filter(Boolean);

  return (
    <main className="mx-auto max-w-7xl px-6 py-8">
      <header className="mb-6">
        <h1 className="text-2xl font-semibold tracking-tight">Engineer rotation cockpit</h1>
        <p className="mt-1 text-sm text-[var(--color-muted)]">
          Spot-audit compliance · freeze enforcement · approaching-freeze early warning. Reads engineer_audit_compliance (r1310).
        </p>
      </header>

      {errors.length > 0 ? (
        <div className="mb-4 rounded-lg border border-[var(--color-danger)] bg-[var(--color-surface)] p-3 text-xs text-[var(--color-danger)]">
          {errors.map((e, i) => (<div key={i}>{e?.message}</div>))}
        </div>
      ) : null}

      <section className="grid grid-cols-2 gap-3 md:grid-cols-4 xl:grid-cols-7">
        <Card label="Engineers active" value={formatNumber(summary?.total_engineers_active ?? 0)} />
        <Card label="Frozen now" value={formatNumber(summary?.engineers_frozen_now ?? 0)} tone="border-[var(--color-danger)]" sub="rotation halted" />
        <Card label="Unfrozen · 30d" value={formatNumber(summary?.engineers_unfrozen_30d ?? 0)} tone="border-[var(--color-ok)]" />
        <Card label="With invite · 90d" value={formatNumber(summary?.engineers_with_recent_invite ?? 0)} />
        <Card label="Ignored invite · 30d" value={formatNumber(summary?.engineers_ignored_invite_count_30d ?? 0)} tone="border-[var(--color-warn)]" />
        <Card label="Responded invite · 30d" value={formatNumber(summary?.engineers_responded_invite_count_30d ?? 0)} />
        <Card label="Response rate · 30d" value={fmtPct(summary?.response_rate_pct_30d ?? null)} />
        <Card label="Avg rating · 30d" value={fmtNum(summary?.avg_rating_30d ?? null, 2)} sub="1–5" />
        <Card label="Repeat low-rating engineers" value={formatNumber(summary?.repeat_low_rating_engineers ?? 0)} tone="border-[var(--color-warn)]" sub="≥3 ratings · 2 · 180d" />
        <Card label="Frozen avg age" value={`${fmtNum(summary?.frozen_avg_age_days ?? null, 1)} d`} />
        <Card label="Newest freeze" value={summary?.newest_freeze_engineer_label ?? "—"} sub={summary?.newest_freeze_age_days ? `${summary.newest_freeze_age_days} d ago` : ""} />
        <Card label="Newest freeze age" value={`${formatNumber(summary?.newest_freeze_age_days ?? 0)} d`} />
        <Card label="Newest freeze engineer id" value={summary?.newest_freeze_engineer_id ? summary.newest_freeze_engineer_id.slice(0, 8) : "—"} sub="short uuid" />
        <Card label="Last audit run" value={fmtDate(summary?.last_audit_run_at ?? null)} sub="compliance refresh" />
      </section>

      <section className="mt-8">
        <div className="mb-2 flex items-baseline justify-between">
          <h2 className="text-sm font-semibold uppercase tracking-wider text-[var(--color-muted)]">Frozen ledger</h2>
          <span className="text-[10px] text-[var(--color-muted)]">top {frozen.length} · newest first</span>
        </div>
        <div className="overflow-x-auto rounded-lg border border-[var(--color-border)]">
          <table className="w-full min-w-[900px] text-sm">
            <thead className="bg-[var(--color-surface)] text-[10px] uppercase tracking-wider text-[var(--color-muted)]">
              <tr>
                <th className="px-3 py-2 text-left">Engineer</th>
                <th className="px-3 py-2 text-right">Invites</th>
                <th className="px-3 py-2 text-right">Responses</th>
                <th className="px-3 py-2 text-right">Ignored · 90d</th>
                <th className="px-3 py-2 text-left">Frozen at</th>
                <th className="px-3 py-2 text-right">Age</th>
                <th className="px-3 py-2 text-left">Last invite</th>
                <th className="px-3 py-2 text-right">Invite age</th>
              </tr>
            </thead>
            <tbody>
              {frozen.length === 0 ? (
                <tr><td colSpan={8} className="px-3 py-6 text-center text-xs text-[var(--color-muted)]">No engineers currently frozen.</td></tr>
              ) : frozen.map((r) => (
                <tr key={r.engineer_user_id} className="border-t border-[var(--color-border)]">
                  <td className="px-3 py-2">
                    <div className="font-medium">{r.engineer_label}</div>
                    <div className="text-[10px] text-[var(--color-muted)]">{r.engineer_user_id.slice(0, 8)}</div>
                  </td>
                  <td className="px-3 py-2 text-right tabular-nums">{formatNumber(r.invitations_sent)}</td>
                  <td className="px-3 py-2 text-right tabular-nums">{formatNumber(r.responses_received)}</td>
                  <td className="px-3 py-2 text-right tabular-nums text-[var(--color-danger)]">{formatNumber(r.ignored_in_90d)}</td>
                  <td className="px-3 py-2 text-left">{fmtDate(r.rotation_frozen_at)}</td>
                  <td className="px-3 py-2 text-right tabular-nums">{r.age_days} d</td>
                  <td className="px-3 py-2 text-left">{fmtDate(r.last_invite_at)}</td>
                  <td className="px-3 py-2 text-right tabular-nums">{r.last_invite_age_days} d</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </section>

      <section className="mt-8">
        <div className="mb-2 flex items-baseline justify-between">
          <h2 className="text-sm font-semibold uppercase tracking-wider text-[var(--color-muted)]">At-risk ledger</h2>
          <span className="text-[10px] text-[var(--color-muted)]">≥ 2 ignored in 90d · 1 more = freeze</span>
        </div>
        <div className="overflow-x-auto rounded-lg border border-[var(--color-border)]">
          <table className="w-full min-w-[900px] text-sm">
            <thead className="bg-[var(--color-surface)] text-[10px] uppercase tracking-wider text-[var(--color-muted)]">
              <tr>
                <th className="px-3 py-2 text-left">Engineer</th>
                <th className="px-3 py-2 text-right">Invites</th>
                <th className="px-3 py-2 text-right">Responses</th>
                <th className="px-3 py-2 text-right">Ignored · 90d</th>
                <th className="px-3 py-2 text-right">Resp rate</th>
                <th className="px-3 py-2 text-left">Last invite</th>
                <th className="px-3 py-2 text-right">Invite age</th>
              </tr>
            </thead>
            <tbody>
              {atRisk.length === 0 ? (
                <tr><td colSpan={7} className="px-3 py-6 text-center text-xs text-[var(--color-muted)]">No engineers approaching freeze threshold.</td></tr>
              ) : atRisk.map((r) => (
                <tr key={r.engineer_user_id} className="border-t border-[var(--color-border)]">
                  <td className="px-3 py-2">
                    <div className="font-medium">{r.engineer_label}</div>
                    <div className="text-[10px] text-[var(--color-muted)]">{r.engineer_user_id.slice(0, 8)}</div>
                  </td>
                  <td className="px-3 py-2 text-right tabular-nums">{formatNumber(r.invitations_sent)}</td>
                  <td className="px-3 py-2 text-right tabular-nums">{formatNumber(r.responses_received)}</td>
                  <td className="px-3 py-2 text-right tabular-nums text-[var(--color-warn)]">{formatNumber(r.ignored_in_90d)}</td>
                  <td className="px-3 py-2 text-right tabular-nums">{fmtPct(r.response_rate_pct ?? null)}</td>
                  <td className="px-3 py-2 text-left">{fmtDate(r.last_invite_at)}</td>
                  <td className="px-3 py-2 text-right tabular-nums">{r.last_invite_age_days} d</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </section>

      <section className="mt-8 rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4 text-xs leading-relaxed text-[var(--color-muted)]">
        <div className="mb-1 text-[10px] font-semibold uppercase tracking-wider">Freeze · unfreeze rules</div>
        <ul className="list-disc space-y-1 pl-4">
          <li>Freeze fires when an engineer has · 3 ignored spot-audit invitations within the trailing 90 days. Rotation enforcement skips frozen engineers on auto-assignment.</li>
          <li>Unfreeze fires automatically once ignored_in_90d drops below 3 (i.e. older invites age out of window or the engineer responds).</li>
          <li>The hourly spot_audit_auto_invite cron job (r1310) refreshes engineer_audit_compliance tallies and emits new invitations at every 10th completed job per engineer.</li>
          <li>At-risk = 2 ignored in 90d AND not yet frozen. One more skipped invite triggers freeze — pre-empt by reaching out manually.</li>
        </ul>
      </section>
    </main>
  );
}
