import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type TargetRow = {
  id: string;
  target_team_name: string;
  founder_count: number;
  employee_count: number;
  current_runway_months: number;
  asking_price_rupees: number;
  status: string;
  expected_close_date: string | null;
  founder_contact_email: string | null;
  diligence_total: number;
  diligence_clean: number;
  diligence_blockers: number;
  created_at: string;
};

type SummaryRow = {
  status: string;
  target_count: number;
  total_asking_rupees: number;
  total_founder_count: number;
  total_employee_count: number;
  avg_runway_months: number;
};

type BlockedRow = {
  id: string;
  target_id: string;
  target_team_name: string;
  diligence_area: string;
  status: string;
  notes_md: string | null;
  created_at: string;
};

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [targetsRes, summaryRes, blockedRes] = await Promise.all([
    sb.rpc('list_targets_r1746'),
    sb.rpc('pipeline_value_summary_r1746'),
    sb.rpc('blocked_diligence_r1746'),
  ]);

  const targets: TargetRow[] = (targetsRes.data as TargetRow[] | null) ?? [];
  const summary: SummaryRow[] = (summaryRes.data as SummaryRow[] | null) ?? [];
  const blocked: BlockedRow[] = (blockedRes.data as BlockedRow[] | null) ?? [];

  const totalPipelineRupees = summary.reduce(
    (acc, s) => acc + Number(s.total_asking_rupees ?? 0),
    0
  );
  const activeTargets = targets.filter(
    (t) => t.status !== 'closed' && t.status !== 'passed'
  ).length;

  const targetCols: Column<TargetRow>[] = [
    { key: 'target_team_name', header: 'Team', render: (r: any) => r.target_team_name },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'founder_count', header: 'Founders', render: (r: any) => r.founder_count },
    { key: 'employee_count', header: 'Employees', render: (r: any) => r.employee_count },
    { key: 'current_runway_months', header: 'Runway (mo)', render: (r: any) => r.current_runway_months },
    {
      key: 'asking_price_rupees',
      header: 'Asking (Rs)',
      render: (r: any) => Number(r.asking_price_rupees ?? 0).toLocaleString('en-IN'),
    },
    { key: 'expected_close_date', header: 'Expected close', render: (r: any) => r.expected_close_date ?? '—' },
    { key: 'founder_contact_email', header: 'Contact', render: (r: any) => r.founder_contact_email ?? '—' },
    {
      key: 'diligence_total',
      header: 'DD',
      render: (r: any) => `${r.diligence_clean}/${r.diligence_total} clean`,
    },
    { key: 'diligence_blockers', header: 'Blockers', render: (r: any) => r.diligence_blockers },
  ];

  const summaryCols: Column<SummaryRow>[] = [
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'target_count', header: 'Targets', render: (r: any) => r.target_count },
    {
      key: 'total_asking_rupees',
      header: 'Total asking (Rs)',
      render: (r: any) => Number(r.total_asking_rupees ?? 0).toLocaleString('en-IN'),
    },
    { key: 'total_founder_count', header: 'Founders', render: (r: any) => r.total_founder_count },
    { key: 'total_employee_count', header: 'Employees', render: (r: any) => r.total_employee_count },
    {
      key: 'avg_runway_months',
      header: 'Avg runway (mo)',
      render: (r: any) => Number(r.avg_runway_months ?? 0).toFixed(1),
    },
  ];

  const blockedCols: Column<BlockedRow>[] = [
    { key: 'target_team_name', header: 'Team', render: (r: any) => r.target_team_name },
    { key: 'diligence_area', header: 'Area', render: (r: any) => r.diligence_area },
    { key: 'status', header: 'DD status', render: (r: any) => r.status },
    { key: 'notes_md', header: 'Notes', render: (r: any) => r.notes_md ?? '—' },
    { key: 'created_at', header: 'Opened', render: (r: any) => String(r.created_at).slice(0, 10) },
  ];

  return (
    <div style={{ padding: 24, maxWidth: 1200, margin: '0 auto' }}>
      <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 8 }}>Acquihire Pipeline</h1>
      <p style={{ color: '#666', marginBottom: 24 }}>
        Track potential team-acquihires (small teams to absorb). Pipeline value, per-stage funnel, and
        diligence blockers in one place.
      </p>

      <section style={{ marginBottom: 32, display: 'grid', gridTemplateColumns: 'repeat(3, 1fr)', gap: 12 }}>
        <div style={{ padding: 16, border: '1px solid #eee', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#888' }}>Active targets</div>
          <div style={{ fontSize: 22, fontWeight: 700 }}>{activeTargets}</div>
        </div>
        <div style={{ padding: 16, border: '1px solid #eee', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#888' }}>Total targets</div>
          <div style={{ fontSize: 22, fontWeight: 700 }}>{targets.length}</div>
        </div>
        <div style={{ padding: 16, border: '1px solid #eee', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#888' }}>Total pipeline asking (Rs)</div>
          <div style={{ fontSize: 22, fontWeight: 700 }}>
            {totalPipelineRupees.toLocaleString('en-IN')}
          </div>
        </div>
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>
          Pipeline by stage ({summary.length})
        </h2>
        <p style={{ color: '#666', marginBottom: 8, fontSize: 13 }}>
          Funnel from intro → diligence → LOI → negotiating → closed or passed.
        </p>
        <DataTable
          rows={summary}
          columns={summaryCols}
          rowKey={(r: any, i: number) => String(r.status ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>
          All targets ({targets.length})
        </h2>
        <DataTable
          rows={targets}
          columns={targetCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>
          Blocked diligence ({blocked.length})
        </h2>
        <p style={{ color: '#666', marginBottom: 8, fontSize: 13 }}>
          Diligence items flagged blockers or concerns on targets still in pipeline.
        </p>
        <DataTable
          rows={blocked}
          columns={blockedCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>
    </div>
  );
}
