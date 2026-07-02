import { requireFounder } from '@/lib/auth/requireFounder';
import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Kpi = { label: string; value: string };

async function rpc<T>(name: string, args: Record<string, unknown> = {}): Promise<T[]> {
  const sb = await getSupabaseServerClient();
  try {
    const { data, error } = await sb.rpc(name, args);
    if (error) return [];
    return (data ?? []) as T[];
  } catch {
    return [];
  }
}

function fmt(n: number | null | undefined, suffix = ''): string {
  if (n === null || n === undefined || Number.isNaN(Number(n))) return '—';
  return `${Number(n).toLocaleString('en-IN')}${suffix}`;
}

export default async function Page() {
  await requireFounder();

  const [stages, drop, cohort, stuck, ladder, ttam] = await Promise.all([
    rpc<any>('founder_funnel_stage_counts'),
    rpc<any>('founder_funnel_drop_off'),
    rpc<any>('founder_funnel_cohort_by_source'),
    rpc<any>('founder_funnel_stuck_hospitals'),
    rpc<any>('founder_funnel_action_ladder'),
    rpc<any>('founder_funnel_time_to_amc'),
  ]);

  const stageMap = new Map<string, number>(stages.map((s: any) => [s.stage, Number(s.hospitals ?? 0)]));
  const total = stageMap.get('first_touch') ?? 0;
  const reachedAmc = stageMap.get('first_amc') ?? 0;
  const overallConv = total > 0 ? ((reachedAmc / total) * 100).toFixed(1) : '0';

  const worstDrop = [...drop].sort((a, b) => Number(b.drop_pct ?? 0) - Number(a.drop_pct ?? 0))[0];
  const bestSource = [...cohort].sort((a, b) => Number(b.conversion_pct ?? 0) - Number(a.conversion_pct ?? 0))[0];
  const worstSource = [...cohort].sort((a, b) => Number(a.conversion_pct ?? 0) - Number(b.conversion_pct ?? 0))[0];
  const overallTtam = ttam.find((t: any) => t.acquisition_source === 'unknown') ?? ttam[0];

  const kpis: Kpi[] = [
    { label: 'First Touch', value: fmt(total) },
    { label: 'Demos Booked', value: fmt(stageMap.get('demo_booked') ?? 0) },
    { label: 'Demos Done', value: fmt(stageMap.get('demo_done') ?? 0) },
    { label: 'Quotes Sent', value: fmt(stageMap.get('quote_sent') ?? 0) },
    { label: 'First Job', value: fmt(stageMap.get('first_job') ?? 0) },
    { label: 'First Job Paid', value: fmt(stageMap.get('first_job_paid') ?? 0) },
    { label: 'First AMC', value: fmt(reachedAmc) },
    { label: 'Overall Conv %', value: `${overallConv}%` },
    { label: 'Worst Drop Stage', value: worstDrop ? `${worstDrop.from_stage} → ${worstDrop.to_stage}` : '—' },
    { label: 'Worst Drop %', value: worstDrop ? `${fmt(worstDrop.drop_pct)}%` : '—' },
    { label: 'Best Source', value: bestSource ? bestSource.acquisition_source : '—' },
    { label: 'Best Source Conv %', value: bestSource ? `${fmt(bestSource.conversion_pct)}%` : '—' },
    { label: 'Worst Source', value: worstSource ? worstSource.acquisition_source : '—' },
    { label: 'Stuck Hospitals', value: fmt(stuck.length) },
    { label: 'Open Action Rungs', value: fmt(ladder.length) },
    { label: 'Median Days → AMC', value: overallTtam ? `${fmt(overallTtam.median_days)}d` : '—' },
  ];

  const stageCols: Column<any>[] = [
    { key: 'stage', header: 'Stage', render: (r: any) => r.stage ?? '—' },
    { key: 'hospitals', header: 'Hospitals', render: (r: any) => fmt(r.hospitals) },
    { key: 'share_pct', header: 'Share %', render: (r: any) => `${fmt(r.share_pct)}%` },
  ];

  const dropCols: Column<any>[] = [
    { key: 'from_stage', header: 'From', render: (r: any) => r.from_stage ?? '—' },
    { key: 'to_stage', header: 'To', render: (r: any) => r.to_stage ?? '—' },
    { key: 'retained', header: 'Retained', render: (r: any) => fmt(r.retained) },
    { key: 'dropped', header: 'Dropped', render: (r: any) => fmt(r.dropped) },
    { key: 'drop_pct', header: 'Drop %', render: (r: any) => `${fmt(r.drop_pct)}%` },
  ];

  const cohortCols: Column<any>[] = [
    { key: 'acquisition_source', header: 'Source', render: (r: any) => r.acquisition_source ?? '—' },
    { key: 'hospitals', header: 'Hospitals', render: (r: any) => fmt(r.hospitals) },
    { key: 'reached_first_amc', header: 'Reached AMC', render: (r: any) => fmt(r.reached_first_amc) },
    { key: 'conversion_pct', header: 'Conv %', render: (r: any) => `${fmt(r.conversion_pct)}%` },
  ];

  const stuckCols: Column<any>[] = [
    { key: 'org_name', header: 'Hospital', render: (r: any) => r.org_name ?? '—' },
    { key: 'stuck_stage', header: 'Stuck Stage', render: (r: any) => r.stuck_stage ?? '—' },
    { key: 'days_stuck', header: 'Days Stuck', render: (r: any) => `${fmt(r.days_stuck)}d` },
    { key: 'acquisition_source', header: 'Source', render: (r: any) => r.acquisition_source ?? '—' },
  ];

  const ladderCols: Column<any>[] = [
    { key: 'org_name', header: 'Hospital', render: (r: any) => r.org_name ?? '—' },
    { key: 'stuck_stage', header: 'Stage', render: (r: any) => r.stuck_stage ?? '—' },
    { key: 'action_rung', header: 'Rung', render: (r: any) => fmt(r.action_rung) },
    { key: 'action_label', header: 'Next Action', render: (r: any) => r.action_label ?? '—' },
    { key: 'status', header: 'Status', render: (r: any) => r.status ?? '—' },
  ];

  return (
    <div className="p-6 space-y-6">
      <div>
        <h1 className="text-2xl font-bold">Hospital Activation Funnel</h1>
        <p className="text-sm text-gray-600">First-touch {">"} first-AMC. Per-stage drop-off, cohort by source, founder action ladder.</p>
      </div>

      <div className="grid grid-cols-2 md:grid-cols-4 gap-3">
        {kpis.map((k) => (
          <div key={k.label} className="rounded border bg-white p-3">
            <div className="text-xs uppercase tracking-wide text-gray-500">{k.label}</div>
            <div className="mt-1 text-lg font-semibold">{k.value}</div>
          </div>
        ))}
      </div>

      <section className="space-y-2">
        <h2 className="text-lg font-semibold">Stage Counts</h2>
        <DataTable rowKey={(r: any) => r.stage} columns={stageCols} rows={stages} />
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-semibold">Stage Drop-off</h2>
        <DataTable rowKey={(r: any) => `${r.from_stage}-${r.to_stage}`} columns={dropCols} rows={drop} />
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-semibold">Cohort by Acquisition Source</h2>
        <DataTable rowKey={(r: any) => r.acquisition_source} columns={cohortCols} rows={cohort} />
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-semibold">Stuck Hospitals ({">"}14d at stage)</h2>
        <DataTable rowKey={(r: any) => r.id} columns={stuckCols} rows={stuck} />
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-semibold">Founder Action Ladder</h2>
        <DataTable rowKey={(r: any) => r.id} columns={ladderCols} rows={ladder} />
      </section>
    </div>
  );
}
