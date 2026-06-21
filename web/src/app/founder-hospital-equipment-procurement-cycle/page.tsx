import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type CycleRow = {
  id: string;
  hospital_user_id: string;
  hospital_email: string | null;
  equipment_category: string;
  decision_committee: string[] | null;
  decision_deadline: string | null;
  our_pitch_status: string;
  our_quote_rupees: number | null;
  status: string;
  decided_at: string | null;
  activity_count: number | null;
  created_at: string;
};

type ActivityRow = {
  id: string;
  cycle_id: string;
  activity_type: string;
  activity_at: string;
  our_team: string[] | null;
  outcome_summary: string | null;
  created_at: string;
};

type WinRateRow = {
  equipment_category: string;
  total_cycles: number;
  won_cycles: number;
  lost_cycles: number;
  open_cycles: number;
  win_rate_pct: number | null;
};

type DecisionRow = {
  id: string;
  hospital_user_id: string;
  hospital_email: string | null;
  equipment_category: string;
  status: string;
  our_pitch_status: string;
  our_quote_rupees: number | null;
  decided_at: string | null;
};

function fmtRupees(n: number | null | undefined): string {
  if (n === null || n === undefined) return '—';
  return '₹' + n.toLocaleString('en-IN');
}

function fmtDate(iso: string | null | undefined): string {
  if (!iso) return '—';
  try {
    return new Date(iso).toLocaleDateString('en-IN', { day: '2-digit', month: 'short', year: 'numeric' });
  } catch {
    return iso;
  }
}

