import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Overview = {
  total_crashes_7d: number;
  total_anrs_7d: number;
  blocking_open: number;
  p0_open: number;
  affected_users_7d: number;
  distinct_signatures: number;
  worst_build: string | null;
  worst_build_count: number | null;
};

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [overviewR, buildR, deviceR, sigR, queueR, recentR, trendR] = await Promise.all([
    sb.rpc('eacr_r2322_overview'),
    sb.rpc('eacr_r2322_by_build'),
    sb.rpc('eacr_r2322_by_device'),
    sb.rpc('eacr_r2322_top_signatures'),
    sb.rpc('eacr_r2322_priority_queue'),
    sb.rpc('eacr_r2322_recent_events'),
    sb.rpc('eacr_r2322_daily_trend'),
  ]);

  const overview: Overview | null = overviewR.data?.[0] ?? null;
  const builds: any[] = buildR.data ?? [];
  const devices: any[] = deviceR.data ?? [];
  const signatures: any[] = sigR.data ?? [];
  const queue: any[] = queueR.data ?? [];
  const recent: any[] = recentR.data ?? [];
  const trend: any[] = trendR.data ?? [];

  const buildCols: Column<any>[] = [
    { key: 'build_version', header: 'Build', render: (r: any) => String(r.build_version ?? '') },
    { key: 'build_code', header: 'Code', render: (r: any) => String(r.build_code ?? '') },
    { key: 'total_events', header: 'Total', render: (r: any) => String(r.total_events ?? '') },
    { key: 'crash_count', header: 'Crashes', render: (r: any) => String(r.crash_count ?? '') },
    { key: 'anr_count', header: 'ANRs', render: (r: any) => String(r.anr_count ?? '') },
    { key: 'affected_users', header: 'Users', render: (r: any) => String(r.affected_users ?? '') },
    { key: 'blocking_count', header: 'Blocking', render: (r: any) => String(r.blocking_count ?? '') },
    { key: 'last_seen', header: 'Last seen', render: (r: any) => new Date(r.last_seen).toLocaleString('en-IN') },
  ];

  const deviceCols: Column<any>[] = [
    { key: 'device_brand', header: 'Brand', render: (r: any) => String(r.device_brand ?? '') },
    { key: 'device_model', header: 'Model', render: (r: any) => String(r.device_model ?? '') },
    { key: 'android_sdk', header: 'SDK', render: (r: any) => String(r.android_sdk ?? '') },
    { key: 'total_events', header: 'Total', render: (r: any) => String(r.total_events ?? '') },
    { key: 'crash_count', header: 'Crashes', render: (r: any) => String(r.crash_count ?? '') },
    { key: 'anr_count', header: 'ANRs', render: (r: any) => String(r.anr_count ?? '') },
    { key: 'affected_users', header: 'Users', render: (r: any) => String(r.affected_users ?? '') },
    { key: 'last_seen', header: 'Last seen', render: (r: any) => new Date(r.last_seen).toLocaleString('en-IN') },
  ];

  const sigCols: Column<any>[] = [
    { key: 'signature', header: 'Top frame', render: (r: any) => String(r.signature ?? '') },
    { key: 'exception_class', header: 'Class', render: (r: any) => String(r.exception_class ?? '') },
    { key: 'event_kind', header: 'Kind', render: (r: any) => String(r.event_kind ?? '') },
    { key: 'total_occurrences', header: 'Count', render: (r: any) => String(r.total_occurrences ?? '') },
    { key: 'affected_users', header: 'Users', render: (r: any) => String(r.affected_users ?? '') },
    { key: 'triage_status', header: 'Status', render: (r: any) => String(r.triage_status ?? '') },
    { key: 'fix_priority', header: 'Priority', render: (r: any) => String(r.fix_priority ?? '') },
    { key: 'last_seen', header: 'Last seen', render: (r: any) => new Date(r.last_seen).toLocaleString('en-IN') },
  ];

  const queueCols: Column<any>[] = [
    { key: 'fix_priority', header: 'Priority', render: (r: any) => String(r.fix_priority ?? '') },
    { key: 'signature', header: 'Signature', render: (r: any) => String(r.signature ?? '') },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
    { key: 'blocking_release', header: 'Blocking', render: (r: any) => (r.blocking_release ? 'yes' : 'no') },
    { key: 'total_occurrences', header: 'Count', render: (r: any) => String(r.total_occurrences ?? '') },
    { key: 'affected_users', header: 'Users', render: (r: any) => String(r.affected_users ?? '') },
    { key: 'assignee_email', header: 'Assignee', render: (r: any) => String(r.assignee_email ?? '') },
    { key: 'fixed_in_build', header: 'Fixed in', render: (r: any) => String(r.fixed_in_build ?? '') },
    { key: 'last_seen_at', header: 'Last seen', render: (r: any) => new Date(r.last_seen_at).toLocaleString('en-IN') },
  ];

  const recentCols: Column<any>[] = [
    { key: 'occurred_at', header: 'When', render: (r: any) => new Date(r.occurred_at).toLocaleString('en-IN') },
    { key: 'event_kind', header: 'Kind', render: (r: any) => String(r.event_kind ?? '') },
    { key: 'build_version', header: 'Build', render: (r: any) => String(r.build_version ?? '') },
    { key: 'device_brand', header: 'Brand', render: (r: any) => String(r.device_brand ?? '') },
    { key: 'device_model', header: 'Model', render: (r: any) => String(r.device_model ?? '') },
    { key: 'android_sdk', header: 'SDK', render: (r: any) => String(r.android_sdk ?? '') },
    { key: 'exception_class', header: 'Exception', render: (r: any) => String(r.exception_class ?? '') },
    { key: 'top_frame', header: 'Top frame', render: (r: any) => String(r.top_frame ?? '') },
    { key: 'reporter_email', header: 'Reporter', render: (r: any) => String(r.reporter_email ?? '') },
    { key: 'is_blocking', header: 'Blocking', render: (r: any) => (r.is_blocking ? 'yes' : 'no') },
  ];

  const trendCols: Column<any>[] = [
    { key: 'day', header: 'Day', render: (r: any) => String(r.day ?? '') },
    { key: 'crash_count', header: 'Crashes', render: (r: any) => String(r.crash_count ?? '') },
    { key: 'anr_count', header: 'ANRs', render: (r: any) => String(r.anr_count ?? '') },
    { key: 'blocking_count', header: 'Blocking', render: (r: any) => String(r.blocking_count ?? '') },
    { key: 'affected_users', header: 'Users', render: (r: any) => String(r.affected_users ?? '') },
  ];

  return (
    <main style={{ padding: 24, fontFamily: 'system-ui, sans-serif' }}>
      <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 8 }}>
        Engineer App — Crash & ANR Tracker
      </h1>
      <p style={{ color: '#555', marginBottom: 16 }}>
        Crash & ANR reports from engineer Android app grouped by build & device, with fix-priority triage queue.
      </p>

      <section style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: 12, marginBottom: 24 }}>
        <Kpi label="Crashes 7d" value={overview?.total_crashes_7d ?? 0} />
        <Kpi label="ANRs 7d" value={overview?.total_anrs_7d ?? 0} />
        <Kpi label="Blocking open" value={overview?.blocking_open ?? 0} />
        <Kpi label="P0 open" value={overview?.p0_open ?? 0} />
        <Kpi label="Users hit 7d" value={overview?.affected_users_7d ?? 0} />
        <Kpi label="Signatures" value={overview?.distinct_signatures ?? 0} />
        <Kpi label="Worst build" value={overview?.worst_build ?? '—'} />
        <Kpi label="Worst build count" value={overview?.worst_build_count ?? 0} />
      </section>

      <h2 style={{ fontSize: 18, fontWeight: 600, margin: '16px 0 8px' }}>Fix-priority queue</h2>
      <DataTable
        columns={queueCols}
        rows={queue}
        rowKey={(r: any) => r.stack_hash}
        emptyMessage="No open triage items"
      />

      <h2 style={{ fontSize: 18, fontWeight: 600, margin: '24px 0 8px' }}>Top signatures (30d)</h2>
      <DataTable
        columns={sigCols}
        rows={signatures}
        rowKey={(r: any) => r.stack_hash}
        emptyMessage="No signatures"
      />

      <h2 style={{ fontSize: 18, fontWeight: 600, margin: '24px 0 8px' }}>By build version (30d)</h2>
      <DataTable
        columns={buildCols}
        rows={builds}
        rowKey={(r: any) => r.build_version}
        emptyMessage="No build data"
      />

      <h2 style={{ fontSize: 18, fontWeight: 600, margin: '24px 0 8px' }}>By device model (30d)</h2>
      <DataTable
        columns={deviceCols}
        rows={devices}
        rowKey={(r: any) => `${r.device_brand}-${r.device_model}`}
        emptyMessage="No device data"
      />

      <h2 style={{ fontSize: 18, fontWeight: 600, margin: '24px 0 8px' }}>Daily trend (14d)</h2>
      <DataTable
        columns={trendCols}
        rows={trend}
        rowKey={(r: any) => String(r.day)}
        emptyMessage="No trend data"
      />

      <h2 style={{ fontSize: 18, fontWeight: 600, margin: '24px 0 8px' }}>Recent events</h2>
      <DataTable
        columns={recentCols}
        rows={recent}
        rowKey={(r: any) => r.id}
        emptyMessage="No recent events"
      />
    </main>
  );
}

function Kpi({ label, value }: { label: string; value: string | number }) {
  return (
    <div style={{ border: '1px solid #e5e7eb', borderRadius: 8, padding: 12, background: '#fff' }}>
      <div style={{ fontSize: 12, color: '#666' }}>{label}</div>
      <div style={{ fontSize: 22, fontWeight: 700 }}>{value}</div>
    </div>
  );
}
