import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type KpiRow = { metric_name: string; metric_value: string };
type ComplianceRow = {
  compliance_status: string;
  cycle_count: number;
  unique_probes: number;
  avg_signal_quality: number | null;
  avg_bioload_cfu: number | null;
  share_of_cycles_percent: number | null;
};
type MethodRow = {
  sterilization_method: string;
  cycle_count: number;
  avg_signal_quality: number | null;
  avg_bioload_cfu: number | null;
  pass_sterile_count: number;
  fail_count: number;
  effectiveness_score: number | null;
};
type TrajectoryRow = {
  probe_serial_number: string;
  probe_manufacturer: string;
  probe_model: string;
  icu_ward: string;
  cycle_count: number;
  max_reuse_count: number;
  latest_signal_quality: number | null;
  latest_degradation: string;
  latest_compliance: string;
};
type BioloadRow = {
  bioload_test_result: string;
  cycle_count: number;
  avg_cfu: number | null;
  max_cfu: number | null;
  share_of_cycles_percent: number | null;
};
type WardRow = {
  icu_ward: string;
  cycle_count: number;
  unique_probes: number;
  major_or_non_compliant: number;
  deviation_rate_percent: number | null;
};
type QueueTierRow = {
  priority_tier: string;
  queue_count: number;
  total_replacement_cost: number | null;
  avg_replacement_cost: number | null;
  open_count: number;
  completed_count: number;
};
type FlagReasonRow = {
  flag_reason: string;
  count: number;
  total_cost: number | null;
  share_percent: number | null;
};
type ManufacturerRow = {
  probe_manufacturer: string;
  probe_count: number;
  cycle_count: number;
  avg_signal_quality: number | null;
  avg_bioload_cfu: number | null;
  deviation_rate_percent: number | null;
};

function fmtNum(v: number | null | undefined, digits = 2): string {
  if (v === null || v === undefined) return '-';
  return Number(v).toFixed(digits);
}

