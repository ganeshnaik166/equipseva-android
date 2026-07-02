import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type SiteSummary = {
  hospital_site_name: string;
  runs_total: number;
  runs_today: number;
  pct_within_tolerance: number | null;
  pct_action_level: number | null;
  pct_suspend_or_down: number | null;
  worst_output_drift_percent: number | null;
  patients_held_today: number;
};

type EnergyDrift = {
  energy_mode: string;
  runs_count: number;
  avg_output_drift_percent: number | null;
  max_output_drift_percent: number | null;
  avg_energy_constancy_percent: number | null;
  picket_fence_failure_rate_percent: number | null;
};

type OutOfTolerance = {
  hospital_site_name: string;
  linac_serial: string;
  linac_make_model: string;
  energy_mode: string;
  output_drift_percent: number;
  tg142_status: string;
  drift_classification: string;
  patient_treatment_held: boolean;
  patients_affected_count: number;
};

type CapaBacklog = {
  severity: string;
  open_count: number;
  in_progress_count: number;
  awaiting_part_count: number;
  vendor_escalated_count: number;
  closed_count: number;
  avg_hours_to_close: number | null;
};

type RootCause = {
  root_cause_class: string;
  capa_count: number;
  critical_or_clinical_count: number;
  patient_safety_events: number;
  avg_hours_to_close: number | null;
};

type MlcIso = {
  hospital_site_name: string;
  runs_count: number;
  avg_mlc_max_leaf_position_error_mm: number | null;
  worst_mlc_max_leaf_position_error_mm: number | null;
  picket_fence_failures: number;
  worst_isocenter_walkout_mm: number | null;
  worst_laser_alignment_mm: number | null;
  worst_odi_accuracy_mm: number | null;
};

type BeamProfile = {
  energy_mode: string;
  runs_count: number;
  worst_inline_symmetry_percent: number | null;
  worst_crossline_symmetry_percent: number | null;
  worst_inline_flatness_percent: number | null;
  worst_crossline_flatness_percent: number | null;
  beam_profile_skew_capa_count: number;
};

type AerbEvent = {
  capa_code: string;
  hospital_site_name: string;
  linac_serial: string;
  severity: string;
  capa_status: string;
  patient_safety_event: boolean;
  aerb_notification_required: boolean;
  aerb_notified_at: string | null;
  trigger_parameter: string;
  measured_value: number;
  tolerance_limit: number;
};

type EnvCorr = {
  hospital_site_name: string;
  avg_temperature_c: number | null;
  max_temperature_c: number | null;
  avg_humidity_percent: number | null;
  max_humidity_percent: number | null;
  high_temp_runs: number;
  high_humidity_runs: number;
  high_temp_action_level_overlap: number;
};

function fmt(v: number | null | undefined, digits = 2): string {
  if (v === null || v === undefined) return '-';
  return Number(v).toFixed(digits);
}

