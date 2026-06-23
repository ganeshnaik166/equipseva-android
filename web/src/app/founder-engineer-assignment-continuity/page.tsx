import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type OverviewRow = {
  hospitals_tracked: number;
  avg_continuity_pct: number;
  high_continuity_hospitals: number;
  critical_rotation_hospitals: number;
  open_churn_events: number;
  revenue_at_risk_rupees: number;
  win_back_count_30d: number;
};

function fmtInr(n: number): string {
  if (!n) return '0';
  return new Intl.NumberFormat('en-IN').format(n);
}

function fmtDate(s: string | null): string {
  if (!s) return '-';
  return new Date(s).toLocaleDateString('en-IN', { day: '2-digit', month: 'short', year: 'numeric' });
}

function bandPill(band: string) {
  const map: Record<string, string> = {
    low: 'bg-emerald-100 text-emerald-800',
    medium: 'bg-amber-100 text-amber-800',
    high: 'bg-orange-100 text-orange-800',
    critical: 'bg-red-100 text-red-800',
  };
  const cls = map[band] || 'bg-slate-100 text-slate-700';
  return <span className={`inline-block rounded px-2 py-0.5 text-xs font-medium ${cls}`}>{band}</span>;
}

function statusPill(status: string) {
  const map: Record<string, string> = {
    open: 'bg-red-100 text-red-800',
    investigating: 'bg-amber-100 text-amber-800',
    resolved: 'bg-emerald-100 text-emerald-800',
    lost: 'bg-slate-200 text-slate-700',
  };
  const cls = map[status] || 'bg-slate-100 text-slate-700';
  return <span className={`inline-block rounded px-2 py-0.5 text-xs font-medium ${cls}`}>{status}</span>;
}

