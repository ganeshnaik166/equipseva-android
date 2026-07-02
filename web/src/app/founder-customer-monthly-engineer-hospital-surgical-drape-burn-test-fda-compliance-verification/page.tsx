import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type MonthlySummary = { test_month: string; total_tests: number; passed: number; failed: number; marginal: number; retest_required: number; pass_rate_pct: number };
type FailedLot = { drape_lot_code: string; drape_manufacturer: string; drape_material: string; flame_spread_seconds: number; char_length_mm: number; afterflame_seconds: number; fda_class: string; founder_signoff: string };
type Leaderboard = { drape_manufacturer: string; lots_tested: number; lots_passed: number; lots_failed: number; avg_flame_spread: number; avg_char_length: number; pass_rate_pct: number };
type RiskSummary = { device_category: string; total_audited: number; compliant: number; non_compliant: number; critical_findings: number; avg_risk_score: number };
type CriticalFinding = { audit_date: string; device_category: string; udi_di: string; packaging_integrity: string; expiry_date: string; corrective_action_due: string | null; risk_score: number };
type ExpiryWatch = { device_category: string; udi_di: string; expiry_date: string; days_to_expiry: number; sterilization_method: string; compliance_status: string };
type MaterialDive = { drape_material: string; lots_tested: number; avg_flame_spread: number; avg_char_length: number; avg_afterflame: number; nfpa701_pass_pct: number; astm_f1959_pass_pct: number };
type SignoffRow = { drape_lot_code: string; drape_manufacturer: string; test_outcome: string; founder_signoff: string; remediation_required: boolean; test_month: string };

