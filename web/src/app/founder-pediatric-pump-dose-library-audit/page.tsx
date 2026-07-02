import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type Summary = {
  total_entries: number;
  active_entries: number;
  quarantined: number;
  draft: number;
  signed_off: number;
  freeflow_failing: number;
  total_overrides: number;
  capa_open: number;
};

type UnitRow = { hospital_unit: string; entries: number; active: number; ff_fail: number; signed_off: number };
type DrugClassRow = { drug_class: string; entries: number; avg_hard_max: number; avg_soft_max: number; ff_protected: number };
type KindRow = { override_kind: string; events: number; avg_pct_over: number; critical_events: number; capa_open: number };
type ReasonRow = { override_reason_code: string; events: number; near_miss: number; harm_events: number };
type PrescriberRow = { prescriber_role: string; events: number; hard_max_over_events: number; avg_pct: number };
type CapaRow = { capa_status: string; events: number; avg_age_days: number; oldest_days: number };
type CritRow = {
  event_at: string;
  patient_pseudo_id: string;
  override_kind: string;
  override_pct_over_hard: number | null;
  override_reason_code: string;
  patient_outcome: string;
  capa_status: string;
  severity: string;
};
type PumpRow = { pump_make_model: string; total_pumps: number; ff_failing: number; last_test_at: string | null };

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [summaryR, unitR, drugR, kindR, reasonR, prescR, capaR, critR, pumpR] = await Promise.all([
    supabase.rpc('r3124_summary'),
    supabase.rpc('r3124_library_by_unit'),
    supabase.rpc('r3124_library_by_drug_class'),
    supabase.rpc('r3124_overrides_by_kind'),
    supabase.rpc('r3124_overrides_by_reason'),
    supabase.rpc('r3124_overrides_by_prescriber'),
    supabase.rpc('r3124_capa_aging'),
    supabase.rpc('r3124_critical_events'),
    supabase.rpc('r3124_pump_freeflow_status'),
  ]);

  const summary: Summary | null = (summaryR.data?.[0] as Summary) ?? null;
  const unitRows: UnitRow[] = (unitR.data as UnitRow[]) ?? [];
  const drugRows: DrugClassRow[] = (drugR.data as DrugClassRow[]) ?? [];
  const kindRows: KindRow[] = (kindR.data as KindRow[]) ?? [];
  const reasonRows: ReasonRow[] = (reasonR.data as ReasonRow[]) ?? [];
  const prescRows: PrescriberRow[] = (prescR.data as PrescriberRow[]) ?? [];
  const capaRows: CapaRow[] = (capaR.data as CapaRow[]) ?? [];
  const critRows: CritRow[] = (critR.data as CritRow[]) ?? [];
  const pumpRows: PumpRow[] = (pumpR.data as PumpRow[]) ?? [];

  const unitCols: Column<UnitRow>[] = [
    { key: 'hospital_unit', header: 'Unit' },
    { key: 'entries', header: 'Entries' },
    { key: 'active', header: 'Active' },
    { key: 'ff_fail', header: 'Free-flow Failing' },
    { key: 'signed_off', header: 'PharmD Signed' },
  ];

  const drugCols: Column<DrugClassRow>[] = [
    { key: 'drug_class', header: 'Drug Class' },
    { key: 'entries', header: 'Entries' },
    { key: 'avg_hard_max', header: 'Avg Hard Max' },
    { key: 'avg_soft_max', header: 'Avg Soft Max' },
    { key: 'ff_protected', header: 'Free-flow Protected' },
  ];

  const kindCols: Column<KindRow>[] = [
    { key: 'override_kind', header: 'Override Kind' },
    { key: 'events', header: 'Events' },
    { key: 'avg_pct_over', header: 'Avg % Over Hard' },
    { key: 'critical_events', header: 'Critical' },
    { key: 'capa_open', header: 'CAPA Open' },
  ];

  const reasonCols: Column<ReasonRow>[] = [
    { key: 'override_reason_code', header: 'Reason' },
    { key: 'events', header: 'Events' },
    { key: 'near_miss', header: 'Near Miss' },
    { key: 'harm_events', header: 'Harm Events' },
  ];

  const prescCols: Column<PrescriberRow>[] = [
    { key: 'prescriber_role', header: 'Role' },
    { key: 'events', header: 'Events' },
    { key: 'hard_max_over_events', header: 'Hard-Max Over' },
    { key: 'avg_pct', header: 'Avg % Over' },
  ];

  const capaCols: Column<CapaRow>[] = [
    { key: 'capa_status', header: 'CAPA Status' },
    { key: 'events', header: 'Events' },
    { key: 'avg_age_days', header: 'Avg Age (days)' },
    { key: 'oldest_days', header: 'Oldest (days)' },
  ];

  const critCols: Column<CritRow>[] = [
    { key: 'event_at', header: 'Event At' },
    { key: 'patient_pseudo_id', header: 'Patient' },
    { key: 'override_kind', header: 'Kind' },
    { key: 'override_pct_over_hard', header: '% Over Hard' },
    { key: 'override_reason_code', header: 'Reason' },
    { key: 'patient_outcome', header: 'Outcome' },
    { key: 'capa_status', header: 'CAPA' },
    { key: 'severity', header: 'Severity' },
  ];

  const pumpCols: Column<PumpRow>[] = [
    { key: 'pump_make_model', header: 'Pump' },
    { key: 'total_pumps', header: 'Units' },
    { key: 'ff_failing', header: 'FF Failing' },
    { key: 'last_test_at', header: 'Last FF Test' },
  ];

  return (
    <div className="p-6 space-y-6">
      <h1 className="text-2xl font-semibold">Pediatric Pump Dose Library Audit (r3124)</h1>
      <p className="text-sm text-gray-600">
        Smart-pump dose-library audit across PICU/NICU/peds units. Tracks drug × concentration ×
        weight band × pediatric hard-limit, free-flow protection, override events, and CAPA aging.
        Hard-max breaches &gt;= 10% auto-escalate to QC; CDSCO 24h report fires for sentinel events.
      </p>

      {summary && (
        <div className="grid grid-cols-4 gap-3">
          <div className="border p-3 rounded"><div className="text-xs text-gray-500">Library Entries</div><div className="text-xl font-mono">{summary.total_entries}</div></div>
          <div className="border p-3 rounded"><div className="text-xs text-gray-500">Active</div><div className="text-xl font-mono">{summary.active_entries}</div></div>
          <div className="border p-3 rounded"><div className="text-xs text-gray-500">Quarantined</div><div className="text-xl font-mono">{summary.quarantined}</div></div>
          <div className="border p-3 rounded"><div className="text-xs text-gray-500">Draft</div><div className="text-xl font-mono">{summary.draft}</div></div>
          <div className="border p-3 rounded"><div className="text-xs text-gray-500">PharmD Signed</div><div className="text-xl font-mono">{summary.signed_off}</div></div>
          <div className="border p-3 rounded"><div className="text-xs text-gray-500">Free-flow Failing</div><div className="text-xl font-mono">{summary.freeflow_failing}</div></div>
          <div className="border p-3 rounded"><div className="text-xs text-gray-500">Override Events</div><div className="text-xl font-mono">{summary.total_overrides}</div></div>
          <div className="border p-3 rounded"><div className="text-xs text-gray-500">CAPA Open</div><div className="text-xl font-mono">{summary.capa_open}</div></div>
        </div>
      )}

      <section>
        <h2 className="text-lg font-semibold mb-2">Library by Hospital Unit</h2>
        <DataTable rows={unitRows} columns={unitCols} emptyMessage="No library entries" rowKey={(r, i) => String(r.hospital_unit ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Library by Drug Class</h2>
        <DataTable rows={drugRows} columns={drugCols} emptyMessage="No drug classes" rowKey={(r, i) => String(r.drug_class ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Overrides by Kind</h2>
        <DataTable rows={kindRows} columns={kindCols} emptyMessage="No override events" rowKey={(r, i) => String(r.override_kind ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Overrides by Reason</h2>
        <DataTable rows={reasonRows} columns={reasonCols} emptyMessage="No reasons" rowKey={(r, i) => String(r.override_reason_code ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Overrides by Prescriber Role</h2>
        <DataTable rows={prescRows} columns={prescCols} emptyMessage="No prescribers" rowKey={(r, i) => String(r.prescriber_role ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">CAPA Aging</h2>
        <DataTable rows={capaRows} columns={capaCols} emptyMessage="No CAPA rows" rowKey={(r, i) => String(r.capa_status ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Critical & High-Severity Events</h2>
        <DataTable rows={critRows} columns={critCols} emptyMessage="No critical events" rowKey={(r, i) => String(r.patient_pseudo_id ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Pump Free-Flow Test Status</h2>
        <DataTable rows={pumpRows} columns={pumpCols} emptyMessage="No pumps" rowKey={(r, i) => String(r.pump_make_model ?? i)} />
      </section>
    </div>
  );
}
