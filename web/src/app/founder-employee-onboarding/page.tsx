import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type HireRow = {
  id: string;
  hire_name: string;
  hire_email: string;
  role_title: string;
  start_date: string;
  mentor_name: string | null;
  status: string;
  total_items: number;
  done_items: number;
  pct_done: number;
  days_since_start: number;
};

type SummaryRow = {
  active_hires: number;
  completed_hires: number;
  offboarded_hires: number;
  total_items: number;
  done_items: number;
  avg_pct_done_active: number;
  stalled_hires: number;
};

export default async function FounderEmployeeOnboardingPage() {
  const sb = await getSupabaseServerClient();

  const hiresRes = await sb.rpc('fn_founder_onboarding_list_hires');
  const summaryRes = await sb.rpc('fn_founder_onboarding_summary');

  const hires: HireRow[] = (hiresRes.data as HireRow[] | null) ?? [];
  const summary: SummaryRow = ((summaryRes.data as SummaryRow[] | null) ?? [])[0] ?? {
    active_hires: 0,
    completed_hires: 0,
    offboarded_hires: 0,
    total_items: 0,
    done_items: 0,
    avg_pct_done_active: 0,
    stalled_hires: 0,
  };

  const hireColumns: Column<HireRow>[] = [
    { key: 'hire_name', header: 'Name', render: (r: HireRow) => r.hire_name ?? '—' },
    { key: 'role_title', header: 'Role', render: (r: HireRow) => r.role_title ?? '—' },
    { key: 'start_date', header: 'Start date', render: (r: HireRow) => r.start_date ?? '—' },
    { key: 'days_since_start', header: 'Day #', render: (r: HireRow) => String(r.days_since_start ?? 0) },
    { key: 'mentor_name', header: 'Mentor', render: (r: HireRow) => r.mentor_name ?? '—' },
    {
      key: 'pct_done',
      header: 'Progress',
      render: (r: HireRow) => `${r.done_items ?? 0}/${r.total_items ?? 0} (${r.pct_done ?? 0}%)`,
    },
    { key: 'status', header: 'Status', render: (r: HireRow) => (r.status ?? '—').toUpperCase() },
  ];

  const active = hires.filter((h) => h.status === 'active');
  const completed = hires.filter((h) => h.status === 'completed');

  return (
    <main style={{ padding: 24, maxWidth: 1200, margin: '0 auto' }}>
      <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 4 }}>
        Employee onboarding checklist
      </h1>
      <p style={{ color: '#64748b', marginBottom: 24 }}>
        Founder-run 30-item onboarding for every new hire — hardware, accounts, payroll, mentor, goals, compliance.
      </p>

      <section style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: 12, marginBottom: 24 }}>
        <Card label="Active hires" value={String(summary.active_hires)} />
        <Card label="Completed" value={String(summary.completed_hires)} />
        <Card
          label="Avg progress (active)"
          value={`${summary.avg_pct_done_active}%`}
        />
        <Card label="Stalled (>14d)" value={String(summary.stalled_hires)} tone={summary.stalled_hires > 0 ? 'warn' : 'ok'} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Active onboarding ({active.length})</h2>
        <DataTable
          columns={hireColumns}
          rows={active}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Completed ({completed.length})</h2>
        <DataTable
          columns={hireColumns}
          rows={completed}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ background: '#f8fafc', padding: 16, borderRadius: 8, fontSize: 13, color: '#475569' }}>
        <strong>How to use:</strong> Call <code>fn_founder_onboarding_create_hire(name, email, role, start_date, mentor)</code>{' '}
        when a new hire signs the offer. 30 checklist items auto-seed across 6 categories. Mark items done via{' '}
        <code>fn_founder_onboarding_toggle_item(item_id, done, note)</code>. When all items done, call{' '}
        <code>fn_founder_onboarding_set_status(hire_id, 'completed')</code>.
      </section>
    </main>
  );
}

function Card({ label, value, tone }: { label: string; value: string; tone?: 'ok' | 'warn' }) {
  const color = tone === 'warn' ? '#b45309' : '#0f172a';
  const bg = tone === 'warn' ? '#fef3c7' : '#ffffff';
  return (
    <div style={{ background: bg, border: '1px solid #e2e8f0', borderRadius: 8, padding: 16 }}>
      <div style={{ fontSize: 12, color: '#64748b', marginBottom: 4 }}>{label}</div>
      <div style={{ fontSize: 22, fontWeight: 700, color }}>{value}</div>
    </div>
  );
}
