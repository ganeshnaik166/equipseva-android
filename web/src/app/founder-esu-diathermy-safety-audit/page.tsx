import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type RosterRow = {
  audit_ref: string;
  ot_room_label: string;
  esu_make_model: string;
  audit_quarter: string;
  audit_date: string;
  mode: string;
  set_watts: number;
  delivered_watts_avg: number;
  deviation_pct: number;
  iec_60601_2_2_band: string;
  outcome: string;
};

type OutcomeRow = {
  outcome: string;
  audit_count: number;
  avg_deviation_pct: number;
};

type ModeBandRow = {
  mode: string;
  iec_60601_2_2_band: string;
  audit_count: number;
  avg_abs_deviation: number;
};

type LeakRow = {
  audit_ref: string;
  esu_make_model: string;
  mode: string;
  hf_leakage_ma: number;
  outcome: string;
  audit_date: string;
};

type CapaRow = {
  finding_ref: string;
  audit_ref: string;
  rem_system: string;
  burn_risk_level: string;
  finding_severity: string;
  capa_status: string;
  capa_owner: string;
  due_at: string | null;
};

type BurnRow = {
  burn_risk_level: string;
  finding_count: number;
  open_count: number;
  avg_contact_quality: number;
};

type AgingRow = {
  finding_ref: string;
  capa_status: string;
  capa_owner: string;
  days_open: number;
  due_at: string | null;
  remediation_notes: string | null;
};

type TrendRow = {
  audit_quarter: string;
  audits: number;
  failures: number;
  failure_rate_pct: number;
  avg_abs_deviation: number;
};

type CableRow = {
  finding_ref: string;
  audit_ref: string;
  cable_integrity: string;
  rem_system: string;
  burn_risk_level: string;
  capa_status: string;
};

