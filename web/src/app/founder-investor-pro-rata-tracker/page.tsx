import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type RightRow = {
  id: string;
  investor_id: string;
  investor_email: string | null;
  round_name: string;
  pct_pro_rata: number;
  max_invest_rupees: number;
  expires_on: string;
  status: string;
  created_at: string;
};

type ExerciseRow = {
  id: string;
  right_id: string;
  investor_email: string | null;
  round_name: string;
  decision_date: string;
  decision: string;
  amount_exercised_rupees: number;
  note: string | null;
  created_at: string;
};

type ExpiringRow = {
  id: string;
  investor_id: string;
  investor_email: string | null;
  round_name: string;
  pct_pro_rata: number;
  max_invest_rupees: number;
  expires_on: string;
  days_left: number;
};

type SummaryRow = {
  total_rights: number;
  active_rights: number;
  expired_rights: number;
  exercised_rights: number;
  waived_rights: number;
  total_max_invest_rupees: number;
  total_exercised_rupees: number;
};

type ExercisedTotalRow = {
  round_name: string;
  exercise_count: number;
  total_exercised_rupees: number;
  avg_exercised_rupees: number;
};

function fmtRupees(n: number | null | undefined) {
  if (n == null) return '—';
  return '₹' + n.toLocaleString('en-IN');
}

function fmtDate(d: string | null | undefined) {
  if (!d) return '—';
  return new Date(d).toLocaleDateString('en-IN');
}

