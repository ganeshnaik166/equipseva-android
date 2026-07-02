import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';
export const revalidate = 0;

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [campaignsRes, summaryRes, wonRes, activitiesRes] = await Promise.all([
    sb.rpc('r1851_list_campaigns'),
    sb.rpc('r1851_active_campaigns_summary'),
    sb.rpc('r1851_recent_won'),
    sb.rpc('r1851_list_activities', { p_campaign_id: null }),
  ]);

  const campaigns: any[] = Array.isArray(campaignsRes.data) ? campaignsRes.data : [];
  const summary: any = Array.isArray(summaryRes.data) && summaryRes.data.length > 0 ? summaryRes.data[0] : null;
  const wonRecent: any[] = Array.isArray(wonRes.data) ? wonRes.data : [];
  const activities: any[] = Array.isArray(activitiesRes.data) ? activitiesRes.data : [];

  const err =
    campaignsRes.error?.message ||
    summaryRes.error?.message ||
    wonRes.error?.message ||
    activitiesRes.error?.message ||
    null;

  const fmtRupees = (n: number | null | undefined) => {
    const v = Number(n ?? 0);
    return '₹' + v.toLocaleString('en-IN');
  };
  const fmtDate = (s: string | null | undefined) =>
    s ? new Date(s).toLocaleString('en-IN', { hour12: false }) : '—';
  const fmtDay = (s: string | null | undefined) =>
    s ? new Date(s).toLocaleDateString('en-IN') : '—';

  const campaignCols: Column<any>[] = [
    { key: 'campaign_name', header: 'Campaign', render: (r: any) => <span className="font-medium">{r.campaign_name ?? '—'}</span> },
    { key: 'campaign_type', header: 'Type', render: (r: any) => <span className="text-xs uppercase tracking-wide">{r.campaign_type ?? '—'}</span> },
    { key: 'hospital', header: 'Hospital', render: (r: any) => (
        <div className="text-xs">
          <div>{r.org_name ?? '—'}</div>
          <div className="text-neutral-500">{r.hospital_email ?? '—'}</div>
        </div>
      ) },
    { key: 'status', header: 'Status', render: (r: any) => {
        const s = String(r.status ?? '');
        const cls =
          s === 'won' ? 'bg-emerald-100 text-emerald-800' :
          s === 'lost' ? 'bg-rose-100 text-rose-800' :
          s === 'active' ? 'bg-blue-100 text-blue-800' :
          s === 'paused' ? 'bg-amber-100 text-amber-800' :
          'bg-neutral-100 text-neutral-700';
        return <span className={'inline-block rounded px-2 py-0.5 text-xs ' + cls}>{s || '—'}</span>;
      } },
    { key: 'value_at_stake_rupees', header: 'Value', render: (r: any) => fmtRupees(r.value_at_stake_rupees) },
    { key: 'started_at', header: 'Started', render: (r: any) => fmtDate(r.started_at) },
    { key: 'expected_close_date', header: 'Expected close', render: (r: any) => fmtDay(r.expected_close_date) },
    { key: 'activity_count', header: 'Activities', render: (r: any) => <span className="tabular-nums">{r.activity_count ?? 0}</span> },
  ];

  const wonCols: Column<any>[] = [
    { key: 'campaign_name', header: 'Campaign', render: (r: any) => r.campaign_name ?? '—' },
    { key: 'hospital', header: 'Hospital', render: (r: any) => (
        <div className="text-xs">
          <div>{r.org_name ?? '—'}</div>
          <div className="text-neutral-500">{r.hospital_email ?? '—'}</div>
        </div>
      ) },
    { key: 'campaign_type', header: 'Type', render: (r: any) => r.campaign_type ?? '—' },
    { key: 'value_at_stake_rupees', header: 'Won value', render: (r: any) => fmtRupees(r.value_at_stake_rupees) },
    { key: 'updated_at', header: 'Closed at', render: (r: any) => fmtDate(r.updated_at) },
  ];

  const activityCols: Column<any>[] = [
    { key: 'activity_at', header: 'When', render: (r: any) => fmtDate(r.activity_at) },
    { key: 'activity_type', header: 'Type', render: (r: any) => <span className="text-xs uppercase">{r.activity_type ?? '—'}</span> },
    { key: 'by_email', header: 'By', render: (r: any) => r.by_email ?? '—' },
    { key: 'outcome', header: 'Outcome', render: (r: any) => <span className="text-xs">{r.outcome ?? '—'}</span> },
    { key: 'campaign_id', header: 'Campaign', render: (r: any) => <span className="font-mono text-xs">{String(r.campaign_id ?? '').slice(0, 8)}</span> },
  ];

  return (
    <main className="mx-auto max-w-7xl space-y-8 p-6">
      <header>
        <h1 className="text-2xl font-semibold">Hospital ABM Campaigns</h1>
        <p className="text-sm text-neutral-600">
          Per-hospital account-based marketing. Track campaigns & activities. Round r1851.
        </p>
      </header>

      {err ? (
        <div className="rounded border border-rose-300 bg-rose-50 p-3 text-sm text-rose-800">
          {err}
        </div>
      ) : null}

      <section>
        <h2 className="mb-2 text-lg font-medium">Pipeline summary</h2>
        <div className="grid grid-cols-2 gap-3 md:grid-cols-4 lg:grid-cols-7">
          <Stat label="Active" value={summary?.total_active ?? 0} />
          <Stat label="Planned" value={summary?.total_planned ?? 0} />
          <Stat label="Won" value={summary?.total_won ?? 0} />
          <Stat label="Lost" value={summary?.total_lost ?? 0} />
          <Stat label="Paused" value={summary?.total_paused ?? 0} />
          <Stat label="Pipeline value" value={fmtRupees(summary?.pipeline_value_rupees)} />
          <Stat label="Won value" value={fmtRupees(summary?.won_value_rupees)} />
        </div>
      </section>

      <section>
        <h2 className="mb-2 text-lg font-medium">All campaigns</h2>
        <p className="mb-3 text-xs text-neutral-500">Showing ≤ 200 most recent.</p>
        <DataTable
          rows={campaigns}
          columns={campaignCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="mb-2 text-lg font-medium">Recently won</h2>
        <DataTable
          rows={wonRecent}
          columns={wonCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="mb-2 text-lg font-medium">Recent activities</h2>
        <p className="mb-3 text-xs text-neutral-500">Latest ≤ 500 logged touches across all campaigns.</p>
        <DataTable
          rows={activities}
          columns={activityCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>
    </main>
  );
}

function Stat({ label, value }: { label: string; value: any }) {
  return (
    <div className="rounded border border-neutral-200 bg-white p-3">
      <div className="text-xs uppercase tracking-wide text-neutral-500">{label}</div>
      <div className="mt-1 text-lg font-semibold tabular-nums">{value}</div>
    </div>
  );
}