export default async function Page() {
  const sb = await getSupabaseServerClient();
  const [monthly, failed, leaderboard, risk, critical, expiry, material, signoff] = await Promise.all([
    sb.rpc('r3000_burn_test_monthly_summary'),
    sb.rpc('r3000_failed_lots_recall_queue'),
    sb.rpc('r3000_manufacturer_burn_leaderboard'),
    sb.rpc('r3000_fda_audit_risk_summary'),
    sb.rpc('r3000_critical_findings_action_list'),
    sb.rpc('r3000_expiry_watch_90d'),
    sb.rpc('r3000_material_burn_deep_dive'),
    sb.rpc('r3000_founder_signoff_queue'),
  ]);

  const monthlyRows: MonthlySummary[] = (monthly.data as MonthlySummary[]) ?? [];
  const failedRows: FailedLot[] = (failed.data as FailedLot[]) ?? [];
  const leaderboardRows: Leaderboard[] = (leaderboard.data as Leaderboard[]) ?? [];
  const riskRows: RiskSummary[] = (risk.data as RiskSummary[]) ?? [];
  const criticalRows: CriticalFinding[] = (critical.data as CriticalFinding[]) ?? [];
  const expiryRows: ExpiryWatch[] = (expiry.data as ExpiryWatch[]) ?? [];
  const materialRows: MaterialDive[] = (material.data as MaterialDive[]) ?? [];
  const signoffRows: SignoffRow[] = (signoff.data as SignoffRow[]) ?? [];

  const monthlyCols: Column<MonthlySummary>[] = [
    { header: 'Month', accessor: (r) => r.test_month },
    { header: 'Total', accessor: (r) => r.total_tests },
    { header: 'Passed', accessor: (r) => r.passed },
    { header: 'Failed', accessor: (r) => r.failed },
    { header: 'Marginal', accessor: (r) => r.marginal },
    { header: 'Retest', accessor: (r) => r.retest_required },
    { header: 'Pass %', accessor: (r) => r.pass_rate_pct },
  ];

  const failedCols: Column<FailedLot>[] = [
    { header: 'Lot', accessor: (r) => r.drape_lot_code },
    { header: 'Manufacturer', accessor: (r) => r.drape_manufacturer },
    { header: 'Material', accessor: (r) => r.drape_material },
    { header: 'Flame s', accessor: (r) => r.flame_spread_seconds },
    { header: 'Char mm', accessor: (r) => r.char_length_mm },
    { header: 'Afterflame s', accessor: (r) => r.afterflame_seconds },
    { header: 'FDA Class', accessor: (r) => r.fda_class },
    { header: 'Signoff', accessor: (r) => r.founder_signoff },
  ];

  const leaderboardCols: Column<Leaderboard>[] = [
    { header: 'Manufacturer', accessor: (r) => r.drape_manufacturer },
    { header: 'Tested', accessor: (r) => r.lots_tested },
    { header: 'Passed', accessor: (r) => r.lots_passed },
    { header: 'Failed', accessor: (r) => r.lots_failed },
    { header: 'Avg Flame s', accessor: (r) => r.avg_flame_spread },
    { header: 'Avg Char mm', accessor: (r) => r.avg_char_length },
    { header: 'Pass %', accessor: (r) => r.pass_rate_pct },
  ];

  const riskCols: Column<RiskSummary>[] = [
    { header: 'Category', accessor: (r) => r.device_category },
    { header: 'Audited', accessor: (r) => r.total_audited },
    { header: 'Compliant', accessor: (r) => r.compliant },
    { header: 'Non-Compl', accessor: (r) => r.non_compliant },
    { header: 'Critical', accessor: (r) => r.critical_findings },
    { header: 'Avg Risk', accessor: (r) => r.avg_risk_score },
  ];

  const criticalCols: Column<CriticalFinding>[] = [
    { header: 'Date', accessor: (r) => r.audit_date },
    { header: 'Category', accessor: (r) => r.device_category },
    { header: 'UDI-DI', accessor: (r) => r.udi_di },
    { header: 'Packaging', accessor: (r) => r.packaging_integrity },
    { header: 'Expiry', accessor: (r) => r.expiry_date },
    { header: 'CA Due', accessor: (r) => r.corrective_action_due ?? '—' },
    { header: 'Risk', accessor: (r) => r.risk_score },
  ];

  const expiryCols: Column<ExpiryWatch>[] = [
    { header: 'Category', accessor: (r) => r.device_category },
    { header: 'UDI-DI', accessor: (r) => r.udi_di },
    { header: 'Expiry', accessor: (r) => r.expiry_date },
    { header: 'Days Left', accessor: (r) => r.days_to_expiry },
    { header: 'Steril.', accessor: (r) => r.sterilization_method },
    { header: 'Status', accessor: (r) => r.compliance_status },
  ];

  const materialCols: Column<MaterialDive>[] = [
    { header: 'Material', accessor: (r) => r.drape_material },
    { header: 'Lots', accessor: (r) => r.lots_tested },
    { header: 'Avg Flame s', accessor: (r) => r.avg_flame_spread },
    { header: 'Avg Char mm', accessor: (r) => r.avg_char_length },
    { header: 'Avg Afterflame s', accessor: (r) => r.avg_afterflame },
    { header: 'NFPA 701 %', accessor: (r) => r.nfpa701_pass_pct },
    { header: 'ASTM F1959 %', accessor: (r) => r.astm_f1959_pass_pct },
  ];

  const signoffCols: Column<SignoffRow>[] = [
    { header: 'Lot', accessor: (r) => r.drape_lot_code },
    { header: 'Manufacturer', accessor: (r) => r.drape_manufacturer },
    { header: 'Outcome', accessor: (r) => r.test_outcome },
    { header: 'Signoff', accessor: (r) => r.founder_signoff },
    { header: 'Remediation', accessor: (r) => (r.remediation_required ? 'yes' : 'no') },
    { header: 'Month', accessor: (r) => r.test_month },
  ];

  return (
    <main style={{ padding: 24, display: 'flex', flexDirection: 'column', gap: 32 }}>
      <header>
        <h1 style={{ fontSize: 26, fontWeight: 700 }}>r3000 — Surgical Drape Burn-Test & FDA Spot Verification</h1>
        <p style={{ color: '#555', marginTop: 6 }}>Monthly engineer-led NFPA 701 / ASTM F1959 burn tests & FDA UDI-DI spot audits across hospital surgical-drape supply.</p>
      </header>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Monthly Burn-Test Summary</h2>
        <DataTable rows={monthlyRows} columns={monthlyCols} emptyMessage="No monthly data" rowKey={(r, i) => String(r.test_month ?? i)} />
      </section>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Failed Lots — Recall Queue</h2>
        <DataTable rows={failedRows} columns={failedCols} emptyMessage="No failed lots" rowKey={(r, i) => String(r.drape_lot_code ?? i)} />
      </section>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Manufacturer Burn Leaderboard</h2>
        <DataTable rows={leaderboardRows} columns={leaderboardCols} emptyMessage="No manufacturer data" rowKey={(r, i) => String(r.drape_manufacturer ?? i)} />
      </section>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>FDA Audit Risk Summary</h2>
        <DataTable rows={riskRows} columns={riskCols} emptyMessage="No audit data" rowKey={(r, i) => String(r.device_category ?? i)} />
      </section>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Critical Findings — Action List</h2>
        <DataTable rows={criticalRows} columns={criticalCols} emptyMessage="No critical findings" rowKey={(r, i) => String(r.udi_di ?? i)} />
      </section>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Expiry Watch (90 days)</h2>
        <DataTable rows={expiryRows} columns={expiryCols} emptyMessage="No items expiring" rowKey={(r, i) => String(r.udi_di ?? i)} />
      </section>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Material Burn Deep Dive</h2>
        <DataTable rows={materialRows} columns={materialCols} emptyMessage="No material data" rowKey={(r, i) => String(r.drape_material ?? i)} />
      </section>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Founder Signoff Queue</h2>
        <DataTable rows={signoffRows} columns={signoffCols} emptyMessage="Queue clear" rowKey={(r, i) => String(r.drape_lot_code ?? i)} />
      </section>
    </main>
  );
}