function fmtDateTime(iso: string | null | undefined): string {
  if (!iso) return '—';
  try {
    return new Date(iso).toLocaleString('en-IN');
  } catch {
    return iso;
  }
}

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [cyclesRes, activitiesRes, winRateRes, decisionsRes] = await Promise.all([
    sb.rpc('list_cycles_r1823'),
    sb.rpc('list_activities_r1823', { p_cycle_id: null }),
    sb.rpc('win_rate_by_category_r1823'),
    sb.rpc('recent_decisions_r1823'),
  ]);

  const cycles: CycleRow[] = (cyclesRes.data ?? []) as CycleRow[];
  const activities: ActivityRow[] = (activitiesRes.data ?? []) as ActivityRow[];
  const winRates: WinRateRow[] = (winRateRes.data ?? []) as WinRateRow[];
  const decisions: DecisionRow[] = (decisionsRes.data ?? []) as DecisionRow[];

  const errMsg =
    cyclesRes.error?.message ||
    activitiesRes.error?.message ||
    winRateRes.error?.message ||
    decisionsRes.error?.message ||
    null;

  const totalCycles = cycles.length;
  const openCycles = cycles.filter((c) => c.status === 'open').length;
  const wonCycles = cycles.filter((c) => c.status === 'won').length;
  const lostCycles = cycles.filter((c) => c.status === 'lost').length;
  const pipelineRupees = cycles
    .filter((c) => c.status === 'open' && c.our_quote_rupees)
    .reduce((sum, c) => sum + (c.our_quote_rupees ?? 0), 0);

  const cycleColumns: Column<CycleRow>[] = [
    { key: 'hospital_email', header: 'Hospital', render: (r: any) => <span>{r.hospital_email ?? r.hospital_user_id?.slice(0, 8)}</span> },
    { key: 'equipment_category', header: 'Category', render: (r: any) => <span>{r.equipment_category}</span> },
    { key: 'decision_committee', header: 'Committee', render: (r: any) => <span>{Array.isArray(r.decision_committee) ? r.decision_committee.join(', ') : '—'}</span> },
    { key: 'decision_deadline', header: 'Deadline', render: (r: any) => <span>{fmtDate(r.decision_deadline)}</span> },
    { key: 'our_pitch_status', header: 'Pitch', render: (r: any) => <span>{r.our_pitch_status}</span> },
    { key: 'our_quote_rupees', header: 'Quote', render: (r: any) => <span>{fmtRupees(r.our_quote_rupees)}</span> },
    { key: 'status', header: 'Status', render: (r: any) => <span>{r.status}</span> },
    { key: 'activity_count', header: 'Activities', render: (r: any) => <span>{r.activity_count ?? 0}</span> },
    { key: 'created_at', header: 'Opened', render: (r: any) => <span>{fmtDate(r.created_at)}</span> },
  ];

  const activityColumns: Column<ActivityRow>[] = [
    { key: 'activity_at', header: 'When', render: (r: any) => <span>{fmtDateTime(r.activity_at)}</span> },
    { key: 'activity_type', header: 'Type', render: (r: any) => <span>{r.activity_type}</span> },
    { key: 'cycle_id', header: 'Cycle', render: (r: any) => <span>{String(r.cycle_id).slice(0, 8)}</span> },
    { key: 'our_team', header: 'Our Team', render: (r: any) => <span>{Array.isArray(r.our_team) ? r.our_team.join(', ') : '—'}</span> },
    { key: 'outcome_summary', header: 'Outcome', render: (r: any) => <span>{r.outcome_summary ?? '—'}</span> },
  ];

  const winRateColumns: Column<WinRateRow>[] = [
    { key: 'equipment_category', header: 'Category', render: (r: any) => <span>{r.equipment_category}</span> },
    { key: 'total_cycles', header: 'Total', render: (r: any) => <span>{r.total_cycles}</span> },
    { key: 'won_cycles', header: 'Won', render: (r: any) => <span>{r.won_cycles}</span> },
    { key: 'lost_cycles', header: 'Lost', render: (r: any) => <span>{r.lost_cycles}</span> },
    { key: 'open_cycles', header: 'Open', render: (r: any) => <span>{r.open_cycles}</span> },
    { key: 'win_rate_pct', header: 'Win %', render: (r: any) => <span>{r.win_rate_pct ?? 0}%</span> },
  ];

  const decisionColumns: Column<DecisionRow>[] = [
    { key: 'decided_at', header: 'Decided', render: (r: any) => <span>{fmtDateTime(r.decided_at)}</span> },
    { key: 'hospital_email', header: 'Hospital', render: (r: any) => <span>{r.hospital_email ?? r.hospital_user_id?.slice(0, 8)}</span> },
    { key: 'equipment_category', header: 'Category', render: (r: any) => <span>{r.equipment_category}</span> },
    { key: 'status', header: 'Outcome', render: (r: any) => <span>{r.status}</span> },
    { key: 'our_pitch_status', header: 'Pitch End', render: (r: any) => <span>{r.our_pitch_status}</span> },
    { key: 'our_quote_rupees', header: 'Quote', render: (r: any) => <span>{fmtRupees(r.our_quote_rupees)}</span> },
  ];

  return (
    <main style={{ padding: '24px', maxWidth: 1400, margin: '0 auto' }}>
      <header style={{ marginBottom: 24 }}>
        <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 4 }}>Hospital Equipment Procurement Cycle</h1>
        <p style={{ color: '#666', fontSize: 14 }}>
          Track multi-month hospital equipment buying decisions — pitch stage, committee, activities & win rate.
        </p>
      </header>

      {errMsg ? (
        <div style={{ padding: 12, background: '#fee', border: '1px solid #fcc', borderRadius: 8, marginBottom: 16 }}>
          <strong>Error:</strong> {errMsg}
        </div>
      ) : null}

      <section style={{ marginBottom: 24 }}>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 12 }}>Overview</h2>
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(180px, 1fr))', gap: 12 }}>
          <div style={{ padding: 16, border: '1px solid #eee', borderRadius: 8 }}>
            <div style={{ fontSize: 12, color: '#666' }}>Total Cycles</div>
            <div style={{ fontSize: 24, fontWeight: 700 }}>{totalCycles}</div>
          </div>
          <div style={{ padding: 16, border: '1px solid #eee', borderRadius: 8 }}>
            <div style={{ fontSize: 12, color: '#666' }}>Open</div>
            <div style={{ fontSize: 24, fontWeight: 700 }}>{openCycles}</div>
          </div>
          <div style={{ padding: 16, border: '1px solid #eee', borderRadius: 8 }}>
            <div style={{ fontSize: 12, color: '#666' }}>Won</div>
            <div style={{ fontSize: 24, fontWeight: 700, color: '#0a7f3f' }}>{wonCycles}</div>
          </div>
          <div style={{ padding: 16, border: '1px solid #eee', borderRadius: 8 }}>
            <div style={{ fontSize: 12, color: '#666' }}>Lost</div>
            <div style={{ fontSize: 24, fontWeight: 700, color: '#a11' }}>{lostCycles}</div>
          </div>
          <div style={{ padding: 16, border: '1px solid #eee', borderRadius: 8 }}>
            <div style={{ fontSize: 12, color: '#666' }}>Open Pipeline</div>
            <div style={{ fontSize: 20, fontWeight: 700 }}>{fmtRupees(pipelineRupees)}</div>
          </div>
        </div>
      </section>

      <section style={{ marginBottom: 24 }}>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 12 }}>Win Rate by Category</h2>
        <DataTable<WinRateRow>
          rows={winRates}
          columns={winRateColumns}
          rowKey={(r: any, i: number) => String(r.equipment_category ?? i)}
        />
      </section>

      <section style={{ marginBottom: 24 }}>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 12 }}>Active & Recent Cycles</h2>
        <DataTable<CycleRow>
          rows={cycles}
          columns={cycleColumns}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 24 }}>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 12 }}>Recent Activities</h2>
        <DataTable<ActivityRow>
          rows={activities}
          columns={activityColumns}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 24 }}>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 12 }}>Recent Decisions (Won / Lost / Cancelled)</h2>
        <DataTable<DecisionRow>
          rows={decisions}
          columns={decisionColumns}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>
    </main>
  );
}
