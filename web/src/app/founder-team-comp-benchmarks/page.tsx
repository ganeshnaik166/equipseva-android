import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Summary = {
  total_employees: number | null;
  total_roles: number | null;
  pending_raises: number | null;
  under_market_count: number | null;
  over_market_count: number | null;
  total_annual_comp_rupees: number | null;
};

type Benchmark = {
  id: string;
  role_title: string | null;
  level: string | null;
  market_median_rupees: number | null;
  market_p25_rupees: number | null;
  market_p75_rupees: number | null;
  source_label: string | null;
  effective_from: string | null;
  employees_in_role: number | null;
};

type Delta = {
  employee_user_id: string;
  employee_email: string | null;
  role_title: string | null;
  level: string | null;
  current_rupees: number | null;
  market_median_rupees: number | null;
  delta_rupees: number | null;
  delta_pct: number | null;
};

type RaiseRow = {
  id: string;
  employee_user_id: string;
  employee_email: string | null;
  role_title: string | null;
  level: string | null;
  current_rupees: number | null;
  proposed_rupees: number | null;
  raise_pct: number | null;
  justification: string | null;
  status: string | null;
  created_at: string | null;
};

function fmtRupees(v: number | null | undefined): string {
  if (v === null || v === undefined) return '—';
  return '₹ ' + Number(v).toLocaleString('en-IN');
}

function fmtPct(v: number | null | undefined): string {
  if (v === null || v === undefined) return '—';
  return `${v}%`;
}

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const summaryRes = await sb.rpc('founder_team_comp_summary');
  const benchmarksRes = await sb.rpc('founder_team_comp_benchmarks_list');
  const deltasRes = await sb.rpc('founder_team_comp_employee_deltas');
  const queueRes = await sb.rpc('founder_team_comp_raise_queue');

  const summary: Summary = ((summaryRes.data ?? [])[0] ?? {
    total_employees: 0,
    total_roles: 0,
    pending_raises: 0,
    under_market_count: 0,
    over_market_count: 0,
    total_annual_comp_rupees: 0,
  }) as Summary;

  const benchmarks: Benchmark[] = (benchmarksRes.data ?? []) as Benchmark[];
  const deltas: Delta[] = (deltasRes.data ?? []) as Delta[];
  const queue: RaiseRow[] = (queueRes.data ?? []) as RaiseRow[];

  const benchmarkColumns: Column<Benchmark>[] = [
    { key: 'role_title', header: 'Role', render: (r) => r.role_title ?? '—' },
    { key: 'level', header: 'Level', render: (r) => r.level ?? '—' },
    { key: 'market_median_rupees', header: 'Median', render: (r) => fmtRupees(r.market_median_rupees) },
    { key: 'market_p25_rupees', header: 'P25', render: (r) => fmtRupees(r.market_p25_rupees) },
    { key: 'market_p75_rupees', header: 'P75', render: (r) => fmtRupees(r.market_p75_rupees) },
    { key: 'source_label', header: 'Source', render: (r) => r.source_label ?? '—' },
    { key: 'employees_in_role', header: 'In role', render: (r) => String(r.employees_in_role ?? 0) },
  ];

  const deltaColumns: Column<Delta>[] = [
    { key: 'employee_email', header: 'Employee', render: (r) => r.employee_email ?? '—' },
    { key: 'role_title', header: 'Role', render: (r) => r.role_title ?? '—' },
    { key: 'level', header: 'Level', render: (r) => r.level ?? '—' },
    { key: 'current_rupees', header: 'Current', render: (r) => fmtRupees(r.current_rupees) },
    { key: 'market_median_rupees', header: 'Market median', render: (r) => fmtRupees(r.market_median_rupees) },
    { key: 'delta_rupees', header: 'Delta', render: (r) => fmtRupees(r.delta_rupees) },
    { key: 'delta_pct', header: 'Delta %', render: (r) => fmtPct(r.delta_pct) },
  ];

  const queueColumns: Column<RaiseRow>[] = [
    { key: 'employee_email', header: 'Employee', render: (r) => r.employee_email ?? '—' },
    { key: 'role_title', header: 'Role', render: (r) => r.role_title ?? '—' },
    { key: 'current_rupees', header: 'Current', render: (r) => fmtRupees(r.current_rupees) },
    { key: 'proposed_rupees', header: 'Proposed', render: (r) => fmtRupees(r.proposed_rupees) },
    { key: 'raise_pct', header: 'Raise %', render: (r) => fmtPct(r.raise_pct) },
    { key: 'status', header: 'Status', render: (r) => r.status ?? '—' },
    { key: 'justification', header: 'Justification', render: (r) => r.justification ?? '—' },
    { key: 'created_at', header: 'Filed', render: (r) => (r.created_at ? new Date(r.created_at).toLocaleDateString('en-IN') : '—') },
  ];

  return (
    <main style={{ padding: '24px', maxWidth: 1280, margin: '0 auto', fontFamily: 'system-ui, sans-serif' }}>
      <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 4 }}>Team Comp Benchmarks</h1>
      <p style={{ color: '#666', marginBottom: 24 }}>
        Per-role market medians, per-employee delta, and founder raise approval queue.
      </p>

      <section style={{ display: 'grid', gridTemplateColumns: 'repeat(3, 1fr)', gap: 12, marginBottom: 24 }}>
        <div style={{ border: '1px solid #e5e5e5', borderRadius: 8, padding: 12 }}>
          <div style={{ fontSize: 12, color: '#666' }}>Employees</div>
          <div style={{ fontSize: 20, fontWeight: 600 }}>{summary.total_employees ?? 0}</div>
        </div>
        <div style={{ border: '1px solid #e5e5e5', borderRadius: 8, padding: 12 }}>
          <div style={{ fontSize: 12, color: '#666' }}>Roles benchmarked</div>
          <div style={{ fontSize: 20, fontWeight: 600 }}>{summary.total_roles ?? 0}</div>
        </div>
        <div style={{ border: '1px solid #e5e5e5', borderRadius: 8, padding: 12 }}>
          <div style={{ fontSize: 12, color: '#666' }}>Pending raises</div>
          <div style={{ fontSize: 20, fontWeight: 600 }}>{summary.pending_raises ?? 0}</div>
        </div>
        <div style={{ border: '1px solid #e5e5e5', borderRadius: 8, padding: 12 }}>
          <div style={{ fontSize: 12, color: '#666' }}>Under market</div>
          <div style={{ fontSize: 20, fontWeight: 600 }}>{summary.under_market_count ?? 0}</div>
        </div>
        <div style={{ border: '1px solid #e5e5e5', borderRadius: 8, padding: 12 }}>
          <div style={{ fontSize: 12, color: '#666' }}>Over market</div>
          <div style={{ fontSize: 20, fontWeight: 600 }}>{summary.over_market_count ?? 0}</div>
        </div>
        <div style={{ border: '1px solid #e5e5e5', borderRadius: 8, padding: 12 }}>
          <div style={{ fontSize: 12, color: '#666' }}>Total annual comp</div>
          <div style={{ fontSize: 20, fontWeight: 600 }}>{fmtRupees(summary.total_annual_comp_rupees)}</div>
        </div>
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Role benchmarks</h2>
        <DataTable
          rows={benchmarks}
          columns={benchmarkColumns}
          rowKey={(r) => r.id}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Employee deltas vs market</h2>
        <DataTable
          rows={deltas}
          columns={deltaColumns}
          rowKey={(r) => r.employee_user_id}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Raise approval queue</h2>
        <DataTable
          rows={queue}
          columns={queueColumns}
          rowKey={(r) => r.id}
        />
      </section>
    </main>
  );
}
