import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type InstrumentRollupRow = {
  instrument_type: string;
  execution_status: string;
  instrument_count: number;
  total_liquid_inr: number;
  total_illiquid_inr: number;
  total_contingent_inr: number;
  next_review_min: string | null;
};

type UpcomingReviewRow = {
  instrument_code: string;
  instrument_title: string;
  instrument_type: string;
  next_review_due: string;
  days_to_review: number;
  review_cadence: string;
  custodian_location: string;
};

type ConflictRow = {
  conflict_flag: string;
  designation_count: number;
  total_value_at_risk_inr: number;
  active_count: number;
  contingent_count: number;
};

type AggregateRow = {
  relationship: string;
  asset_class: string;
  designation_count: number;
  total_share_inr: number;
  weighted_share_pct: number;
};

type MismatchRow = {
  instrument_code: string;
  instrument_type: string;
  beneficiary_alias: string;
  asset_class: string;
  share_percentage: number;
  share_value_inr: number;
  conflict_flag: string;
  status: string;
};

type CustodianRow = {
  custodian_location: string;
  instrument_count: number;
  total_value_under_custody_inr: number;
  oldest_signed_on: string | null;
  governing_laws_covered: string | null;
};

type DigitalAssetRow = {
  beneficiary_alias: string;
  relationship: string;
  asset_class: string;
  designation_role: string;
  share_value_inr: number;
  conflict_flag: string;
  status: string;
  next_communication_due: string | null;
};

type CommGapRow = {
  beneficiary_alias: string;
  relationship: string;
  designation_role: string;
  last_communicated_on: string | null;
  next_communication_due: string | null;
  days_since_last: number | null;
  days_to_next: number | null;
  conflict_flag: string;
};

function fmtInr(n: number | null | undefined): string {
  if (n === null || n === undefined) return '-';
  if (n === 0) return '0';
  if (n >= 10000000) return `Rs ${(n / 10000000).toFixed(2)} Cr`;
  if (n >= 100000) return `Rs ${(n / 100000).toFixed(2)} L`;
  return `Rs ${n.toLocaleString('en-IN')}`;
}

function fmtNum(n: number | null | undefined): string {
  if (n === null || n === undefined) return '-';
  return Number(n).toLocaleString('en-IN');
}

