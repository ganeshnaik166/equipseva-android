import { requireFounder } from '@/lib/auth/requireFounder';
import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Kpi = { label: string; value: string };

export default async function FounderMidYearBoardPackPage() {
  await requireFounder();
  const sb = await getSupabaseServerClient();

  const today = new Date();
  const periodEnd = today.toISOString().slice(0, 10);
  const periodStart = new Date(today.getFullYear(), today.getMonth() - 6, 1)
    .toISOString()
    .slice(0, 10);

  let kpiRows: any[] = [];
  let drafts: any[] = [];
  let queue: any[] = [];
  let growth: any[] = [];

  try {
    const r = await sb.rpc('founder_board_pack_kpi_snapshot', {
      p_start: periodStart,
      p_end: periodEnd,
    });
    kpiRows = (r.data as any[]) ?? [];
  } catch {
    kpiRows = [];
  }

  try {
    const r = await sb.rpc('founder_board_pack_list_drafts');
    drafts = (r.data as any[]) ?? [];
  } catch {
    drafts = [];
  }

  try {
    const r = await sb.rpc('founder_board_pack_list_email_queue');
    queue = (r.data as any[]) ?? [];
  } catch {
    queue = [];
  }

  try {
    const r = await sb.rpc('founder_board_pack_pillar_growth', {
      p_start: periodStart,
      p_end: periodEnd,
    });
    growth = (r.data as any[]) ?? [];
  } catch {
    growth = [];
  }

  const kpiMap = new Map<string, string>();
  for (const k of kpiRows) {
    kpiMap.set(String(k.metric), String(k.value_num ?? k.value_text ?? '0'));
  }
  const get = (k: string) => kpiMap.get(k) ?? '0';

  const draftsTotal = drafts.length;
  const draftsReady = drafts.filter((d: any) => d.status === 'ready').length;
  const draftsShipped = drafts.filter((d: any) => d.status === 'shipped').length;
  const draftsArchived = drafts.filter((d: any) => d.status === 'archived').length;
  const queueTotal = queue.length;
  const queueSent = queue.filter((q: any) => q.status === 'sent').length;
  const queueQueued = queue.filter((q: any) => q.status === 'queued').length;
  const queueFailed = queue.filter((q: any) => q.status === 'failed').length;
  const growthMonths = growth.length;
  const growthGmv = growth.reduce(
    (s: number, g: any) => s + Number(g.gmv_rupees ?? 0),
    0,
  );

  const kpis: Kpi[] = [
    { label: 'Period start', value: periodStart },
    { label: 'Period end', value: periodEnd },
    { label: 'Hospitals active', value: get('hospitals_active') },
    { label: 'Engineers active', value: get('engineers_active') },
    { label: 'Jobs in period', value: get('jobs_in_period') },
    { label: 'GMV (rupees)', value: get('gmv_rupees') },
    { label: 'AMC active', value: get('amc_active') },
    { label: 'Avg hospital rating', value: Number(get('avg_hospital_rating')).toFixed(2) },
    { label: 'Drafts total', value: String(draftsTotal) },
    { label: 'Drafts ready', value: String(draftsReady) },
    { label: 'Drafts shipped', value: String(draftsShipped) },
    { label: 'Drafts archived', value: String(draftsArchived) },
    { label: 'Queue total', value: String(queueTotal) },
    { label: 'Queue sent', value: String(queueSent) },
    { label: 'Queue queued', value: String(queueQueued) },
    { label: 'Queue failed', value: String(queueFailed) },
  ];

  const draftCols: Column<any>[] = [
    { key: 'cycle_label', header: 'Cycle', render: (r: any) => r.cycle_label ?? '—' },
    { key: 'period_start', header: 'Start', render: (r: any) => r.period_start ?? '—' },
    { key: 'period_end', header: 'End', render: (r: any) => r.period_end ?? '—' },
    { key: 'status', header: 'Status', render: (r: any) => r.status ?? '—' },
    {
      key: 'updated_at',
      header: 'Updated',
      render: (r: any) => (r.updated_at ? String(r.updated_at).slice(0, 19) : '—'),
    },
  ];

  const queueCols: Column<any>[] = [
    { key: 'recipient_email', header: 'Email', render: (r: any) => r.recipient_email ?? '—' },
    { key: 'recipient_name', header: 'Name', render: (r: any) => r.recipient_name ?? '—' },
    { key: 'subject', header: 'Subject', render: (r: any) => r.subject ?? '—' },
    { key: 'status', header: 'Status', render: (r: any) => r.status ?? '—' },
    {
      key: 'queued_at',
      header: 'Queued',
      render: (r: any) => (r.queued_at ? String(r.queued_at).slice(0, 19) : '—'),
    },
  ];

  const growthCols: Column<any>[] = [
    { key: 'bucket', header: 'Month', render: (r: any) => r.bucket ?? '—' },
    { key: 'jobs_count', header: 'Jobs', render: (r: any) => String(r.jobs_count ?? 0) },
    {
      key: 'gmv_rupees',
      header: 'GMV (rupees)',
      render: (r: any) => Number(r.gmv_rupees ?? 0).toLocaleString('en-IN'),
    },
  ];

  const kpiSnapshotCols: Column<any>[] = [
    { key: 'metric', header: 'Metric', render: (r: any) => r.metric ?? '—' },
    {
      key: 'value_num',
      header: 'Value',
      render: (r: any) => String(r.value_num ?? r.value_text ?? '—'),
    },
  ];

  return (
    <main style={{ padding: 24, fontFamily: 'system-ui, sans-serif' }}>
      <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 4 }}>
        Founder — Mid-Year Board Pack Auto-Builder
      </h1>
      <p style={{ color: '#555', marginBottom: 16 }}>
        Auto-aggregate top KPIs into board-pack format (executive summary, pillars, asks).
        Founder edits in-place and ships to the investor email-out queue.
        Growth months tracked: {growthMonths}. Growth GMV total: {growthGmv.toLocaleString('en-IN')}.
      </p>

      <section
        style={{
          display: 'grid',
          gridTemplateColumns: 'repeat(4, minmax(0, 1fr))',
          gap: 12,
          marginBottom: 24,
        }}
      >
        {kpis.map((k) => (
          <div
            key={k.label}
            style={{
              border: '1px solid #e5e7eb',
              borderRadius: 8,
              padding: 12,
              background: '#fff',
            }}
          >
            <div style={{ fontSize: 12, color: '#6b7280' }}>{k.label}</div>
            <div style={{ fontSize: 18, fontWeight: 600 }}>{k.value}</div>
          </div>
        ))}
      </section>

      <section style={{ marginBottom: 24 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Drafts</h2>
        <DataTable
          columns={draftCols}
          rows={drafts}
          rowKey={(r: any) => r.id}
        />
      </section>

      <section style={{ marginBottom: 24 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Email queue</h2>
        <DataTable
          columns={queueCols}
          rows={queue}
          rowKey={(r: any) => r.id}
        />
      </section>

      <section style={{ marginBottom: 24 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>
          Pillar — growth by month
        </h2>
        <DataTable
          columns={growthCols}
          rows={growth}
          rowKey={(r: any) => r.bucket}
        />
      </section>

      <section style={{ marginBottom: 24 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>KPI snapshot rows</h2>
        <DataTable
          columns={kpiSnapshotCols}
          rows={kpiRows}
          rowKey={(r: any) => r.metric}
        />
      </section>
    </main>
  );
}
