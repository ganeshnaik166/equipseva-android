import { requireFounder } from '@/lib/auth/requireFounder';
import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

type Kpi = { label: string; value: string };

export const dynamic = 'force-dynamic';

function fmtInt(n: number | null | undefined): string {
  if (n === null || n === undefined) return '0';
  return Number(n).toLocaleString('en-IN');
}

function fmtRupees(n: number | null | undefined): string {
  if (n === null || n === undefined) return 'Rs 0';
  return 'Rs ' + Number(n).toLocaleString('en-IN');
}

function shortId(s: string | null | undefined): string {
  if (!s) return '-';
  return s.slice(0, 8);
}

export default async function FounderOpsScorecardDailyPage() {
  await requireFounder();
  const sb = await getSupabaseServerClient();

  let snap: any = null;
  let openJobs: any[] = [];
  let escalations: any[] = [];
  let payouts: any[] = [];
  let shortages: any[] = [];
  let incidents: any[] = [];
  let queue: any[] = [];

  try {
    const r = await sb.rpc('rpc_founder_ops_scorecard_today');
    snap = (r.data ?? [])[0] ?? null;
  } catch { snap = null; }

  try {
    const r = await sb.rpc('rpc_founder_ops_open_jobs', { p_limit: 50 });
    openJobs = r.data ?? [];
  } catch { openJobs = []; }

  try {
    const r = await sb.rpc('rpc_founder_ops_unassigned_escalations');
    escalations = r.data ?? [];
  } catch { escalations = []; }

  try {
    const r = await sb.rpc('rpc_founder_ops_payout_backlog');
    payouts = r.data ?? [];
  } catch { payouts = []; }

  try {
    const r = await sb.rpc('rpc_founder_ops_spare_shortages');
    shortages = r.data ?? [];
  } catch { shortages = []; }

  try {
    const r = await sb.rpc('rpc_founder_ops_open_incidents');
    incidents = r.data ?? [];
  } catch { incidents = []; }

  try {
    const r = await sb.rpc('rpc_founder_ops_action_queue');
    queue = r.data ?? [];
  } catch { queue = []; }

  try { await sb.rpc('log_founder_ops_scorecard_view'); } catch {}

  const totalQueue = queue.length;
  const p0Queue = queue.filter((q: any) => q.severity === 'p0').length;
  const p1Queue = queue.filter((q: any) => q.severity === 'p1').length;
  const totalPayoutRupees = payouts.reduce((s: number, p: any) => s + Number(p.amount_rupees ?? 0), 0);

  const kpis: Kpi[] = [
    { label: 'Health Score', value: fmtInt(snap?.health_score ?? 0) + '/100' },
    { label: 'Snapshot Date', value: String(snap?.snapshot_date ?? '-') },
    { label: 'Open Jobs', value: fmtInt(snap?.open_jobs_count ?? openJobs.length) },
    { label: 'Unassigned >48h', value: fmtInt(snap?.unassigned_jobs_count ?? escalations.length) },
    { label: 'Stuck Jobs >7d', value: fmtInt(snap?.stuck_jobs_count ?? 0) },
    { label: 'Payout Backlog', value: fmtInt(snap?.payout_backlog_count ?? payouts.length) },
    { label: 'Payout Rupees', value: fmtRupees(snap?.payout_backlog_rupees ?? totalPayoutRupees) },
    { label: 'Spare Shortages', value: fmtInt(snap?.spare_shortage_count ?? shortages.length) },
    { label: 'P0 Incidents', value: fmtInt(snap?.p0_incidents_open ?? 0) },
    { label: 'P1 Incidents', value: fmtInt(snap?.p1_incidents_open ?? 0) },
    { label: 'AMC Overdue', value: fmtInt(snap?.amc_overdue_count ?? 0) },
    { label: 'Action Queue', value: fmtInt(totalQueue) },
    { label: 'Queue P0', value: fmtInt(p0Queue) },
    { label: 'Queue P1', value: fmtInt(p1Queue) },
    { label: 'Open Incidents Shown', value: fmtInt(incidents.length) },
    { label: 'Built At', value: snap?.built_at ? new Date(snap.built_at).toLocaleString('en-IN') : '-' },
  ];

  const jobCols: Column<any>[] = [
    { key: 'id', header: 'Job', render: (r: any) => shortId(r.id) },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '-') },
    { key: 'kind', header: 'Kind', render: (r: any) => String(r.kind ?? '-') },
    { key: 'contracted_amount_rupees', header: 'Amount', render: (r: any) => fmtRupees(r.contracted_amount_rupees) },
    { key: 'age_days', header: 'Age (d)', render: (r: any) => String(r.age_days ?? '-') },
  ];

  const escCols: Column<any>[] = [
    { key: 'id', header: 'Job', render: (r: any) => shortId(r.id) },
    { key: 'kind', header: 'Kind', render: (r: any) => String(r.kind ?? '-') },
    { key: 'hospital_org_id', header: 'Hospital', render: (r: any) => shortId(r.hospital_org_id) },
    { key: 'hours_open', header: 'Hours Open', render: (r: any) => String(r.hours_open ?? '-') },
  ];

  const payCols: Column<any>[] = [
    { key: 'id', header: 'Payout', render: (r: any) => shortId(r.id) },
    { key: 'engineer_user_id', header: 'Engineer', render: (r: any) => shortId(r.engineer_user_id) },
    { key: 'amount_rupees', header: 'Amount', render: (r: any) => fmtRupees(r.amount_rupees) },
    { key: 'age_days', header: 'Age (d)', render: (r: any) => String(r.age_days ?? '-') },
  ];

  const incCols: Column<any>[] = [
    { key: 'id', header: 'Incident', render: (r: any) => shortId(r.id) },
    { key: 'severity', header: 'Severity', render: (r: any) => String(r.severity ?? '-').toUpperCase() },
    { key: 'title', header: 'Title', render: (r: any) => String(r.title ?? '-') },
    { key: 'hours_open', header: 'Hours Open', render: (r: any) => String(r.hours_open ?? '-') },
  ];

  const queueCols: Column<any>[] = [
    { key: 'severity', header: 'Sev', render: (r: any) => String(r.severity ?? '-').toUpperCase() },
    { key: 'category', header: 'Category', render: (r: any) => String(r.category ?? '-') },
    { key: 'subject', header: 'Subject', render: (r: any) => String(r.subject ?? '-') },
    { key: 'detail', header: 'Detail', render: (r: any) => String(r.detail ?? '-') },
    { key: 'age_hours', header: 'Age (h)', render: (r: any) => String(r.age_hours ?? '-') },
  ];

  return (
    <main style={{ padding: 24, maxWidth: 1280, margin: '0 auto' }}>
      <h1 style={{ fontSize: 28, fontWeight: 700, marginBottom: 4 }}>Founder Ops Scorecard — Daily</h1>
      <p style={{ color: '#666', marginBottom: 20 }}>
        Daily ops health card: open jobs, unassigned escalations, payout backlog, spare-part shortages, P0/P1 incidents and the founder action queue.
      </p>

      <section style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fill, minmax(180px, 1fr))', gap: 12, marginBottom: 28 }}>
        {kpis.map((k) => (
          <div key={k.label} style={{ border: '1px solid #e5e7eb', borderRadius: 8, padding: 12, background: '#fff' }}>
            <div style={{ fontSize: 11, color: '#6b7280', textTransform: 'uppercase', letterSpacing: 0.5 }}>{k.label}</div>
            <div style={{ fontSize: 18, fontWeight: 600, marginTop: 4 }}>{k.value}</div>
          </div>
        ))}
      </section>

      <section style={{ marginBottom: 28 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 10 }}>Open Jobs Queue</h2>
        <DataTable columns={jobCols} rows={openJobs} rowKey={(r: any) => r.id} />
      </section>

      <section style={{ marginBottom: 28 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 10 }}>Unassigned Escalations</h2>
        <DataTable columns={escCols} rows={escalations} rowKey={(r: any) => r.id} />
      </section>

      <section style={{ marginBottom: 28 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 10 }}>Payout Backlog</h2>
        <DataTable columns={payCols} rows={payouts} rowKey={(r: any) => r.id} />
      </section>

      <section style={{ marginBottom: 28 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 10 }}>Open P0/P1 Incidents</h2>
        <DataTable columns={incCols} rows={incidents} rowKey={(r: any) => r.id} />
      </section>

      <section style={{ marginBottom: 28 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 10 }}>Founder Action Queue</h2>
        <DataTable columns={queueCols} rows={queue} rowKey={(r: any) => r.id} />
      </section>
    </main>
  );
}
