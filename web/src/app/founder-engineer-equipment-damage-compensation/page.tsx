import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type CompensationRow = {
  id: string;
  engineer_user_id: string;
  engineer_email: string | null;
  damage_event_id: string | null;
  equipment_name: string;
  damage_assessment_rupees: number;
  deduction_amount_rupees: number;
  recovery_method: string;
  status: string;
  recovered_at: string | null;
  appeal_count: number;
  created_at: string;
};

type AppealRow = {
  id: string;
  compensation_id: string;
  equipment_name: string;
  engineer_user_id: string;
  appeal_at: string;
  appeal_reason: string | null;
  decision: string | null;
  decided_at: string | null;
  compensation_status: string;
};

type SummaryRow = {
  total_cases: number;
  assessed_cases: number;
  agreed_cases: number;
  recovering_cases: number;
  recovered_cases: number;
  written_off_cases: number;
  total_assessment_rupees: number;
  total_deduction_rupees: number;
  total_recovered_rupees: number;
  total_written_off_rupees: number;
  appeals_count: number;
  appeals_waived: number;
  cases_last_30d: number;
};

type TopEngineerRow = {
  engineer_user_id: string;
  engineer_email: string | null;
  case_count: number;
  total_assessment_rupees: number;
  total_deduction_rupees: number;
  recovered_rupees: number;
  open_cases: number;
  appeal_count: number;
};

