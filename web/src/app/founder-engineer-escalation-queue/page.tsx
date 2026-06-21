import { requireFounder } from '@/lib/auth/requireFounder';
import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

type Kpi = { label: string; value: string };

export const dynamic = 'force-dynamic';

async function fetchAll() {
  const sb = await getSupabaseServerClient();

  const safe = async <T,>(p: Promise<{ data: T | null; error: unknown }>): Promise<T[]> => {
    try {
      const { data } = await p;
      return Array.isArray(data) ? (data as T[]) : [];
    } catch {
      return [];
    }
  };

  const [kpis, openQueue, perEngineer, byCategory, recent, slaBreaches, notes] = await Promise.all([
    safe<any>(sb.rpc('founder_engineer_escalation_kpis') as any),
    safe<any>(sb.rpc('founder_engineer_escalation_open_queue') as any),
    safe<any>(sb.rpc('founder_engineer_escalation_per_engineer') as any),
    safe<any>(sb.rpc('founder_engineer_escalation_by_category') as any),
    safe<any>(sb.rpc('founder_engineer_escalation_recent') as any),
    safe<any>(sb.rpc('founder_engineer_escalation_sla_breaches') as any),
    safe<any>(sb.rpc('founder_engineer_escalation_notes_recent') as any),
  ]);

  return { kpis: kpis[0] ?? {}, openQueue, perEngineer, byCategory, recent, slaBreaches, notes };
}

