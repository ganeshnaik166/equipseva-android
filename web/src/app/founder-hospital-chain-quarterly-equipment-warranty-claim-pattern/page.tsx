import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type KpiRow = {
  total_claims: number;
  total_approved: number;
  total_rejected: number;
  total_pending: number;
  overall_success_pct: number | null;
  total_claim_value: number;
  avg_resolution_days: number | null;
  watchlist_oem_count: number;
  tracked_chains: number;
};

type ChainRow = {
  chain_name: string;
  total_claims: number;
  approved: number;
  rejected: number;
  pending: number;
  success_rate_pct: number | null;
  total_value_rupees: number;
};

type QuarterRow = {
  quarter: string;
  claim_count: number;
  approved: number;
  avg_resolution_days: number | null;
  total_value: number;
};

type CauseRow = {
  primary_failure_cause: string;
  claim_count: number;
  approved: number;
  success_rate_pct: number | null;
  avg_resolution_days: number | null;
};

type OemRow = {
  oem_name: string;
  asset_category: string;
  sla_response_hours: number;
  actual_avg_response_hours: number;
  approval_rate_pct: number;
  first_resolution_pct: number;
  parts_availability_score: number;
  escalation_count: number;
  rating: string;
};

type CategoryRow = {
  asset_category: string;
  claim_count: number;
  approved: number;
  rejected: number;
  success_rate_pct: number | null;
  avg_value_per_claim: number;
};

type WatchRow = {
  oem_name: string;
  asset_category: string;
  sla_breach_hours: number;
  approval_rate_pct: number;
  escalation_count: number;
  rating: string;
};

function fmtNum(n: number | null | undefined): string {
  if (n === null || n === undefined) return '-';
  return new Intl.NumberFormat('en-IN').format(n);
}

function fmtRupees(n: number | null | undefined): string {
  if (n === null || n === undefined) return '-';
  return '₹' + new Intl.NumberFormat('en-IN').format(n);
}

