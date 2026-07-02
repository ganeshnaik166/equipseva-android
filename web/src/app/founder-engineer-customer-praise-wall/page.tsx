import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const { data: praiseRows } = await sb.rpc('list_praise_r2108', { p_limit: 200 });
  const { data: featuredRows } = await sb.rpc('list_featured_praise_r2108', { p_limit: 50 });
  const { data: recentActionRows } = await sb.rpc('recent_praise_actions_r2108', { p_limit: 100 });

  const praise = Array.isArray(praiseRows) ? praiseRows : [];
  const featured = Array.isArray(featuredRows) ? featuredRows : [];
  const actions = Array.isArray(recentActionRows) ? recentActionRows : [];

  const praiseColumns: Column<any>[] = [
    { key: 'captured_at', header: 'Captured', render: (r: any) => r.captured_at ? new Date(r.captured_at).toLocaleString() : '' },
    { key: 'engineer_email', header: 'Engineer', render: (r: any) => r.engineer_email ?? '' },
    { key: 'hospital_name', header: 'Hospital', render: (r: any) => r.hospital_name ?? '' },
    { key: 'source', header: 'Source', render: (r: any) => r.source ?? '' },
    { key: 'status', header: 'Status', render: (r: any) => r.status ?? '' },
    { key: 'praise_text_md', header: 'Praise', render: (r: any) => r.praise_text_md ?? '' },
  ];

  const featuredColumns: Column<any>[] = [
    { key: 'captured_at', header: 'Captured', render: (r: any) => r.captured_at ? new Date(r.captured_at).toLocaleString() : '' },
    { key: 'engineer_email', header: 'Engineer', render: (r: any) => r.engineer_email ?? '' },
    { key: 'hospital_name', header: 'Hospital', render: (r: any) => r.hospital_name ?? '' },
    { key: 'source', header: 'Source', render: (r: any) => r.source ?? '' },
    { key: 'praise_text_md', header: 'Praise', render: (r: any) => r.praise_text_md ?? '' },
  ];

  const actionColumns: Column<any>[] = [
    { key: 'taken_at', header: 'When', render: (r: any) => r.taken_at ? new Date(r.taken_at).toLocaleString() : '' },
    { key: 'action_type', header: 'Action', render: (r: any) => r.action_type ?? '' },
    { key: 'by_email', header: 'By', render: (r: any) => r.by_email ?? '' },
    { key: 'praise_id', header: 'Praise ID', render: (r: any) => r.praise_id ?? '' },
    { key: 'notes_md', header: 'Notes', render: (r: any) => r.notes_md ?? '' },
  ];

  return (
    <div className="p-6 space-y-8">
      <header>
        <h1 className="text-2xl font-bold">Engineer Customer Praise Wall</h1>
        <p className="text-sm text-gray-600">Public-facing praise wall capturing customer kudos for engineers across surveys, visits, email, phone and written reviews. Surface highlights for marketing, awards and morale.</p>
      </header>

      <section>
        <h2 className="text-lg font-semibold mb-2">All Captured Praise</h2>
        <DataTable rows={praise} columns={praiseColumns} rowKey={(r: any, i: number) => String(r?.id ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Featured and Marketing-Used</h2>
        <DataTable rows={featured} columns={featuredColumns} rowKey={(r: any, i: number) => String(r?.id ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Recent Praise Actions</h2>
        <DataTable rows={actions} columns={actionColumns} rowKey={(r: any, i: number) => String(r?.id ?? i)} />
      </section>
    </div>
  );
}
