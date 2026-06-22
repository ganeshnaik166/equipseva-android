import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [knowledgeRes, topHelpfulRes, recentEndorsementsRes] = await Promise.all([
    sb.rpc('list_knowledge_r1872'),
    sb.rpc('top_helpful_r1872'),
    sb.rpc('recent_endorsements_r1872'),
  ]);

  const knowledge: any[] = Array.isArray(knowledgeRes.data) ? knowledgeRes.data : [];
  const topHelpful: any[] = Array.isArray(topHelpfulRes.data) ? topHelpfulRes.data : [];
  const recentEnd: any[] = Array.isArray(recentEndorsementsRes.data) ? recentEndorsementsRes.data : [];

  const knowledgeCols: Column<any>[] = [
    { key: 'knowledge_title', header: 'Title', render: (r: any) => String(r.knowledge_title ?? '') },
    { key: 'knowledge_category', header: 'Category', render: (r: any) => String(r.knowledge_category ?? '') },
    { key: 'engineer_email', header: 'Engineer', render: (r: any) => String(r.engineer_email ?? '-') },
    { key: 'related_equipment', header: 'Equipment', render: (r: any) => String(r.related_equipment ?? '-') },
    { key: 'helpful_score', header: 'Score', render: (r: any) => String(r.helpful_score ?? 0) },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
    { key: 'endorsement_count', header: 'Endorsements', render: (r: any) => String(r.endorsement_count ?? 0) },
    { key: 'created_at', header: 'Logged', render: (r: any) => r.created_at ? new Date(r.created_at).toLocaleString() : '-' },
  ];

  const topHelpfulCols: Column<any>[] = [
    { key: 'knowledge_title', header: 'Title', render: (r: any) => String(r.knowledge_title ?? '') },
    { key: 'knowledge_category', header: 'Category', render: (r: any) => String(r.knowledge_category ?? '') },
    { key: 'helpful_score', header: 'Helpful Score', render: (r: any) => String(r.helpful_score ?? 0) },
    { key: 'endorsement_count', header: 'Endorsements', render: (r: any) => String(r.endorsement_count ?? 0) },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
  ];

  const recentEndCols: Column<any>[] = [
    { key: 'knowledge_title', header: 'Knowledge', render: (r: any) => String(r.knowledge_title ?? '') },
    { key: 'endorser_email', header: 'Endorser', render: (r: any) => String(r.endorser_email ?? '') },
    { key: 'endorser_role', header: 'Role', render: (r: any) => String(r.endorser_role ?? '') },
    { key: 'endorsement_text', header: 'Text', render: (r: any) => String(r.endorsement_text ?? '-') },
    { key: 'endorsed_at', header: 'When', render: (r: any) => r.endorsed_at ? new Date(r.endorsed_at).toLocaleString() : '-' },
  ];

  const totalKnowledge = knowledge.length;
  const activeCount = knowledge.filter((k) => k.status === 'active').length;
  const supersededCount = knowledge.filter((k) => k.status === 'superseded').length;
  const totalEndorsements = recentEnd.length;

  return (
    <div className="p-6 space-y-8">
      <header>
        <h1 className="text-2xl font-bold">Engineer Field Knowledge Wiki</h1>
        <p className="text-sm text-gray-600">
          Per-engineer field-knowledge wiki — workarounds, calibration tricks, vendor-specific hacks.
        </p>
      </header>

      <section className="grid grid-cols-2 md:grid-cols-4 gap-4">
        <div className="rounded border p-4">
          <div className="text-xs text-gray-500">Total Entries</div>
          <div className="text-2xl font-semibold">{totalKnowledge}</div>
        </div>
        <div className="rounded border p-4">
          <div className="text-xs text-gray-500">Active</div>
          <div className="text-2xl font-semibold">{activeCount}</div>
        </div>
        <div className="rounded border p-4">
          <div className="text-xs text-gray-500">Superseded</div>
          <div className="text-2xl font-semibold">{supersededCount}</div>
        </div>
        <div className="rounded border p-4">
          <div className="text-xs text-gray-500">Recent Endorsements</div>
          <div className="text-2xl font-semibold">{totalEndorsements}</div>
        </div>
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">All Knowledge Entries</h2>
        <DataTable rows={knowledge} columns={knowledgeCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Top Helpful (score &gt;= 1, active only)</h2>
        <DataTable rows={topHelpful} columns={topHelpfulCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Recent Endorsements</h2>
        <DataTable rows={recentEnd} columns={recentEndCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>
    </div>
  );
}