export default async function FounderLinacTg142DailyQaPage() {
  const sb = await getSupabaseServerClient();

  const [
    siteSummary,
    energyDrift,
    outOfTol,
    capaBacklog,
    rootCause,
    mlcIso,
    beamProfile,
    aerb,
    envCorr,
  ] = await Promise.all([
    sb.rpc('fn_r3112_linac_site_daily_summary'),
    sb.rpc('fn_r3112_linac_energy_mode_drift'),
    sb.rpc('fn_r3112_linac_out_of_tolerance_today'),
    sb.rpc('fn_r3112_linac_capa_backlog'),
    sb.rpc('fn_r3112_linac_root_cause_rollup'),
    sb.rpc('fn_r3112_linac_mlc_isocenter_rollup'),
    sb.rpc('fn_r3112_linac_beam_profile_rollup'),
    sb.rpc('fn_r3112_linac_aerb_notifiable'),
    sb.rpc('fn_r3112_linac_environmental_correlation'),
  ]);

  const siteRows = (siteSummary.data ?? []) as SiteSummary[];
  const energyRows = (energyDrift.data ?? []) as EnergyDrift[];
  const ootRows = (outOfTol.data ?? []) as OutOfTolerance[];
  const capaRows = (capaBacklog.data ?? []) as CapaBacklog[];
  const rootRows = (rootCause.data ?? []) as RootCause[];
  const mlcRows = (mlcIso.data ?? []) as MlcIso[];
  const beamRows = (beamProfile.data ?? []) as BeamProfile[];
  const aerbRows = (aerb.data ?? []) as AerbEvent[];
  const envRows = (envCorr.data ?? []) as EnvCorr[];

  const siteCols: Column<SiteSummary>[] = [
    { key: 'hospital_site_name', header: 'Cancer Centre' },
    { key: 'runs_total', header: 'Runs (all)' },
    { key: 'runs_today', header: 'Runs today' },
    { key: 'pct_within_tolerance', header: '% within tol', render: (r) => fmt(r.pct_within_tolerance, 1) },
    { key: 'pct_action_level', header: '% action lvl', render: (r) => fmt(r.pct_action_level, 1) },
    { key: 'pct_suspend_or_down', header: '% suspend/down', render: (r) => fmt(r.pct_suspend_or_down, 1) },
    { key: 'worst_output_drift_percent', header: 'Worst drift %', render: (r) => fmt(r.worst_output_drift_percent, 3) },
    { key: 'patients_held_today', header: 'Pts held today' },
  ];

  const energyCols: Column<EnergyDrift>[] = [
    { key: 'energy_mode', header: 'Energy mode' },
    { key: 'runs_count', header: 'Runs' },
    { key: 'avg_output_drift_percent', header: 'Avg drift %', render: (r) => fmt(r.avg_output_drift_percent, 3) },
    { key: 'max_output_drift_percent', header: 'Max |drift| %', render: (r) => fmt(r.max_output_drift_percent, 3) },
    { key: 'avg_energy_constancy_percent', header: 'Avg energy const %', render: (r) => fmt(r.avg_energy_constancy_percent, 3) },
    { key: 'picket_fence_failure_rate_percent', header: 'Picket-fence fail %', render: (r) => fmt(r.picket_fence_failure_rate_percent, 1) },
  ];

  const ootCols: Column<OutOfTolerance>[] = [
    { key: 'hospital_site_name', header: 'Site' },
    { key: 'linac_serial', header: 'LINAC' },
    { key: 'linac_make_model', header: 'Make/Model' },
    { key: 'energy_mode', header: 'Energy' },
    { key: 'output_drift_percent', header: 'Drift %', render: (r) => fmt(r.output_drift_percent, 3) },
    { key: 'tg142_status', header: 'TG-142 status' },
    { key: 'drift_classification', header: 'Class' },
    { key: 'patient_treatment_held', header: 'Held?', render: (r) => (r.patient_treatment_held ? 'YES' : 'no') },
    { key: 'patients_affected_count', header: 'Pts affected' },
  ];

  const capaCols: Column<CapaBacklog>[] = [
    { key: 'severity', header: 'Severity' },
    { key: 'open_count', header: 'Open' },
    { key: 'in_progress_count', header: 'In progress' },
    { key: 'awaiting_part_count', header: 'Awaiting part' },
    { key: 'vendor_escalated_count', header: 'Vendor esc.' },
    { key: 'closed_count', header: 'Closed' },
    { key: 'avg_hours_to_close', header: 'Avg hrs to close', render: (r) => fmt(r.avg_hours_to_close, 1) },
  ];

  const rootCols: Column<RootCause>[] = [
    { key: 'root_cause_class', header: 'Root cause' },
    { key: 'capa_count', header: 'CAPAs' },
    { key: 'critical_or_clinical_count', header: 'Critical/suspend' },
    { key: 'patient_safety_events', header: 'Pt safety events' },
    { key: 'avg_hours_to_close', header: 'Avg hrs to close', render: (r) => fmt(r.avg_hours_to_close, 1) },
  ];

  const mlcCols: Column<MlcIso>[] = [
    { key: 'hospital_site_name', header: 'Site' },
    { key: 'runs_count', header: 'Runs' },
    { key: 'avg_mlc_max_leaf_position_error_mm', header: 'Avg MLC err mm', render: (r) => fmt(r.avg_mlc_max_leaf_position_error_mm, 3) },
    { key: 'worst_mlc_max_leaf_position_error_mm', header: 'Worst MLC err mm', render: (r) => fmt(r.worst_mlc_max_leaf_position_error_mm, 3) },
    { key: 'picket_fence_failures', header: 'Picket-fence fails' },
    { key: 'worst_isocenter_walkout_mm', header: 'Worst iso-walkout mm', render: (r) => fmt(r.worst_isocenter_walkout_mm, 3) },
    { key: 'worst_laser_alignment_mm', header: 'Worst laser mm', render: (r) => fmt(r.worst_laser_alignment_mm, 3) },
    { key: 'worst_odi_accuracy_mm', header: 'Worst ODI mm', render: (r) => fmt(r.worst_odi_accuracy_mm, 3) },
  ];

  const beamCols: Column<BeamProfile>[] = [
    { key: 'energy_mode', header: 'Energy' },
    { key: 'runs_count', header: 'Runs' },
    { key: 'worst_inline_symmetry_percent', header: 'Worst inline sym %', render: (r) => fmt(r.worst_inline_symmetry_percent, 2) },
    { key: 'worst_crossline_symmetry_percent', header: 'Worst crossline sym %', render: (r) => fmt(r.worst_crossline_symmetry_percent, 2) },
    { key: 'worst_inline_flatness_percent', header: 'Worst inline flat %', render: (r) => fmt(r.worst_inline_flatness_percent, 2) },
    { key: 'worst_crossline_flatness_percent', header: 'Worst crossline flat %', render: (r) => fmt(r.worst_crossline_flatness_percent, 2) },
    { key: 'beam_profile_skew_capa_count', header: 'Profile-skew CAPAs' },
  ];

  const aerbCols: Column<AerbEvent>[] = [
    { key: 'capa_code', header: 'CAPA' },
    { key: 'hospital_site_name', header: 'Site' },
    { key: 'linac_serial', header: 'LINAC' },
    { key: 'severity', header: 'Severity' },
    { key: 'capa_status', header: 'Status' },
    { key: 'patient_safety_event', header: 'Pt-safety?', render: (r) => (r.patient_safety_event ? 'YES' : 'no') },
    { key: 'aerb_notification_required', header: 'AERB req?', render: (r) => (r.aerb_notification_required ? 'YES' : 'no') },
    { key: 'aerb_notified_at', header: 'AERB notified at', render: (r) => (r.aerb_notified_at ? new Date(r.aerb_notified_at).toLocaleString('en-IN') : '-') },
    { key: 'trigger_parameter', header: 'Trigger' },
    { key: 'measured_value', header: 'Measured', render: (r) => fmt(r.measured_value, 3) },
    { key: 'tolerance_limit', header: 'Tol limit', render: (r) => fmt(r.tolerance_limit, 3) },
  ];

  const envCols: Column<EnvCorr>[] = [
    { key: 'hospital_site_name', header: 'Site' },
    { key: 'avg_temperature_c', header: 'Avg temp degC', render: (r) => fmt(r.avg_temperature_c, 2) },
    { key: 'max_temperature_c', header: 'Max temp degC', render: (r) => fmt(r.max_temperature_c, 2) },
    { key: 'avg_humidity_percent', header: 'Avg RH %', render: (r) => fmt(r.avg_humidity_percent, 1) },
    { key: 'max_humidity_percent', header: 'Max RH %', render: (r) => fmt(r.max_humidity_percent, 1) },
    { key: 'high_temp_runs', header: 'High-temp runs (>24)' },
    { key: 'high_humidity_runs', header: 'High-RH runs (>55)' },
    { key: 'high_temp_action_level_overlap', header: 'High-temp x action-lvl' },
  ];

  return (
    <main className="mx-auto max-w-7xl space-y-10 p-6">
      <header className="space-y-2">
        <h1 className="text-2xl font-semibold">LINAC TG-142 Daily QA — Cancer-Centre Audit (r3112)</h1>
        <p className="text-sm text-gray-600">
          AAPM TG-142 daily output drift, energy constancy, symmetry/flatness, MLC positioning,
          isocenter & laser checks across customer hospital cancer centres, with CAPA workflow
          and AERB-notifiable patient-safety events.
        </p>
      </header>

      <section className="space-y-2">
        <h2 className="text-lg font-medium">1. Site daily summary</h2>
        <DataTable
          rows={siteRows}
          columns={siteCols}
          emptyMessage="No LINAC runs recorded."
          rowKey={(r, i) => String(r.hospital_site_name ?? i)}
        />
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-medium">2. Energy-mode drift distribution</h2>
        <DataTable
          rows={energyRows}
          columns={energyCols}
          emptyMessage="No energy data."
          rowKey={(r, i) => String(r.energy_mode ?? i)}
        />
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-medium">3. Out-of-tolerance & clinical-suspend machines</h2>
        <DataTable
          rows={ootRows}
          columns={ootCols}
          emptyMessage="All LINACs are within TG-142 tolerance."
          rowKey={(r, i) => String(r.linac_serial + '|' + r.energy_mode ?? i)}
        />
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-medium">4. CAPA backlog by severity</h2>
        <DataTable
          rows={capaRows}
          columns={capaCols}
          emptyMessage="No CAPA tickets."
          rowKey={(r, i) => String(r.severity ?? i)}
        />
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-medium">5. Root-cause rollup</h2>
        <DataTable
          rows={rootRows}
          columns={rootCols}
          emptyMessage="No root-cause data."
          rowKey={(r, i) => String(r.root_cause_class ?? i)}
        />
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-medium">6. MLC & isocenter physics</h2>
        <DataTable
          rows={mlcRows}
          columns={mlcCols}
          emptyMessage="No MLC/isocenter data."
          rowKey={(r, i) => String(r.hospital_site_name ?? i)}
        />
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-medium">7. Beam-profile symmetry & flatness</h2>
        <DataTable
          rows={beamRows}
          columns={beamCols}
          emptyMessage="No beam-profile data."
          rowKey={(r, i) => String(r.energy_mode ?? i)}
        />
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-medium">8. AERB-notifiable events & environmental correlation</h2>
        <DataTable
          rows={aerbRows}
          columns={aerbCols}
          emptyMessage="No AERB-notifiable events."
          rowKey={(r, i) => String(r.capa_code ?? i)}
        />
        <div className="pt-4">
          <DataTable
            rows={envRows}
            columns={envCols}
            emptyMessage="No environmental data."
            rowKey={(r, i) => String(r.hospital_site_name ?? i)}
          />
        </div>
      </section>
    </main>
  );
}
