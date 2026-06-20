import { requireFounder } from '@/lib/auth/requireFounder';
import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Kpi = { label: string; value: string };

function inr(n: number | null | undefined): string {
  const v = Number(n ?? 0);
  if (v >= 10000000) return `Rs ${(v/10000000).toFixed(2)}Cr`;
  if (v >= 100000) return `Rs ${(v/100000).toFixed(2)}L`;
  if (v >= 1000) return `Rs ${(v/1000).toFixed(1)}K`;
  return `Rs ${v}`;
}

export default async function Page() {
  await requireFounder();
  const sb = await getSupabaseServerClient();

  let kpis: any = null;
  let ladder: any[] = [];
  let ageing: any[] = [];
  let events: any[] = [];

  try {
    const r = await sb.rpc('founder_isc_kpis');
    kpis = (r.data && r.data[0]) || null;
  } catch (_e) { kpis = null; }

  try {
    const r = await sb.rpc('founder_isc_ladder');
    ladder = (r.data as any[]) || [];
  } catch (_e) { ladder = []; }

  try {
    const r = await sb.rpc('founder_isc_ageing_report');
    ageing = (r.data as any[]) || [];
  } catch (_e) { ageing = []; }

  try {
    const r = await sb.rpc('founder_isc_recent_events');
    events = (r.data as any[]) || [];
  } catch (_e) { events = []; }

  const k: Kpi[] = [
    { label: 'Total commits', value: String(kpis?.total_commits ?? 0) },
    { label: 'Pipeline total', value: inr(kpis?.total_amount_rupees) },
    { label: 'Weighted pipeline', value: inr(kpis?.weighted_pipeline_rupees) },
    { label: 'Hardening rate %', value: String(kpis?.hardening_rate ?? 0) },
    { label: 'Verbal count', value: String(kpis?.verbal_count ?? 0) },
    { label: 'Verbal amount', value: inr(kpis?.verbal_amount) },
    { label: 'Soft count', value: String(kpis?.soft_count ?? 0) },
    { label: 'Soft amount', value: inr(kpis?.soft_amount) },
    { label: 'Term-sheet count', value: String(kpis?.ts_count ?? 0) },
    { label: 'Term-sheet amount', value: inr(kpis?.ts_amount) },
    { label: 'Signed count', value: String(kpis?.signed_count ?? 0) },
    { label: 'Signed amount', value: inr(kpis?.signed_amount) },
    { label: 'Wired count', value: String(kpis?.wired_count ?? 0) },
    { label: 'Wired amount', value: inr(kpis?.wired_amount) },
    { label: 'Dropped count', value: String(kpis?.dropped_count ?? 0) },
    { label: 'Overdue SLA', value: String(kpis?.overdue_sla_count ?? 0) },
  ];

  const ladderCols: Column<any>[] = [
    { key: 'investor_name', header: 'Investor', render: (r: any) => r.investor_name ?? '—' },
    { key: 'investor_firm', header: 'Firm', render: (r: any) => r.investor_firm ?? '—' },
    { key: 'commit_stage', header: 'Stage', render: (r: any) => r.commit_stage ?? '—' },
    { key: 'amount_rupees', header: 'Amount', render: (r: any) => inr(r.amount_rupees) },
    { key: 'weighted_amount', header: 'Weighted', render: (r: any) => inr(r.weighted_amount) },
    { key: 'days_in_pipeline', header: 'Days in pipe', render: (r: any) => String(r.days_in_pipeline ?? 0) },
    { key: 'expected_close_date', header: 'Expected close', render: (r: any) => r.expected_close_date ?? '—' },
  ];

  const ageingCols: Column<any>[] = [
    { key: 'investor_name', header: 'Investor', render: (r: any) => r.investor_name ?? '—' },
    { key: 'commit_stage', header: 'Stage', render: (r: any) => r.commit_stage ?? '—' },
    { key: 'amount_rupees', header: 'Amount', render: (r: any) => inr(r.amount_rupees) },
    { key: 'days_since_touch', header: 'Days since touch', render: (r: any) => String(r.days_since_touch ?? 0) },
    { key: 'follow_up_sla_days', header: 'SLA (d)', render: (r: any) => String(r.follow_up_sla_days ?? 0) },
    { key: 'sla_breach_days', header: 'Breach (d)', render: (r: any) => String(r.sla_breach_days ?? 0) },
    { key: 'status', header: 'Status', render: (r: any) => r.status ?? '—' },
  ];

  const conditionsCols: Column<any>[] = [
    { key: 'investor_name', header: 'Investor', render: (r: any) => r.investor_name ?? '—' },
    { key: 'commit_stage', header: 'Stage', render: (r: any) => r.commit_stage ?? '—' },
    { key: 'conditions', header: 'Conditions', render: (r: any) => r.conditions ?? '—' },
    { key: 'amount_rupees', header: 'Amount', render: (r: any) => inr(r.amount_rupees) },
  ];

  const breachCols: Column<any>[] = [
    { key: 'investor_name', header: 'Investor', render: (r: any) => r.investor_name ?? '—' },
    { key: 'status', header: 'Bucket', render: (r: any) => r.status ?? '—' },
    { key: 'days_since_touch', header: 'Days quiet', render: (r: any) => String(r.days_since_touch ?? 0) },
    { key: 'amount_rupees', header: 'At risk', render: (r: any) => inr(r.amount_rupees) },
  ];

  const eventCols: Column<any>[] = [
    { key: 'investor_name', header: 'Investor', render: (r: any) => r.investor_name ?? '—' },
    { key: 'event_type', header: 'Event', render: (r: any) => r.event_type ?? '—' },
    { key: 'from_stage', header: 'From', render: (r: any) => r.from_stage ?? '—' },
    { key: 'to_stage', header: 'To', render: (r: any) => r.to_stage ?? '—' },
    { key: 'created_at', header: 'When', render: (r: any) => r.created_at ?? '—' },
  ];

  const breachList = (ageing || []).filter((r: any) => r.status === 'red' || r.status === 'amber');
  const conditionsList = (ladder || []).filter((r: any) => r.conditions && String(r.conditions).length > 0);

  return (
    <main style={{ padding: 24, fontFamily: 'system-ui, sans-serif', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: 24, fontWeight: 700 }}>Investor soft-commit ladder</h1>
      <p style={{ color: '#666', marginTop: 4, marginBottom: 16 }}>
        Capture verbal {">"} soft {">"} term-sheet {">"} signed {">"} wired. Track ageing + SLA breaches.
      </p>

      <section style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: 12, marginBottom: 24 }}>
        {k.map((c) => (
          <div key={c.label} style={{ border: '1px solid #e5e7eb', borderRadius: 8, padding: 12 }}>
            <div style={{ fontSize: 12, color: '#6b7280' }}>{c.label}</div>
            <div style={{ fontSize: 18, fontWeight: 600, marginTop: 4 }}>{c.value}</div>
          </div>
        ))}
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Ladder (active)</h2>
        <DataTable columns={ladderCols} rows={ladder} rowKey={(r: any) => r.id} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Ageing report (follow-up SLA)</h2>
        <DataTable columns={ageingCols} rows={ageing} rowKey={(r: any) => r.id} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>SLA breaches (amber + red)</h2>
        <DataTable columns={breachCols} rows={breachList} rowKey={(r: any) => r.id} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Conditions to clear</h2>
        <DataTable columns={conditionsCols} rows={conditionsList} rowKey={(r: any) => r.id} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Recent events</h2>
        <DataTable columns={eventCols} rows={events} rowKey={(r: any) => r.id} />
      </section>
    </main>
  );
}
