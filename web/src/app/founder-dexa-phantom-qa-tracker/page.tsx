import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type OutOfSpecRow = {
  reading_id: string;
  scan_date: string;
  scanner_asset_tag: string;
  scanner_model: string;
  hospital_org: string;
  measured_bmd: number;
  expected_bmd: number;
  percent_deviation: number;
  drift_direction: string;
  technologist_name: string;
};

type DriftTrendRow = {
  scanner_asset_tag: string;
  scanner_model: string;
  hospital_org: string;
  readings_30d: number;
  avg_deviation_pct: number;
  max_deviation_pct: number;
  out_of_spec_count: number;
  dominant_drift: string;
};

type CapaPipelineRow = {
  capa_status: string;
  severity: string;
  open_count: number;
  avg_downtime_hours: number;
  total_cost_rupees: number;
};

type TechRow = {
  technologist_name: string;
  dmlt_no: string | null;
  total_scans: number;
  within_tolerance: number;
  out_of_spec: number;
  warning_drift: number;
  pass_rate_pct: number;
};

type PhantomRow = {
  phantom_type: string;
  scans: number;
  avg_deviation_pct: number;
  out_of_spec: number;
  unique_serials: number;
};

type RootCauseRow = {
  root_cause_category: string;
  capa_count: number;
  avg_downtime_hours: number;
  total_cost_rupees: number;
  reportable_count: number;
};

type HospitalRow = {
  hospital_org: string;
  scanners_tracked: number;
  scans_30d: number;
  pass_rate_pct: number;
  open_capas: number;
  jcia_reportable: number;
};

type CapaEventRow = {
  capa_id: string;
  opened_at: string;
  hospital_org: string;
  capa_type: string;
  severity: string;
  capa_status: string;
  engineer_name: string | null;
  root_cause: string;
  downtime_hours: number | null;
  cost_rupees: number | null;
};

