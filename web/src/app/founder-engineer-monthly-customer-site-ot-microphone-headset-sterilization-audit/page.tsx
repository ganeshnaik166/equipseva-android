import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type MonthlySummary = { audit_month: string; audits: number; green: number; amber: number; red: number; avg_score: number; rework: number };
type Hospital = { hospital_name: string; audits: number; avg_score: number; red_count: number; total_invoice: number };
type Engineer = { engineer_name: string; audits: number; avg_score: number; fail_rate: number; rework: number };
type Method = { sterilization_method: string; audits: number; pass_rate: number; avg_bioburden: number; avg_score: number };
type Finding = { finding_code: string; severity: string; count: number; overdue: number };
type EtoRow = { hospital_name: string; ot_room_code: string; headset_serial: string; residual_etylene_ppm: number; audit_month: string };
type Invoice = { audit_month: string; hospitals: number; total_invoice: number; rework_invoice: number };

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [monthly, hospitals, engineers, methods, findings, eto, invoices] = await Promise.all([
    supabase.rpc('r2982_monthly_compliance_summary'),
    supabase.rpc('r2982_hospital_leaderboard'),
    supabase.rpc('r2982_engineer_performance'),
    supabase.rpc('r2982_method_efficacy'),
    supabase.rpc('r2982_open_findings'),
    supabase.rpc('r2982_residual_eto_watchlist'),
    supabase.rpc('r2982_invoice_rollup'),
  ]);

  const monthlyRows = (monthly.data ?? []) as MonthlySummary[];
  const hospitalRows = (hospitals.data ?? []) as Hospital[];
  const engineerRows = (engineers.data ?? []) as Engineer[];
  const methodRows = (methods.data ?? []) as Method[];
  const findingRows = (findings.data ?? []) as Finding[];
  const etoRows = (eto.data ?? []) as EtoRow[];
  const invoiceRows = (invoices.data ?? []) as Invoice[];

  const monthlyCols: Column<MonthlySummary>[] = [
    { header: 'Month', accessor: (r) => r.audit_month },
    { header: 'Audits', accessor: (r) => r.audits },
    { header: 'Green', accessor: (r) => r.green },
    { header: 'Amber', accessor: (r) => r.amber },
    { header: 'Red', accessor: (r) => r.red },
    { header: 'Avg Score', accessor: (r) => r.avg_score },
    { header: 'Rework', accessor: (r) => r.rework },
  ];

  const hospitalCols: Column<Hospital>[] = [
    { header: 'Hospital', accessor: (r) => r.hospital_name },
    { header: 'Audits', accessor: (r) => r.audits },
    { header: 'Avg Score', accessor: (r) => r.avg_score },
    { header: 'Red', accessor: (r) => r.red_count },
    { header: 'Invoice (Rs)', accessor: (r) => r.total_invoice },
  ];

  const engineerCols: Column<Engineer>[] = [
    { header: 'Engineer', accessor: (r) => r.engineer_name },
    { header: 'Audits', accessor: (r) => r.audits },
    { header: 'Avg Score', accessor: (r) => r.avg_score },
    { header: 'Fail %', accessor: (r) => r.fail_rate },
    { header: 'Rework', accessor: (r) => r.rework },
  ];

  const methodCols: Column<Method>[] = [
    { header: 'Method', accessor: (r) => r.sterilization_method },
    { header: 'Audits', accessor: (r) => r.audits },
    { header: 'Pass %', accessor: (r) => r.pass_rate },
    { header: 'Avg CFU', accessor: (r) => r.avg_bioburden },
    { header: 'Avg Score', accessor: (r) => r.avg_score },
  ];

  const findingCols: Column<Finding>[] = [
    { header: 'Code', accessor: (r) => r.finding_code },
    { header: 'Severity', accessor: (r) => r.severity },
    { header: 'Count', accessor: (r) => r.count },
    { header: 'Overdue', accessor: (r) => r.overdue },
  ];

  const etoCols: Column<EtoRow>[] = [
    { header: 'Hospital', accessor: (r) => r.hospital_name },
    { header: 'OT', accessor: (r) => r.ot_room_code },
    { header: 'Headset', accessor: (r) => r.headset_serial },
    { header: 'ETO ppm', accessor: (r) => r.residual_etylene_ppm },
    { header: 'Month', accessor: (r) => r.audit_month },
  ];

  const invoiceCols: Column<Invoice>[] = [
    { header: 'Month', accessor: (r) => r.audit_month },
    { header: 'Hospitals', accessor: (r) => r.hospitals },
    { header: 'Total (Rs)', accessor: (r) => r.total_invoice },
    { header: 'Rework (Rs)', accessor: (r) => r.rework_invoice },
  ];

  return (
    <main style={{ padding: 24, display: 'flex', flexDirection: 'column', gap: 24 }}>
      <header>
        <h1 style={{ fontSize: 22, fontWeight: 700 }}>Engineer Monthly Customer-Site OT Microphone-Headset Sterilization Audit</h1>
        <p style={{ color: '#555', marginTop: 4 }}>Round r2982 — founder console. Tracks ETO/HPV/UVC cycles, bioburden CFU & CAPA findings across customer-site operating theatres.</p>
      </header>

      <section>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>Monthly compliance summary</h2>
        <DataTable rows={monthlyRows} columns={monthlyCols} emptyMessage="No audits yet" rowKey={(r, i) => String(r.audit_month ?? i)} />
      </section>

      <section>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>Hospital leaderboard</h2>
        <DataTable rows={hospitalRows} columns={hospitalCols} emptyMessage="No hospitals" rowKey={(r, i) => String(r.hospital_name ?? i)} />
      </section>

      <section>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>Engineer performance</h2>
        <DataTable rows={engineerRows} columns={engineerCols} emptyMessage="No engineers" rowKey={(r, i) => String(r.engineer_name ?? i)} />
      </section>

      <section>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>Sterilization method efficacy</h2>
        <DataTable rows={methodRows} columns={methodCols} emptyMessage="No methods" rowKey={(r, i) => String(r.sterilization_method ?? i)} />
      </section>

      <section>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>Open CAPA findings</h2>
        <DataTable rows={findingRows} columns={findingCols} emptyMessage="No open findings" rowKey={(r, i) => String((r.finding_code ?? '') + (r.severity ?? '') + i)} />
      </section>

      <section>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>Residual ETO watchlist (&gt; 1.0 ppm)</h2>
        <DataTable rows={etoRows} columns={etoCols} emptyMessage="No watchlist rows" rowKey={(r, i) => String((r.headset_serial ?? '') + (r.audit_month ?? '') + i)} />
      </section>

      <section>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>Invoice roll-up</h2>
        <DataTable rows={invoiceRows} columns={invoiceCols} emptyMessage="No invoices" rowKey={(r, i) => String(r.audit_month ?? i)} />
      </section>
    </main>
  );
}
