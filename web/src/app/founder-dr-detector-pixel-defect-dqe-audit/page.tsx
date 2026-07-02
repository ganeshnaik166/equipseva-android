import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type FleetRow = {
  modality: string;
  panel_count: number;
  pass_count: number;
  watch_count: number;
  fail_or_replace: number;
  avg_dead_pixels: number;
  avg_dqe_2lp: number;
  avg_mtf_2lp: number;
  total_replacement_lakhs: number;
};

type DefectMapRow = {
  panel_serial: string;
  panel_make: string;
  modality: string;
  total_dead_pixels: number;
  cluster_defects: number;
  line_defects: number;
  ghost_image_severity: string;
  defect_score: number;
  risk_band: string;
};

type DqeRow = {
  panel_serial: string;
  panel_model: string;
  pixel_pitch_um: number;
  dqe_at_1lp_mm: number;
  dqe_at_2lp_mm: number;
  mtf_at_2lp_mm: number;
  limiting_resolution_lp_mm: number;
  spec_compliance: string;
};

type GhostRow = {
  ghost_image_severity: string;
  panel_count: number;
  modalities_affected: number;
  avg_uniformity: number;
  avg_age_years: number;
  ghost_share_pct: number;
};

type CostRow = {
  audit_verdict: string;
  panel_count: number;
  amc_covered_count: number;
  out_of_pocket_count: number;
  total_replacement_lakhs: number;
  avg_replacement_lakhs: number;
  exposure_lakhs: number;
};

type CapaRow = {
  event_type: string;
  event_count: number;
  successful_count: number;
  failed_or_rejected: number;
  total_spend_rupees: number;
  total_downtime_hours: number;
  total_revenue_loss: number;
  avg_vendor_response_hours: number;
};

type DefectClassRow = {
  defect_class: string;
  severity: string;
  event_count: number;
  total_studies_lost: number;
  total_revenue_loss: number;
  avg_downtime_hours: number;
};