export default async function FounderInvestorProRataTrackerPage() {
  const sb = await getSupabaseServerClient();

  const [rightsRes, exercisesRes, expiringRes, summaryRes, exercisedTotalRes] = await Promise.all([
    sb.rpc('r1669_list_rights'),
    sb.rpc('r1669_list_exercises'),
    sb.rpc('r1669_expiring_rights_window', { p_days: 30 }),
    sb.rpc('r1669_pro_rata_summary'),
    sb.rpc('r1669_exercised_total'),
  ]);

  const rights: RightRow[] = (rightsRes.data as RightRow[] | null) ?? [];
  const exercises: ExerciseRow[] = (exercisesRes.data as ExerciseRow[] | null) ?? [];
  const expiring: ExpiringRow[] = (expiringRes.data as ExpiringRow[] | null) ?? [];
  const summary: SummaryRow | null = Array.isArray(summaryRes.data)
    ? ((summaryRes.data[0] as SummaryRow) ?? null)
    : ((summaryRes.data as SummaryRow | null) ?? null);
  const exercisedTotals: ExercisedTotalRow[] = (exercisedTotalRes.data as ExercisedTotalRow[] | null) ?? [];

  const rightCols: Column<RightRow>[] = [
    { key: 'investor_email', header: 'Investor', render: (r) => <span>{r.investor_email ?? r.investor_id.slice(0, 8)}</span> },
    { key: 'round_name', header: 'Round', render: (r) => <span>{r.round_name}</span> },
    { key: 'pct_pro_rata', header: 'Pro-Rata %', render: (r) => <span>{Number(r.pct_pro_rata).toFixed(2)}%</span> },
    { key: 'max_invest_rupees', header: 'Max Invest', render: (r) => <span>{fmtRupees(r.max_invest_rupees)}</span> },
    { key: 'expires_on', header: 'Expires', render: (r) => <span>{fmtDate(r.expires_on)}</span> },
    {
      key: 'status',
      header: 'Status',
      render: (r) => (
        <span
          style={{
            padding: '2px 8px',
            borderRadius: 4,
            background:
              r.status === 'active' ? '#dcfce7' :
              r.status === 'expired' ? '#fee2e2' :
              r.status === 'exercised' ? '#dbeafe' :
              '#f3f4f6',
            color:
              r.status === 'active' ? '#166534' :
              r.status === 'expired' ? '#991b1b' :
              r.status === 'exercised' ? '#1e40af' :
              '#374151',
            fontSize: 12,
            fontWeight: 600,
          }}
        >
          {r.status}
        </span>
      ),
    },
  ];

  const exerciseCols: Column<ExerciseRow>[] = [
    { key: 'decision_date', header: 'Date', render: (r) => <span>{fmtDate(r.decision_date)}</span> },
    { key: 'investor_email', header: 'Investor', render: (r) => <span>{r.investor_email ?? '—'}</span> },
    { key: 'round_name', header: 'Round', render: (r) => <span>{r.round_name}</span> },
    {
      key: 'decision',
      header: 'Decision',
      render: (r) => (
        <span
          style={{
            padding: '2px 8px',
            borderRadius: 4,
            background:
              r.decision === 'exercise' ? '#dbeafe' :
              r.decision === 'partial' ? '#fef3c7' :
              '#f3f4f6',
            fontSize: 12,
            fontWeight: 600,
          }}
        >
          {r.decision}
        </span>
      ),
    },
    { key: 'amount_exercised_rupees', header: 'Amount', render: (r) => <span>{fmtRupees(r.amount_exercised_rupees)}</span> },
    { key: 'note', header: 'Note', render: (r) => <span style={{ color: '#6b7280' }}>{r.note ?? '—'}</span> },
  ];

  const expiringCols: Column<ExpiringRow>[] = [
    {
      key: 'days_left',
      header: 'Days Left',
      render: (r) => (
        <span
          style={{
            padding: '2px 8px',
            borderRadius: 4,
            background: r.days_left <= 7 ? '#fee2e2' : r.days_left <= 14 ? '#fef3c7' : '#f3f4f6',
            color: r.days_left <= 7 ? '#991b1b' : r.days_left <= 14 ? '#92400e' : '#374151',
            fontWeight: 700,
          }}
        >
          {r.days_left}d
        </span>
      ),
    },
    { key: 'investor_email', header: 'Investor', render: (r) => <span>{r.investor_email ?? r.investor_id.slice(0, 8)}</span> },
    { key: 'round_name', header: 'Round', render: (r) => <span>{r.round_name}</span> },
    { key: 'pct_pro_rata', header: 'Pro-Rata %', render: (r) => <span>{Number(r.pct_pro_rata).toFixed(2)}%</span> },
    { key: 'max_invest_rupees', header: 'Max Invest', render: (r) => <span>{fmtRupees(r.max_invest_rupees)}</span> },
    { key: 'expires_on', header: 'Expires', render: (r) => <span>{fmtDate(r.expires_on)}</span> },
  ];

  const totalsByCols: Column<ExercisedTotalRow>[] = [
    { key: 'round_name', header: 'Round', render: (r) => <span style={{ fontWeight: 600 }}>{r.round_name}</span> },
    { key: 'exercise_count', header: 'Exercises', render: (r) => <span>{r.exercise_count}</span> },
    { key: 'total_exercised_rupees', header: 'Total Exercised', render: (r) => <span>{fmtRupees(r.total_exercised_rupees)}</span> },
    { key: 'avg_exercised_rupees', header: 'Avg Exercised', render: (r) => <span>{fmtRupees(r.avg_exercised_rupees)}</span> },
  ];

  const kpiCard = (label: string, value: string, accent?: string) => (
    <div
      style={{
        background: '#fff',
        border: '1px solid #e5e7eb',
        borderRadius: 8,
        padding: 16,
        flex: '1 1 180px',
        minWidth: 160,
      }}
    >
      <div style={{ fontSize: 12, color: '#6b7280', textTransform: 'uppercase', letterSpacing: 0.5 }}>{label}</div>
      <div style={{ fontSize: 24, fontWeight: 700, marginTop: 6, color: accent ?? '#111827' }}>{value}</div>
    </div>
  );

  return (
    <div style={{ padding: 24, maxWidth: 1400, margin: '0 auto' }}>
      <header style={{ marginBottom: 24 }}>
        <h1 style={{ fontSize: 28, fontWeight: 700, margin: 0 }}>Investor Pro-Rata Tracker</h1>
        <p style={{ color: '#6b7280', marginTop: 4 }}>
          Track pro-rata rights + exercise queue per investor per round (r1669)
        </p>
      </header>

      {/* Section 1 — Summary KPIs */}
      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Summary</h2>
        <div style={{ display: 'flex', flexWrap: 'wrap', gap: 12 }}>
          {kpiCard('Total Rights', String(summary?.total_rights ?? 0))}
          {kpiCard('Active', String(summary?.active_rights ?? 0), '#166534')}
          {kpiCard('Expired', String(summary?.expired_rights ?? 0), '#991b1b')}
          {kpiCard('Exercised', String(summary?.exercised_rights ?? 0), '#1e40af')}
          {kpiCard('Waived', String(summary?.waived_rights ?? 0), '#6b7280')}
          {kpiCard('Max Invest Pool', fmtRupees(summary?.total_max_invest_rupees ?? 0))}
          {kpiCard('Total Exercised', fmtRupees(summary?.total_exercised_rupees ?? 0), '#1e40af')}
        </div>
      </section>

      {/* Section 2 — Expiring Action Queue */}
      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>
          Action Queue — Expiring in 30 Days ({expiring.length})
        </h2>
        {expiring.length === 0 ? (
          <div
            style={{
              padding: 24,
              background: '#f9fafb',
              border: '1px dashed #d1d5db',
              borderRadius: 8,
              color: '#6b7280',
              textAlign: 'center',
            }}
          >
            No expiring rights in next 30 days.
          </div>
        ) : (
          <DataTable
            rows={expiring}
            columns={expiringCols}
            rowKey={(r, i) => String(r.id ?? i)}
          />
        )}
      </section>

      {/* Section 3 — All Pro-Rata Rights */}
      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>
          All Pro-Rata Rights ({rights.length})
        </h2>
        <DataTable
          rows={rights}
          columns={rightCols}
          rowKey={(r, i) => String(r.id ?? i)}
        />
      </section>

      {/* Section 4 — Exercises Log */}
      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>
          Exercise Decisions ({exercises.length})
        </h2>
        <DataTable
          rows={exercises}
          columns={exerciseCols}
          rowKey={(r, i) => String(r.id ?? i)}
        />
      </section>

      {/* Section 5 — Exercised Totals by Round */}
      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Exercised Totals by Round</h2>
        <DataTable
          rows={exercisedTotals}
          columns={totalsByCols}
          rowKey={(r, i) => String(r.round_name ?? i)}
        />
      </section>
    </div>
  );
}