function fmtPct(n: number | null | undefined): string {
  if (n === null || n === undefined) return '-';
  return `${n}%`;
}

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [kpiRes, chainRes, quarterRes, causeRes, oemRes, categoryRes, watchRes] = await Promise.all([
    supabase.rpc('r2851_kpi_overview'),
    supabase.rpc('r2851_chain_claim_summary'),
    supabase.rpc('r2851_quarter_trend'),
    supabase.rpc('r2851_failure_cause_breakdown'),
    supabase.rpc('r2851_oem_response_table'),
    supabase.rpc('r2851_asset_category_pattern'),
    supabase.rpc('r2851_watchlist_oems'),
  ]);

  const kpi: KpiRow | null = (kpiRes.data as KpiRow[] | null)?.[0] ?? null;
  const chains: ChainRow[] = (chainRes.data as ChainRow[] | null) ?? [];
  const quarters: QuarterRow[] = (quarterRes.data as QuarterRow[] | null) ?? [];
  const causes: CauseRow[] = (causeRes.data as CauseRow[] | null) ?? [];
  const oems: OemRow[] = (oemRes.data as OemRow[] | null) ?? [];
  const categories: CategoryRow[] = (categoryRes.data as CategoryRow[] | null) ?? [];
  const watchlist: WatchRow[] = (watchRes.data as WatchRow[] | null) ?? [];

  return (
    <div className="p-6 space-y-6">
      <header className="space-y-1">
        <h1 className="text-2xl font-semibold">Hospital Chain Quarterly Warranty Claim Pattern</h1>
        <p className="text-sm text-gray-600">
          Round r2851 · chain × asset × warranty claim × cause × OEM response × success rate
        </p>
      </header>

      <section className="grid grid-cols-2 md:grid-cols-4 gap-3">
        <div className="rounded-lg border p-4">
          <div className="text-xs text-gray-500">Total Claims</div>
          <div className="text-xl font-semibold">{fmtNum(kpi?.total_claims)}</div>
        </div>
        <div className="rounded-lg border p-4">
          <div className="text-xs text-gray-500">Approved</div>
          <div className="text-xl font-semibold">{fmtNum(kpi?.total_approved)}</div>
        </div>
        <div className="rounded-lg border p-4">
          <div className="text-xs text-gray-500">Rejected</div>
          <div className="text-xl font-semibold">{fmtNum(kpi?.total_rejected)}</div>
        </div>
        <div className="rounded-lg border p-4">
          <div className="text-xs text-gray-500">Pending</div>
          <div className="text-xl font-semibold">{fmtNum(kpi?.total_pending)}</div>
        </div>
        <div className="rounded-lg border p-4">
          <div className="text-xs text-gray-500">Overall Success</div>
          <div className="text-xl font-semibold">{fmtPct(kpi?.overall_success_pct ?? null)}</div>
        </div>
        <div className="rounded-lg border p-4">
          <div className="text-xs text-gray-500">Total Claim Value</div>
          <div className="text-xl font-semibold">{fmtRupees(kpi?.total_claim_value)}</div>
        </div>
        <div className="rounded-lg border p-4">
          <div className="text-xs text-gray-500">Avg Resolution Days</div>
          <div className="text-xl font-semibold">{kpi?.avg_resolution_days ?? '-'}</div>
        </div>
        <div className="rounded-lg border p-4">
          <div className="text-xs text-gray-500">Watchlist OEMs / Chains</div>
          <div className="text-xl font-semibold">
            {fmtNum(kpi?.watchlist_oem_count)} / {fmtNum(kpi?.tracked_chains)}
          </div>
        </div>
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-semibold">Chain Claim Summary</h2>
        <DataTable
          rows={chains}
          columns={[
            { key: 'chain_name', header: 'Chain', render: (r: ChainRow) => r.chain_name },
            { key: 'total_claims', header: 'Claims', render: (r: ChainRow) => fmtNum(r.total_claims) },
            { key: 'approved', header: 'Approved', render: (r: ChainRow) => fmtNum(r.approved) },
            { key: 'rejected', header: 'Rejected', render: (r: ChainRow) => fmtNum(r.rejected) },
            { key: 'pending', header: 'Pending', render: (r: ChainRow) => fmtNum(r.pending) },
            { key: 'success_rate_pct', header: 'Success', render: (r: ChainRow) => fmtPct(r.success_rate_pct) },
            { key: 'total_value_rupees', header: 'Total Value', render: (r: ChainRow) => fmtRupees(r.total_value_rupees) },
          ]}
          emptyMessage="No data"
          rowKey={(r: ChainRow, i: number) => String(r.chain_name ?? i)}
        />
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-semibold">Quarterly Trend</h2>
        <DataTable
          rows={quarters}
          columns={[
            { key: 'quarter', header: 'Quarter', render: (r: QuarterRow) => r.quarter },
            { key: 'claim_count', header: 'Claims', render: (r: QuarterRow) => fmtNum(r.claim_count) },
            { key: 'approved', header: 'Approved', render: (r: QuarterRow) => fmtNum(r.approved) },
            { key: 'avg_resolution_days', header: 'Avg Resolution Days', render: (r: QuarterRow) => r.avg_resolution_days ?? '-' },
            { key: 'total_value', header: 'Total Value', render: (r: QuarterRow) => fmtRupees(r.total_value) },
          ]}
          emptyMessage="No data"
          rowKey={(r: QuarterRow, i: number) => String(r.quarter ?? i)}
        />
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-semibold">Failure Cause Breakdown</h2>
        <p className="text-xs text-gray-500">Claims grouped by primary failure cause — success rate & resolution time per cause.</p>
        <DataTable
          rows={causes}
          columns={[
            { key: 'primary_failure_cause', header: 'Cause', render: (r: CauseRow) => r.primary_failure_cause },
            { key: 'claim_count', header: 'Claims', render: (r: CauseRow) => fmtNum(r.claim_count) },
            { key: 'approved', header: 'Approved', render: (r: CauseRow) => fmtNum(r.approved) },
            { key: 'success_rate_pct', header: 'Success', render: (r: CauseRow) => fmtPct(r.success_rate_pct) },
            { key: 'avg_resolution_days', header: 'Avg Days', render: (r: CauseRow) => r.avg_resolution_days ?? '-' },
          ]}
          emptyMessage="No data"
          rowKey={(r: CauseRow, i: number) => String(r.primary_failure_cause ?? i)}
        />
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-semibold">Asset Category Pattern</h2>
        <DataTable
          rows={categories}
          columns={[
            { key: 'asset_category', header: 'Category', render: (r: CategoryRow) => r.asset_category },
            { key: 'claim_count', header: 'Claims', render: (r: CategoryRow) => fmtNum(r.claim_count) },
            { key: 'approved', header: 'Approved', render: (r: CategoryRow) => fmtNum(r.approved) },
            { key: 'rejected', header: 'Rejected', render: (r: CategoryRow) => fmtNum(r.rejected) },
            { key: 'success_rate_pct', header: 'Success', render: (r: CategoryRow) => fmtPct(r.success_rate_pct) },
            { key: 'avg_value_per_claim', header: 'Avg Value / Claim', render: (r: CategoryRow) => fmtRupees(r.avg_value_per_claim) },
          ]}
          emptyMessage="No data"
          rowKey={(r: CategoryRow, i: number) => String(r.asset_category ?? i)}
        />
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-semibold">OEM Response Benchmarks</h2>
        <p className="text-xs text-gray-500">SLA vs actual response — approval rate &gt;= 80% is healthy; escalations &gt;= 10 means watchlist.</p>
        <DataTable
          rows={oems}
          columns={[
            { key: 'oem_name', header: 'OEM', render: (r: OemRow) => r.oem_name },
            { key: 'asset_category', header: 'Category', render: (r: OemRow) => r.asset_category },
            { key: 'sla_response_hours', header: 'SLA (hrs)', render: (r: OemRow) => fmtNum(r.sla_response_hours) },
            { key: 'actual_avg_response_hours', header: 'Actual (hrs)', render: (r: OemRow) => r.actual_avg_response_hours },
            { key: 'approval_rate_pct', header: 'Approval', render: (r: OemRow) => fmtPct(r.approval_rate_pct) },
            { key: 'first_resolution_pct', header: 'First Res', render: (r: OemRow) => fmtPct(r.first_resolution_pct) },
            { key: 'parts_availability_score', header: 'Parts Score', render: (r: OemRow) => r.parts_availability_score },
            { key: 'escalation_count', header: 'Escalations', render: (r: OemRow) => fmtNum(r.escalation_count) },
            { key: 'rating', header: 'Rating', render: (r: OemRow) => r.rating },
          ]}
          emptyMessage="No data"
          rowKey={(r: OemRow, i: number) => String(`${r.oem_name}-${r.asset_category}` ?? i)}
        />
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-semibold">Watchlist OEMs (SLA breach or poor rating)</h2>
        <DataTable
          rows={watchlist}
          columns={[
            { key: 'oem_name', header: 'OEM', render: (r: WatchRow) => r.oem_name },
            { key: 'asset_category', header: 'Category', render: (r: WatchRow) => r.asset_category },
            { key: 'sla_breach_hours', header: 'SLA Breach (hrs)', render: (r: WatchRow) => r.sla_breach_hours },
            { key: 'approval_rate_pct', header: 'Approval', render: (r: WatchRow) => fmtPct(r.approval_rate_pct) },
            { key: 'escalation_count', header: 'Escalations', render: (r: WatchRow) => fmtNum(r.escalation_count) },
            { key: 'rating', header: 'Rating', render: (r: WatchRow) => r.rating },
          ]}
          emptyMessage="No data"
          rowKey={(r: WatchRow, i: number) => String(`${r.oem_name}-${r.asset_category}` ?? i)}
        />
      </section>
    </div>
  );
}
