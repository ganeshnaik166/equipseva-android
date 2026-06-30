import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type StageRow = { deal_stage: string; target_count: number; total_ask_cr: number; weighted_value_cr: number; avg_fit_score: number };
type TopRow = { acquirer_name: string; archetype: string; fit: number; probability_pct: number; valuation_ask_cr: number; weighted_value_cr: number; stage: string; priority: string };
type FunnelRow = { banker_status: string; count: number; executed_ndas: number; avg_days_since_last_touch: number };
type WsRow = { workstream: string; avg_readiness_pct: number; total_docs_uploaded: number; total_docs_required: number; total_red_flags: number; total_remediation_lakh: number };
type AcqRollupRow = { acquirer_name: string; stage: string; workstream_count: number; avg_readiness_pct: number; red_flag_total: number; remediation_lakh: number; blocked_count: number };
type CloseRow = { expected_close_quarter: string; target_count: number; total_ask_cr: number; weighted_close_cr: number; top_acquirer: string };
type RedFlagRow = { acquirer_name: string; workstream: string; red_flag_count: number; readiness_pct: number; status: string; owner_role: string; remediation_lakh: number; blocker_summary: string | null };
type ArchRow = { archetype: string; count: number; avg_ask_cr: number; avg_probability: number; total_weighted_cr: number };
type PriorityRow = { founder_priority: string; count: number; executed_nda_count: number; avg_fit: number; avg_probability: number; total_weighted_cr: number };

