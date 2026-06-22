import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type SlaRow = {
  id: string;
  hospital_id: string;
  hospital_name: string | null;
  part_category: string;
  target_delivery_hours: number;
  actual_delivery_hours: number;
  sla_met: boolean;
  status: string;
  captured_at: string;
};

type BreachRow = {
  id: string;
  sla_id: string;
  hospital_name: string | null;
  action_type: string;
  taken_at: string;
  by_email: string | null;
  notes_md: string | null;
};

type RecentBreachRow = {
  id: string;
  hospital_name: string | null;
  part_category: string;
  target_delivery_hours: number;
  actual_delivery_hours: number;
  captured_at: string;
  status: string;
};

type TopBreachRow = {
  hospital_id: string;
  hospital_name: string | null;
  breach_count: number;
  total_count: number;
  breach_rate_pct: number;
};

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [slasRes, breachesRes, recentRes, topRes] = await Promise.all([
    sb.rpc('list_slas_r1963'),
    sb.rpc('list_breaches_r1963', { p_sla_id: null }),
    sb.rpc('recent_breaches_r1963'),
    sb.rpc('top_breach_hospitals_r1963'),
  ]);

  const slas: SlaRow[] = (slasRes.data as SlaRow[]) ?? [];
  const breaches: BreachRow[] = (breachesRes.data as BreachRow[]) ?? [];
  const recent: RecentBreachRow[] = (recentRes.data as RecentBreachRow[]) ?? [];
  const top: TopBreachRow[] = (topRes.data as TopBreachRow[]) ?? [];

  const slaCols: Column<SlaRow>[] = [
    { key: 'hospital_name', header: 'Hospital', render: (r: any) => r.hospital_name ?? '—' },
    { key: 'part_category', header: 'Category', render: (r: any) => r.part_category },
    { key: 'target_delivery_hours', header: 'Target (hr)', render: (r: any) => String(r.target_delivery_hours) },
    { key: 'actual_delivery_hours', header: 'Actual (hr)', render: (r: any) => String(r.actual_delivery_hours) },
    { key: 'sla_met', header: 'Met', render: (r: any) => (r.sla_met ? 'yes' : 'no') },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'captured_at', header: 'Captured', render: (r: any) => new Date(r.captured_at).toLocaleString() },
  ];

  const breachCols: Column<BreachRow>[] = [
    { key: 'hospital_name', header: 'Hospital', render: (r: any) => r.hospital_name ?? '—' },
    { key: 'action_type', header: 'Action', render: (r: any) => r.action_type },
    { key: 'taken_at', header: 'Taken at', render: (r: any) => new Date(r.taken_at).toLocaleString() },
    { key: 'by_email', header: 'By', render: (r: any) => r.by_email ?? '—' },
    { key: 'notes_md', header: 'Notes', render: (r: any) => r.notes_md ?? '—' },
  ];

  const recentCols: Column<RecentBreachRow>[] = [
    { key: 'hospital_name', header: 'Hospital', render: (r: any) => r.hospital_name ?? '—' },
    { key: 'part_category', header: 'Category', render: (r: any) => r.part_category },
    { key: 'target_delivery_hours', header: 'Target (hr)', render: (r: any) => String(r.target_delivery_hours) },
    { key: 'actual_delivery_hours', header: 'Actual (hr)', render: (r: any) => String(r.actual_delivery_hours) },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'captured_at', header: 'Captured', render: (r: any) => new Date(r.captured_at).toLocaleString() },
  ];

  const topCols: Column<TopBreachRow>[] = [
    { key: 'hospital_name', header: 'Hospital', render: (r: any) => r.hospital_name ?? '—' },
    { key: 'breach_count', header: 'Breaches', render: (r: any) => String(r.breach_count) },
    { key: 'total_count', header: 'Total SLAs', render: (r: any) => String(r.total_count) },
    { key: 'breach_rate_pct', header: 'Breach %', render: (r: any) => `${r.breach_rate_pct ?? 0}%` },
  ];

  return (
    <main className="p-6 space-y-8">
      <header className="space-y-1">
        <h1 className="text-2xl font-semibold">Hospital Spare Parts SLA Tracker</h1>
        <p className="text-sm text-gray-600">
          Track spare parts delivery SLA per hospital. Categories: consumable, critical spare, non critical, and long lead time.
          A breach is logged when actual delivery hours go above target.
        </p>
      </header>

      <section>
        <h2 className="text-lg font-semibold mb-2">Top breach hospitals</h2>
        <p className="text-xs text-gray-500 mb-2">Hospitals with at least one breached or escalated SLA, ranked by breach count.</p>
        <DataTable rows={top} columns={topCols} rowKey={(r: any, i: number) => String(r.hospital_id ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Recent breaches (last 30 days)</h2>
        <p className="text-xs text-gray-500 mb-2">SLAs where status is breached or escalated within the last 30 days.</p>
        <DataTable rows={recent} columns={recentCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">All SLA records</h2>
        <p className="text-xs text-gray-500 mb-2">Most recent 200 SLA captures across all hospitals and part categories.</p>
        <DataTable rows={slas} columns={slaCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Breach action log</h2>
        <p className="text-xs text-gray-500 mb-2">Actions taken on breached SLAs: escalated, expedited alternative, customer notified, credit issued, or process improved.</p>
        <DataTable rows={breaches} columns={breachCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>
    </main>
  );
}
