import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type QuarterlyRow = {
  calibration_quarter: string;
  total_sessions: number;
  pass_count: number;
  conditional_pass_count: number;
  fail_count: number;
  withdrawn_count: number;
  pass_rate_pct: number | null;
};

type WardRow = {
  ward_name: string;
  sessions: number;
  fails: number;
  withdrawn: number;
  avg_spo2_dev: number | null;
  avg_nibp_dev: number | null;
};

type VendorRow = {
  monitor_make: string;
  monitors_tested: number;
  fail_rate_pct: number | null;
  avg_spo2_dev: number | null;
  worst_spo2_dev: number | null;
  avg_nibp_dev: number | null;
  worst_nibp_dev: number | null;
};

type ProbeRow = { probe_cable_health: string; count: number; share_pct: number | null };
type NabhRow = { nabh_clause_ref: string; sessions: number; non_pass: number; open_capa: number };
type CapaPipeRow = {
  capa_status: string;
  count: number;
  est_cost_rupees: number;
  actual_cost_rupees: number;
  avg_days_open: number | null;
};
type RootCauseRow = { root_cause: string; severity: string; count: number; total_cost_rupees: number };
type OverdueRow = {
  capa_id: string;
  monitor_asset_tag: string;
  ward_name: string;
  capa_kind: string;
  severity: string;
  capa_status: string;
  days_overdue: number;
  patient_safety_impact: string;
  estimated_cost_rupees: number;
};
type SafetyRow = { patient_safety_impact: string; count: number; open_count: number; closed_count: number };

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [qSummary, wardHeat, vendorDev, probeHealth, nabhRoll, capaPipe, rootMatrix, overdue, safety] =
    await Promise.all([
      supabase.rpc('r3108_quarterly_summary'),
      supabase.rpc('r3108_ward_heatmap'),
      supabase.rpc('r3108_vendor_deviation'),
      supabase.rpc('r3108_probe_cable_health'),
      supabase.rpc('r3108_nabh_clause_rollup'),
      supabase.rpc('r3108_capa_pipeline'),
      supabase.rpc('r3108_root_cause_matrix'),
      supabase.rpc('r3108_overdue_capa_watch'),
      supabase.rpc('r3108_patient_safety_impact'),
    ]);

  const quarterlyRows = (qSummary.data ?? []) as QuarterlyRow[];
  const wardRows = (wardHeat.data ?? []) as WardRow[];
  const vendorRows = (vendorDev.data ?? []) as VendorRow[];
  const probeRows = (probeHealth.data ?? []) as ProbeRow[];
  const nabhRows = (nabhRoll.data ?? []) as NabhRow[];
  const capaRows = (capaPipe.data ?? []) as CapaPipeRow[];
  const rootRows = (rootMatrix.data ?? []) as RootCauseRow[];
  const overdueRows = (overdue.data ?? []) as OverdueRow[];
  const safetyRows = (safety.data ?? []) as SafetyRow[];

  const quarterlyCols: Column<QuarterlyRow>[] = [
    { key: 'calibration_quarter', header: 'Quarter' },
    { key: 'total_sessions', header: 'Sessions' },
    { key: 'pass_count', header: 'Pass' },
    { key: 'conditional_pass_count', header: 'Conditional' },
    { key: 'fail_count', header: 'Fail' },
    { key: 'withdrawn_count', header: 'Withdrawn' },
    {
      key: 'pass_rate_pct',
      header: 'Pass rate %',
      render: (r) => (r.pass_rate_pct == null ? '-' : `${r.pass_rate_pct}%`),
    },
  ];

  const wardCols: Column<WardRow>[] = [
    { key: 'ward_name', header: 'Ward' },
    { key: 'sessions', header: 'Sessions' },
    { key: 'fails', header: 'Fails' },
    { key: 'withdrawn', header: 'Withdrawn' },
    {
      key: 'avg_spo2_dev',
      header: 'Avg SpO2 dev %',
      render: (r) => (r.avg_spo2_dev == null ? '-' : `${r.avg_spo2_dev}%`),
    },
    {
      key: 'avg_nibp_dev',
      header: 'Avg NIBP dev mmHg',
      render: (r) => (r.avg_nibp_dev == null ? '-' : `${r.avg_nibp_dev}`),
    },
  ];

  const vendorCols: Column<VendorRow>[] = [
    { key: 'monitor_make', header: 'Make' },
    { key: 'monitors_tested', header: 'Tested' },
    {
      key: 'fail_rate_pct',
      header: 'Fail rate %',
      render: (r) => (r.fail_rate_pct == null ? '-' : `${r.fail_rate_pct}%`),
    },
    { key: 'avg_spo2_dev', header: 'Avg SpO2 dev %' },
    { key: 'worst_spo2_dev', header: 'Worst SpO2 dev %' },
    { key: 'avg_nibp_dev', header: 'Avg NIBP dev mmHg' },
    { key: 'worst_nibp_dev', header: 'Worst NIBP dev mmHg' },
  ];

  const probeCols: Column<ProbeRow>[] = [
    { key: 'probe_cable_health', header: 'Probe / cable health' },
    { key: 'count', header: 'Count' },
    {
      key: 'share_pct',
      header: 'Share %',
      render: (r) => (r.share_pct == null ? '-' : `${r.share_pct}%`),
    },
  ];

  const nabhCols: Column<NabhRow>[] = [
    { key: 'nabh_clause_ref', header: 'NABH clause' },
    { key: 'sessions', header: 'Sessions' },
    { key: 'non_pass', header: 'Non-pass' },
    { key: 'open_capa', header: 'Open CAPA' },
  ];

  const capaCols: Column<CapaPipeRow>[] = [
    { key: 'capa_status', header: 'CAPA status' },
    { key: 'count', header: 'Count' },
    {
      key: 'est_cost_rupees',
      header: 'Est cost',
      render: (r) => `Rs ${r.est_cost_rupees.toLocaleString('en-IN')}`,
    },
    {
      key: 'actual_cost_rupees',
      header: 'Actual cost',
      render: (r) => `Rs ${r.actual_cost_rupees.toLocaleString('en-IN')}`,
    },
    {
      key: 'avg_days_open',
      header: 'Avg days open',
      render: (r) => (r.avg_days_open == null ? '-' : `${r.avg_days_open}`),
    },
  ];

  const rootCols: Column<RootCauseRow>[] = [
    { key: 'root_cause', header: 'Root cause' },
    { key: 'severity', header: 'Severity' },
    { key: 'count', header: 'Count' },
    {
      key: 'total_cost_rupees',
      header: 'Total cost',
      render: (r) => `Rs ${r.total_cost_rupees.toLocaleString('en-IN')}`,
    },
  ];

  const overdueCols: Column<OverdueRow>[] = [
    { key: 'monitor_asset_tag', header: 'Asset tag' },
    { key: 'ward_name', header: 'Ward' },
    { key: 'capa_kind', header: 'CAPA kind' },
    { key: 'severity', header: 'Severity' },
    { key: 'capa_status', header: 'Status' },
    {
      key: 'days_overdue',
      header: 'Days overdue',
      render: (r) => (r.days_overdue > 0 ? `${r.days_overdue}d` : 'on time'),
    },
    { key: 'patient_safety_impact', header: 'Safety impact' },
    {
      key: 'estimated_cost_rupees',
      header: 'Est cost',
      render: (r) => `Rs ${r.estimated_cost_rupees.toLocaleString('en-IN')}`,
    },
  ];

  const safetyCols: Column<SafetyRow>[] = [
    { key: 'patient_safety_impact', header: 'Patient safety impact' },
    { key: 'count', header: 'Total' },
    { key: 'open_count', header: 'Still open' },
    { key: 'closed_count', header: 'Closed' },
  ];

  return (
    <main className="mx-auto max-w-7xl space-y-10 p-6">
      <header>
        <h1 className="text-2xl font-semibold">Patient-Monitor Calibration Compliance Audit</h1>
        <p className="mt-1 text-sm text-gray-600">
          Round 3108 — Quarterly SpO2 simulator deviation, NIBP cuff accuracy, ECG calibration,
          probe & cable health, and CAPA pipeline across hospital wards.
        </p>
      </header>

      <section>
        <h2 className="mb-3 text-lg font-medium">Quarterly summary</h2>
        <DataTable
          rows={quarterlyRows}
          columns={quarterlyCols}
          emptyMessage="No calibration sessions yet."
          rowKey={(r, i) => String((r as QuarterlyRow).calibration_quarter ?? i)}
        />
      </section>

      <section>
        <h2 className="mb-3 text-lg font-medium">Ward heatmap (fails & deviation)</h2>
        <DataTable
          rows={wardRows}
          columns={wardCols}
          emptyMessage="No ward rollup yet."
          rowKey={(r, i) => String((r as WardRow).ward_name ?? i)}
        />
      </section>

      <section>
        <h2 className="mb-3 text-lg font-medium">Vendor (make) deviation</h2>
        <DataTable
          rows={vendorRows}
          columns={vendorCols}
          emptyMessage="No vendor data."
          rowKey={(r, i) => String((r as VendorRow).monitor_make ?? i)}
        />
      </section>

      <section>
        <h2 className="mb-3 text-lg font-medium">Probe & cable health distribution</h2>
        <DataTable
          rows={probeRows}
          columns={probeCols}
          emptyMessage="No probe data."
          rowKey={(r, i) => String((r as ProbeRow).probe_cable_health ?? i)}
        />
      </section>

      <section>
        <h2 className="mb-3 text-lg font-medium">NABH clause rollup</h2>
        <DataTable
          rows={nabhRows}
          columns={nabhCols}
          emptyMessage="No NABH rollup."
          rowKey={(r, i) => String((r as NabhRow).nabh_clause_ref ?? i)}
        />
      </section>

      <section>
        <h2 className="mb-3 text-lg font-medium">CAPA pipeline</h2>
        <DataTable
          rows={capaRows}
          columns={capaCols}
          emptyMessage="No CAPA in flight."
          rowKey={(r, i) => String((r as CapaPipeRow).capa_status ?? i)}
        />
      </section>

      <section>
        <h2 className="mb-3 text-lg font-medium">Root cause × severity matrix</h2>
        <DataTable
          rows={rootRows}
          columns={rootCols}
          emptyMessage="No root-cause data."
          rowKey={(r, i) => `${(r as RootCauseRow).root_cause}-${(r as RootCauseRow).severity}-${i}`}
        />
      </section>

      <section>
        <h2 className="mb-3 text-lg font-medium">Overdue CAPA watchlist</h2>
        <DataTable
          rows={overdueRows}
          columns={overdueCols}
          emptyMessage="No overdue CAPA — clean."
          rowKey={(r, i) => String((r as OverdueRow).capa_id ?? i)}
        />
      </section>

      <section>
        <h2 className="mb-3 text-lg font-medium">Patient safety impact distribution</h2>
        <DataTable
          rows={safetyRows}
          columns={safetyCols}
          emptyMessage="No safety-impact data."
          rowKey={(r, i) => String((r as SafetyRow).patient_safety_impact ?? i)}
        />
      </section>
    </main>
  );
}