export default async function Page() {
  const supabase = await getSupabaseServerClient();
  const { data: userData } = await supabase.auth.getUser();
  const email = userData?.user?.email ?? '';

  const [
    overviewRes,
    hospitalsRes,
    eventsRes,
    bandsRes,
    typesRes,
    primariesRes,
  ] = await Promise.all([
    supabase.rpc('r2388_continuity_overview'),
    supabase.rpc('r2388_hospital_continuity_list'),
    supabase.rpc('r2388_churn_events_list'),
    supabase.rpc('r2388_band_breakdown'),
    supabase.rpc('r2388_event_type_breakdown'),
    supabase.rpc('r2388_top_primary_engineers'),
  ]);

  const overview: OverviewRow = (overviewRes.data?.[0] as OverviewRow) ?? {
    hospitals_tracked: 0,
    avg_continuity_pct: 0,
    high_continuity_hospitals: 0,
    critical_rotation_hospitals: 0,
    open_churn_events: 0,
    revenue_at_risk_rupees: 0,
    win_back_count_30d: 0,
  };

  const hospitals: any[] = hospitalsRes.data ?? [];
  const events: any[] = eventsRes.data ?? [];
  const bands: any[] = bandsRes.data ?? [];
  const types: any[] = typesRes.data ?? [];
  const primaries: any[] = primariesRes.data ?? [];

  const hospitalCols: Column<any>[] = [
    { key: 'hospital_name', header: 'Hospital', render: (r) => <span className="font-medium">{r.hospital_name}</span> },
    { key: 'hospital_city', header: 'City', render: (r) => r.hospital_city ?? '-' },
    { key: 'total_jobs_90d', header: 'Jobs 90d', render: (r) => r.total_jobs_90d },
    { key: 'distinct_engineers_90d', header: 'Engineers', render: (r) => r.distinct_engineers_90d },
    { key: 'primary_engineer_name', header: 'Primary engineer', render: (r) => r.primary_engineer_name ?? '-' },
    { key: 'primary_engineer_job_count', header: 'Primary jobs', render: (r) => r.primary_engineer_job_count },
    { key: 'continuity_pct', header: 'Continuity %', render: (r) => `${Number(r.continuity_pct).toFixed(1)}%` },
    { key: 'rotation_score', header: 'Rotation', render: (r) => Number(r.rotation_score).toFixed(2) },
    { key: 'churn_risk_band', header: 'Band', render: (r) => bandPill(r.churn_risk_band) },
    { key: 'amc_active', header: 'AMC', render: (r) => r.amc_active ? <span className="text-emerald-700">active</span> : <span className="text-slate-500">none</span> },
    { key: 'amc_monthly_rupees', header: 'AMC/mo', render: (r) => `Rs ${fmtInr(r.amc_monthly_rupees)}` },
    { key: 'last_job_at', header: 'Last job', render: (r) => fmtDate(r.last_job_at) },
  ];

  const eventCols: Column<any>[] = [
    { key: 'hospital_name', header: 'Hospital', render: (r) => <span className="font-medium">{r.hospital_name}</span> },
    { key: 'event_type', header: 'Event', render: (r) => r.event_type },
    { key: 'prior_continuity_pct', header: 'Prior %', render: (r) => r.prior_continuity_pct != null ? `${Number(r.prior_continuity_pct).toFixed(1)}%` : '-' },
    { key: 'current_continuity_pct', header: 'Now %', render: (r) => r.current_continuity_pct != null ? `${Number(r.current_continuity_pct).toFixed(1)}%` : '-' },
    { key: 'delta_pct', header: 'Delta', render: (r) => {
      if (r.delta_pct == null) return '-';
      const v = Number(r.delta_pct);
      const cls = v < 0 ? 'text-red-700' : 'text-emerald-700';
      return <span className={cls}>{v.toFixed(1)}%</span>;
    }},
    { key: 'prior_engineer_name', header: 'Prior eng', render: (r) => r.prior_engineer_name ?? '-' },
    { key: 'new_engineer_name', header: 'New eng', render: (r) => r.new_engineer_name ?? '-' },
    { key: 'revenue_at_risk_rupees', header: 'Revenue at risk', render: (r) => `Rs ${fmtInr(r.revenue_at_risk_rupees)}` },
    { key: 'action_taken', header: 'Action', render: (r) => r.action_taken ?? '-' },
    { key: 'resolution_status', header: 'Status', render: (r) => statusPill(r.resolution_status) },
    { key: 'occurred_at', header: 'Occurred', render: (r) => fmtDate(r.occurred_at) },
    { key: 'resolved_at', header: 'Resolved', render: (r) => fmtDate(r.resolved_at) },
  ];

  const bandCols: Column<any>[] = [
    { key: 'churn_risk_band', header: 'Band', render: (r) => bandPill(r.churn_risk_band) },
    { key: 'hospital_count', header: 'Hospitals', render: (r) => r.hospital_count },
    { key: 'avg_continuity_pct', header: 'Avg continuity %', render: (r) => `${Number(r.avg_continuity_pct).toFixed(1)}%` },
    { key: 'amc_revenue_rupees', header: 'AMC revenue/mo', render: (r) => `Rs ${fmtInr(r.amc_revenue_rupees)}` },
  ];

  const typeCols: Column<any>[] = [
    { key: 'event_type', header: 'Event type', render: (r) => r.event_type },
    { key: 'event_count', header: 'Count', render: (r) => r.event_count },
    { key: 'avg_delta_pct', header: 'Avg delta %', render: (r) => `${Number(r.avg_delta_pct).toFixed(1)}%` },
    { key: 'total_revenue_at_risk_rupees', header: 'Revenue at risk', render: (r) => `Rs ${fmtInr(r.total_revenue_at_risk_rupees)}` },
  ];

  const primaryCols: Column<any>[] = [
    { key: 'primary_engineer_name', header: 'Engineer', render: (r) => <span className="font-medium">{r.primary_engineer_name}</span> },
    { key: 'hospitals_served', header: 'Hospitals served', render: (r) => r.hospitals_served },
    { key: 'total_jobs', header: 'Total jobs', render: (r) => r.total_jobs },
    { key: 'avg_continuity_pct', header: 'Avg continuity %', render: (r) => `${Number(r.avg_continuity_pct).toFixed(1)}%` },
  ];

  return (
    <main className="mx-auto max-w-7xl px-4 py-8">
      <header className="mb-6">
        <h1 className="text-2xl font-semibold">Engineer assignment continuity</h1>
        <p className="mt-1 text-sm text-slate-600">
          Track what share of jobs each hospital sees from a single primary engineer, and quantify churn risk when rotation spikes. Signed in as {email}.
        </p>
      </header>

      <section className="mb-8 grid grid-cols-2 gap-3 md:grid-cols-4 lg:grid-cols-7">
        <div className="rounded-lg border bg-white p-3">
          <div className="text-xs uppercase text-slate-500">Hospitals tracked</div>
          <div className="mt-1 text-xl font-semibold">{overview.hospitals_tracked}</div>
        </div>
        <div className="rounded-lg border bg-white p-3">
          <div className="text-xs uppercase text-slate-500">Avg continuity</div>
          <div className="mt-1 text-xl font-semibold">{Number(overview.avg_continuity_pct).toFixed(1)}%</div>
        </div>
        <div className="rounded-lg border bg-white p-3">
          <div className="text-xs uppercase text-slate-500">High continuity (&gt;=75%)</div>
          <div className="mt-1 text-xl font-semibold text-emerald-700">{overview.high_continuity_hospitals}</div>
        </div>
        <div className="rounded-lg border bg-white p-3">
          <div className="text-xs uppercase text-slate-500">Critical rotation</div>
          <div className="mt-1 text-xl font-semibold text-red-700">{overview.critical_rotation_hospitals}</div>
        </div>
        <div className="rounded-lg border bg-white p-3">
          <div className="text-xs uppercase text-slate-500">Open churn events</div>
          <div className="mt-1 text-xl font-semibold">{overview.open_churn_events}</div>
        </div>
        <div className="rounded-lg border bg-white p-3">
          <div className="text-xs uppercase text-slate-500">Revenue at risk</div>
          <div className="mt-1 text-xl font-semibold">Rs {fmtInr(overview.revenue_at_risk_rupees)}</div>
        </div>
        <div className="rounded-lg border bg-white p-3">
          <div className="text-xs uppercase text-slate-500">Win-backs 30d</div>
          <div className="mt-1 text-xl font-semibold text-emerald-700">{overview.win_back_count_30d}</div>
        </div>
      </section>

      <section className="mb-8">
        <h2 className="mb-2 text-lg font-medium">Hospital continuity snapshots</h2>
        <p className="mb-3 text-sm text-slate-600">
          Sorted by churn risk band then continuity ascending. A continuity of &gt;= 75% reads as a single primary engineer owning the relationship; &lt;= 40% reads as thrash.
        </p>
        <DataTable
          rows={hospitals}
          columns={hospitalCols}
          emptyMessage="No hospital snapshots yet"
          rowKey={(r: any) => r.id}
        />
      </section>

      <section className="mb-8">
        <h2 className="mb-2 text-lg font-medium">Churn impact events</h2>
        <p className="mb-3 text-sm text-slate-600">
          Each row pairs a rotation event with the AMC revenue at risk and resolution status.
        </p>
        <DataTable
          rows={events}
          columns={eventCols}
          emptyMessage="No churn events logged"
          rowKey={(r: any) => r.id}
        />
      </section>

      <section className="mb-8 grid gap-6 md:grid-cols-2">
        <div>
          <h2 className="mb-2 text-lg font-medium">Risk band breakdown</h2>
          <DataTable
            rows={bands}
            columns={bandCols}
            emptyMessage="No bands"
            rowKey={(r: any) => r.churn_risk_band}
          />
        </div>
        <div>
          <h2 className="mb-2 text-lg font-medium">Event type breakdown</h2>
          <DataTable
            rows={types}
            columns={typeCols}
            emptyMessage="No events"
            rowKey={(r: any) => r.event_type}
          />
        </div>
      </section>

      <section className="mb-8">
        <h2 className="mb-2 text-lg font-medium">Top primary engineers</h2>
        <p className="mb-3 text-sm text-slate-600">
          Engineers who anchor the most hospital relationships. High avg continuity =&gt; strong customer attachment.
        </p>
        <DataTable
          rows={primaries}
          columns={primaryCols}
          emptyMessage="No primary engineers"
          rowKey={(r: any) => r.primary_engineer_name}
        />
      </section>
    </main>
  );
}
