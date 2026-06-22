import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

function rupees(n: number | null | undefined): string {
  if (n === null || n === undefined) return '—';
  const v = Number(n);
  if (!isFinite(v)) return '—';
  return '₹' + v.toLocaleString('en-IN');
}

function fmtDate(s: string | null | undefined): string {
  if (!s) return '—';
  try {
    return new Date(s).toLocaleString('en-IN', { dateStyle: 'medium', timeStyle: 'short' });
  } catch {
    return String(s);
  }
}

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [targetsRes, topRes, warmRes, introsRes] = await Promise.all([
    sb.rpc('list_family_office_targets_r1890'),
    sb.rpc('top_priority_family_offices_r1890'),
    sb.rpc('recent_warm_family_office_intros_r1890'),
    sb.rpc('list_family_office_intros_r1890', { p_target_id: null }),
  ]);

  const targets: any[] = Array.isArray(targetsRes.data) ? targetsRes.data : [];
  const top: any[] = Array.isArray(topRes.data) ? topRes.data : [];
  const warm: any[] = Array.isArray(warmRes.data) ? warmRes.data : [];
  const intros: any[] = Array.isArray(introsRes.data) ? introsRes.data : [];

  const totalAum = targets.reduce((s, r) => s + Number(r.family_office_size_aum_rupees || 0), 0);
  const totalExpected = targets.reduce((s, r) => s + Number(r.expected_check_rupees || 0), 0);
  const inDialog = targets.filter((r) => r.status === 'in_dialog' || r.status === 'intro_made').length;

  const targetCols: Column<any>[] = [
    { key: 'family_office_name', header: 'Family Office', render: (r: any) => <span className="font-medium">{r.family_office_name}</span> },
    { key: 'family_office_size_aum_rupees', header: 'AUM', render: (r: any) => rupees(r.family_office_size_aum_rupees) },
    { key: 'expected_check_rupees', header: 'Expected Check', render: (r: any) => rupees(r.expected_check_rupees) },
    { key: 'status', header: 'Status', render: (r: any) => <span className="px-2 py-0.5 rounded text-xs bg-slate-100">{String(r.status)}</span> },
    { key: 'intro_count', header: 'Intros', render: (r: any) => <span>{r.intro_count ?? 0}</span> },
    { key: 'last_touch_at', header: 'Last Touch', render: (r: any) => fmtDate(r.last_touch_at) },
    { key: 'first_outreach_at', header: 'First Outreach', render: (r: any) => fmtDate(r.first_outreach_at) },
  ];

  const topCols: Column<any>[] = [
    { key: 'family_office_name', header: 'Family Office', render: (r: any) => <span className="font-medium">{r.family_office_name}</span> },
    { key: 'status', header: 'Status', render: (r: any) => <span>{String(r.status)}</span> },
    { key: 'expected_check_rupees', header: 'Expected', render: (r: any) => rupees(r.expected_check_rupees) },
    { key: 'family_office_size_aum_rupees', header: 'AUM', render: (r: any) => rupees(r.family_office_size_aum_rupees) },
    { key: 'intro_count', header: 'Intros', render: (r: any) => <span>{r.intro_count ?? 0}</span> },
    { key: 'last_touch_at', header: 'Last Touch', render: (r: any) => fmtDate(r.last_touch_at) },
  ];

  const warmCols: Column<any>[] = [
    { key: 'family_office_name', header: 'Family Office', render: (r: any) => <span className="font-medium">{r.family_office_name}</span> },
    { key: 'intro_via', header: 'Via', render: (r: any) => <span className="px-2 py-0.5 rounded text-xs bg-emerald-100 text-emerald-800">{String(r.intro_via)}</span> },
    { key: 'intro_at', header: 'At', render: (r: any) => fmtDate(r.intro_at) },
    { key: 'by_email', header: 'By', render: (r: any) => <span>{r.by_email ?? '—'}</span> },
    { key: 'response', header: 'Response', render: (r: any) => <span className="text-sm text-slate-600">{r.response ?? '—'}</span> },
  ];

  const introCols: Column<any>[] = [
    { key: 'target_id', header: 'Target', render: (r: any) => <span className="font-mono text-xs">{String(r.target_id).slice(0, 8)}</span> },
    { key: 'intro_via', header: 'Via', render: (r: any) => <span>{String(r.intro_via)}</span> },
    { key: 'intro_at', header: 'At', render: (r: any) => fmtDate(r.intro_at) },
    { key: 'by_email', header: 'By', render: (r: any) => <span>{r.by_email ?? '—'}</span> },
    { key: 'response', header: 'Response', render: (r: any) => <span className="text-sm text-slate-600">{r.response ?? '—'}</span> },
  ];

  return (
    <div className="p-6 space-y-8 max-w-7xl mx-auto">
      <header>
        <h1 className="text-2xl font-bold">Founder · Family-Office Outreach</h1>
        <p className="text-sm text-slate-600 mt-1">
          Track family-office targeted outreach (high-NW, multi-gen wealth). Round r1890.
        </p>
      </header>

      <section className="grid grid-cols-1 md:grid-cols-4 gap-4">
        <div className="border rounded p-4 bg-white">
          <div className="text-xs text-slate-500">Targets</div>
          <div className="text-2xl font-semibold">{targets.length}</div>
        </div>
        <div className="border rounded p-4 bg-white">
          <div className="text-xs text-slate-500">Total AUM (sum)</div>
          <div className="text-2xl font-semibold">{rupees(totalAum)}</div>
        </div>
        <div className="border rounded p-4 bg-white">
          <div className="text-xs text-slate-500">Expected Checks</div>
          <div className="text-2xl font-semibold">{rupees(totalExpected)}</div>
        </div>
        <div className="border rounded p-4 bg-white">
          <div className="text-xs text-slate-500">Intro made & In dialog</div>
          <div className="text-2xl font-semibold">{inDialog}</div>
        </div>
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-3">Top Priority (researching, intro made, in dialog)</h2>
        <DataTable rows={top} columns={topCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-3">Recent Warm & Referral Intros (last 90 days)</h2>
        <DataTable rows={warm} columns={warmCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-3">All Targets</h2>
        <DataTable rows={targets} columns={targetCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-3">All Intro Log Entries</h2>
        <DataTable rows={intros} columns={introCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>
    </div>
  );
}