function fmtDate(d: string | null | undefined): string {
  if (!d) return '-';
  return d;
}

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    rollup,
    upcoming,
    conflict,
    aggregate,
    mismatch,
    custodian,
    digital,
    commGap,
  ] = await Promise.all([
    supabase.rpc('founder_estate_instrument_rollup_r3133'),
    supabase.rpc('founder_estate_upcoming_reviews_r3133'),
    supabase.rpc('founder_estate_conflict_heatmap_r3133'),
    supabase.rpc('founder_estate_beneficiary_aggregate_r3133'),
    supabase.rpc('founder_estate_nominee_will_mismatch_r3133'),
    supabase.rpc('founder_estate_custodian_distribution_r3133'),
    supabase.rpc('founder_estate_digital_asset_coverage_r3133'),
    supabase.rpc('founder_estate_communication_gaps_r3133'),
  ]);

  const rollupRows = (rollup.data ?? []) as InstrumentRollupRow[];
  const upcomingRows = (upcoming.data ?? []) as UpcomingReviewRow[];
  const conflictRows = (conflict.data ?? []) as ConflictRow[];
  const aggregateRows = (aggregate.data ?? []) as AggregateRow[];
  const mismatchRows = (mismatch.data ?? []) as MismatchRow[];
  const custodianRows = (custodian.data ?? []) as CustodianRow[];
  const digitalRows = (digital.data ?? []) as DigitalAssetRow[];
  const commGapRows = (commGap.data ?? []) as CommGapRow[];

  const rollupCols: Column<InstrumentRollupRow>[] = [
    { key: 'instrument_type', header: 'Instrument Type' },
    { key: 'execution_status', header: 'Execution Status' },
    { key: 'instrument_count', header: 'Count', render: (r) => fmtNum(r.instrument_count) },
    { key: 'total_liquid_inr', header: 'Liquid', render: (r) => fmtInr(r.total_liquid_inr) },
    { key: 'total_illiquid_inr', header: 'Illiquid', render: (r) => fmtInr(r.total_illiquid_inr) },
    { key: 'total_contingent_inr', header: 'Contingent', render: (r) => fmtInr(r.total_contingent_inr) },
    { key: 'next_review_min', header: 'Earliest Review', render: (r) => fmtDate(r.next_review_min) },
  ];

  const upcomingCols: Column<UpcomingReviewRow>[] = [
    { key: 'instrument_code', header: 'Code' },
    { key: 'instrument_title', header: 'Title' },
    { key: 'instrument_type', header: 'Type' },
    { key: 'next_review_due', header: 'Review Due' },
    { key: 'days_to_review', header: 'Days', render: (r) => fmtNum(r.days_to_review) },
    { key: 'review_cadence', header: 'Cadence' },
    { key: 'custodian_location', header: 'Custodian' },
  ];

  const conflictCols: Column<ConflictRow>[] = [
    { key: 'conflict_flag', header: 'Conflict Flag' },
    { key: 'designation_count', header: 'Count', render: (r) => fmtNum(r.designation_count) },
    { key: 'total_value_at_risk_inr', header: 'Value At Risk', render: (r) => fmtInr(r.total_value_at_risk_inr) },
    { key: 'active_count', header: 'Active', render: (r) => fmtNum(r.active_count) },
    { key: 'contingent_count', header: 'Contingent', render: (r) => fmtNum(r.contingent_count) },
  ];

  const aggregateCols: Column<AggregateRow>[] = [
    { key: 'relationship', header: 'Relationship' },
    { key: 'asset_class', header: 'Asset Class' },
    { key: 'designation_count', header: 'Designations', render: (r) => fmtNum(r.designation_count) },
    { key: 'total_share_inr', header: 'Total Share', render: (r) => fmtInr(r.total_share_inr) },
    { key: 'weighted_share_pct', header: 'Avg Share %', render: (r) => `${fmtNum(r.weighted_share_pct)}%` },
  ];

  const mismatchCols: Column<MismatchRow>[] = [
    { key: 'instrument_code', header: 'Instrument' },
    { key: 'instrument_type', header: 'Type' },
    { key: 'beneficiary_alias', header: 'Beneficiary' },
    { key: 'asset_class', header: 'Asset Class' },
    { key: 'share_percentage', header: 'Share %', render: (r) => `${fmtNum(r.share_percentage)}%` },
    { key: 'share_value_inr', header: 'Share Value', render: (r) => fmtInr(r.share_value_inr) },
    { key: 'conflict_flag', header: 'Conflict' },
    { key: 'status', header: 'Status' },
  ];

  const custodianCols: Column<CustodianRow>[] = [
    { key: 'custodian_location', header: 'Custodian Location' },
    { key: 'instrument_count', header: 'Instruments', render: (r) => fmtNum(r.instrument_count) },
    { key: 'total_value_under_custody_inr', header: 'Value Under Custody', render: (r) => fmtInr(r.total_value_under_custody_inr) },
    { key: 'oldest_signed_on', header: 'Oldest Signed', render: (r) => fmtDate(r.oldest_signed_on) },
    { key: 'governing_laws_covered', header: 'Governing Laws' },
  ];

  const digitalCols: Column<DigitalAssetRow>[] = [
    { key: 'beneficiary_alias', header: 'Beneficiary' },
    { key: 'relationship', header: 'Relationship' },
    { key: 'asset_class', header: 'Asset Class' },
    { key: 'designation_role', header: 'Role' },
    { key: 'share_value_inr', header: 'Value', render: (r) => fmtInr(r.share_value_inr) },
    { key: 'conflict_flag', header: 'Conflict' },
    { key: 'status', header: 'Status' },
    { key: 'next_communication_due', header: 'Next Comm', render: (r) => fmtDate(r.next_communication_due) },
  ];

  const commGapCols: Column<CommGapRow>[] = [
    { key: 'beneficiary_alias', header: 'Beneficiary' },
    { key: 'relationship', header: 'Relationship' },
    { key: 'designation_role', header: 'Role' },
    { key: 'last_communicated_on', header: 'Last Comm', render: (r) => fmtDate(r.last_communicated_on) },
    { key: 'next_communication_due', header: 'Next Due', render: (r) => fmtDate(r.next_communication_due) },
    { key: 'days_since_last', header: 'Days Since', render: (r) => fmtNum(r.days_since_last) },
    { key: 'days_to_next', header: 'Days To Next', render: (r) => fmtNum(r.days_to_next) },
    { key: 'conflict_flag', header: 'Conflict' },
  ];

  return (
    <main className="p-6 space-y-8 max-w-7xl mx-auto">
      <header>
        <h1 className="text-2xl font-bold">Founder Family Office Estate Audit (r3133)</h1>
        <p className="text-sm text-gray-600 mt-1">
          Quarterly strategic audit of will, living trust, beneficiary designations, insurance nominees,
          guardianship, digital-asset access, trustee structure, and review cadence. Founder-gated.
        </p>
      </header>

      <section>
        <h2 className="text-lg font-semibold mb-2">Instrument Rollup by Type and Execution Status</h2>
        <DataTable
          rows={rollupRows}
          columns={rollupCols}
          emptyMessage="No estate instruments tracked yet."
          rowKey={(r, i) => String(`${r.instrument_type}-${r.execution_status}-${i}`)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Upcoming Reviews (next 180 days)</h2>
        <DataTable
          rows={upcomingRows}
          columns={upcomingCols}
          emptyMessage="No reviews due in next 180 days."
          rowKey={(r, i) => String(r.instrument_code ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Beneficiary Conflict Heatmap</h2>
        <DataTable
          rows={conflictRows}
          columns={conflictCols}
          emptyMessage="No conflicts recorded."
          rowKey={(r, i) => String(r.conflict_flag ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Beneficiary Aggregate by Relationship x Asset Class</h2>
        <DataTable
          rows={aggregateRows}
          columns={aggregateCols}
          emptyMessage="No beneficiary designations."
          rowKey={(r, i) => String(`${r.relationship}-${r.asset_class}-${i}`)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Nominee vs Will Mismatches & FEMA / Guardian Gaps</h2>
        <DataTable
          rows={mismatchRows}
          columns={mismatchCols}
          emptyMessage="No mismatches detected."
          rowKey={(r, i) => String(`${r.instrument_code}-${r.beneficiary_alias}-${i}`)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Custodian Distribution Snapshot</h2>
        <DataTable
          rows={custodianRows}
          columns={custodianCols}
          emptyMessage="No custodians on record."
          rowKey={(r, i) => String(r.custodian_location ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Digital-Asset Agent & Trustee Coverage</h2>
        <DataTable
          rows={digitalRows}
          columns={digitalCols}
          emptyMessage="No digital-asset agents designated."
          rowKey={(r, i) => String(`${r.beneficiary_alias}-${r.asset_class}-${i}`)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Communication Cadence Gaps</h2>
        <DataTable
          rows={commGapRows}
          columns={commGapCols}
          emptyMessage="No beneficiary communications tracked."
          rowKey={(r, i) => String(`${r.beneficiary_alias}-${r.designation_role}-${i}`)}
        />
      </section>
    </main>
  );
}
