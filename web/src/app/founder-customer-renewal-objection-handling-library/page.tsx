import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type ObjectionRow = {
  id: string;
  objection_code: string;
  objection_label: string;
  objection_category: string;
  customer_quote: string;
  scripted_response: string;
  total_attempts: number;
  saved_count: number;
  lost_count: number;
  pending_count: number;
  success_rate_pct: number;
  avg_concession_rupees: number;
  is_active: boolean;
};

type CategoryRow = {
  objection_category: string;
  objection_count: number;
  total_attempts: number;
  saved_attempts: number;
  success_rate_pct: number;
  total_concession_rupees: number;
};

type AttemptRow = {
  attempt_id: string;
  attempted_at: string;
  objection_label: string;
  objection_category: string;
  outcome: string;
  concession_offered_rupees: number;
  handler_email: string | null;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [objectionsRes, categoryRes, recentRes] = await Promise.all([
    supabase.rpc('list_renewal_objections_r2356'),
    supabase.rpc('renewal_objection_category_rollup_r2356'),
    supabase.rpc('recent_renewal_objection_attempts_r2356', { p_limit: 30 }),
  ]);

  const objections = (objectionsRes.data ?? []) as ObjectionRow[];
  const categories = (categoryRes.data ?? []) as CategoryRow[];
  const recent = (recentRes.data ?? []) as AttemptRow[];

  const totalAttempts = categories.reduce((s, c) => s + Number(c.total_attempts ?? 0), 0);
  const totalSaved = categories.reduce((s, c) => s + Number(c.saved_attempts ?? 0), 0);
  const overallRate = totalAttempts > 0 ? Math.round((100 * totalSaved) / totalAttempts) : 0;
  const activeObjections = objections.filter((o) => o.is_active).length;

  const objCols: Column<any>[] = [
    { key: 'objection_label', header: 'Objection', render: (r: ObjectionRow) => (
      <div>
        <div style={{ fontWeight: 600 }}>{r.objection_label}</div>
        <div style={{ fontSize: 12, color: '#666' }}>{r.objection_code}</div>
      </div>
    ) },
    { key: 'objection_category', header: 'Category', render: (r: ObjectionRow) => r.objection_category },
    { key: 'customer_quote', header: 'Customer quote', render: (r: ObjectionRow) => (
      <div style={{ maxWidth: 280, fontStyle: 'italic', color: '#444' }}>“{r.customer_quote}”</div>
    ) },
    { key: 'scripted_response', header: 'Scripted response', render: (r: ObjectionRow) => (
      <div style={{ maxWidth: 320 }}>{r.scripted_response}</div>
    ) },
    { key: 'total_attempts', header: 'Attempts', render: (r: ObjectionRow) => r.total_attempts },
    { key: 'success_rate_pct', header: 'Win rate', render: (r: ObjectionRow) => {
      const rate = Number(r.success_rate_pct ?? 0);
      const color = rate >= 70 ? '#1a7f37' : rate >= 40 ? '#9a6700' : '#b42318';
      return <span style={{ fontWeight: 600, color }}>{rate}%</span>;
    } },
    { key: 'avg_concession_rupees', header: 'Avg concession', render: (r: ObjectionRow) => `₹${Math.round(Number(r.avg_concession_rupees ?? 0)).toLocaleString('en-IN')}` },
    { key: 'is_active', header: 'Status', render: (r: ObjectionRow) => r.is_active ? 'active' : 'archived' },
  ];

  const catCols: Column<any>[] = [
    { key: 'objection_category', header: 'Category', render: (r: CategoryRow) => r.objection_category },
    { key: 'objection_count', header: 'Scripts', render: (r: CategoryRow) => r.objection_count },
    { key: 'total_attempts', header: 'Attempts', render: (r: CategoryRow) => r.total_attempts },
    { key: 'saved_attempts', header: 'Saved', render: (r: CategoryRow) => r.saved_attempts },
    { key: 'success_rate_pct', header: 'Win rate', render: (r: CategoryRow) => `${Number(r.success_rate_pct ?? 0)}%` },
    { key: 'total_concession_rupees', header: 'Concession given', render: (r: CategoryRow) => `₹${Number(r.total_concession_rupees ?? 0).toLocaleString('en-IN')}` },
  ];

  const recentCols: Column<any>[] = [
    { key: 'attempted_at', header: 'When', render: (r: AttemptRow) => new Date(r.attempted_at).toLocaleString('en-IN') },
    { key: 'objection_label', header: 'Objection', render: (r: AttemptRow) => r.objection_label },
    { key: 'objection_category', header: 'Category', render: (r: AttemptRow) => r.objection_category },
    { key: 'outcome', header: 'Outcome', render: (r: AttemptRow) => {
      const c = r.outcome === 'saved' ? '#1a7f37' : r.outcome === 'lost' ? '#b42318' : r.outcome === 'escalated' ? '#9a6700' : '#555';
      return <span style={{ fontWeight: 600, color: c }}>{r.outcome}</span>;
    } },
    { key: 'concession_offered_rupees', header: 'Concession', render: (r: AttemptRow) => `₹${r.concession_offered_rupees.toLocaleString('en-IN')}` },
    { key: 'handler_email', header: 'Handler', render: (r: AttemptRow) => r.handler_email ?? '—' },
    { key: 'notes', header: 'Notes', render: (r: AttemptRow) => r.notes ?? '—' },
  ];

  return (
    <main style={{ padding: 24, maxWidth: 1280, margin: '0 auto' }}>
      <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 8 }}>Customer renewal-objection handling library</h1>
      <p style={{ color: '#555', marginBottom: 20 }}>
        Common renewal objections, the scripted response we use, and how often that response actually saves the contract.
      </p>

      <section style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(180px, 1fr))', gap: 12, marginBottom: 28 }}>
        <div style={{ padding: 16, border: '1px solid #e5e7eb', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#666' }}>Active scripts</div>
          <div style={{ fontSize: 24, fontWeight: 700 }}>{activeObjections}</div>
        </div>
        <div style={{ padding: 16, border: '1px solid #e5e7eb', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#666' }}>Total attempts logged</div>
          <div style={{ fontSize: 24, fontWeight: 700 }}>{totalAttempts}</div>
        </div>
        <div style={{ padding: 16, border: '1px solid #e5e7eb', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#666' }}>Contracts saved</div>
          <div style={{ fontSize: 24, fontWeight: 700, color: '#1a7f37' }}>{totalSaved}</div>
        </div>
        <div style={{ padding: 16, border: '1px solid #e5e7eb', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#666' }}>Overall win rate</div>
          <div style={{ fontSize: 24, fontWeight: 700 }}>{overallRate}%</div>
        </div>
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Objections by category</h2>
        <DataTable
          rows={categories}
          columns={catCols}
          rowKey={(r: CategoryRow) => r.objection_category}
          emptyMessage="No attempts logged yet."
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Objection scripts & win rate</h2>
        <DataTable
          rows={objections}
          columns={objCols}
          rowKey={(r: ObjectionRow) => r.id}
          emptyMessage="No objection scripts in library."
        />
      </section>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Recent attempts</h2>
        <DataTable
          rows={recent}
          columns={recentCols}
          rowKey={(r: AttemptRow) => r.attempt_id}
          emptyMessage="No recent attempts."
        />
      </section>
    </main>
  );
}
