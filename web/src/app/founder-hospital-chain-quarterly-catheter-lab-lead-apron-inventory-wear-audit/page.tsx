import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type ChainSummary = { chain_name: string; apron_count: number; retire_count: number; total_replacement_cost: number };
type WearDist = { wear_severity: string; apron_count: number; avg_defect_cm2: number };
type FailedFluoro = { asset_tag: string; chain_name: string; branch: string; room: string; wear: string; defect_cm2: number };
type AgeBucket = { age_bucket: string; apron_count: number; retire_count: number };
type ActionSummary = { action_taken: string; event_count: number; defect_total: number };
type ComplianceSplit = { compliance_status: string; event_count: number; pct: number };
type TopBranch = { chain_name: string; branch: string; retire_count: number; total_cost: number };

export default async function Page() {
  const supabase = await getSupabaseServerClient();
  const [chainSummary, wearDist, failedFluoro, ageBuckets, actionSummary, complianceSplit, topBranches] = await Promise.all([
    supabase.rpc('founder_r3079_chain_summary'),
    supabase.rpc('founder_r3079_wear_distribution'),
    supabase.rpc('founder_r3079_failed_fluoro'),
    supabase.rpc('founder_r3079_age_buckets'),
    supabase.rpc('founder_r3079_action_summary'),
    supabase.rpc('founder_r3079_compliance_split'),
    supabase.rpc('founder_r3079_top_branches_at_risk'),
  ]);

  const chainCols: Column<ChainSummary>[] = [
    { key: 'chain_name', header: 'Chain' },
    { key: 'apron_count', header: 'Aprons' },
    { key: 'retire_count', header: 'Retire' },
    { key: 'total_replacement_cost', header: 'Replace Cost (Rs)' },
  ];
  const wearCols: Column<WearDist>[] = [
    { key: 'wear_severity', header: 'Wear' },
    { key: 'apron_count', header: 'Count' },
    { key: 'avg_defect_cm2', header: 'Avg defect cm2' },
  ];
  const failCols: Column<FailedFluoro>[] = [
    { key: 'asset_tag', header: 'Tag' },
    { key: 'chain_name', header: 'Chain' },
    { key: 'branch', header: 'Branch' },
    { key: 'room', header: 'Room' },
    { key: 'wear', header: 'Wear' },
    { key: 'defect_cm2', header: 'Defect cm2' },
  ];
  const ageCols: Column<AgeBucket>[] = [
    { key: 'age_bucket', header: 'Age bucket' },
    { key: 'apron_count', header: 'Aprons' },
    { key: 'retire_count', header: 'Retire' },
  ];
  const actionCols: Column<ActionSummary>[] = [
    { key: 'action_taken', header: 'Action' },
    { key: 'event_count', header: 'Events' },
    { key: 'defect_total', header: 'Total defects' },
  ];
  const compCols: Column<ComplianceSplit>[] = [
    { key: 'compliance_status', header: 'Compliance' },
    { key: 'event_count', header: 'Events' },
    { key: 'pct', header: 'Pct %' },
  ];
  const topCols: Column<TopBranch>[] = [
    { key: 'chain_name', header: 'Chain' },
    { key: 'branch', header: 'Branch' },
    { key: 'retire_count', header: 'Retire' },
    { key: 'total_cost', header: 'Cost (Rs)' },
  ];

  return (
    <div className="p-6 space-y-8">
      <header>
        <h1 className="text-2xl font-bold">Hospital Chain Quarterly Catheter Lab Lead-Apron Inventory & Wear Audit</h1>
        <p className="text-sm text-gray-600">Round r3079 — AERB & NABH compliance view across cath-lab lead-apron fleet.</p>
      </header>

      <section>
        <h2 className="text-lg font-semibold mb-2">Chain Summary</h2>
        <DataTable<ChainSummary>
          rows={(chainSummary.data ?? []) as ChainSummary[]}
          columns={chainCols}
          emptyMessage="No chains"
          rowKey={(r, i) => String((r as { id?: string }).id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Wear Distribution</h2>
        <DataTable<WearDist>
          rows={(wearDist.data ?? []) as WearDist[]}
          columns={wearCols}
          emptyMessage="No wear data"
          rowKey={(r, i) => String((r as { id?: string }).id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Failed Fluoroscopy (defect &gt;= threshold)</h2>
        <DataTable<FailedFluoro>
          rows={(failedFluoro.data ?? []) as FailedFluoro[]}
          columns={failCols}
          emptyMessage="No failures"
          rowKey={(r, i) => String((r as { id?: string }).id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Age Buckets</h2>
        <DataTable<AgeBucket>
          rows={(ageBuckets.data ?? []) as AgeBucket[]}
          columns={ageCols}
          emptyMessage="No age data"
          rowKey={(r, i) => String((r as { id?: string }).id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Audit Actions</h2>
        <DataTable<ActionSummary>
          rows={(actionSummary.data ?? []) as ActionSummary[]}
          columns={actionCols}
          emptyMessage="No actions"
          rowKey={(r, i) => String((r as { id?: string }).id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Compliance Split</h2>
        <DataTable<ComplianceSplit>
          rows={(complianceSplit.data ?? []) as ComplianceSplit[]}
          columns={compCols}
          emptyMessage="No compliance data"
          rowKey={(r, i) => String((r as { id?: string }).id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Top Branches At Risk (retire &gt; 0)</h2>
        <DataTable<TopBranch>
          rows={(topBranches.data ?? []) as TopBranch[]}
          columns={topCols}
          emptyMessage="No at-risk branches"
          rowKey={(r, i) => String((r as { id?: string }).id ?? i)}
        />
      </section>
    </div>
  );
}
