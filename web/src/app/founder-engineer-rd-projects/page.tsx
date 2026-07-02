import { requireFounder } from '@/lib/auth/requireFounder';
import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';
import type { ReactNode } from 'react';

export const dynamic = 'force-dynamic';
export const revalidate = 0;

function Kpi({ label, value }: { label: string; value: ReactNode }) {
  return (
    <div className="rounded-lg border border-neutral-200 bg-white p-3 shadow-sm">
      <div className="text-xs text-neutral-500">{label}</div>
      <div className="mt-1 text-lg font-semibold text-neutral-900">{value}</div>
    </div>
  );
}

function fmtNum(n: number | null | undefined): string {
  if (n === null || n === undefined) return '—';
  return new Intl.NumberFormat('en-IN').format(n);
}

function fmtRupees(n: number | null | undefined): string {
  if (n === null || n === undefined) return '—';
  return '₹' + new Intl.NumberFormat('en-IN').format(n);
}

function fmtDate(s: string | null | undefined): string {
  if (!s) return '—';
  try { return new Date(s).toLocaleString('en-IN'); } catch { return s; }
}

export default async function FounderEngineerRDProjectsPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();

  const { data: dashRows } = await supabase.rpc('founder_rd_projects_dashboard');
  const dash: any = Array.isArray(dashRows) ? dashRows[0] : dashRows;

  const { data: projects } = await supabase
    .from('engineer_rd_projects')
    .select('*')
    .order('created_at', { ascending: false })
    .limit(100);

  const { data: pending } = await supabase
    .from('engineer_rd_projects')
    .select('*')
    .in('status', ['submitted', 'under_review'])
    .order('created_at', { ascending: false })
    .limit(50);

  const { data: sopPromoted } = await supabase
    .from('engineer_rd_projects')
    .select('*')
    .eq('promote_to_sop', true)
    .order('sop_promoted_at', { ascending: false })
    .limit(50);

  const { data: validations } = await supabase
    .from('engineer_rd_validations')
    .select('*')
    .order('validated_at', { ascending: false })
    .limit(50);

  const kindCounts: Record<string, number> = {};
  for (const p of (projects ?? []) as any[]) {
    kindCounts[p.kind] = (kindCounts[p.kind] ?? 0) + 1;
  }
  const kindRollup = Object.entries(kindCounts)
    .map(([kind, n], i) => ({ id: 'k-' + i, kind, count: n }))
    .sort((a, b) => b.count - a.count);

  const projectCols: Column<any>[] = [
    { key: 'created_at', header: 'Created', render: (r: any) => fmtDate(r.created_at) },
    { key: 'title', header: 'Title', render: (r: any) => r.title ?? '—' },
    { key: 'kind', header: 'Kind', render: (r: any) => r.kind ?? '—' },
    { key: 'status', header: 'Status', render: (r: any) => r.status ?? '—' },
    { key: 'tier', header: 'Tier', render: (r: any) => r.founder_validation_tier ?? 0 },
    { key: 'time_saved', header: 'Time saved (min)', render: (r: any) => fmtNum(r.estimated_time_saved_minutes) },
    { key: 'cost_saved', header: 'Cost saved', render: (r: any) => fmtRupees(r.estimated_cost_saved_rupees) },
    { key: 'sop', header: 'SOP?', render: (r: any) => (r.promote_to_sop ? 'yes' : 'no') },
    { key: 'reward', header: 'Reward', render: (r: any) => fmtRupees(r.reward_rupees) },
  ];

  const pendingCols: Column<any>[] = [
    { key: 'created_at', header: 'Created', render: (r: any) => fmtDate(r.created_at) },
    { key: 'title', header: 'Title', render: (r: any) => r.title ?? '—' },
    { key: 'kind', header: 'Kind', render: (r: any) => r.kind ?? '—' },
    { key: 'status', header: 'Status', render: (r: any) => r.status ?? '—' },
    { key: 'problem', header: 'Problem', render: (r: any) => r.problem_statement ?? '—' },
  ];

  const sopCols: Column<any>[] = [
    { key: 'sop_promoted_at', header: 'Promoted', render: (r: any) => fmtDate(r.sop_promoted_at) },
    { key: 'title', header: 'Title', render: (r: any) => r.title ?? '—' },
    { key: 'kind', header: 'Kind', render: (r: any) => r.kind ?? '—' },
    { key: 'tier', header: 'Tier', render: (r: any) => r.founder_validation_tier ?? 0 },
    { key: 'reward', header: 'Reward', render: (r: any) => fmtRupees(r.reward_rupees) },
  ];

  const validationCols: Column<any>[] = [
    { key: 'validated_at', header: 'When', render: (r: any) => fmtDate(r.validated_at) },
    { key: 'project_id', header: 'Project', render: (r: any) => (r.project_id ?? '—').toString().slice(0, 8) },
    { key: 'tier', header: 'Tier', render: (r: any) => r.tier_assigned ?? 0 },
    { key: 'note', header: 'Note', render: (r: any) => r.validation_note ?? '—' },
  ];

  const kindCols: Column<any>[] = [
    { key: 'kind', header: 'Kind', render: (r: any) => r.kind ?? '—' },
    { key: 'count', header: 'Count', render: (r: any) => fmtNum(r.count) },
  ];

  return (
    <div className="mx-auto max-w-7xl space-y-6 p-6">
      <header>
        <h1 className="text-2xl font-bold text-neutral-900">Engineer R&D Pet-Project Log</h1>
        <p className="mt-1 text-sm text-neutral-600">
          Engineer-led experiments: new repair techniques, time-saver hacks, tool builds. Founder validates & promotes to SOP.
        </p>
      </header>

      <section className="grid grid-cols-2 md:grid-cols-4 gap-3">
        <Kpi label="Total projects" value={fmtNum(dash?.total_projects ?? 0)} />
        <Kpi label="Submitted" value={fmtNum(dash?.submitted_count ?? 0)} />
        <Kpi label="Under review" value={fmtNum(dash?.under_review_count ?? 0)} />
        <Kpi label="Validated" value={fmtNum(dash?.validated_count ?? 0)} />
        <Kpi label="Rejected" value={fmtNum(dash?.rejected_count ?? 0)} />
        <Kpi label="Promoted to SOP" value={fmtNum(dash?.promoted_to_sop_count ?? 0)} />
        <Kpi label="Archived" value={fmtNum(dash?.archived_count ?? 0)} />
        <Kpi label="Distinct engineers" value={fmtNum(dash?.distinct_engineers ?? 0)} />
        <Kpi label="Distinct kinds" value={fmtNum(dash?.distinct_kinds ?? 0)} />
        <Kpi label="Time saved (min)" value={fmtNum(dash?.total_time_saved_minutes ?? 0)} />
        <Kpi label="Cost saved" value={fmtRupees(dash?.total_cost_saved_rupees ?? 0)} />
        <Kpi label="Rewards paid" value={fmtRupees(dash?.total_rewards_paid_rupees ?? 0)} />
        <Kpi label="Avg validation tier" value={(dash?.avg_validation_tier ?? 0).toString()} />
        <Kpi label="New (30d)" value={fmtNum(dash?.projects_last_30d ?? 0)} />
        <Kpi label="New (7d)" value={fmtNum(dash?.projects_last_7d ?? 0)} />
        <Kpi label="SOP promotion %" value={(dash?.sop_promotion_rate_pct ?? 0).toString() + '%'} />
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-semibold text-neutral-900">All projects (latest 100)</h2>
        <DataTable columns={projectCols} rows={(projects ?? []) as any[]} rowKey={(r: any) => r.id} />
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-semibold text-neutral-900">Pending founder review</h2>
        <DataTable columns={pendingCols} rows={(pending ?? []) as any[]} rowKey={(r: any) => r.id} />
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-semibold text-neutral-900">Promoted to SOP</h2>
        <DataTable columns={sopCols} rows={(sopPromoted ?? []) as any[]} rowKey={(r: any) => r.id} />
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-semibold text-neutral-900">Recent validations</h2>
        <DataTable columns={validationCols} rows={(validations ?? []) as any[]} rowKey={(r: any) => r.id} />
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-semibold text-neutral-900">Kind rollup</h2>
        <DataTable columns={kindCols} rows={kindRollup} rowKey={(r: any) => r.id} />
      </section>
    </div>
  );
}