type CalibRow = {
  calibration_status: string;
  capa_status: string;
  panel_count: number;
  total_dead_pixels_sum: number;
  total_remediation_window_days: number;
  exposure_lakhs: number;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    fleet,
    defectMap,
    dqe,
    ghost,
    cost,
    capa,
    defectClass,
    calib,
  ] = await Promise.all([
    supabase.rpc('dr_detector_audit_fleet_summary_r3132'),
    supabase.rpc('dr_detector_pixel_defect_severity_map_r3132'),
    supabase.rpc('dr_detector_dqe_mtf_resolution_r3132'),
    supabase.rpc('dr_detector_ghost_image_audit_r3132'),
    supabase.rpc('dr_detector_replacement_cost_funnel_r3132'),
    supabase.rpc('dr_detector_capa_event_rollup_r3132'),
    supabase.rpc('dr_detector_defect_class_severity_r3132'),
    supabase.rpc('dr_detector_calibration_capa_status_r3132'),
  ]);

  const fleetRows: FleetRow[] = (fleet.data ?? []) as FleetRow[];
  const defectMapRows: DefectMapRow[] = (defectMap.data ?? []) as DefectMapRow[];
  const dqeRows: DqeRow[] = (dqe.data ?? []) as DqeRow[];
  const ghostRows: GhostRow[] = (ghost.data ?? []) as GhostRow[];
  const costRows: CostRow[] = (cost.data ?? []) as CostRow[];
  const capaRows: CapaRow[] = (capa.data ?? []) as CapaRow[];
  const defectClassRows: DefectClassRow[] = (defectClass.data ?? []) as DefectClassRow[];
  const calibRows: CalibRow[] = (calib.data ?? []) as CalibRow[];

  const fleetCols: Column<FleetRow>[] = [
    { key: 'modality', header: 'Modality', render: (r) => r.modality },
    { key: 'panel_count', header: 'Panels', render: (r) => r.panel_count },
    { key: 'pass_count', header: 'Pass', render: (r) => r.pass_count },
    { key: 'watch_count', header: 'Watch', render: (r) => r.watch_count },
    { key: 'fail_or_replace', header: 'Fail/Replace', render: (r) => r.fail_or_replace },
    { key: 'avg_dead_pixels', header: 'Avg Dead Px', render: (r) => r.avg_dead_pixels },
    { key: 'avg_dqe_2lp', header: 'Avg DQE 2lp/mm', render: (r) => r.avg_dqe_2lp },
    { key: 'avg_mtf_2lp', header: 'Avg MTF 2lp/mm', render: (r) => r.avg_mtf_2lp },
    { key: 'total_replacement_lakhs', header: 'Replace Cost (L)', render: (r) => r.total_replacement_lakhs },
  ];

  const defectMapCols: Column<DefectMapRow>[] = [
    { key: 'panel_serial', header: 'Serial', render: (r) => r.panel_serial },
    { key: 'panel_make', header: 'Make', render: (r) => r.panel_make },
    { key: 'modality', header: 'Modality', render: (r) => r.modality },
    { key: 'total_dead_pixels', header: 'Dead Px', render: (r) => r.total_dead_pixels },
    { key: 'cluster_defects', header: 'Clusters', render: (r) => r.cluster_defects },
    { key: 'line_defects', header: 'Lines', render: (r) => r.line_defects },
    { key: 'ghost_image_severity', header: 'Ghost', render: (r) => r.ghost_image_severity },
    { key: 'defect_score', header: 'Defect Score', render: (r) => r.defect_score },
    { key: 'risk_band', header: 'Risk Band', render: (r) => r.risk_band },
  ];

  const dqeCols: Column<DqeRow>[] = [
    { key: 'panel_serial', header: 'Serial', render: (r) => r.panel_serial },
    { key: 'panel_model', header: 'Model', render: (r) => r.panel_model },
    { key: 'pixel_pitch_um', header: 'Pitch (um)', render: (r) => r.pixel_pitch_um },
    { key: 'dqe_at_1lp_mm', header: 'DQE 1lp/mm', render: (r) => r.dqe_at_1lp_mm },
    { key: 'dqe_at_2lp_mm', header: 'DQE 2lp/mm', render: (r) => r.dqe_at_2lp_mm },
    { key: 'mtf_at_2lp_mm', header: 'MTF 2lp/mm', render: (r) => r.mtf_at_2lp_mm },
    { key: 'limiting_resolution_lp_mm', header: 'Lim Res (lp/mm)', render: (r) => r.limiting_resolution_lp_mm },
    { key: 'spec_compliance', header: 'Spec', render: (r) => r.spec_compliance },
  ];

  const ghostCols: Column<GhostRow>[] = [
    { key: 'ghost_image_severity', header: 'Ghost Severity', render: (r) => r.ghost_image_severity },
    { key: 'panel_count', header: 'Panels', render: (r) => r.panel_count },
    { key: 'modalities_affected', header: 'Modalities', render: (r) => r.modalities_affected },
    { key: 'avg_uniformity', header: 'Avg Uniformity %', render: (r) => r.avg_uniformity },
    { key: 'avg_age_years', header: 'Avg Age (yrs)', render: (r) => r.avg_age_years },
    { key: 'ghost_share_pct', header: 'Share %', render: (r) => r.ghost_share_pct },
  ];

  const costCols: Column<CostRow>[] = [
    { key: 'audit_verdict', header: 'Verdict', render: (r) => r.audit_verdict },
    { key: 'panel_count', header: 'Panels', render: (r) => r.panel_count },
    { key: 'amc_covered_count', header: 'AMC Covered', render: (r) => r.amc_covered_count },
    { key: 'out_of_pocket_count', header: 'Out of Pocket', render: (r) => r.out_of_pocket_count },
    { key: 'total_replacement_lakhs', header: 'Total (L)', render: (r) => r.total_replacement_lakhs },
    { key: 'avg_replacement_lakhs', header: 'Avg (L)', render: (r) => r.avg_replacement_lakhs },
    { key: 'exposure_lakhs', header: 'Hospital Exposure (L)', render: (r) => r.exposure_lakhs },
  ];

  const capaCols: Column<CapaRow>[] = [
    { key: 'event_type', header: 'CAPA Event', render: (r) => r.event_type },
    { key: 'event_count', header: 'Count', render: (r) => r.event_count },
    { key: 'successful_count', header: 'Success', render: (r) => r.successful_count },
    { key: 'failed_or_rejected', header: 'Failed/Rejected', render: (r) => r.failed_or_rejected },
    { key: 'total_spend_rupees', header: 'Spend (Rs)', render: (r) => r.total_spend_rupees },
    { key: 'total_downtime_hours', header: 'Downtime (h)', render: (r) => r.total_downtime_hours },
    { key: 'total_revenue_loss', header: 'Revenue Loss (Rs)', render: (r) => r.total_revenue_loss },
    { key: 'avg_vendor_response_hours', header: 'Avg Vendor SLA (h)', render: (r) => r.avg_vendor_response_hours },
  ];

  const defectClassCols: Column<DefectClassRow>[] = [
    { key: 'defect_class', header: 'Defect Class', render: (r) => r.defect_class },
    { key: 'severity', header: 'Severity', render: (r) => r.severity },
    { key: 'event_count', header: 'Events', render: (r) => r.event_count },
    { key: 'total_studies_lost', header: 'Studies Lost', render: (r) => r.total_studies_lost },
    { key: 'total_revenue_loss', header: 'Revenue Loss (Rs)', render: (r) => r.total_revenue_loss },
    { key: 'avg_downtime_hours', header: 'Avg Downtime (h)', render: (r) => r.avg_downtime_hours },
  ];

  const calibCols: Column<CalibRow>[] = [
    { key: 'calibration_status', header: 'Calibration', render: (r) => r.calibration_status },
    { key: 'capa_status', header: 'CAPA Status', render: (r) => r.capa_status },
    { key: 'panel_count', header: 'Panels', render: (r) => r.panel_count },
    { key: 'total_dead_pixels_sum', header: 'Sum Dead Px', render: (r) => r.total_dead_pixels_sum },
    { key: 'total_remediation_window_days', header: 'Remediation Days', render: (r) => r.total_remediation_window_days },
    { key: 'exposure_lakhs', header: 'Exposure (L)', render: (r) => r.exposure_lakhs },
  ];

  return (
    <main className="mx-auto max-w-7xl space-y-8 p-6">
      <header className="space-y-2">
        <p className="text-xs uppercase tracking-wider text-[var(--color-muted)]">Round 3132 · Founder Console</p>
        <h1 className="text-2xl font-semibold">DR Detector Panel Pixel Defect & DQE Performance Audit</h1>
        <p className="text-sm text-[var(--color-muted)]">
          Hospital radiology digital detector panels graded across pixel defect map, DQE, MTF, limiting resolution, ghost image,
          replacement cost exposure, and CAPA closure.
        </p>
      </header>

      <section className="space-y-3">
        <h2 className="text-lg font-semibold">Fleet Summary by Modality</h2>
        <DataTable
          rows={fleetRows}
          columns={fleetCols}
          emptyMessage="No DR panel audits on record."
          rowKey={(r, i) => String(r.modality ?? i)}
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-semibold">Pixel Defect Severity Map</h2>
        <DataTable
          rows={defectMapRows}
          columns={defectMapCols}
          emptyMessage="No defect map rows."
          rowKey={(r, i) => String(r.panel_serial ?? i)}
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-semibold">DQE · MTF · Limiting Resolution</h2>
        <DataTable
          rows={dqeRows}
          columns={dqeCols}
          emptyMessage="No DQE rows."
          rowKey={(r, i) => String(r.panel_serial ?? i)}
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-semibold">Ghost Image Audit</h2>
        <DataTable
          rows={ghostRows}
          columns={ghostCols}
          emptyMessage="No ghost image data."
          rowKey={(r, i) => String(r.ghost_image_severity ?? i)}
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-semibold">Replacement Cost Funnel by Verdict</h2>
        <DataTable
          rows={costRows}
          columns={costCols}
          emptyMessage="No replacement cost rows."
          rowKey={(r, i) => String(r.audit_verdict ?? i)}
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-semibold">CAPA Event Rollup</h2>
        <DataTable
          rows={capaRows}
          columns={capaCols}
          emptyMessage="No CAPA events."
          rowKey={(r, i) => String(r.event_type ?? i)}
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-semibold">Defect Class × Severity</h2>
        <DataTable
          rows={defectClassRows}
          columns={defectClassCols}
          emptyMessage="No defect class rows."
          rowKey={(r, i) => String(r.defect_class + '|' + r.severity + '|' + i)}
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-semibold">Calibration & CAPA Status Cross-Tab</h2>
        <DataTable
          rows={calibRows}
          columns={calibCols}
          emptyMessage="No calibration cross-tab rows."
          rowKey={(r, i) => String(r.calibration_status + '|' + r.capa_status + '|' + i)}
        />
      </section>
    </main>
  );
}
