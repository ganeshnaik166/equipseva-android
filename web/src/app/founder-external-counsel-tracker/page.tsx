import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function FounderExternalCounselTrackerPage() {
  const sb = await getSupabaseServerClient();

  const [counselRes, engagementsRes, byTypeRes, recentRes] = await Promise.all([
    sb.rpc('list_counsel_r1970'),
    sb.rpc('list_engagements_r1970'),
    sb.rpc('counsel_by_type_r1970'),
    sb.rpc('recent_engagements_r1970', { p_days: 30 }),
  ]);

  const counsel: any[] = (counselRes.data as any[]) ?? [];
  const engagements: any[] = (engagementsRes.data as any[]) ?? [];
  const byType: any[] = (byTypeRes.data as any[]) ?? [];
  const recent: any[] = (recentRes.data as any[]) ?? [];

  const counselColumns: Column<any>[] = [
    { key: 'counsel_name', header: 'Counsel', render: (r: any) => <span className="font-medium">{r.counsel_name}</span> },
    { key: 'counsel_type', header: 'Type', render: (r: any) => <span className="text-xs uppercase tracking-wide">{r.counsel_type}</span> },
    { key: 'monthly_retainer_rupees', header: 'Monthly Retainer', render: (r: any) => <span>₹{Number(r.monthly_retainer_rupees ?? 0).toLocaleString('en-IN')}</span> },
    { key: 'engagement_start_date', header: 'Start', render: (r: any) => <span>{r.engagement_start_date ?? '—'}</span> },
    { key: 'engagement_end_date', header: 'End', render: (r: any) => <span>{r.engagement_end_date ?? '—'}</span> },
    { key: 'status', header: 'Status', render: (r: any) => <span className="text-xs">{r.status}</span> },
    { key: 'captured_at', header: 'Captured', render: (r: any) => <span className="text-xs text-zinc-500">{r.captured_at ? new Date(r.captured_at).toLocaleDateString() : '—'}</span> },
  ];

  const engagementsColumns: Column<any>[] = [
    { key: 'taken_at', header: 'When', render: (r: any) => <span className="text-xs">{r.taken_at ? new Date(r.taken_at).toLocaleString() : '—'}</span> },
    { key: 'counsel_name', header: 'Counsel', render: (r: any) => <span>{r.counsel_name}</span> },
    { key: 'engagement_type', header: 'Type', render: (r: any) => <span className="text-xs uppercase">{r.engagement_type}</span> },
    { key: 'billable_hours', header: 'Hours', render: (r: any) => <span>{r.billable_hours ?? 0}</span> },
    { key: 'by_email', header: 'By', render: (r: any) => <span className="text-xs">{r.by_email ?? '—'}</span> },
    { key: 'notes_md', header: 'Notes', render: (r: any) => <span className="text-xs text-zinc-600 line-clamp-2">{r.notes_md ?? '—'}</span> },
  ];

  const byTypeColumns: Column<any>[] = [
    { key: 'counsel_type', header: 'Type', render: (r: any) => <span className="font-medium uppercase text-xs">{r.counsel_type}</span> },
    { key: 'total_count', header: 'Total', render: (r: any) => <span>{r.total_count}</span> },
    { key: 'active_count', header: 'Active', render: (r: any) => <span>{r.active_count}</span> },
    { key: 'total_monthly_retainer_rupees', header: 'Active Monthly Retainer', render: (r: any) => <span>₹{Number(r.total_monthly_retainer_rupees ?? 0).toLocaleString('en-IN')}</span> },
  ];

  const recentColumns: Column<any>[] = [
    { key: 'taken_at', header: 'When', render: (r: any) => <span className="text-xs">{r.taken_at ? new Date(r.taken_at).toLocaleString() : '—'}</span> },
    { key: 'counsel_name', header: 'Counsel', render: (r: any) => <span>{r.counsel_name}</span> },
    { key: 'counsel_type', header: 'Type', render: (r: any) => <span className="text-xs uppercase">{r.counsel_type}</span> },
    { key: 'engagement_type', header: 'Engagement', render: (r: any) => <span className="text-xs">{r.engagement_type}</span> },
    { key: 'billable_hours', header: 'Hours', render: (r: any) => <span>{r.billable_hours ?? 0}</span> },
    { key: 'by_email', header: 'By', render: (r: any) => <span className="text-xs">{r.by_email ?? '—'}</span> },
  ];

  const activeCount = counsel.filter((c: any) => c.status === 'active').length;
  const totalMonthlyRetainer = counsel
    .filter((c: any) => c.status === 'active')
    .reduce((acc: number, c: any) => acc + Number(c.monthly_retainer_rupees ?? 0), 0);
  const totalBillableHours = recent.reduce((acc: number, r: any) => acc + Number(r.billable_hours ?? 0), 0);

  return (
    <div className="mx-auto max-w-7xl p-6 space-y-8">
      <header className="space-y-2">
        <h1 className="text-2xl font-semibold">External Counsel Tracker</h1>
        <p className="text-sm text-zinc-600">
          Track external advisors and counsel engagements across legal, tax, regulatory, M and A, employment, IP, and compliance matters.
        </p>
      </header>

      <section className="grid grid-cols-1 md:grid-cols-4 gap-4">
        <div className="rounded-lg border border-zinc-200 p-4">
          <div className="text-xs uppercase text-zinc-500">Counsel On File</div>
          <div className="text-2xl font-semibold mt-1">{counsel.length}</div>
        </div>
        <div className="rounded-lg border border-zinc-200 p-4">
          <div className="text-xs uppercase text-zinc-500">Active</div>
          <div className="text-2xl font-semibold mt-1">{activeCount}</div>
        </div>
        <div className="rounded-lg border border-zinc-200 p-4">
          <div className="text-xs uppercase text-zinc-500">Active Monthly Retainer</div>
          <div className="text-2xl font-semibold mt-1">₹{totalMonthlyRetainer.toLocaleString('en-IN')}</div>
        </div>
        <div className="rounded-lg border border-zinc-200 p-4">
          <div className="text-xs uppercase text-zinc-500">Billable Hours (last 30 days)</div>
          <div className="text-2xl font-semibold mt-1">{totalBillableHours}</div>
        </div>
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-medium">By Counsel Type</h2>
        <p className="text-xs text-zinc-500">Rolled up across all engagement categories. Active monthly retainer sums only active counsel.</p>
        <DataTable rows={byType} columns={byTypeColumns} rowKey={(r: any, i: number) => String(r.counsel_type ?? i)} />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-medium">All Counsel</h2>
        <p className="text-xs text-zinc-500">Full roster of external counsel engagements (most recent first, up to 200 rows).</p>
        <DataTable rows={counsel} columns={counselColumns} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-medium">Recent Engagements (last 30 days)</h2>
        <p className="text-xs text-zinc-500">Engagement entries logged in the last 30 days across all counsel.</p>
        <DataTable rows={recent} columns={recentColumns} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-medium">Engagement Log</h2>
        <p className="text-xs text-zinc-500">Complete engagement history: matters opened, advice given, billing received, scope extended, and escalations.</p>
        <DataTable rows={engagements} columns={engagementsColumns} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>
    </div>
  );
}
