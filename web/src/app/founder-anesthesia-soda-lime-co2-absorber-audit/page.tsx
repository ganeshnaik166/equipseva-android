import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type SeverityRow = { audit_severity: string; audit_count: number; channeling_count: number; rebreathing_count: number };
type ColorRow = { indicator_color: string; audit_count: number; avg_percent_purple: number; avg_inspired_co2: number };
type ChannelRow = { hospital_name: string; workstation_make_model: string; ot_room_label: string; heat_rise_c: number; inspired_co2_mmhg: number; channeling_evidence: string; audit_severity: string };
type RebreathRow = { hospital_name: string; ot_room_label: string; workstation_make_model: string; inspired_co2_mmhg: number; fresh_gas_flow_lpm: number; canister_hours_in_use: number; capa_action: string };
type SpentRow = { workstation_make_model: string; audit_count: number; avg_hours_used: number; avg_pct_of_recommended: number; max_heat_rise: number };
type CapaStatusRow = { followup_kind: string; followup_status: string; followup_count: number; total_cost_inr: number; total_spent_lime_kg: number };
type CapaActionRow = { capa_action: string; audit_count: number; avg_inspired_co2: number; avg_heat_rise: number };
type WorstRow = { hospital_name: string; total_audits: number; critical_or_red: number; max_inspired_co2: number; max_heat_rise: number };

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [severity, color, channeling, rebreath, spent, capaStatus, capaAction, worst] = await Promise.all([
    supabase.rpc('r3122_severity_rollup'),
    supabase.rpc('r3122_indicator_color_distribution'),
    supabase.rpc('r3122_channeling_offenders'),
    supabase.rpc('r3122_rebreathing_risk'),
    supabase.rpc('r3122_spent_capacity_by_model'),
    supabase.rpc('r3122_capa_followup_status'),
    supabase.rpc('r3122_capa_action_distribution'),
    supabase.rpc('r3122_hospital_worst_exposure'),
  ]);

  const severityRows: SeverityRow[] = (severity.data ?? []) as SeverityRow[];
  const colorRows: ColorRow[] = (color.data ?? []) as ColorRow[];
  const channelRows: ChannelRow[] = (channeling.data ?? []) as ChannelRow[];
  const rebreathRows: RebreathRow[] = (rebreath.data ?? []) as RebreathRow[];
  const spentRows: SpentRow[] = (spent.data ?? []) as SpentRow[];
  const capaStatusRows: CapaStatusRow[] = (capaStatus.data ?? []) as CapaStatusRow[];
  const capaActionRows: CapaActionRow[] = (capaAction.data ?? []) as CapaActionRow[];
  const worstRows: WorstRow[] = (worst.data ?? []) as WorstRow[];

  const severityCols: Column<SeverityRow>[] = [
    { key: 'audit_severity', header: 'Severity' },
    { key: 'audit_count', header: 'Audits' },
    { key: 'channeling_count', header: 'Channeling' },
    { key: 'rebreathing_count', header: 'Rebreathing' },
  ];

  const colorCols: Column<ColorRow>[] = [
    { key: 'indicator_color', header: 'Indicator Color' },
    { key: 'audit_count', header: 'Audits' },
    { key: 'avg_percent_purple', header: 'Avg % Purple' },
    { key: 'avg_inspired_co2', header: 'Avg Inspired CO2 (mmHg)' },
  ];

  const channelCols: Column<ChannelRow>[] = [
    { key: 'hospital_name', header: 'Hospital' },
    { key: 'workstation_make_model', header: 'Workstation' },
    { key: 'ot_room_label', header: 'OT Room' },
    { key: 'heat_rise_c', header: 'Heat Rise (C)' },
    { key: 'inspired_co2_mmhg', header: 'Inspired CO2' },
    { key: 'channeling_evidence', header: 'Evidence' },
    { key: 'audit_severity', header: 'Severity' },
  ];

  const rebreathCols: Column<RebreathRow>[] = [
    { key: 'hospital_name', header: 'Hospital' },
    { key: 'ot_room_label', header: 'OT' },
    { key: 'workstation_make_model', header: 'Workstation' },
    { key: 'inspired_co2_mmhg', header: 'Inspired CO2 (mmHg)' },
    { key: 'fresh_gas_flow_lpm', header: 'FGF (L/min)' },
    { key: 'canister_hours_in_use', header: 'Canister Hours' },
    { key: 'capa_action', header: 'CAPA Action' },
  ];

  const spentCols: Column<SpentRow>[] = [
    { key: 'workstation_make_model', header: 'Workstation Model' },
    { key: 'audit_count', header: 'Audits' },
    { key: 'avg_hours_used', header: 'Avg Hours Used' },
    { key: 'avg_pct_of_recommended', header: 'Avg % of Recommended' },
    { key: 'max_heat_rise', header: 'Max Heat Rise (C)' },
  ];

  const capaStatusCols: Column<CapaStatusRow>[] = [
    { key: 'followup_kind', header: 'Followup Kind' },
    { key: 'followup_status', header: 'Status' },
    { key: 'followup_count', header: 'Count' },
    { key: 'total_cost_inr', header: 'Total Cost (INR)' },
    { key: 'total_spent_lime_kg', header: 'Spent Lime (kg)' },
  ];

  const capaActionCols: Column<CapaActionRow>[] = [
    { key: 'capa_action', header: 'CAPA Action' },
    { key: 'audit_count', header: 'Audits' },
    { key: 'avg_inspired_co2', header: 'Avg Inspired CO2' },
    { key: 'avg_heat_rise', header: 'Avg Heat Rise (C)' },
  ];

  const worstCols: Column<WorstRow>[] = [
    { key: 'hospital_name', header: 'Hospital' },
    { key: 'total_audits', header: 'Total Audits' },
    { key: 'critical_or_red', header: 'Critical/Red' },
    { key: 'max_inspired_co2', header: 'Max Inspired CO2' },
    { key: 'max_heat_rise', header: 'Max Heat Rise (C)' },
  ];

  return (
    <div className="p-6 space-y-8">
      <header>
        <h1 className="text-2xl font-bold">Anesthesia Soda Lime CO2 Absorber Audit</h1>
        <p className="text-sm text-gray-600">
          Round 3122 — canister hours, indicator color, rebreathing, heat-rise &amp; CAPA. Rebreathing flagged when inspired CO2 &gt;= 3.0 mmHg.
        </p>
      </header>

      <section>
        <h2 className="text-lg font-semibold mb-2">Severity rollup</h2>
        <DataTable
          rows={severityRows}
          columns={severityCols}
          emptyMessage="No severity rollup available"
          rowKey={(r, i) => String(r.audit_severity ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Indicator color distribution</h2>
        <DataTable
          rows={colorRows}
          columns={colorCols}
          emptyMessage="No indicator color data"
          rowKey={(r, i) => String(r.indicator_color ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Channeling offenders (heat &gt;= rise &amp; CO2 rebreath)</h2>
        <DataTable
          rows={channelRows}
          columns={channelCols}
          emptyMessage="No channeling detected"
          rowKey={(r, i) => String(i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Rebreathing risk — inspired CO2 &gt;= 3 mmHg</h2>
        <DataTable
          rows={rebreathRows}
          columns={rebreathCols}
          emptyMessage="No rebreathing risk"
          rowKey={(r, i) => String(i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Spent-capacity by workstation model</h2>
        <DataTable
          rows={spentRows}
          columns={spentCols}
          emptyMessage="No spent-capacity data"
          rowKey={(r, i) => String(r.workstation_make_model ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">CAPA followup status</h2>
        <DataTable
          rows={capaStatusRows}
          columns={capaStatusCols}
          emptyMessage="No CAPA followups"
          rowKey={(r, i) => String(i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">CAPA action distribution</h2>
        <DataTable
          rows={capaActionRows}
          columns={capaActionCols}
          emptyMessage="No CAPA actions"
          rowKey={(r, i) => String(r.capa_action ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Hospital worst exposure (red & critical concentration)</h2>
        <DataTable
          rows={worstRows}
          columns={worstCols}
          emptyMessage="No hospital exposure data"
          rowKey={(r, i) => String(r.hospital_name ?? i)}
        />
      </section>
    </div>
  );
}