type HeadlineRow = {
  total_audits: number;
  failed_audits: number;
  critical_band_audits: number;
  open_capas: number;
  escalated_capas: number;
  avg_abs_deviation: number;
  max_hf_leakage_ma: number;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    rosterRes,
    outcomeRes,
    modeBandRes,
    leakRes,
    capaRes,
    burnRes,
    agingRes,
    trendRes,
    cableRes,
    headlineRes,
  ] = await Promise.all([
    supabase.rpc('founder_esu_audit_roster_r3110'),
    supabase.rpc('founder_esu_outcome_rollup_r3110'),
    supabase.rpc('founder_esu_mode_band_crosstab_r3110'),
    supabase.rpc('founder_esu_hf_leakage_offenders_r3110'),
    supabase.rpc('founder_esu_capa_roster_r3110'),
    supabase.rpc('founder_esu_burn_risk_distribution_r3110'),
    supabase.rpc('founder_esu_capa_aging_r3110'),
    supabase.rpc('founder_esu_quarterly_trend_r3110'),
    supabase.rpc('founder_esu_cable_integrity_hotlist_r3110'),
    supabase.rpc('founder_esu_safety_headline_r3110'),
  ]);

  const roster = (rosterRes.data ?? []) as RosterRow[];
  const outcomes = (outcomeRes.data ?? []) as OutcomeRow[];
  const modeBand = (modeBandRes.data ?? []) as ModeBandRow[];
  const leaks = (leakRes.data ?? []) as LeakRow[];
  const capas = (capaRes.data ?? []) as CapaRow[];
  const burn = (burnRes.data ?? []) as BurnRow[];
  const aging = (agingRes.data ?? []) as AgingRow[];
  const trend = (trendRes.data ?? []) as TrendRow[];
  const cable = (cableRes.data ?? []) as CableRow[];
  const headline = (headlineRes.data ?? []) as HeadlineRow[];

  const rosterCols: Column<RosterRow>[] = [
    { key: 'audit_ref', header: 'Audit Ref' },
    { key: 'ot_room_label', header: 'OT Room' },
    { key: 'esu_make_model', header: 'ESU Make/Model' },
    { key: 'audit_quarter', header: 'Quarter' },
    { key: 'audit_date', header: 'Date' },
    { key: 'mode', header: 'Mode' },
    { key: 'set_watts', header: 'Set W', render: (r) => r.set_watts.toFixed(1) },
    { key: 'delivered_watts_avg', header: 'Avg W', render: (r) => r.delivered_watts_avg.toFixed(1) },
    { key: 'deviation_pct', header: 'Dev %', render: (r) => `${r.deviation_pct.toFixed(2)}%` },
    { key: 'iec_60601_2_2_band', header: 'IEC Band' },
    { key: 'outcome', header: 'Outcome' },
  ];

  const outcomeCols: Column<OutcomeRow>[] = [
    { key: 'outcome', header: 'Outcome' },
    { key: 'audit_count', header: 'Audits' },
    { key: 'avg_deviation_pct', header: 'Avg Dev %', render: (r) => `${Number(r.avg_deviation_pct ?? 0).toFixed(2)}%` },
  ];

  const modeBandCols: Column<ModeBandRow>[] = [
    { key: 'mode', header: 'Mode' },
    { key: 'iec_60601_2_2_band', header: 'IEC Band' },
    { key: 'audit_count', header: 'Count' },
    { key: 'avg_abs_deviation', header: 'Avg |Dev|%', render: (r) => `${Number(r.avg_abs_deviation ?? 0).toFixed(2)}%` },
  ];

  const leakCols: Column<LeakRow>[] = [
    { key: 'audit_ref', header: 'Audit Ref' },
    { key: 'esu_make_model', header: 'ESU' },
    { key: 'mode', header: 'Mode' },
    { key: 'hf_leakage_ma', header: 'HF Leak (mA)', render: (r) => r.hf_leakage_ma.toFixed(2) },
    { key: 'outcome', header: 'Outcome' },
    { key: 'audit_date', header: 'Date' },
  ];

  const capaCols: Column<CapaRow>[] = [
    { key: 'finding_ref', header: 'Finding' },
    { key: 'audit_ref', header: 'Audit' },
    { key: 'rem_system', header: 'REM System' },
    { key: 'burn_risk_level', header: 'Burn Risk' },
    { key: 'finding_severity', header: 'Severity' },
    { key: 'capa_status', header: 'CAPA Status' },
    { key: 'capa_owner', header: 'Owner' },
    { key: 'due_at', header: 'Due', render: (r) => r.due_at ? new Date(r.due_at).toLocaleDateString('en-IN') : '-' },
  ];

  const burnCols: Column<BurnRow>[] = [
    { key: 'burn_risk_level', header: 'Burn Risk' },
    { key: 'finding_count', header: 'Findings' },
    { key: 'open_count', header: 'Open' },
    { key: 'avg_contact_quality', header: 'Avg Contact %', render: (r) => `${Number(r.avg_contact_quality ?? 0).toFixed(2)}%` },
  ];

  const agingCols: Column<AgingRow>[] = [
    { key: 'finding_ref', header: 'Finding' },
    { key: 'capa_status', header: 'Status' },
    { key: 'capa_owner', header: 'Owner' },
    { key: 'days_open', header: 'Days Open', render: (r) => Number(r.days_open ?? 0).toFixed(1) },
    { key: 'due_at', header: 'Due', render: (r) => r.due_at ? new Date(r.due_at).toLocaleDateString('en-IN') : '-' },
    { key: 'remediation_notes', header: 'Notes' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'audit_quarter', header: 'Quarter' },
    { key: 'audits', header: 'Audits' },
    { key: 'failures', header: 'Failures' },
    { key: 'failure_rate_pct', header: 'Fail Rate %', render: (r) => `${Number(r.failure_rate_pct ?? 0).toFixed(2)}%` },
    { key: 'avg_abs_deviation', header: 'Avg |Dev|%', render: (r) => `${Number(r.avg_abs_deviation ?? 0).toFixed(2)}%` },
  ];

  const cableCols: Column<CableRow>[] = [
    { key: 'finding_ref', header: 'Finding' },
    { key: 'audit_ref', header: 'Audit' },
    { key: 'cable_integrity', header: 'Cable State' },
    { key: 'rem_system', header: 'REM System' },
    { key: 'burn_risk_level', header: 'Burn Risk' },
    { key: 'capa_status', header: 'CAPA Status' },
  ];

  const headlineCols: Column<HeadlineRow>[] = [
    { key: 'total_audits', header: 'Total Audits' },
    { key: 'failed_audits', header: 'Failed' },
    { key: 'critical_band_audits', header: 'Critical Band' },
    { key: 'open_capas', header: 'Open CAPAs' },
    { key: 'escalated_capas', header: 'Escalated' },
    { key: 'avg_abs_deviation', header: 'Avg |Dev|%', render: (r) => `${Number(r.avg_abs_deviation ?? 0).toFixed(2)}%` },
    { key: 'max_hf_leakage_ma', header: 'Max HF Leak mA', render: (r) => Number(r.max_hf_leakage_ma ?? 0).toFixed(2) },
  ];

  return (
    <main className="mx-auto max-w-7xl space-y-10 p-6">
      <header className="space-y-2">
        <h1 className="text-2xl font-semibold">Customer Hospital Surgical Diathermy ESU Output-Power & Patient-Plate Safety Audit</h1>
        <p className="text-sm text-neutral-600">
          Quarterly electrosurgical-unit audit: set vs delivered watts across pure-cut / coag / blend modes, REM patient-plate impedance, HF & LF leakage currents, and CAPA tracking against IEC 60601-2-2.
        </p>
      </header>

      <section className="space-y-3">
        <h2 className="text-lg font-medium">Headline KPIs</h2>
        <DataTable
          rows={headline}
          columns={headlineCols}
          emptyMessage="No headline data."
          rowKey={(r, i) => String(i)}
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-medium">ESU Audit Roster</h2>
        <DataTable
          rows={roster}
          columns={rosterCols}
          emptyMessage="No ESU audits recorded."
          rowKey={(r, i) => String(r.audit_ref ?? i)}
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-medium">Outcome Rollup</h2>
        <DataTable
          rows={outcomes}
          columns={outcomeCols}
          emptyMessage="No outcome data."
          rowKey={(r, i) => String(r.outcome ?? i)}
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-medium">Mode × IEC Band Cross-tab</h2>
        <DataTable
          rows={modeBand}
          columns={modeBandCols}
          emptyMessage="No cross-tab data."
          rowKey={(r, i) => `${r.mode}-${r.iec_60601_2_2_band}-${i}`}
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-medium">HF Leakage Offenders (&gt; 0.30 mA)</h2>
        <DataTable
          rows={leaks}
          columns={leakCols}
          emptyMessage="No HF leakage offenders."
          rowKey={(r, i) => String(r.audit_ref ?? i)}
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-medium">CAPA Roster (REM / Plate / Cable)</h2>
        <DataTable
          rows={capas}
          columns={capaCols}
          emptyMessage="No CAPA findings."
          rowKey={(r, i) => String(r.finding_ref ?? i)}
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-medium">Burn-Risk Distribution</h2>
        <DataTable
          rows={burn}
          columns={burnCols}
          emptyMessage="No burn-risk data."
          rowKey={(r, i) => String(r.burn_risk_level ?? i)}
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-medium">CAPA Aging (Open Items)</h2>
        <DataTable
          rows={aging}
          columns={agingCols}
          emptyMessage="All CAPAs closed."
          rowKey={(r, i) => String(r.finding_ref ?? i)}
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-medium">Quarterly Failure-Rate Trend</h2>
        <DataTable
          rows={trend}
          columns={trendCols}
          emptyMessage="No quarterly trend data."
          rowKey={(r, i) => String(r.audit_quarter ?? i)}
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-medium">Cable-Integrity Hot List</h2>
        <DataTable
          rows={cable}
          columns={cableCols}
          emptyMessage="No cable-integrity issues open."
          rowKey={(r, i) => String(r.finding_ref ?? i)}
        />
      </section>
    </main>
  );
}
