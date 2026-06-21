import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type StageRow = {
  stage: string;
  prospect_count: number;
  total_arr_rupees: number;
  avg_arr_rupees: number;
};

type ProspectRow = {
  id: string;
  hospital_name: string;
  city: string | null;
  state: string | null;
  intro_source: string | null;
  expected_arr_rupees: number;
  stage: string;
  owner_email: string | null;
  last_activity_at: string | null;
  activity_count: number;
  created_at: string;
};

type ActivityRow = {
  id: string;
  prospect_id: string;
  hospital_name: string;
  activity_type: string;
  activity_at: string;
  by_email: string | null;
  note: string | null;
};

type StaleRow = {
  id: string;
  hospital_name: string;
  city: string | null;
  stage: string;
  expected_arr_rupees: number;
  owner_email: string | null;
  last_activity_at: string | null;
  days_stale: number;
};

function rupees(n: number | null | undefined) {
  const v = Number(n ?? 0);
  return '₹' + v.toLocaleString('en-IN');
}

function fmtDate(s: string | null | undefined) {
  if (!s) return '—';
  try { return new Date(s).toLocaleString('en-IN'); } catch { return s; }
}

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [summaryRes, prospectsRes, staleRes, activitiesRes] = await Promise.all([
    sb.rpc('pipeline_summary_by_stage_r1687'),
    sb.rpc('list_prospects_r1687', { p_stage: null }),
    sb.rpc('stale_prospects_r1687', { p_days: 14 }),
    sb.rpc('list_activities_r1687', { p_prospect_id: null }),
  ]);

  const summary: StageRow[] = (summaryRes.data ?? []) as StageRow[];
  const prospects: ProspectRow[] = (prospectsRes.data ?? []) as ProspectRow[];
  const stale: StaleRow[] = (staleRes.data ?? []) as StaleRow[];
  const activities: ActivityRow[] = (activitiesRes.data ?? []) as ActivityRow[];

  const totalProspects = summary.reduce((a, r) => a + Number(r.prospect_count || 0), 0);
  const totalArr = summary.reduce((a, r) => a + Number(r.total_arr_rupees || 0), 0);
  const wonRow = summary.find((r) => r.stage === 'won');
  const wonArr = Number(wonRow?.total_arr_rupees || 0);
  const stalledCount = stale.length;

  const summaryCols: Column<StageRow>[] = [
    { key: 'stage', header: 'Stage', render: (r: any) => <span className="font-mono uppercase text-xs">{r.stage}</span> },
    { key: 'prospect_count', header: 'Count', render: (r: any) => <span>{r.prospect_count}</span> },
    { key: 'total_arr_rupees', header: 'Total ARR', render: (r: any) => <span>{rupees(r.total_arr_rupees)}</span> },
    { key: 'avg_arr_rupees', header: 'Avg ARR', render: (r: any) => <span>{rupees(r.avg_arr_rupees)}</span> },
  ];

  const prospectCols: Column<ProspectRow>[] = [
    { key: 'hospital_name', header: 'Hospital', render: (r: any) => (
      <div className="flex flex-col">
        <span className="font-medium">{r.hospital_name}</span>
        <span className="text-xs text-gray-500">{[r.city, r.state].filter(Boolean).join(', ') || '—'}</span>
      </div>
    ) },
    { key: 'stage', header: 'Stage', render: (r: any) => (
      <span className="px-2 py-0.5 rounded text-xs font-mono uppercase bg-gray-100">{r.stage}</span>
    ) },
    { key: 'expected_arr_rupees', header: 'Expected ARR', render: (r: any) => <span className="font-medium">{rupees(r.expected_arr_rupees)}</span> },
    { key: 'intro_source', header: 'Source', render: (r: any) => <span className="text-xs">{r.intro_source ?? '—'}</span> },
    { key: 'owner_email', header: 'Owner', render: (r: any) => <span className="text-xs">{r.owner_email ?? '—'}</span> },
    { key: 'activity_count', header: 'Activities', render: (r: any) => <span>{r.activity_count}</span> },
    { key: 'last_activity_at', header: 'Last Activity', render: (r: any) => <span className="text-xs">{fmtDate(r.last_activity_at)}</span> },
  ];

  const staleCols: Column<StaleRow>[] = [
    { key: 'hospital_name', header: 'Hospital', render: (r: any) => (
      <div className="flex flex-col">
        <span className="font-medium">{r.hospital_name}</span>
        <span className="text-xs text-gray-500">{r.city ?? '—'}</span>
      </div>
    ) },
    { key: 'stage', header: 'Stage', render: (r: any) => <span className="font-mono uppercase text-xs">{r.stage}</span> },
    { key: 'expected_arr_rupees', header: 'ARR', render: (r: any) => <span>{rupees(r.expected_arr_rupees)}</span> },
    { key: 'owner_email', header: 'Owner', render: (r: any) => <span className="text-xs">{r.owner_email ?? '—'}</span> },
    { key: 'days_stale', header: 'Days Stale', render: (r: any) => (
      <span className={r.days_stale > 30 ? 'text-red-600 font-semibold' : 'text-amber-600 font-medium'}>{r.days_stale}d</span>
    ) },
    { key: 'last_activity_at', header: 'Last Touch', render: (r: any) => <span className="text-xs">{fmtDate(r.last_activity_at)}</span> },
  ];

  const actCols: Column<ActivityRow>[] = [
    { key: 'activity_at', header: 'When', render: (r: any) => <span className="text-xs">{fmtDate(r.activity_at)}</span> },
    { key: 'hospital_name', header: 'Hospital', render: (r: any) => <span className="font-medium">{r.hospital_name}</span> },
    { key: 'activity_type', header: 'Type', render: (r: any) => (
      <span className="px-2 py-0.5 rounded text-xs font-mono uppercase bg-blue-50 text-blue-700">{r.activity_type}</span>
    ) },
    { key: 'by_email', header: 'By', render: (r: any) => <span className="text-xs">{r.by_email ?? '—'}</span> },
    { key: 'note', header: 'Note', render: (r: any) => <span className="text-xs text-gray-700">{r.note ?? '—'}</span> },
  ];

  return (
    <div className="p-6 max-w-7xl mx-auto space-y-8">
      <header>
        <h1 className="text-2xl font-bold">Hospital New-Logo Pipeline</h1>
        <p className="text-sm text-gray-600">Per-prospect pipeline for net-new hospital logos. Track intro → won/lost across all stages.</p>
      </header>

      <section className="grid grid-cols-1 md:grid-cols-4 gap-4">
        <div className="border rounded-lg p-4 bg-white">
          <div className="text-xs uppercase text-gray-500">Prospects</div>
          <div className="text-2xl font-bold">{totalProspects}</div>
        </div>
        <div className="border rounded-lg p-4 bg-white">
          <div className="text-xs uppercase text-gray-500">Pipeline ARR</div>
          <div className="text-2xl font-bold">{rupees(totalArr)}</div>
        </div>
        <div className="border rounded-lg p-4 bg-white">
          <div className="text-xs uppercase text-gray-500">Won ARR</div>
          <div className="text-2xl font-bold text-green-600">{rupees(wonArr)}</div>
        </div>
        <div className="border rounded-lg p-4 bg-white">
          <div className="text-xs uppercase text-gray-500">Stale Prospects (&gt;14d)</div>
          <div className="text-2xl font-bold text-amber-600">{stalledCount}</div>
        </div>
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-3">Pipeline Summary By Stage</h2>
        <DataTable
          rows={summary}
          columns={summaryCols}
          rowKey={(r: any, i: number) => String(r.stage ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-3">All Prospects</h2>
        <DataTable
          rows={prospects}
          columns={prospectCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-3">Stale Prospects Action Queue (&gt;14 days no touch)</h2>
        <DataTable
          rows={stale}
          columns={staleCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-3">Recent Activity Log</h2>
        <DataTable
          rows={activities}
          columns={actCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>
    </div>
  );
}
