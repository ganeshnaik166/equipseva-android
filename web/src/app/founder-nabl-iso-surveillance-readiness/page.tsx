import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type ReadinessRow = {
  standard_code: string;
  readiness_status: string;
  clause_count: number;
  total_doc_gaps: number;
  total_competency_gaps: number;
};

type CountdownRow = {
  lab_name: string;
  standard_code: string;
  earliest_due_on: string;
  days_remaining: number;
  open_clauses: number;
  gap_clauses: number;
};

type HeatmapRow = {
  clause_category: string;
  total_clauses: number;
  gap_clauses: number;
  gap_pct: number | null;
};

type CapaRollupRow = {
  capa_status: string;
  nc_count: number;
  avg_ageing_days: number | null;
  total_remediation_rupees: number;
};

type AgeingBandRow = {
  nc_severity: string;
  band: string;
  nc_count: number;
};

type WatchlistRow = {
  nc_reference: string;
  nc_severity: string;
  lab_name: string;
  clause_reference: string;
  target_closure_on: string;
  days_overdue: number;
  capa_status: string;
};

type ScorecardRow = {
  lab_name: string;
  standard_code: string;
  total_clauses: number;
  ready_clauses: number;
  readiness_pct: number | null;
  open_ncs: number;
  total_remediation_rupees: number;
};