function rupeesToInr(n: number | null | undefined): string {
  if (n == null) return '—';
  return '₹' + Number(n).toLocaleString('en-IN');
}

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [compRes, appealRes, sumRes, topRes] = await Promise.all([
    sb.rpc('list_compensations_r1772'),
    sb.rpc('list_appeals_r1772'),
    sb.rpc('compensation_summary_r1772'),
    sb.rpc('top_damage_engineers_r1772'),
  ]);

  const comps: CompensationRow[] = (compRes.data as CompensationRow[] | null) ?? [];
  const appeals: AppealRow[] = (appealRes.data as AppealRow[] | null) ?? [];
  const summary: SummaryRow[] = (sumRes.data as SummaryRow[] | null) ?? [];
  const top: TopEngineerRow[] = (topRes.data as TopEngineerRow[] | null) ?? [];

  const s = summary[0];

  const compCols: Column<CompensationRow>[] = [
    { key: 'equipment_name', header: 'Equipment', render: (r: any) => r.equipment_name },
    { key: 'engineer_email', header: 'Engineer', render: (r: any) => r.engineer_email ?? String(r.engineer_user_id).slice(0, 8) },
    { key: 'damage_assessment_rupees', header: 'Assessment', render: (r: any) => rupeesToInr(r.damage_assessment_rupees) },
    { key: 'deduction_amount_rupees', header: 'Deduction', render: (r: any) => rupeesToInr(r.deduction_amount_rupees) },
    { key: 'recovery_method', header: 'Method', render: (r: any) => r.recovery_method },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'appeal_count', header: 'Appeals', render: (r: any) => r.appeal_count },
    { key: 'recovered_at', header: 'Recovered', render: (r: any) => r.recovered_at ?? '—' },
    { key: 'created_at', header: 'Created', render: (r: any) => r.created_at ? String(r.created_at).slice(0, 10) : '—' },
  ];

  const appealCols: Column<AppealRow>[] = [
    { key: 'equipment_name', header: 'Equipment', render: (r: any) => r.equipment_name },
    { key: 'engineer_user_id', header: 'Engineer', render: (r: any) => String(r.engineer_user_id).slice(0, 8) },
    { key: 'appeal_at', header: 'Filed', render: (r: any) => r.appeal_at ? String(r.appeal_at).slice(0, 10) : '—' },
    { key: 'appeal_reason', header: 'Reason', render: (r: any) => r.appeal_reason ?? '—' },
    { key: 'decision', header: 'Decision', render: (r: any) => r.decision ?? 'pending' },
    { key: 'decided_at', header: 'Decided', render: (r: any) => r.decided_at ? String(r.decided_at).slice(0, 10) : '—' },
    { key: 'compensation_status', header: 'Case status', render: (r: any) => r.compensation_status },
  ];

  const topCols: Column<TopEngineerRow>[] = [
    { key: 'engineer_email', header: 'Engineer', render: (r: any) => r.engineer_email ?? String(r.engineer_user_id).slice(0, 8) },
    { key: 'case_count', header: 'Cases', render: (r: any) => r.case_count },
    { key: 'total_assessment_rupees', header: 'Total assessed', render: (r: any) => rupeesToInr(r.total_assessment_rupees) },
    { key: 'total_deduction_rupees', header: 'Total deduction', render: (r: any) => rupeesToInr(r.total_deduction_rupees) },
    { key: 'recovered_rupees', header: 'Recovered', render: (r: any) => rupeesToInr(r.recovered_rupees) },
    { key: 'open_cases', header: 'Open', render: (r: any) => r.open_cases },
    { key: 'appeal_count', header: 'Appeals', render: (r: any) => r.appeal_count },
  ];

  return (
    <div style={{ padding: 24, maxWidth: 1200, margin: '0 auto' }}>
      <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 8 }}>Engineer Equipment Damage Compensation</h1>
      <p style={{ color: '#666', marginBottom: 24 }}>
        Track engineer-caused equipment damages, assessment values, and recovery via payroll deduction, cash payment, or written-off. Appeals tracked separately with decision outcomes.
      </p>

      {s ? (
        <section style={{ marginBottom: 32 }}>
          <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Summary</h2>
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(180px, 1fr))', gap: 12 }}>
            <div style={{ padding: 16, background: '#f7f7f7', borderRadius: 8 }}>
              <div style={{ fontSize: 12, color: '#666' }}>Total cases</div>
              <div style={{ fontSize: 22, fontWeight: 700 }}>{s.total_cases}</div>
            </div>
            <div style={{ padding: 16, background: '#fff7e6', borderRadius: 8 }}>
              <div style={{ fontSize: 12, color: '#666' }}>Recovering</div>
              <div style={{ fontSize: 22, fontWeight: 700 }}>{s.recovering_cases}</div>
            </div>
            <div style={{ padding: 16, background: '#e6f7ea', borderRadius: 8 }}>
              <div style={{ fontSize: 12, color: '#666' }}>Recovered</div>
              <div style={{ fontSize: 22, fontWeight: 700 }}>{s.recovered_cases}</div>
            </div>
            <div style={{ padding: 16, background: '#fbeaea', borderRadius: 8 }}>
              <div style={{ fontSize: 12, color: '#666' }}>Written off</div>
              <div style={{ fontSize: 22, fontWeight: 700 }}>{s.written_off_cases}</div>
            </div>
            <div style={{ padding: 16, background: '#eef2ff', borderRadius: 8 }}>
              <div style={{ fontSize: 12, color: '#666' }}>Total assessment</div>
              <div style={{ fontSize: 18, fontWeight: 700 }}>{rupeesToInr(s.total_assessment_rupees)}</div>
            </div>
            <div style={{ padding: 16, background: '#eef2ff', borderRadius: 8 }}>
              <div style={{ fontSize: 12, color: '#666' }}>Total deduction</div>
              <div style={{ fontSize: 18, fontWeight: 700 }}>{rupeesToInr(s.total_deduction_rupees)}</div>
            </div>
            <div style={{ padding: 16, background: '#eef2ff', borderRadius: 8 }}>
              <div style={{ fontSize: 12, color: '#666' }}>Recovered amount</div>
              <div style={{ fontSize: 18, fontWeight: 700 }}>{rupeesToInr(s.total_recovered_rupees)}</div>
            </div>
            <div style={{ padding: 16, background: '#eef2ff', borderRadius: 8 }}>
              <div style={{ fontSize: 12, color: '#666' }}>Written off amount</div>
              <div style={{ fontSize: 18, fontWeight: 700 }}>{rupeesToInr(s.total_written_off_rupees)}</div>
            </div>
            <div style={{ padding: 16, background: '#f7f7f7', borderRadius: 8 }}>
              <div style={{ fontSize: 12, color: '#666' }}>Appeals</div>
              <div style={{ fontSize: 22, fontWeight: 700 }}>{s.appeals_count}</div>
              <div style={{ fontSize: 12, color: '#666' }}>waived: {s.appeals_waived}</div>
            </div>
            <div style={{ padding: 16, background: '#f7f7f7', borderRadius: 8 }}>
              <div style={{ fontSize: 12, color: '#666' }}>Last 30 days</div>
              <div style={{ fontSize: 22, fontWeight: 700 }}>{s.cases_last_30d}</div>
            </div>
          </div>
        </section>
      ) : null}

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>All compensation cases ({comps.length})</h2>
        <p style={{ color: '#666', marginBottom: 8, fontSize: 13 }}>
          Damage assessments with deduction amount, recovery method, and status. Status flows assessed → agreed → recovering → recovered, or written_off.
        </p>
        <DataTable
          rows={comps}
          columns={compCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Appeals ({appeals.length})</h2>
        <p style={{ color: '#666', marginBottom: 8, fontSize: 13 }}>
          Engineer appeals against assessment with decision outcomes: upheld, reduced, waived, or escalated to legal.
        </p>
        <DataTable
          rows={appeals}
          columns={appealCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Top damage engineers ({top.length})</h2>
        <p style={{ color: '#666', marginBottom: 8, fontSize: 13 }}>
          Engineers ranked by total assessment value. Watch for repeat offenders and open-case counts.
        </p>
        <DataTable
          rows={top}
          columns={topCols}
          rowKey={(r: any, i: number) => String(r.engineer_user_id ?? i)}
        />
      </section>
    </div>
  );
}