export default async function DexaPhantomQaTrackerPage() {
  const supabase = await getSupabaseServerClient();

  const [
    outOfSpecRes,
    driftTrendRes,
    capaPipelineRes,
    techScorecardRes,
    phantomBreakdownRes,
    rootCauseRes,
    hospitalComplianceRes,
    capaRecentRes,
  ] = await Promise.all([
    supabase.rpc('founder_dexa_qa_out_of_spec_r3098'),
    supabase.rpc('founder_dexa_qa_drift_trend_r3098'),
    supabase.rpc('founder_dexa_capa_pipeline_r3098'),
    supabase.rpc('founder_dexa_qa_technologist_scorecard_r3098'),
    supabase.rpc('founder_dexa_qa_phantom_breakdown_r3098'),
    supabase.rpc('founder_dexa_capa_root_cause_r3098'),
    supabase.rpc('founder_dexa_qa_hospital_compliance_r3098'),
    supabase.rpc('founder_dexa_capa_recent_events_r3098'),
  ]);

  const outOfSpec = (outOfSpecRes.data ?? []) as OutOfSpecRow[];
  const driftTrend = (driftTrendRes.data ?? []) as DriftTrendRow[];
  const capaPipeline = (capaPipelineRes.data ?? []) as CapaPipelineRow[];
  const techScorecard = (techScorecardRes.data ?? []) as TechRow[];
  const phantomBreakdown = (phantomBreakdownRes.data ?? []) as PhantomRow[];
  const rootCause = (rootCauseRes.data ?? []) as RootCauseRow[];
  const hospitalCompliance = (hospitalComplianceRes.data ?? []) as HospitalRow[];
  const capaRecent = (capaRecentRes.data ?? []) as CapaEventRow[];

  const outOfSpecCols: Column<OutOfSpecRow>[] = [
    { key: 'scan_date', header: 'Scan Date' },
    { key: 'scanner_asset_tag', header: 'Scanner Tag' },
    { key: 'scanner_model', header: 'Model' },
    { key: 'hospital_org', header: 'Hospital' },
    { key: 'measured_bmd', header: 'Measured BMD (g/cm2)' },
    { key: 'expected_bmd', header: 'Expected BMD (g/cm2)' },
    { key: 'percent_deviation', header: 'Deviation %' },
    { key: 'drift_direction', header: 'Drift' },
    { key: 'technologist_name', header: 'Technologist' },
  ];

  const driftCols: Column<DriftTrendRow>[] = [
    { key: 'scanner_asset_tag', header: 'Scanner Tag' },
    { key: 'scanner_model', header: 'Model' },
    { key: 'hospital_org', header: 'Hospital' },
    { key: 'readings_30d', header: 'Readings 30d' },
    { key: 'avg_deviation_pct', header: 'Avg Dev %' },
    { key: 'max_deviation_pct', header: 'Max Abs Dev %' },
    { key: 'out_of_spec_count', header: 'Out of Spec' },
    { key: 'dominant_drift', header: 'Dominant Drift' },
  ];

  const capaCols: Column<CapaPipelineRow>[] = [
    { key: 'severity', header: 'Severity' },
    { key: 'capa_status', header: 'Status' },
    { key: 'open_count', header: 'Count' },
    { key: 'avg_downtime_hours', header: 'Avg Downtime (hr)' },
    { key: 'total_cost_rupees', header: 'Total Cost (Rs)' },
  ];

  const techCols: Column<TechRow>[] = [
    { key: 'technologist_name', header: 'Technologist' },
    { key: 'dmlt_no', header: 'DMLT No' },
    { key: 'total_scans', header: 'Total Scans' },
    { key: 'within_tolerance', header: 'Within Tol' },
    { key: 'warning_drift', header: 'Warning' },
    { key: 'out_of_spec', header: 'Out of Spec' },
    { key: 'pass_rate_pct', header: 'Pass Rate %' },
  ];

  const phantomCols: Column<PhantomRow>[] = [
    { key: 'phantom_type', header: 'Phantom Type' },
    { key: 'scans', header: 'Scans' },
    { key: 'avg_deviation_pct', header: 'Avg Dev %' },
    { key: 'out_of_spec', header: 'Out of Spec' },
    { key: 'unique_serials', header: 'Unique Serials' },
  ];

  const rootCauseCols: Column<RootCauseRow>[] = [
    { key: 'root_cause_category', header: 'Root Cause' },
    { key: 'capa_count', header: 'CAPAs' },
    { key: 'avg_downtime_hours', header: 'Avg Downtime (hr)' },
    { key: 'total_cost_rupees', header: 'Total Cost (Rs)' },
    { key: 'reportable_count', header: 'JCIA Reportable' },
  ];

  const hospitalCols: Column<HospitalRow>[] = [
    { key: 'hospital_org', header: 'Hospital' },
    { key: 'scanners_tracked', header: 'Scanners' },
    { key: 'scans_30d', header: 'Scans 30d' },
    { key: 'pass_rate_pct', header: 'Pass Rate %' },
    { key: 'open_capas', header: 'Open CAPAs' },
    { key: 'jcia_reportable', header: 'JCIA Reportable' },
  ];

  const capaEventCols: Column<CapaEventRow>[] = [
    { key: 'opened_at', header: 'Opened' },
    { key: 'hospital_org', header: 'Hospital' },
    { key: 'capa_type', header: 'CAPA Type' },
    { key: 'severity', header: 'Severity' },
    { key: 'capa_status', header: 'Status' },
    { key: 'engineer_name', header: 'Engineer' },
    { key: 'root_cause', header: 'Root Cause' },
    { key: 'downtime_hours', header: 'Downtime (hr)' },
    { key: 'cost_rupees', header: 'Cost (Rs)' },
  ];

  return (
    <main className="p-6 space-y-8">
      <header className="space-y-1">
        <h1 className="text-2xl font-semibold">
          Customer Hospital DEXA Scanner Daily QA Phantom Tracker
        </h1>
        <p className="text-sm text-gray-600">
          Daily phantom-based bone-density QA — BMD reading vs tolerance band, drift trend,
          technologist accountability, and CAPA when out-of-spec.
        </p>
      </header>

      <section>
        <h2 className="text-lg font-medium mb-2">Out-of-Spec Readings (30d)</h2>
        <DataTable
          rows={outOfSpec}
          columns={outOfSpecCols}
          emptyMessage="No out-of-spec readings — all scanners within tolerance band"
          rowKey={(r, i) => String(r.reading_id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-medium mb-2">Drift Trend per Scanner (30d)</h2>
        <DataTable
          rows={driftTrend}
          columns={driftCols}
          emptyMessage="No drift data"
          rowKey={(r, i) => String(r.scanner_asset_tag ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-medium mb-2">CAPA Pipeline by Severity & Status</h2>
        <DataTable
          rows={capaPipeline}
          columns={capaCols}
          emptyMessage="No active CAPAs"
          rowKey={(r, i) => String(i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-medium mb-2">Technologist Scorecard</h2>
        <DataTable
          rows={techScorecard}
          columns={techCols}
          emptyMessage="No technologist data"
          rowKey={(r, i) => String(r.dmlt_no ?? r.technologist_name ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-medium mb-2">Phantom-Type Performance</h2>
        <DataTable
          rows={phantomBreakdown}
          columns={phantomCols}
          emptyMessage="No phantom data"
          rowKey={(r, i) => String(r.phantom_type ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-medium mb-2">CAPA Root-Cause Distribution</h2>
        <DataTable
          rows={rootCause}
          columns={rootCauseCols}
          emptyMessage="No CAPA root-cause data"
          rowKey={(r, i) => String(r.root_cause_category ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-medium mb-2">Hospital QA Compliance Summary</h2>
        <DataTable
          rows={hospitalCompliance}
          columns={hospitalCols}
          emptyMessage="No hospital compliance data"
          rowKey={(r, i) => String(r.hospital_org ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-medium mb-2">Recent CAPA Events</h2>
        <DataTable
          rows={capaRecent}
          columns={capaEventCols}
          emptyMessage="No recent CAPA events"
          rowKey={(r, i) => String(r.capa_id ?? i)}
        />
      </section>
    </main>
  );
}
