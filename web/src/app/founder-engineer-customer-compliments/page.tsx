import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [complimentsRes, topRes, recentRes] = await Promise.all([
    sb.rpc('list_compliments_r1928'),
    sb.rpc('top_engineers_complimented_r1928'),
    sb.rpc('recent_responses_r1928'),
  ]);

  const compliments = (complimentsRes.data as any[]) ?? [];
  const topEngineers = (topRes.data as any[]) ?? [];
  const recentResponses = (recentRes.data as any[]) ?? [];

  const complimentCols: Column<any>[] = [
    { key: 'captured_at', header: 'Captured', render: (r: any) => new Date(r.captured_at).toLocaleString() },
    { key: 'engineer_email', header: 'Engineer', render: (r: any) => r.engineer_email ?? '—' },
    { key: 'hospital_name', header: 'Hospital', render: (r: any) => r.hospital_name ?? '—' },
    { key: 'compliment_source', header: 'Source', render: (r: any) => r.compliment_source },
    { key: 'severity_of_praise', header: 'Severity', render: (r: any) => r.severity_of_praise },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'compliment_text_md', header: 'Text', render: (r: any) => (r.compliment_text_md ?? '').slice(0, 120) },
  ];

  const topCols: Column<any>[] = [
    { key: 'engineer_email', header: 'Engineer', render: (r: any) => r.engineer_email ?? '—' },
    { key: 'total_compliments', header: 'Total', render: (r: any) => String(r.total_compliments) },
    { key: 'heroic_count', header: 'Heroic', render: (r: any) => String(r.heroic_count) },
    { key: 'exceptional_count', header: 'Exceptional', render: (r: any) => String(r.exceptional_count) },
    { key: 'standard_count', header: 'Standard', render: (r: any) => String(r.standard_count) },
  ];

  const responseCols: Column<any>[] = [
    { key: 'taken_at', header: 'Taken', render: (r: any) => new Date(r.taken_at).toLocaleString() },
    { key: 'engineer_email', header: 'Engineer', render: (r: any) => r.engineer_email ?? '—' },
    { key: 'action_type', header: 'Action', render: (r: any) => r.action_type },
    { key: 'by_email', header: 'By', render: (r: any) => r.by_email },
  ];

  return (
    <div className="p-6 space-y-8">
      <header>
        <h1 className="text-2xl font-bold">Engineer Customer Compliments</h1>
        <p className="text-sm text-gray-600">Track positive customer feedback per engineer. Celebrate heroic moments & promote to marketing.</p>
      </header>

      <section>
        <h2 className="text-lg font-semibold mb-2">Recent Compliments ({compliments.length})</h2>
        <DataTable rows={compliments} columns={complimentCols} rowKey={(r, i) => String(r.id ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Top Engineers by Compliment Count</h2>
        <DataTable rows={topEngineers} columns={topCols} rowKey={(r, i) => String(r.engineer_user_id ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Recent Response Actions</h2>
        <DataTable rows={recentResponses} columns={responseCols} rowKey={(r, i) => String(r.id ?? i)} />
      </section>
    </div>
  );
}