export default async function Page() {
  await requireFounder();
  const { kpis, openQueue, perEngineer, byCategory, recent, slaBreaches, notes } = await fetchAll();

  const k: Kpi[] = [
    { label: 'Open', value: String(kpis.open_count ?? 0) },
    { label: 'Acknowledged', value: String(kpis.ack_count ?? 0) },
    { label: 'In Progress', value: String(kpis.in_progress_count ?? 0) },
    { label: 'Resolved (7d)', value: String(kpis.resolved_7d ?? 0) },
    { label: 'Rejected (7d)', value: String(kpis.rejected_7d ?? 0) },
    { label: 'P0 Open', value: String(kpis.p0_open ?? 0) },
    { label: 'P1 Open', value: String(kpis.p1_open ?? 0) },
    { label: 'P2 Open', value: String(kpis.p2_open ?? 0) },
    { label: 'P3 Open', value: String(kpis.p3_open ?? 0) },
    { label: 'Avg Ack (min)', value: String(kpis.avg_ack_minutes ?? 0) },
    { label: 'Avg Resolve (h)', value: String(kpis.avg_resolve_hours ?? 0) },
    { label: 'Median Resolve (h)', value: String(kpis.median_resolve_hours ?? 0) },
    { label: 'Ack SLA 4h %', value: `${kpis.ack_sla_4h_pct ?? 0}%` },
    { label: 'Resolve SLA 24h %', value: `${kpis.resolve_sla_24h_pct ?? 0}%` },
    { label: 'Engineers (30d)', value: String(kpis.unique_engineers_30d ?? 0) },
    { label: 'Escalations (30d)', value: String(kpis.escalations_30d ?? 0) },
  ];

  const openCols: Column<any>[] = [
    { key: 'engineer_email', header: 'Engineer', render: (r: any) => r.engineer_email ?? '-' },
    { key: 'engineer_tier', header: 'Tier', render: (r: any) => r.engineer_tier ?? '-' },
    { key: 'severity', header: 'Sev', render: (r: any) => (r.severity ?? '-').toUpperCase() },
    { key: 'category', header: 'Category', render: (r: any) => r.category ?? '-' },
    { key: 'subject', header: 'Subject', render: (r: any) => r.subject ?? '-' },
    { key: 'status', header: 'Status', render: (r: any) => r.status ?? '-' },
    { key: 'hospital_name', header: 'Hospital', render: (r: any) => r.hospital_name ?? '-' },
    { key: 'age_hours', header: 'Age (h)', render: (r: any) => String(r.age_hours ?? 0) },
  ];

  const engCols: Column<any>[] = [
    { key: 'engineer_email', header: 'Engineer', render: (r: any) => r.engineer_email ?? '-' },
    { key: 'tier', header: 'Tier', render: (r: any) => r.tier ?? '-' },
    { key: 'total_30d', header: 'Total 30d', render: (r: any) => String(r.total_30d ?? 0) },
    { key: 'open_now', header: 'Open', render: (r: any) => String(r.open_now ?? 0) },
    { key: 'resolved_30d', header: 'Resolved 30d', render: (r: any) => String(r.resolved_30d ?? 0) },
    { key: 'avg_age_hours', header: 'Avg Age (h)', render: (r: any) => String(r.avg_age_hours ?? 0) },
    { key: 'last_escalation', header: 'Last', render: (r: any) => r.last_escalation ? new Date(r.last_escalation).toLocaleDateString() : '-' },
  ];

  const catCols: Column<any>[] = [
    { key: 'category', header: 'Category', render: (r: any) => r.category ?? '-' },
    { key: 'total_30d', header: 'Total 30d', render: (r: any) => String(r.total_30d ?? 0) },
    { key: 'open_now', header: 'Open', render: (r: any) => String(r.open_now ?? 0) },
    { key: 'avg_resolve_hours', header: 'Avg Resolve (h)', render: (r: any) => String(r.avg_resolve_hours ?? 0) },
    { key: 'resolve_sla_pct', header: 'SLA %', render: (r: any) => `${r.resolve_sla_pct ?? 0}%` },
  ];

  const slaCols: Column<any>[] = [
    { key: 'engineer_email', header: 'Engineer', render: (r: any) => r.engineer_email ?? '-' },
    { key: 'severity', header: 'Sev', render: (r: any) => (r.severity ?? '-').toUpperCase() },
    { key: 'category', header: 'Category', render: (r: any) => r.category ?? '-' },
    { key: 'subject', header: 'Subject', render: (r: any) => r.subject ?? '-' },
    { key: 'status', header: 'Status', render: (r: any) => r.status ?? '-' },
    { key: 'age_hours', header: 'Age (h)', render: (r: any) => String(r.age_hours ?? 0) },
    { key: 'breach_type', header: 'Breach', render: (r: any) => r.breach_type ?? '-' },
  ];

  const recentCols: Column<any>[] = [
    { key: 'engineer_email', header: 'Engineer', render: (r: any) => r.engineer_email ?? '-' },
    { key: 'category', header: 'Category', render: (r: any) => r.category ?? '-' },
    { key: 'severity', header: 'Sev', render: (r: any) => (r.severity ?? '-').toUpperCase() },
    { key: 'status', header: 'Status', render: (r: any) => r.status ?? '-' },
    { key: 'subject', header: 'Subject', render: (r: any) => r.subject ?? '-' },
    { key: 'resolve_hours', header: 'Resolved (h)', render: (r: any) => r.resolve_hours != null ? String(r.resolve_hours) : '-' },
    { key: 'created_at', header: 'Created', render: (r: any) => r.created_at ? new Date(r.created_at).toLocaleString() : '-' },
  ];

  const noteCols: Column<any>[] = [
    { key: 'escalation_subject', header: 'Escalation', render: (r: any) => r.escalation_subject ?? '-' },
    { key: 'author_email', header: 'Author', render: (r: any) => r.author_email ?? '-' },
    { key: 'visibility', header: 'Visibility', render: (r: any) => r.visibility ?? '-' },
    { key: 'note', header: 'Note', render: (r: any) => r.note ?? '-' },
    { key: 'created_at', header: 'When', render: (r: any) => r.created_at ? new Date(r.created_at).toLocaleString() : '-' },
  ];

  return (
    <div className="p-6 space-y-6">
      <header>
        <h1 className="text-2xl font-semibold">Engineer Escalation Queue</h1>
        <p className="text-sm text-gray-600">Stuck jobs, disputes, payment delays, tool requests. Founder triage SLA: 4h ack / 24h resolve.</p>
      </header>

      <section className="grid grid-cols-2 md:grid-cols-4 lg:grid-cols-8 gap-3">
        {k.map((c) => (
          <div key={c.label} className="rounded-lg border p-3 bg-white">
            <div className="text-xs text-gray-500">{c.label}</div>
            <div className="text-lg font-semibold">{c.value}</div>
          </div>
        ))}
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-semibold">Open Queue (priority order)</h2>
        <DataTable columns={openCols} rows={openQueue} rowKey={(r: any) => r.id} />
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-semibold">SLA Breaches</h2>
        <DataTable columns={slaCols} rows={slaBreaches} rowKey={(r: any) => r.id} />
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-semibold">Per-Engineer (30d)</h2>
        <DataTable columns={engCols} rows={perEngineer} rowKey={(r: any) => r.engineer_user_id} />
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-semibold">By Category</h2>
        <DataTable columns={catCols} rows={byCategory} rowKey={(r: any) => r.id} />
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-semibold">Recent Activity</h2>
        <DataTable columns={recentCols} rows={recent} rowKey={(r: any) => r.id} />
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-semibold">Recent Triage Notes</h2>
        <DataTable columns={noteCols} rows={notes} rowKey={(r: any) => r.id} />
      </section>
    </div>
  );
}
