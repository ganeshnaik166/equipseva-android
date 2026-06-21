import { requireFounder } from '@/lib/auth/requireFounder';
import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

type Kpi = { label: string; value: string };

export const dynamic = 'force-dynamic';

export default async function FounderInvestorDiligenceFaqPage() {
  await requireFounder();
  const sb = await getSupabaseServerClient();

  let kpis: any = {};
  let list: any[] = [];
  let byCat: any[] = [];
  let stale: any[] = [];
  let revisions: any[] = [];

  try {
    const r = await sb.rpc('founder_inv_dd_faq_kpis');
    kpis = (r.data as any) || {};
  } catch {}
  try {
    const r = await sb.rpc('founder_inv_dd_faq_list');
    list = (r.data as any[]) || [];
  } catch {}
  try {
    const r = await sb.rpc('founder_inv_dd_faq_by_category');
    byCat = (r.data as any[]) || [];
  } catch {}
  try {
    const r = await sb.rpc('founder_inv_dd_faq_stale');
    stale = (r.data as any[]) || [];
  } catch {}
  try {
    const r = await sb.rpc('founder_inv_dd_faq_recent_revisions');
    revisions = (r.data as any[]) || [];
  } catch {}

  const k: Kpi[] = [
    { label: 'Total questions', value: String(kpis.total ?? 0) },
    { label: 'Published', value: String(kpis.published ?? 0) },
    { label: 'Unpublished', value: String(kpis.unpublished ?? 0) },
    { label: 'High confidence', value: String(kpis.high_conf ?? 0) },
    { label: 'Medium confidence', value: String(kpis.medium_conf ?? 0) },
    { label: 'Low confidence', value: String(kpis.low_conf ?? 0) },
    { label: 'With metric', value: String(kpis.with_metric ?? 0) },
    { label: 'Without metric', value: String(kpis.without_metric ?? 0) },
    { label: 'Categories', value: String(kpis.categories ?? 0) },
    { label: 'Reviewed last 30d', value: String(kpis.reviewed_30d ?? 0) },
    { label: 'Stale (90d+)', value: String(kpis.stale_90d ?? 0) },
    { label: 'Stale (180d+)', value: String(kpis.stale_180d ?? 0) },
    { label: 'Never reviewed', value: String(kpis.never_reviewed ?? 0) },
    { label: 'Total views', value: String(kpis.total_views ?? 0) },
    { label: 'Edits last 7d', value: String(kpis.recent_edits_7d ?? 0) },
    { label: 'Total revisions', value: String(kpis.total_revisions ?? 0) },
  ];

  const listCols: Column<any>[] = [
    { key: 'category', header: 'Category', render: (r: any) => r.category ?? '—' },
    { key: 'question', header: 'Question', render: (r: any) => (r.question ?? '—').slice(0, 80) },
    { key: 'confidence', header: 'Confidence', render: (r: any) => r.confidence ?? '—' },
    { key: 'supporting_metric', header: 'Metric', render: (r: any) => r.supporting_metric ?? '—' },
    { key: 'is_published', header: 'Pub', render: (r: any) => (r.is_published ? 'yes' : 'no') },
    { key: 'days_since_review', header: 'Days since review', render: (r: any) => r.days_since_review != null ? Number(r.days_since_review).toFixed(0) : '—' },
  ];

  const catCols: Column<any>[] = [
    { key: 'category', header: 'Category', render: (r: any) => r.category ?? '—' },
    { key: 'total_questions', header: 'Total', render: (r: any) => r.total_questions ?? '—' },
    { key: 'published_count', header: 'Published', render: (r: any) => r.published_count ?? '—' },
    { key: 'high_conf_count', header: 'High conf', render: (r: any) => r.high_conf_count ?? '—' },
    { key: 'with_metric_count', header: 'With metric', render: (r: any) => r.with_metric_count ?? '—' },
    { key: 'avg_days_since_review', header: 'Avg days since review', render: (r: any) => r.avg_days_since_review != null ? Number(r.avg_days_since_review).toFixed(0) : '—' },
  ];

  const staleCols: Column<any>[] = [
    { key: 'category', header: 'Category', render: (r: any) => r.category ?? '—' },
    { key: 'question', header: 'Question', render: (r: any) => (r.question ?? '—').slice(0, 80) },
    { key: 'last_reviewed_at', header: 'Last reviewed', render: (r: any) => r.last_reviewed_at ? new Date(r.last_reviewed_at).toLocaleDateString() : 'never' },
    { key: 'days_since_review', header: 'Days', render: (r: any) => r.days_since_review != null ? Number(r.days_since_review).toFixed(0) : '—' },
    { key: 'confidence', header: 'Confidence', render: (r: any) => r.confidence ?? '—' },
  ];

  const revCols: Column<any>[] = [
    { key: 'edited_at', header: 'Edited', render: (r: any) => r.edited_at ? new Date(r.edited_at).toLocaleString() : '—' },
    { key: 'question', header: 'Question', render: (r: any) => (r.question ?? '—').slice(0, 80) },
    { key: 'edit_note', header: 'Note', render: (r: any) => r.edit_note ?? '—' },
  ];

  return (
    <div className="p-6 space-y-6">
      <header>
        <h1 className="text-2xl font-semibold">Investor Diligence FAQ</h1>
        <p className="text-sm text-gray-600">Central FAQ for investor DD questions. Per-question canonical answer + supporting metric + last-updated. Founder maintains.</p>
      </header>

      <section className="grid grid-cols-2 md:grid-cols-4 gap-3">
        {k.map((c) => (
          <div key={c.label} className="rounded border bg-white p-3">
            <div className="text-xs text-gray-500">{c.label}</div>
            <div className="text-lg font-semibold">{c.value}</div>
          </div>
        ))}
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">All FAQ entries</h2>
        <DataTable rows={list} columns={listCols} rowKey={(r: any) => r.id} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">By category</h2>
        <DataTable rows={byCat} columns={catCols} rowKey={(r: any) => r.category} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Stale / needs review</h2>
        <DataTable rows={stale} columns={staleCols} rowKey={(r: any) => r.id} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Recent revisions</h2>
        <DataTable rows={revisions} columns={revCols} rowKey={(r: any) => r.rev_id} />
      </section>
    </div>
  );
}