export default async function FounderStrategicAcquirerDiligenceTrackerPage() {
  const supabase = await getSupabaseServerClient();

  const [
    stageRes,
    topRes,
    funnelRes,
    wsRes,
    acqRollupRes,
    closeRes,
    redFlagRes,
    archRes,
    priorityRes,
  ] = await Promise.all([
    supabase.rpc('fn_acquirer_pipeline_by_stage_r3103'),
    supabase.rpc('fn_acquirer_top_weighted_targets_r3103'),
    supabase.rpc('fn_acquirer_nda_banker_funnel_r3103'),
    supabase.rpc('fn_diligence_readiness_by_workstream_r3103'),
    supabase.rpc('fn_diligence_per_acquirer_rollup_r3103'),
    supabase.rpc('fn_acquirer_close_calendar_r3103'),
    supabase.rpc('fn_diligence_red_flag_hotlist_r3103'),
    supabase.rpc('fn_acquirer_archetype_mix_r3103'),
    supabase.rpc('fn_acquirer_priority_tier_rollup_r3103'),
  ]);

  const stages = (stageRes.data ?? []) as StageRow[];
  const tops = (topRes.data ?? []) as TopRow[];
  const funnel = (funnelRes.data ?? []) as FunnelRow[];
  const workstreams = (wsRes.data ?? []) as WsRow[];
  const acqRollup = (acqRollupRes.data ?? []) as AcqRollupRow[];
  const closeCal = (closeRes.data ?? []) as CloseRow[];
  const redFlags = (redFlagRes.data ?? []) as RedFlagRow[];
  const archMix = (archRes.data ?? []) as ArchRow[];
  const priority = (priorityRes.data ?? []) as PriorityRow[];

  const stageCols: Column<StageRow>[] = [
    { key: 'deal_stage', header: 'Deal Stage' },
    { key: 'target_count', header: 'Targets' },
    { key: 'total_ask_cr', header: 'Total Ask (cr)', render: (r) => `INR ${Number(r.total_ask_cr ?? 0).toFixed(1)}` },
    { key: 'weighted_value_cr', header: 'Weighted (cr)', render: (r) => `INR ${Number(r.weighted_value_cr ?? 0).toFixed(1)}` },
    { key: 'avg_fit_score', header: 'Avg Fit', render: (r) => `${Number(r.avg_fit_score ?? 0).toFixed(1)} / 100` },
  ];

  const topCols: Column<TopRow>[] = [
    { key: 'acquirer_name', header: 'Acquirer' },
    { key: 'archetype', header: 'Archetype' },
    { key: 'fit', header: 'Fit' },
    { key: 'probability_pct', header: 'P(close)', render: (r) => `${r.probability_pct}%` },
    { key: 'valuation_ask_cr', header: 'Ask (cr)', render: (r) => `INR ${Number(r.valuation_ask_cr ?? 0).toFixed(1)}` },
    { key: 'weighted_value_cr', header: 'Weighted (cr)', render: (r) => `INR ${Number(r.weighted_value_cr ?? 0).toFixed(1)}` },
    { key: 'stage', header: 'Stage' },
    { key: 'priority', header: 'Priority' },
  ];

  const funnelCols: Column<FunnelRow>[] = [
    { key: 'banker_status', header: 'Banker Stage' },
    { key: 'count', header: 'Count' },
    { key: 'executed_ndas', header: 'NDAs Executed' },
    { key: 'avg_days_since_last_touch', header: 'Avg days since touch', render: (r) => `${Number(r.avg_days_since_last_touch ?? 0).toFixed(1)}d` },
  ];

  const wsCols: Column<WsRow>[] = [
    { key: 'workstream', header: 'Workstream' },
    { key: 'avg_readiness_pct', header: 'Avg readiness', render: (r) => `${Number(r.avg_readiness_pct ?? 0).toFixed(1)}%` },
    { key: 'total_docs_uploaded', header: 'Docs up' },
    { key: 'total_docs_required', header: 'Docs req' },
    { key: 'total_red_flags', header: 'Red flags' },
    { key: 'total_remediation_lakh', header: 'Remediation (lakh)', render: (r) => `INR ${Number(r.total_remediation_lakh ?? 0).toFixed(1)}` },
  ];

  const acqRollupCols: Column<AcqRollupRow>[] = [
    { key: 'acquirer_name', header: 'Acquirer' },
    { key: 'stage', header: 'Stage' },
    { key: 'workstream_count', header: 'Workstreams' },
    { key: 'avg_readiness_pct', header: 'Avg readiness', render: (r) => `${Number(r.avg_readiness_pct ?? 0).toFixed(1)}%` },
    { key: 'red_flag_total', header: 'Red flags' },
    { key: 'remediation_lakh', header: 'Remediation (lakh)', render: (r) => `INR ${Number(r.remediation_lakh ?? 0).toFixed(1)}` },
    { key: 'blocked_count', header: 'Blocked' },
  ];

  const closeCols: Column<CloseRow>[] = [
    { key: 'expected_close_quarter', header: 'Quarter' },
    { key: 'target_count', header: 'Targets' },
    { key: 'total_ask_cr', header: 'Total Ask (cr)', render: (r) => `INR ${Number(r.total_ask_cr ?? 0).toFixed(1)}` },
    { key: 'weighted_close_cr', header: 'Weighted (cr)', render: (r) => `INR ${Number(r.weighted_close_cr ?? 0).toFixed(1)}` },
    { key: 'top_acquirer', header: 'Top Acquirer' },
  ];

  const redFlagCols: Column<RedFlagRow>[] = [
    { key: 'acquirer_name', header: 'Acquirer' },
    { key: 'workstream', header: 'Workstream' },
    { key: 'red_flag_count', header: 'Flags' },
    { key: 'readiness_pct', header: 'Ready %', render: (r) => `${r.readiness_pct}%` },
    { key: 'status', header: 'Status' },
    { key: 'owner_role', header: 'Owner' },
    { key: 'remediation_lakh', header: 'Remediation (lakh)', render: (r) => `INR ${Number(r.remediation_lakh ?? 0).toFixed(1)}` },
    { key: 'blocker_summary', header: 'Blocker' },
  ];

  const archCols: Column<ArchRow>[] = [
    { key: 'archetype', header: 'Archetype' },
    { key: 'count', header: 'Targets' },
    { key: 'avg_ask_cr', header: 'Avg Ask (cr)', render: (r) => `INR ${Number(r.avg_ask_cr ?? 0).toFixed(1)}` },
    { key: 'avg_probability', header: 'Avg P(close)', render: (r) => `${Number(r.avg_probability ?? 0).toFixed(1)}%` },
    { key: 'total_weighted_cr', header: 'Total Weighted (cr)', render: (r) => `INR ${Number(r.total_weighted_cr ?? 0).toFixed(1)}` },
  ];

  const priorityCols: Column<PriorityRow>[] = [
    { key: 'founder_priority', header: 'Tier' },
    { key: 'count', header: 'Targets' },
    { key: 'executed_nda_count', header: 'NDAs' },
    { key: 'avg_fit', header: 'Avg Fit', render: (r) => `${Number(r.avg_fit ?? 0).toFixed(1)}` },
    { key: 'avg_probability', header: 'Avg P(close)', render: (r) => `${Number(r.avg_probability ?? 0).toFixed(1)}%` },
    { key: 'total_weighted_cr', header: 'Weighted (cr)', render: (r) => `INR ${Number(r.total_weighted_cr ?? 0).toFixed(1)}` },
  ];

  return (
    <main className="mx-auto max-w-7xl space-y-10 p-6">
      <header className="space-y-2">
        <p className="text-xs font-semibold uppercase tracking-widest text-slate-500">Founder Console · Round 3103</p>
        <h1 className="text-3xl font-bold tracking-tight">Strategic Acquirer Target List & Diligence Readiness Tracker</h1>
        <p className="max-w-3xl text-sm text-slate-600">
          Quarterly view of potential acquirers across strategic fit, banker intro, NDA + data-room readiness, valuation ask, and deal probability — paired with workstream-level diligence readiness so we know exactly which gaps block which deal.
        </p>
      </header>

      <section className="space-y-3">
        <h2 className="text-xl font-semibold">1. Pipeline by deal stage</h2>
        <DataTable<StageRow>
          rows={stages}
          columns={stageCols}
          emptyMessage="No acquirer targets logged yet."
          rowKey={(r, i) => String(r.deal_stage ?? i)}
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-xl font-semibold">2. Top targets by weighted expected value</h2>
        <DataTable<TopRow>
          rows={tops}
          columns={topCols}
          emptyMessage="No weighted targets to surface."
          rowKey={(r, i) => String(r.acquirer_name ?? i)}
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-xl font-semibold">3. Banker intro & NDA funnel</h2>
        <DataTable<FunnelRow>
          rows={funnel}
          columns={funnelCols}
          emptyMessage="No banker funnel data."
          rowKey={(r, i) => String(r.banker_status ?? i)}
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-xl font-semibold">4. Diligence readiness by workstream</h2>
        <DataTable<WsRow>
          rows={workstreams}
          columns={wsCols}
          emptyMessage="No workstream readiness data."
          rowKey={(r, i) => String(r.workstream ?? i)}
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-xl font-semibold">5. Per-acquirer diligence rollup</h2>
        <DataTable<AcqRollupRow>
          rows={acqRollup}
          columns={acqRollupCols}
          emptyMessage="No per-acquirer rollup."
          rowKey={(r, i) => String(r.acquirer_name ?? i)}
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-xl font-semibold">6. Expected close calendar</h2>
        <DataTable<CloseRow>
          rows={closeCal}
          columns={closeCols}
          emptyMessage="No close calendar."
          rowKey={(r, i) => String(r.expected_close_quarter ?? i)}
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-xl font-semibold">7. Diligence red-flag hotlist</h2>
        <DataTable<RedFlagRow>
          rows={redFlags}
          columns={redFlagCols}
          emptyMessage="No red flags — data room is clean."
          rowKey={(r, i) => `${r.acquirer_name}-${r.workstream}-${i}`}
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-xl font-semibold">8. Acquirer archetype mix & founder-priority rollup</h2>
        <DataTable<ArchRow>
          rows={archMix}
          columns={archCols}
          emptyMessage="No archetype data."
          rowKey={(r, i) => String(r.archetype ?? i)}
        />
        <DataTable<PriorityRow>
          rows={priority}
          columns={priorityCols}
          emptyMessage="No priority tier data."
          rowKey={(r, i) => String(r.founder_priority ?? i)}
        />
      </section>
    </main>
  );
}
