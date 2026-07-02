import { requireFounder } from '@/lib/auth/requireFounder';
import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Kpi = { label: string; value: string | number };

export default async function FounderInvestorPortfolioNdaPage() {
  await requireFounder();
  const sb = await getSupabaseServerClient();

  let kpis: Record<string, any> = {};
  let records: any[] = [];
  let countersignQueue: any[] = [];
  let expiringSoon: any[] = [];
  let accessEvents: any[] = [];

  try {
    const r = await sb.rpc('founder_nda_kpis_r1580');
    kpis = (r.data as any) ?? {};
  } catch {
    kpis = {};
  }
  try {
    const r = await sb.rpc('founder_nda_list_records_r1580');
    records = (r.data as any[]) ?? [];
  } catch {
    records = [];
  }
  try {
    const r = await sb.rpc('founder_nda_countersign_queue_r1580');
    countersignQueue = (r.data as any[]) ?? [];
  } catch {
    countersignQueue = [];
  }
  try {
    const r = await sb.rpc('founder_nda_expiring_soon_r1580');
    expiringSoon = (r.data as any[]) ?? [];
  } catch {
    expiringSoon = [];
  }
  try {
    const r = await sb.rpc('founder_nda_access_events_r1580');
    accessEvents = (r.data as any[]) ?? [];
  } catch {
    accessEvents = [];
  }

  const cards: Kpi[] = [
    { label: 'Total NDAs', value: kpis.total_records ?? 0 },
    { label: 'Pending', value: kpis.pending ?? 0 },
    { label: 'Signed', value: kpis.signed ?? 0 },
    { label: 'Countersigned', value: kpis.countersigned ?? 0 },
    { label: 'Declined', value: kpis.declined ?? 0 },
    { label: 'Expired', value: kpis.expired ?? 0 },
    { label: 'Access Granted', value: kpis.access_granted ?? 0 },
    { label: 'Access Revoked', value: kpis.access_revoked ?? 0 },
    { label: 'Expiring 30d', value: kpis.expiring_30d ?? 0 },
    { label: 'Expiring 7d', value: kpis.expiring_7d ?? 0 },
    { label: 'Overdue Countersign', value: kpis.overdue_countersign ?? 0 },
    { label: 'Awaiting Countersign', value: kpis.awaiting_countersign ?? 0 },
    { label: 'Access Events Total', value: kpis.access_events_total ?? 0 },
    { label: 'Access Events 7d', value: kpis.access_events_7d ?? 0 },
    { label: 'Distinct Firms', value: kpis.firms_distinct ?? 0 },
    { label: 'Avg Days to Countersign', value: kpis.avg_days_to_countersign ?? 0 },
  ];

  const recordCols: Column<any>[] = [
    { key: 'investor_name', header: 'Investor', render: (r: any) => r.investor_name ?? '—' },
    { key: 'firm_name', header: 'Firm', render: (r: any) => r.firm_name ?? '—' },
    { key: 'investor_email', header: 'Email', render: (r: any) => r.investor_email ?? '—' },
    { key: 'nda_status', header: 'Status', render: (r: any) => r.nda_status ?? '—' },
    { key: 'investor_signed_at', header: 'Signed', render: (r: any) => r.investor_signed_at ? new Date(r.investor_signed_at).toLocaleDateString() : '—' },
    { key: 'founder_countersigned_at', header: 'Countersigned', render: (r: any) => r.founder_countersigned_at ? new Date(r.founder_countersigned_at).toLocaleDateString() : '—' },
    { key: 'expires_at', header: 'Expires', render: (r: any) => r.expires_at ? new Date(r.expires_at).toLocaleDateString() : '—' },
    { key: 'data_room_access_granted', header: 'Data Room', render: (r: any) => r.data_room_access_granted ? 'Yes' : 'No' },
  ];

  const queueCols: Column<any>[] = [
    { key: 'investor_name', header: 'Investor', render: (r: any) => r.investor_name ?? '—' },
    { key: 'firm_name', header: 'Firm', render: (r: any) => r.firm_name ?? '—' },
    { key: 'investor_signed_at', header: 'Signed At', render: (r: any) => r.investor_signed_at ? new Date(r.investor_signed_at).toLocaleString() : '—' },
    { key: 'days_waiting', header: 'Days Waiting', render: (r: any) => r.days_waiting ?? '—' },
  ];

  const expiringCols: Column<any>[] = [
    { key: 'investor_name', header: 'Investor', render: (r: any) => r.investor_name ?? '—' },
    { key: 'firm_name', header: 'Firm', render: (r: any) => r.firm_name ?? '—' },
    { key: 'expires_at', header: 'Expires', render: (r: any) => r.expires_at ? new Date(r.expires_at).toLocaleDateString() : '—' },
    { key: 'days_to_expire', header: 'Days Left', render: (r: any) => r.days_to_expire ?? '—' },
  ];

  const eventCols: Column<any>[] = [
    { key: 'investor_name', header: 'Investor', render: (r: any) => r.investor_name ?? '—' },
    { key: 'event_type', header: 'Event', render: (r: any) => r.event_type ?? '—' },
    { key: 'occurred_at', header: 'When', render: (r: any) => r.occurred_at ? new Date(r.occurred_at).toLocaleString() : '—' },
  ];

  return (
    <div className="p-6 space-y-6">
      <div>
        <h1 className="text-2xl font-semibold">Investor Portfolio NDA Tracker</h1>
        <p className="text-sm text-gray-500">Per-investor NDA status, data room access, auto-expire, countersign queue. (r1580)</p>
      </div>

      <div className="grid grid-cols-2 md:grid-cols-4 lg:grid-cols-8 gap-3">
        {cards.map((c) => (
          <div key={c.label} className="border rounded-lg p-3 bg-white">
            <div className="text-xs text-gray-500">{c.label}</div>
            <div className="text-xl font-semibold">{c.value}</div>
          </div>
        ))}
      </div>

      <section>
        <h2 className="text-lg font-medium mb-2">Countersign Queue</h2>
        <DataTable rows={countersignQueue} columns={queueCols} rowKey={(r: any) => r.id} />
      </section>

      <section>
        <h2 className="text-lg font-medium mb-2">Expiring Soon (60 days)</h2>
        <DataTable rows={expiringSoon} columns={expiringCols} rowKey={(r: any) => r.id} />
      </section>

      <section>
        <h2 className="text-lg font-medium mb-2">All NDA Records</h2>
        <DataTable rows={records} columns={recordCols} rowKey={(r: any) => r.id} />
      </section>

      <section>
        <h2 className="text-lg font-medium mb-2">Recent Data Room Access Events</h2>
        <DataTable rows={accessEvents} columns={eventCols} rowKey={(r: any) => r.id} />
      </section>
    </div>
  );
}
