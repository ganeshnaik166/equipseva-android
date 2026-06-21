import { requireFounder } from '@/lib/auth/requireFounder';
import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Kpi = { label: string; value: string };

function fmt(n: any): string {
  if (n === null || n === undefined) return '—';
  if (typeof n === 'number') return n.toLocaleString('en-IN');
  return String(n);
}

function money(n: any): string {
  const v = Number(n);
  if (!Number.isFinite(v)) return '—';
  return '₹' + v.toLocaleString('en-IN', { maximumFractionDigits: 2 });
}

export default async function FounderEsopGrantLedgerPage() {
  await requireFounder();
  const sb = await getSupabaseServerClient();

  let kpis: any = {};
  let grants: any[] = [];
  let vesting: any[] = [];
  let pending: any[] = [];
  let events: any[] = [];
  let breakdown: any[] = [];

  try {
    const r = await sb.rpc('rpc_esop_kpis');
    kpis = (r.data as any) ?? {};
  } catch { kpis = {}; }

  try {
    const r = await sb.rpc('rpc_esop_grants_list', { p_limit: 200 });
    grants = (r.data as any[]) ?? [];
  } catch { grants = []; }

  try {
    const r = await sb.rpc('rpc_esop_vesting_per_grantee');
    vesting = (r.data as any[]) ?? [];
  } catch { vesting = []; }

  try {
    const r = await sb.rpc('rpc_esop_pending_approvals');
    pending = (r.data as any[]) ?? [];
  } catch { pending = []; }

  try {
    const r = await sb.rpc('rpc_esop_recent_events', { p_limit: 100 });
    events = (r.data as any[]) ?? [];
  } catch { events = []; }

  try {
    const r = await sb.rpc('rpc_esop_status_breakdown');
    breakdown = (r.data as any[]) ?? [];
  } catch { breakdown = []; }

  const cards: Kpi[] = [
    { label: 'Total grants', value: fmt(kpis.total_grants) },
    { label: 'Pending approval', value: fmt(kpis.pending_grants) },
    { label: 'Approved', value: fmt(kpis.approved_grants) },
    { label: 'Rejected', value: fmt(kpis.rejected_grants) },
    { label: 'Cancelled', value: fmt(kpis.cancelled_grants) },
    { label: 'Exercised', value: fmt(kpis.exercised_grants) },
    { label: 'Unique grantees', value: fmt(kpis.unique_grantees) },
    { label: 'Options granted', value: fmt(kpis.total_options_granted) },
    { label: 'Options vested', value: fmt(kpis.total_options_vested) },
    { label: 'Options unvested', value: fmt(kpis.total_options_unvested) },
    { label: 'Avg strike', value: money(kpis.avg_strike_rupees) },
    { label: 'In cliff', value: fmt(kpis.in_cliff_grants) },
    { label: 'Past cliff', value: fmt(kpis.past_cliff_grants) },
    { label: 'Fully vested', value: fmt(kpis.fully_vested_grants) },
    { label: 'Grants last 30d', value: fmt(kpis.grants_last_30d) },
    { label: 'Events last 7d', value: fmt(kpis.events_last_7d) },
  ];

  const grantCols: Column<any>[] = [
    { key: 'grantee_name', header: 'Grantee', render: (r: any) => r.grantee_name ?? '—' },
    { key: 'grantee_email', header: 'Email', render: (r: any) => r.grantee_email ?? '—' },
    { key: 'grantee_role', header: 'Role', render: (r: any) => r.grantee_role ?? '—' },
    { key: 'options_granted', header: 'Options', render: (r: any) => fmt(r.options_granted) },
    { key: 'strike_price_rupees', header: 'Strike', render: (r: any) => money(r.strike_price_rupees) },
    { key: 'status', header: 'Status', render: (r: any) => r.status ?? '—' },
    { key: 'grant_date', header: 'Grant date', render: (r: any) => r.grant_date ?? '—' },
    { key: 'cliff_months', header: 'Cliff (mo)', render: (r: any) => fmt(r.cliff_months) },
    { key: 'vest_months_total', header: 'Vest (mo)', render: (r: any) => fmt(r.vest_months_total) },
  ];

  const vestCols: Column<any>[] = [
    { key: 'grantee_email', header: 'Grantee', render: (r: any) => r.grantee_email ?? '—' },
    { key: 'grantee_name', header: 'Name', render: (r: any) => r.grantee_name ?? '—' },
    { key: 'options_granted', header: 'Granted', render: (r: any) => fmt(r.options_granted) },
    { key: 'options_vested', header: 'Vested', render: (r: any) => fmt(r.options_vested) },
    { key: 'options_unvested', header: 'Unvested', render: (r: any) => fmt(r.options_unvested) },
    { key: 'grants_count', header: '# grants', render: (r: any) => fmt(r.grants_count) },
  ];

  const pendingCols: Column<any>[] = [
    { key: 'grantee_name', header: 'Grantee', render: (r: any) => r.grantee_name ?? '—' },
    { key: 'grantee_email', header: 'Email', render: (r: any) => r.grantee_email ?? '—' },
    { key: 'grantee_role', header: 'Role', render: (r: any) => r.grantee_role ?? '—' },
    { key: 'options_granted', header: 'Options', render: (r: any) => fmt(r.options_granted) },
    { key: 'strike_price_rupees', header: 'Strike', render: (r: any) => money(r.strike_price_rupees) },
    { key: 'grant_date', header: 'Grant date', render: (r: any) => r.grant_date ?? '—' },
    { key: 'created_at', header: 'Submitted', render: (r: any) => r.created_at ?? '—' },
  ];

  const eventCols: Column<any>[] = [
    { key: 'occurred_at', header: 'When', render: (r: any) => r.occurred_at ?? '—' },
    { key: 'event_type', header: 'Event', render: (r: any) => r.event_type ?? '—' },
    { key: 'actor_email', header: 'Actor', render: (r: any) => r.actor_email ?? '—' },
    { key: 'grant_id', header: 'Grant', render: (r: any) => (r.grant_id ? String(r.grant_id).slice(0, 8) : '—') },
    { key: 'payload', header: 'Payload', render: (r: any) => (r.payload ? JSON.stringify(r.payload).slice(0, 80) : '—') },
  ];

  const breakdownCols: Column<any>[] = [
    { key: 'status', header: 'Status', render: (r: any) => r.status ?? '—' },
    { key: 'grants_count', header: 'Grants', render: (r: any) => fmt(r.grants_count) },
    { key: 'options_sum', header: 'Options sum', render: (r: any) => fmt(r.options_sum) },
  ];

  return (
    <div className="p-6 space-y-8">
      <header>
        <h1 className="text-2xl font-semibold">Investor ESOP grant ledger</h1>
        <p className="text-sm text-gray-600">Every grant, 1y cliff + monthly vesting, per-grantee unvested balance, founder approval audit. r1592.</p>
      </header>

      <section className="grid grid-cols-2 md:grid-cols-4 lg:grid-cols-8 gap-3">
        {cards.map((k) => (
          <div key={k.label} className="rounded border p-3">
            <div className="text-xs text-gray-500">{k.label}</div>
            <div className="text-lg font-semibold">{k.value}</div>
          </div>
        ))}
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-semibold">All grants</h2>
        <DataTable rows={grants} columns={grantCols} rowKey={(r: any) => r.id} />
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-semibold">Vesting per grantee</h2>
        <DataTable rows={vesting} columns={vestCols} rowKey={(r: any) => r.grantee_email} />
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-semibold">Pending founder approval</h2>
        <DataTable rows={pending} columns={pendingCols} rowKey={(r: any) => r.id} />
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-semibold">Status breakdown</h2>
        <DataTable rows={breakdown} columns={breakdownCols} rowKey={(r: any) => r.status} />
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-semibold">Recent audit events</h2>
        <DataTable rows={events} columns={eventCols} rowKey={(r: any) => r.id} />
      </section>
    </div>
  );
}
