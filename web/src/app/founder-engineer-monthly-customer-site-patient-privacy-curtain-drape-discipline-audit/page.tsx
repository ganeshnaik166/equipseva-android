import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type MonthlySummary = {
  audit_month: string;
  audits_total: number;
  audits_completed: number;
  audits_escalated: number;
  avg_privacy_score_pct: number;
  grade_a_count: number;
  grade_f_count: number;
};

type EngineerRow = {
  engineer_name: string;
  audits_done: number;
  avg_score: number;
  grade_a_count: number;
  remediation_count: number;
};

type HospitalRow = {
  hospital_name: string;
  wards_audited: number;
  avg_score: number;
  incidents_open: number;
  total_fines_rupees: number;
};

type SeverityRow = {
  severity: string;
  incident_count: number;
  total_exposure_minutes: number;
  total_fines_rupees: number;
};

type TypeRow = {
  incident_type: string;
  occurrences: number;
  open_count: number;
  avg_exposure_minutes: number;
};

type CriticalRow = {
  id: string;
  hospital_name: string;
  ward_name: string;
  engineer_name: string;
  incident_type: string;
  patient_exposure_minutes: number;
  fine_amount_rupees: number;
  reported_at: string;
};

type MomRow = {
  engineer_name: string;
  current_score: number;
  prior_score: number;
  score_delta: number;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [monthly, leaderboard, hospitals, severity, types, critical, mom] = await Promise.all([
    supabase.rpc('founder_curtain_monthly_summary_r2954'),
    supabase.rpc('founder_curtain_engineer_leaderboard_r2954'),
    supabase.rpc('founder_curtain_hospital_rollup_r2954'),
    supabase.rpc('founder_curtain_incident_severity_r2954'),
    supabase.rpc('founder_curtain_incident_types_r2954'),
    supabase.rpc('founder_curtain_open_critical_r2954'),
    supabase.rpc('founder_curtain_mom_delta_r2954'),
  ]);

  const monthlyRows: MonthlySummary[] = (monthly.data as MonthlySummary[]) ?? [];
  const engineerRows: EngineerRow[] = (leaderboard.data as EngineerRow[]) ?? [];
  const hospitalRows: HospitalRow[] = (hospitals.data as HospitalRow[]) ?? [];
  const severityRows: SeverityRow[] = (severity.data as SeverityRow[]) ?? [];
  const typeRows: TypeRow[] = (types.data as TypeRow[]) ?? [];
  const criticalRows: CriticalRow[] = (critical.data as CriticalRow[]) ?? [];
  const momRows: MomRow[] = (mom.data as MomRow[]) ?? [];

  const monthlyCols: Column<MonthlySummary>[] = [
    { header: 'Month', accessor: (r) => r.audit_month },
    { header: 'Audits', accessor: (r) => r.audits_total },
    { header: 'Completed', accessor: (r) => r.audits_completed },
    { header: 'Escalated', accessor: (r) => r.audits_escalated },
    { header: 'Avg Score %', accessor: (r) => r.avg_privacy_score_pct },
    { header: 'Grade A', accessor: (r) => r.grade_a_count },
    { header: 'Grade F', accessor: (r) => r.grade_f_count },
  ];

  const engineerCols: Column<EngineerRow>[] = [
    { header: 'Engineer', accessor: (r) => r.engineer_name },
    { header: 'Audits', accessor: (r) => r.audits_done },
    { header: 'Avg Score', accessor: (r) => r.avg_score },
    { header: 'Grade A', accessor: (r) => r.grade_a_count },
    { header: 'Remediation', accessor: (r) => r.remediation_count },
  ];

  const hospitalCols: Column<HospitalRow>[] = [
    { header: 'Hospital', accessor: (r) => r.hospital_name },
    { header: 'Wards', accessor: (r) => r.wards_audited },
    { header: 'Avg Score', accessor: (r) => r.avg_score },
    { header: 'Open Incidents', accessor: (r) => r.incidents_open },
    { header: 'Fines (Rs)', accessor: (r) => r.total_fines_rupees },
  ];

  const severityCols: Column<SeverityRow>[] = [
    { header: 'Severity', accessor: (r) => r.severity },
    { header: 'Count', accessor: (r) => r.incident_count },
    { header: 'Exposure Min', accessor: (r) => r.total_exposure_minutes },
    { header: 'Fines (Rs)', accessor: (r) => r.total_fines_rupees },
  ];

  const typeCols: Column<TypeRow>[] = [
    { header: 'Type', accessor: (r) => r.incident_type },
    { header: 'Occurrences', accessor: (r) => r.occurrences },
    { header: 'Open', accessor: (r) => r.open_count },
    { header: 'Avg Exposure Min', accessor: (r) => r.avg_exposure_minutes },
  ];

  const criticalCols: Column<CriticalRow>[] = [
    { header: 'Hospital', accessor: (r) => r.hospital_name },
    { header: 'Ward', accessor: (r) => r.ward_name },
    { header: 'Engineer', accessor: (r) => r.engineer_name },
    { header: 'Type', accessor: (r) => r.incident_type },
    { header: 'Exposure Min', accessor: (r) => r.patient_exposure_minutes },
    { header: 'Fine (Rs)', accessor: (r) => r.fine_amount_rupees },
    { header: 'Reported', accessor: (r) => new Date(r.reported_at).toLocaleString() },
  ];

  const momCols: Column<MomRow>[] = [
    { header: 'Engineer', accessor: (r) => r.engineer_name },
    { header: 'Current Score', accessor: (r) => r.current_score },
    { header: 'Prior Score', accessor: (r) => r.prior_score },
    { header: 'Delta', accessor: (r) => r.score_delta },
  ];

  return (
    <main style={{ padding: '24px', maxWidth: 1200, margin: '0 auto' }}>
      <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 8 }}>
        Engineer Monthly Customer Site Patient-Privacy Curtain &amp; Drape Discipline Audit
      </h1>
      <p style={{ color: '#666', marginBottom: 24 }}>
        Round r2954 — enforce privacy curtain &amp; drape discipline at hospital sites; scores &gt;=90% target.
      </p>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Monthly Summary</h2>
        <DataTable
          rows={monthlyRows}
          columns={monthlyCols}
          emptyMessage="No monthly data yet."
          rowKey={(r, i) => String(r.audit_month ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Engineer Leaderboard</h2>
        <DataTable
          rows={engineerRows}
          columns={engineerCols}
          emptyMessage="No engineers."
          rowKey={(r, i) => String(r.engineer_name ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Hospital Roll-up</h2>
        <DataTable
          rows={hospitalRows}
          columns={hospitalCols}
          emptyMessage="No hospitals."
          rowKey={(r, i) => String(r.hospital_name ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Incident Severity Breakdown</h2>
        <DataTable
          rows={severityRows}
          columns={severityCols}
          emptyMessage="No incidents."
          rowKey={(r, i) => String(r.severity ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Incident Type Frequency</h2>
        <DataTable
          rows={typeRows}
          columns={typeCols}
          emptyMessage="No incident types."
          rowKey={(r, i) => String(r.incident_type ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Open Critical Incidents</h2>
        <DataTable
          rows={criticalRows}
          columns={criticalCols}
          emptyMessage="No open critical incidents."
          rowKey={(r, i) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Month-over-Month Delta</h2>
        <DataTable
          rows={momRows}
          columns={momCols}
          emptyMessage="No MoM data."
          rowKey={(r, i) => String(r.engineer_name ?? i)}
        />
      </section>
    </main>
  );
}