function fmtInr(v: number | null | undefined): string {
  if (v === null || v === undefined) return '-';
  return 'Rs ' + Number(v).toLocaleString('en-IN', { maximumFractionDigits: 0 });
}

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    kpis,
    compliance,
    method,
    trajectory,
    bioload,
    ward,
    queueTier,
    flagReason,
    manufacturer,
  ] = await Promise.all([
    supabase.rpc('r3126_headline_kpis'),
    supabase.rpc('r3126_compliance_status_rollup'),
    supabase.rpc('r3126_method_effectiveness'),
    supabase.rpc('r3126_probe_reuse_trajectory'),
    supabase.rpc('r3126_bioload_outcome_distribution'),
    supabase.rpc('r3126_ward_deviation_heatmap'),
    supabase.rpc('r3126_replacement_queue_by_tier'),
    supabase.rpc('r3126_flag_reason_breakdown'),
    supabase.rpc('r3126_manufacturer_scorecard'),
  ]);

  const kpiRows: KpiRow[] = (kpis.data ?? []) as KpiRow[];
  const complianceRows: ComplianceRow[] = (compliance.data ?? []) as ComplianceRow[];
  const methodRows: MethodRow[] = (method.data ?? []) as MethodRow[];
  const trajectoryRows: TrajectoryRow[] = (trajectory.data ?? []) as TrajectoryRow[];
  const bioloadRows: BioloadRow[] = (bioload.data ?? []) as BioloadRow[];
  const wardRows: WardRow[] = (ward.data ?? []) as WardRow[];
  const queueTierRows: QueueTierRow[] = (queueTier.data ?? []) as QueueTierRow[];
  const flagReasonRows: FlagReasonRow[] = (flagReason.data ?? []) as FlagReasonRow[];
  const manufacturerRows: ManufacturerRow[] = (manufacturer.data ?? []) as ManufacturerRow[];

  const kpiColumns: Column<KpiRow>[] = [
    { key: 'metric_name', header: 'Metric', render: (r) => r.metric_name.replace(/_/g, ' ') },
    { key: 'metric_value', header: 'Value', render: (r) => r.metric_value },
  ];

  const complianceColumns: Column<ComplianceRow>[] = [
    { key: 'compliance_status', header: 'Compliance status', render: (r) => r.compliance_status },
    { key: 'cycle_count', header: 'Cycles', render: (r) => String(r.cycle_count) },
    { key: 'unique_probes', header: 'Probes', render: (r) => String(r.unique_probes) },
    { key: 'avg_signal_quality', header: 'Avg SQI %', render: (r) => fmtNum(r.avg_signal_quality) },
    { key: 'avg_bioload_cfu', header: 'Avg CFU/ml', render: (r) => fmtNum(r.avg_bioload_cfu) },
    { key: 'share_of_cycles_percent', header: 'Share %', render: (r) => fmtNum(r.share_of_cycles_percent) },
  ];

  const methodColumns: Column<MethodRow>[] = [
    { key: 'sterilization_method', header: 'Method', render: (r) => r.sterilization_method.replace(/_/g, ' ') },
    { key: 'cycle_count', header: 'Cycles', render: (r) => String(r.cycle_count) },
    { key: 'avg_signal_quality', header: 'Avg SQI %', render: (r) => fmtNum(r.avg_signal_quality) },
    { key: 'avg_bioload_cfu', header: 'Avg CFU/ml', render: (r) => fmtNum(r.avg_bioload_cfu) },
    { key: 'pass_sterile_count', header: 'Pass sterile', render: (r) => String(r.pass_sterile_count) },
    { key: 'fail_count', header: 'Fails', render: (r) => String(r.fail_count) },
    { key: 'effectiveness_score', header: 'Effectiveness %', render: (r) => fmtNum(r.effectiveness_score) },
  ];

  const trajectoryColumns: Column<TrajectoryRow>[] = [
    { key: 'probe_serial_number', header: 'Probe SN', render: (r) => r.probe_serial_number },
    { key: 'probe_manufacturer', header: 'Mfr', render: (r) => r.probe_manufacturer },
    { key: 'probe_model', header: 'Model', render: (r) => r.probe_model },
    { key: 'icu_ward', header: 'Ward', render: (r) => r.icu_ward },
    { key: 'cycle_count', header: 'Cycles', render: (r) => String(r.cycle_count) },
    { key: 'max_reuse_count', header: 'Reuse #', render: (r) => String(r.max_reuse_count) },
    { key: 'latest_signal_quality', header: 'Latest SQI %', render: (r) => fmtNum(r.latest_signal_quality) },
    { key: 'latest_degradation', header: 'Degradation', render: (r) => r.latest_degradation },
    { key: 'latest_compliance', header: 'Compliance', render: (r) => r.latest_compliance },
  ];

  const bioloadColumns: Column<BioloadRow>[] = [
    { key: 'bioload_test_result', header: 'Bioload result', render: (r) => r.bioload_test_result.replace(/_/g, ' ') },
    { key: 'cycle_count', header: 'Cycles', render: (r) => String(r.cycle_count) },
    { key: 'avg_cfu', header: 'Avg CFU/ml', render: (r) => fmtNum(r.avg_cfu) },
    { key: 'max_cfu', header: 'Max CFU/ml', render: (r) => fmtNum(r.max_cfu) },
    { key: 'share_of_cycles_percent', header: 'Share %', render: (r) => fmtNum(r.share_of_cycles_percent) },
  ];

  const wardColumns: Column<WardRow>[] = [
    { key: 'icu_ward', header: 'Ward', render: (r) => r.icu_ward },
    { key: 'cycle_count', header: 'Cycles', render: (r) => String(r.cycle_count) },
    { key: 'unique_probes', header: 'Probes', render: (r) => String(r.unique_probes) },
    { key: 'major_or_non_compliant', header: 'Major/Non-compliant', render: (r) => String(r.major_or_non_compliant) },
    { key: 'deviation_rate_percent', header: 'Deviation rate %', render: (r) => fmtNum(r.deviation_rate_percent) },
  ];

  const queueTierColumns: Column<QueueTierRow>[] = [
    { key: 'priority_tier', header: 'Tier', render: (r) => r.priority_tier },
    { key: 'queue_count', header: 'Queue', render: (r) => String(r.queue_count) },
    { key: 'total_replacement_cost', header: 'Total cost', render: (r) => fmtInr(r.total_replacement_cost) },
    { key: 'avg_replacement_cost', header: 'Avg cost', render: (r) => fmtInr(r.avg_replacement_cost) },
    { key: 'open_count', header: 'Open', render: (r) => String(r.open_count) },
    { key: 'completed_count', header: 'Completed', render: (r) => String(r.completed_count) },
  ];

  const flagReasonColumns: Column<FlagReasonRow>[] = [
    { key: 'flag_reason', header: 'Flag reason', render: (r) => r.flag_reason.replace(/_/g, ' ') },
    { key: 'count', header: 'Count', render: (r) => String(r.count) },
    { key: 'total_cost', header: 'Total cost', render: (r) => fmtInr(r.total_cost) },
    { key: 'share_percent', header: 'Share %', render: (r) => fmtNum(r.share_percent) },
  ];

  const manufacturerColumns: Column<ManufacturerRow>[] = [
    { key: 'probe_manufacturer', header: 'Manufacturer', render: (r) => r.probe_manufacturer },
    { key: 'probe_count', header: 'Probes', render: (r) => String(r.probe_count) },
    { key: 'cycle_count', header: 'Cycles', render: (r) => String(r.cycle_count) },
    { key: 'avg_signal_quality', header: 'Avg SQI %', render: (r) => fmtNum(r.avg_signal_quality) },
    { key: 'avg_bioload_cfu', header: 'Avg CFU/ml', render: (r) => fmtNum(r.avg_bioload_cfu) },
    { key: 'deviation_rate_percent', header: 'Deviation rate %', render: (r) => fmtNum(r.deviation_rate_percent) },
  ];

  return (
    <main className="mx-auto max-w-7xl px-4 py-8 space-y-10">
      <header className="space-y-2">
        <h1 className="text-2xl font-semibold">
          ICU Pulse Oximeter Probe Sterilization Compliance Audit (r3126)
        </h1>
        <p className="text-sm text-slate-600">
          Quarterly audit of pulse-ox probe cable reuse: probe serial & reuse count & sterilization
          method & signal degradation & biological-load test & replace queue.
        </p>
      </header>

      <section className="space-y-3">
        <h2 className="text-lg font-medium">Headline KPIs</h2>
        <DataTable
          rows={kpiRows}
          columns={kpiColumns}
          emptyMessage="No KPI data yet."
          rowKey={(r, i) => String(r.metric_name ?? i)}
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-medium">Compliance status rollup</h2>
        <DataTable
          rows={complianceRows}
          columns={complianceColumns}
          emptyMessage="No cycles recorded."
          rowKey={(r, i) => String(r.compliance_status ?? i)}
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-medium">Sterilization method effectiveness</h2>
        <DataTable
          rows={methodRows}
          columns={methodColumns}
          emptyMessage="No method data."
          rowKey={(r, i) => String(r.sterilization_method ?? i)}
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-medium">Per-probe reuse trajectory</h2>
        <DataTable
          rows={trajectoryRows}
          columns={trajectoryColumns}
          emptyMessage="No probes tracked."
          rowKey={(r, i) => String(r.probe_serial_number ?? i)}
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-medium">Biological-load outcome distribution</h2>
        <DataTable
          rows={bioloadRows}
          columns={bioloadColumns}
          emptyMessage="No bioload tests recorded."
          rowKey={(r, i) => String(r.bioload_test_result ?? i)}
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-medium">ICU ward deviation heatmap</h2>
        <DataTable
          rows={wardRows}
          columns={wardColumns}
          emptyMessage="No ward data."
          rowKey={(r, i) => String(r.icu_ward ?? i)}
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-medium">Replacement queue by priority tier</h2>
        <DataTable
          rows={queueTierRows}
          columns={queueTierColumns}
          emptyMessage="Replacement queue empty."
          rowKey={(r, i) => String(r.priority_tier ?? i)}
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-medium">Flag reason breakdown</h2>
        <DataTable
          rows={flagReasonRows}
          columns={flagReasonColumns}
          emptyMessage="No flagged probes."
          rowKey={(r, i) => String(r.flag_reason ?? i)}
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-medium">Manufacturer scorecard</h2>
        <DataTable
          rows={manufacturerRows}
          columns={manufacturerColumns}
          emptyMessage="No manufacturer data."
          rowKey={(r, i) => String(r.probe_manufacturer ?? i)}
        />
      </section>
    </main>
  );
}