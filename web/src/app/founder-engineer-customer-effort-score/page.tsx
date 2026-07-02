import { requireFounder } from '@/lib/auth/requireFounder';
import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';
import { formatRupees } from '@/lib/format';

export const dynamic = 'force-dynamic';

function Kpi({ label, value }: { label: string; value: string }) {
  return (
    <div className="rounded-xl border border-zinc-200 bg-white p-3">
      <div className="text-xs text-zinc-500">{label}</div>
      <div className="mt-1 text-lg font-semibold text-zinc-900">{value}</div>
    </div>
  );
}

function fmtPct(n: number | null | undefined) {
  if (n === null || n === undefined) return "—";
  return `${Number(n).toFixed(1)}%`;
}
function fmtNum(n: number | null | undefined) {
  if (n === null || n === undefined) return "—";
  return String(n);
}
function fmtDate(s: string | null | undefined) {
  if (!s) return "—";
  try { return new Date(s).toLocaleString('en-IN'); } catch { return s; }
}

export default async function Page() {
  await requireFounder();
  const sb = await getSupabaseServerClient();

  const [overview, byEng, highRecent, lowRecent, tagRoll, trend, openFric] = await Promise.all([
    sb.rpc('founder_engineer_ces_overview_30d'),
    sb.rpc('founder_engineer_ces_by_engineer_90d'),
    sb.rpc('founder_engineer_ces_high_effort_recent'),
    sb.rpc('founder_engineer_ces_low_effort_recent'),
    sb.rpc('founder_engineer_ces_friction_tag_rollup'),
    sb.rpc('founder_engineer_ces_weekly_trend_13wk'),
    sb.rpc('founder_engineer_ces_open_frictions'),
  ]);

  const ov = (overview.data?.[0] ?? {}) as any;
  const engRows = (byEng.data ?? []) as any[];
  const highRows = (highRecent.data ?? []) as any[];
  const lowRows = (lowRecent.data ?? []) as any[];
  const tagRows = (tagRoll.data ?? []) as any[];
  const trendRows = (trend.data ?? []) as any[];
  const openRows = (openFric.data ?? []) as any[];

  const lastWeek = trendRows[0] ?? {};
  const prevWeek = trendRows[1] ?? {};
  const topTag = tagRows[0] ?? {};
  const topFrictionEng = engRows[0] ?? {};
  const totalResp30 = Number(ov.responses_30d ?? 0);
  const lowPct = totalResp30 > 0 ? (Number(ov.low_effort_30d ?? 0) * 100) / totalResp30 : 0;
  const highPct = totalResp30 > 0 ? (Number(ov.high_effort_30d ?? 0) * 100) / totalResp30 : 0;

  const engCols: Column<any>[] = [
    { key: 'engineer_name', header: 'Engineer', render: (r: any) => r.engineer_name ?? "—" },
    { key: 'tier', header: 'Tier', render: (r: any) => r.cached_highest_tier ?? "—" },
    { key: 'response_count', header: 'Responses', render: (r: any) => fmtNum(r.response_count) },
    { key: 'avg_ces', header: 'Avg CES', render: (r: any) => fmtNum(r.avg_ces) },
    { key: 'low_effort_count', header: 'Low-effort', render: (r: any) => fmtNum(r.low_effort_count) },
    { key: 'high_effort_count', header: 'High-effort', render: (r: any) => fmtNum(r.high_effort_count) },
    { key: 'high_effort_pct', header: 'High-effort %', render: (r: any) => fmtPct(r.high_effort_pct) },
    { key: 'last_response_at', header: 'Last response', render: (r: any) => fmtDate(r.last_response_at) },
  ];

  const highCols: Column<any>[] = [
    { key: 'responded_at', header: 'When', render: (r: any) => fmtDate(r.responded_at) },
    { key: 'engineer_name', header: 'Engineer', render: (r: any) => r.engineer_name ?? "—" },
    { key: 'hospital_name', header: 'Hospital', render: (r: any) => r.hospital_name ?? "—" },
    { key: 'ces_score', header: 'CES', render: (r: any) => fmtNum(r.ces_score) },
    { key: 'friction_tag', header: 'Friction', render: (r: any) => r.friction_tag ?? "(untagged)" },
    { key: 'free_text', header: 'Verbatim', render: (r: any) => r.free_text ?? "—" },
  ];

  const lowCols: Column<any>[] = [
    { key: 'responded_at', header: 'When', render: (r: any) => fmtDate(r.responded_at) },
    { key: 'engineer_name', header: 'Engineer', render: (r: any) => r.engineer_name ?? "—" },
    { key: 'hospital_name', header: 'Hospital', render: (r: any) => r.hospital_name ?? "—" },
    { key: 'ces_score', header: 'CES', render: (r: any) => fmtNum(r.ces_score) },
    { key: 'free_text', header: 'Verbatim', render: (r: any) => r.free_text ?? "—" },
  ];

  const tagCols: Column<any>[] = [
    { key: 'friction_tag', header: 'Friction tag', render: (r: any) => r.friction_tag ?? "—" },
    { key: 'response_count', header: 'Count', render: (r: any) => fmtNum(r.response_count) },
    { key: 'avg_ces', header: 'Avg CES', render: (r: any) => fmtNum(r.avg_ces) },
    { key: 'distinct_engineers', header: 'Engineers', render: (r: any) => fmtNum(r.distinct_engineers) },
    { key: 'last_seen_at', header: 'Last seen', render: (r: any) => fmtDate(r.last_seen_at) },
  ];

  const openCols: Column<any>[] = [
    { key: 'responded_at', header: 'When', render: (r: any) => fmtDate(r.responded_at) },
    { key: 'engineer_name', header: 'Engineer', render: (r: any) => r.engineer_name ?? "—" },
    { key: 'hospital_name', header: 'Hospital', render: (r: any) => r.hospital_name ?? "—" },
    { key: 'ces_score', header: 'CES', render: (r: any) => fmtNum(r.ces_score) },
    { key: 'friction_tag', header: 'Friction', render: (r: any) => r.friction_tag ?? "(untagged)" },
    { key: 'action_count', header: 'Actions', render: (r: any) => fmtNum(r.action_count) },
    { key: 'free_text', header: 'Verbatim', render: (r: any) => r.free_text ?? "—" },
  ];

  // formatRupees imported to keep convention; no money on this page, but available.
  const _money = formatRupees(0);

  return (
    <div className="mx-auto max-w-7xl space-y-6 p-6">
      <header className="space-y-1">
        <h1 className="text-2xl font-semibold tracking-tight text-zinc-900">Engineer Customer Effort Score</h1>
        <p className="text-sm text-zinc-600">
          CES from hospital contacts after each repair job. Low effort = growth signal. High effort = friction-fix target. {_money ? "" : ""}
        </p>
      </header>

      <section className="grid grid-cols-2 gap-3 md:grid-cols-4">
        <Kpi label="Responses (30d)" value={fmtNum(ov.responses_30d)} />
        <Kpi label="Avg CES (30d)" value={fmtNum(ov.avg_ces_30d)} />
        <Kpi label="Response rate (30d)" value={fmtPct(ov.response_rate_pct)} />
        <Kpi label="Low-effort (30d)" value={fmtNum(ov.low_effort_30d)} />
        <Kpi label="Neutral (30d)" value={fmtNum(ov.neutral_30d)} />
        <Kpi label="High-effort (30d)" value={fmtNum(ov.high_effort_30d)} />
        <Kpi label="Low-effort share" value={fmtPct(lowPct)} />
        <Kpi label="High-effort share" value={fmtPct(highPct)} />
        <Kpi label="Last week responses" value={fmtNum(lastWeek.responses)} />
        <Kpi label="Last week avg CES" value={fmtNum(lastWeek.avg_ces)} />
        <Kpi label="Prev week responses" value={fmtNum(prevWeek.responses)} />
        <Kpi label="Prev week avg CES" value={fmtNum(prevWeek.avg_ces)} />
        <Kpi label="Top friction tag" value={topTag.friction_tag ?? "—"} />
        <Kpi label="Top friction count" value={fmtNum(topTag.response_count)} />
        <Kpi label="Engineer w/ most friction" value={topFrictionEng.engineer_name ?? "—"} />
        <Kpi label="Open frictions" value={fmtNum(openRows.length)} />
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-semibold text-zinc-900">Engineers by friction (90d)</h2>
        <DataTable<any> columns={engCols} rows={engRows} rowKey={(r: any) => r.engineer_id} />
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-semibold text-zinc-900">Open frictions (high-effort, not yet closed)</h2>
        <DataTable<any> columns={openCols} rows={openRows} rowKey={(r: any) => r.response_id} />
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-semibold text-zinc-900">Friction tag rollup (90d)</h2>
        <DataTable<any> columns={tagCols} rows={tagRows} rowKey={(r: any) => r.friction_tag ?? 'untagged'} />
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-semibold text-zinc-900">High-effort verbatims (60d)</h2>
        <DataTable<any> columns={highCols} rows={highRows} rowKey={(r: any) => r.response_id} />
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-semibold text-zinc-900">Low-effort verbatims (60d) — growth signal</h2>
        <DataTable<any> columns={lowCols} rows={lowRows} rowKey={(r: any) => r.response_id} />
      </section>
    </div>
  );
}