type EffectivenessRow = {
  nc_reference: string;
  lab_name: string;
  capa_status: string;
  effectiveness_score: number | null;
  actual_closure_on: string | null;
  remediation_cost_rupees: number;
};

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [
    summary,
    countdown,
    heatmap,
    capaRollup,
    ageingBands,
    watchlist,
    scorecard,
    effectiveness,
  ] = await Promise.all([
    sb.rpc('founder_r3123_clause_readiness_summary'),
    sb.rpc('founder_r3123_surveillance_countdown'),
    sb.rpc('founder_r3123_category_gap_heatmap'),
    sb.rpc('founder_r3123_capa_status_rollup'),
    sb.rpc('founder_r3123_severity_ageing_bands'),
    sb.rpc('founder_r3123_overdue_capa_watchlist'),
    sb.rpc('founder_r3123_lab_readiness_scorecard'),
    sb.rpc('founder_r3123_effectiveness_review'),
  ]);

  const summaryCols: Column<ReadinessRow>[] = [
    { key: 'standard_code', header: 'Standard' },
    { key: 'readiness_status', header: 'Status' },
    { key: 'clause_count', header: 'Clauses' },
    { key: 'total_doc_gaps', header: 'Doc gaps' },
    { key: 'total_competency_gaps', header: 'Competency gaps' },
  ];

  const countdownCols: Column<CountdownRow>[] = [
    { key: 'lab_name', header: 'Lab' },
    { key: 'standard_code', header: 'Standard' },
    { key: 'earliest_due_on', header: 'Earliest due' },
    { key: 'days_remaining', header: 'Days remaining' },
    { key: 'open_clauses', header: 'Open clauses' },
    { key: 'gap_clauses', header: 'Gap clauses' },
  ];

  const heatmapCols: Column<HeatmapRow>[] = [
    { key: 'clause_category', header: 'Category' },
    { key: 'total_clauses', header: 'Total' },
    { key: 'gap_clauses', header: 'Gap' },
    { key: 'gap_pct', header: 'Gap %', render: (r) => (r.gap_pct ?? 0) + '%' },
  ];

  const capaCols: Column<CapaRollupRow>[] = [
    { key: 'capa_status', header: 'CAPA status' },
    { key: 'nc_count', header: 'NC count' },
    { key: 'avg_ageing_days', header: 'Avg ageing (d)' },
    {
      key: 'total_remediation_rupees',
      header: 'Remediation cost',
      render: (r) => '₹' + r.total_remediation_rupees.toLocaleString('en-IN'),
    },
  ];

  const ageingCols: Column<AgeingBandRow>[] = [
    { key: 'nc_severity', header: 'Severity' },
    { key: 'band', header: 'Ageing band (days)' },
    { key: 'nc_count', header: 'NC count' },
  ];

  const watchlistCols: Column<WatchlistRow>[] = [
    { key: 'nc_reference', header: 'NC ref' },
    { key: 'nc_severity', header: 'Severity' },
    { key: 'lab_name', header: 'Lab' },
    { key: 'clause_reference', header: 'Clause' },
    { key: 'target_closure_on', header: 'Target close' },
    { key: 'days_overdue', header: 'Days overdue' },
    { key: 'capa_status', header: 'Status' },
  ];

  const scorecardCols: Column<ScorecardRow>[] = [
    { key: 'lab_name', header: 'Lab' },
    { key: 'standard_code', header: 'Standard' },
    { key: 'total_clauses', header: 'Clauses' },
    { key: 'ready_clauses', header: 'Ready' },
    { key: 'readiness_pct', header: 'Ready %', render: (r) => (r.readiness_pct ?? 0) + '%' },
    { key: 'open_ncs', header: 'Open NCs' },
    {
      key: 'total_remediation_rupees',
      header: 'Cost',
      render: (r) => '₹' + r.total_remediation_rupees.toLocaleString('en-IN'),
    },
  ];

  const effectivenessCols: Column<EffectivenessRow>[] = [
    { key: 'nc_reference', header: 'NC ref' },
    { key: 'lab_name', header: 'Lab' },
    { key: 'capa_status', header: 'Status' },
    {
      key: 'effectiveness_score',
      header: 'Effectiveness (0-5)',
      render: (r) => (r.effectiveness_score == null ? '—' : r.effectiveness_score.toFixed(2)),
    },
    {
      key: 'actual_closure_on',
      header: 'Closed on',
      render: (r) => r.actual_closure_on ?? '—',
    },
    {
      key: 'remediation_cost_rupees',
      header: 'Cost',
      render: (r) => '₹' + r.remediation_cost_rupees.toLocaleString('en-IN'),
    },
  ];

  return (
    <main className="mx-auto max-w-7xl space-y-10 px-6 py-8">
      <header className="space-y-2">
        <h1 className="text-2xl font-semibold">NABL / ISO Lab Accreditation Surveillance Readiness</h1>
        <p className="text-sm text-gray-600">
          Quarterly founder view: ISO 15189 & ISO 17025 clause readiness, surveillance countdown,
          non-conformity ageing & CAPA closure across partner labs.
        </p>
      </header>

      <section>
        <h2 className="mb-2 text-lg font-medium">Clause readiness summary</h2>
        <DataTable
          rows={(summary.data as ReadinessRow[]) ?? []}
          columns={summaryCols}
          emptyMessage="No readiness rows yet"
          rowKey={(r, i) => String(i)}
        />
      </section>

      <section>
        <h2 className="mb-2 text-lg font-medium">Surveillance countdown by lab</h2>
        <DataTable
          rows={(countdown.data as CountdownRow[]) ?? []}
          columns={countdownCols}
          emptyMessage="No surveillance schedules"
          rowKey={(r, i) => r.lab_name + ':' + r.standard_code + ':' + i}
        />
      </section>

      <section>
        <h2 className="mb-2 text-lg font-medium">Gap heatmap by clause category</h2>
        <DataTable
          rows={(heatmap.data as HeatmapRow[]) ?? []}
          columns={heatmapCols}
          emptyMessage="No category data"
          rowKey={(r, i) => r.clause_category + ':' + i}
        />
      </section>

      <section>
        <h2 className="mb-2 text-lg font-medium">CAPA status rollup</h2>
        <DataTable
          rows={(capaRollup.data as CapaRollupRow[]) ?? []}
          columns={capaCols}
          emptyMessage="No CAPA rows"
          rowKey={(r, i) => r.capa_status + ':' + i}
        />
      </section>

      <section>
        <h2 className="mb-2 text-lg font-medium">NC severity × ageing bands</h2>
        <DataTable
          rows={(ageingBands.data as AgeingBandRow[]) ?? []}
          columns={ageingCols}
          emptyMessage="No ageing data"
          rowKey={(r, i) => r.nc_severity + ':' + r.band + ':' + i}
        />
      </section>

      <section>
        <h2 className="mb-2 text-lg font-medium">Overdue CAPA watchlist</h2>
        <DataTable
          rows={(watchlist.data as WatchlistRow[]) ?? []}
          columns={watchlistCols}
          emptyMessage="No overdue CAPAs - on track"
          rowKey={(r, i) => r.nc_reference + ':' + i}
        />
      </section>

      <section>
        <h2 className="mb-2 text-lg font-medium">Lab readiness scorecard</h2>
        <DataTable
          rows={(scorecard.data as ScorecardRow[]) ?? []}
          columns={scorecardCols}
          emptyMessage="No labs onboarded"
          rowKey={(r, i) => r.lab_name + ':' + r.standard_code + ':' + i}
        />
      </section>

      <section>
        <h2 className="mb-2 text-lg font-medium">Effectiveness review (closed & in-check)</h2>
        <DataTable
          rows={(effectiveness.data as EffectivenessRow[]) ?? []}
          columns={effectivenessCols}
          emptyMessage="No closed CAPAs yet"
          rowKey={(r, i) => r.nc_reference + ':' + i}
        />
      </section>
    </main>
  );
}
