import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type ChainRow = {
  chain_code: string;
  chain_name: string;
  region: string;
  hospital_count: number;
  asset_total: number;
  asset_tagged: number;
  tag_coverage_pct: number | null;
  tag_kind: string;
  audit_status: string;
  compliance_score: number;
  gap_count: number;
  high_severity_gaps: number;
};

type KpiRow = {
  total_chains: number;
  total_hospitals: number;
  total_assets: number;
  total_tagged: number;
  overall_coverage_pct: number | null;
  avg_compliance: number | null;
  passed_chains: number;
  failed_chains: number;
  open_gap_actions: number;
  high_severity_gaps_total: number;
};

type TagKindRow = {
  tag_kind: string;
  chain_count: number;
  asset_total: number;
  asset_tagged: number;
  coverage_pct: number | null;
  avg_compliance: number | null;
};

type AuditPipelineRow = {
  audit_status: string;
  chain_count: number;
  hospital_count: number;
  asset_total: number;
  avg_compliance: number | null;
};

type GapRow = {
  chain_code: string;
  chain_name: string;
  gap_category: string;
  severity: string;
  affected_assets: number;
  close_action: string;
  owner_role: string;
  due_date: string;
  status: string;
  cost_estimate_rupees: number;
};

type RegionRow = {
  region: string;
  chain_count: number;
  hospital_count: number;
  asset_total: number;
  asset_tagged: number;
  coverage_pct: number | null;
  avg_compliance: number | null;
  total_gaps: number;
};

type OwnerRow = {
  owner_role: string;
  open_count: number;
  total_count: number;
  total_assets_affected: number;
  total_cost_rupees: number;
  critical_count: number;
};

type UpcomingRow = {
  chain_code: string;
  chain_name: string;
  region: string;
  next_audit_due: string;
  days_until: number;
  current_status: string;
  auditor_name: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [chainRes, kpiRes, tagRes, auditRes, gapRes, regionRes, ownerRes, upcomingRes] = await Promise.all([
    supabase.rpc('rpc_r2835_chain_overview'),
    supabase.rpc('rpc_r2835_kpi_summary'),
    supabase.rpc('rpc_r2835_tag_kind_breakdown'),
    supabase.rpc('rpc_r2835_audit_pipeline'),
    supabase.rpc('rpc_r2835_open_gap_actions'),
    supabase.rpc('rpc_r2835_region_rollup'),
    supabase.rpc('rpc_r2835_owner_workload'),
    supabase.rpc('rpc_r2835_upcoming_audits'),
  ]);

  const chains = (chainRes.data ?? []) as ChainRow[];
  const kpi = ((kpiRes.data ?? [])[0] ?? null) as KpiRow | null;
  const tagKinds = (tagRes.data ?? []) as TagKindRow[];
  const audits = (auditRes.data ?? []) as AuditPipelineRow[];
  const gaps = (gapRes.data ?? []) as GapRow[];
  const regions = (regionRes.data ?? []) as RegionRow[];
  const owners = (ownerRes.data ?? []) as OwnerRow[];
  const upcoming = (upcomingRes.data ?? []) as UpcomingRow[];

  const fmt = (n: number | null | undefined) =>
    n === null || n === undefined ? '—' : new Intl.NumberFormat('en-IN').format(n);
  const fmtPct = (n: number | null | undefined) =>
    n === null || n === undefined ? '—' : `${Number(n).toFixed(2)}%`;
  const fmtRupees = (n: number | null | undefined) =>
    n === null || n === undefined ? '—' : `₹${new Intl.NumberFormat('en-IN').format(n)}`;

  return (
    <div className="p-6 space-y-6">
      <div>
        <h1 className="text-2xl font-bold">Hospital Chain Quarterly Asset-Tagging Compliance</h1>
        <p className="text-sm text-gray-600 mt-1">
          Round r2835 — chain × asset × tag kind × compliance × audit × gap × close action.
          Compliance scores at or above 95% pass; below 80% trigger escalation.
        </p>
      </div>

      <div className="grid grid-cols-2 md:grid-cols-5 gap-3">
        <div className="rounded-lg border p-3">
          <div className="text-xs text-gray-500">Chains</div>
          <div className="text-xl font-semibold">{fmt(kpi?.total_chains)}</div>
        </div>
        <div className="rounded-lg border p-3">
          <div className="text-xs text-gray-500">Hospitals</div>
          <div className="text-xl font-semibold">{fmt(kpi?.total_hospitals)}</div>
        </div>
        <div className="rounded-lg border p-3">
          <div className="text-xs text-gray-500">Assets</div>
          <div className="text-xl font-semibold">{fmt(kpi?.total_assets)}</div>
        </div>
        <div className="rounded-lg border p-3">
          <div className="text-xs text-gray-500">Coverage</div>
          <div className="text-xl font-semibold">{fmtPct(kpi?.overall_coverage_pct)}</div>
        </div>
        <div className="rounded-lg border p-3">
          <div className="text-xs text-gray-500">Avg compliance</div>
          <div className="text-xl font-semibold">{fmtPct(kpi?.avg_compliance)}</div>
        </div>
        <div className="rounded-lg border p-3">
          <div className="text-xs text-gray-500">Passed chains</div>
          <div className="text-xl font-semibold text-green-700">{fmt(kpi?.passed_chains)}</div>
        </div>
        <div className="rounded-lg border p-3">
          <div className="text-xs text-gray-500">Failed chains</div>
          <div className="text-xl font-semibold text-red-700">{fmt(kpi?.failed_chains)}</div>
        </div>
        <div className="rounded-lg border p-3">
          <div className="text-xs text-gray-500">Open gap actions</div>
          <div className="text-xl font-semibold">{fmt(kpi?.open_gap_actions)}</div>
        </div>
        <div className="rounded-lg border p-3">
          <div className="text-xs text-gray-500">High-severity gaps</div>
          <div className="text-xl font-semibold">{fmt(kpi?.high_severity_gaps_total)}</div>
        </div>
        <div className="rounded-lg border p-3">
          <div className="text-xs text-gray-500">Tagged assets</div>
          <div className="text-xl font-semibold">{fmt(kpi?.total_tagged)}</div>
        </div>
      </div>

      <section>
        <h2 className="text-lg font-semibold mb-2">Chain compliance overview</h2>
        <DataTable
          rows={chains}
          rowKey={(r, i) => String((r as ChainRow).chain_code ?? i)}
          emptyMessage="No data"
          columns={[
            { key: 'chain_code', header: 'Code', render: (r: ChainRow) => r.chain_code },
            { key: 'chain_name', header: 'Chain', render: (r: ChainRow) => r.chain_name },
            { key: 'region', header: 'Region', render: (r: ChainRow) => r.region },
            { key: 'hospital_count', header: 'Hospitals', render: (r: ChainRow) => fmt(r.hospital_count) },
            { key: 'asset_total', header: 'Assets', render: (r: ChainRow) => fmt(r.asset_total) },
            { key: 'tag_coverage_pct', header: 'Coverage', render: (r: ChainRow) => fmtPct(r.tag_coverage_pct) },
            { key: 'tag_kind', header: 'Tag kind', render: (r: ChainRow) => r.tag_kind },
            { key: 'audit_status', header: 'Audit', render: (r: ChainRow) => r.audit_status },
            { key: 'compliance_score', header: 'Score', render: (r: ChainRow) => fmtPct(r.compliance_score) },
            { key: 'gap_count', header: 'Gaps', render: (r: ChainRow) => fmt(r.gap_count) },
            { key: 'high_severity_gaps', header: 'High-sev', render: (r: ChainRow) => fmt(r.high_severity_gaps) },
          ]}
        />
      </section>

      <section className="grid grid-cols-1 md:grid-cols-2 gap-4">
        <div>
          <h2 className="text-lg font-semibold mb-2">Tag kind breakdown</h2>
          <DataTable
            rows={tagKinds}
            rowKey={(r, i) => String((r as TagKindRow).tag_kind ?? i)}
            emptyMessage="No data"
            columns={[
              { key: 'tag_kind', header: 'Tag', render: (r: TagKindRow) => r.tag_kind },
              { key: 'chain_count', header: 'Chains', render: (r: TagKindRow) => fmt(r.chain_count) },
              { key: 'asset_tagged', header: 'Tagged', render: (r: TagKindRow) => fmt(r.asset_tagged) },
              { key: 'coverage_pct', header: 'Coverage', render: (r: TagKindRow) => fmtPct(r.coverage_pct) },
              { key: 'avg_compliance', header: 'Avg score', render: (r: TagKindRow) => fmtPct(r.avg_compliance) },
            ]}
          />
        </div>
        <div>
          <h2 className="text-lg font-semibold mb-2">Audit pipeline</h2>
          <DataTable
            rows={audits}
            rowKey={(r, i) => String((r as AuditPipelineRow).audit_status ?? i)}
            emptyMessage="No data"
            columns={[
              { key: 'audit_status', header: 'Status', render: (r: AuditPipelineRow) => r.audit_status },
              { key: 'chain_count', header: 'Chains', render: (r: AuditPipelineRow) => fmt(r.chain_count) },
              { key: 'hospital_count', header: 'Hospitals', render: (r: AuditPipelineRow) => fmt(r.hospital_count) },
              { key: 'asset_total', header: 'Assets', render: (r: AuditPipelineRow) => fmt(r.asset_total) },
              { key: 'avg_compliance', header: 'Avg score', render: (r: AuditPipelineRow) => fmtPct(r.avg_compliance) },
            ]}
          />
        </div>
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Open gap close actions</h2>
        <DataTable
          rows={gaps}
          rowKey={(r, i) => String(i)}
          emptyMessage="No data"
          columns={[
            { key: 'chain_code', header: 'Chain', render: (r: GapRow) => r.chain_code },
            { key: 'gap_category', header: 'Category', render: (r: GapRow) => r.gap_category },
            { key: 'severity', header: 'Severity', render: (r: GapRow) => r.severity },
            { key: 'affected_assets', header: 'Assets', render: (r: GapRow) => fmt(r.affected_assets) },
            { key: 'close_action', header: 'Close action', render: (r: GapRow) => r.close_action },
            { key: 'owner_role', header: 'Owner', render: (r: GapRow) => r.owner_role },
            { key: 'due_date', header: 'Due', render: (r: GapRow) => r.due_date },
            { key: 'status', header: 'Status', render: (r: GapRow) => r.status },
            { key: 'cost_estimate_rupees', header: 'Cost', render: (r: GapRow) => fmtRupees(r.cost_estimate_rupees) },
          ]}
        />
      </section>

      <section className="grid grid-cols-1 md:grid-cols-2 gap-4">
        <div>
          <h2 className="text-lg font-semibold mb-2">Region rollup</h2>
          <DataTable
            rows={regions}
            rowKey={(r, i) => String((r as RegionRow).region ?? i)}
            emptyMessage="No data"
            columns={[
              { key: 'region', header: 'Region', render: (r: RegionRow) => r.region },
              { key: 'chain_count', header: 'Chains', render: (r: RegionRow) => fmt(r.chain_count) },
              { key: 'hospital_count', header: 'Hospitals', render: (r: RegionRow) => fmt(r.hospital_count) },
              { key: 'coverage_pct', header: 'Coverage', render: (r: RegionRow) => fmtPct(r.coverage_pct) },
              { key: 'avg_compliance', header: 'Avg score', render: (r: RegionRow) => fmtPct(r.avg_compliance) },
              { key: 'total_gaps', header: 'Gaps', render: (r: RegionRow) => fmt(r.total_gaps) },
            ]}
          />
        </div>
        <div>
          <h2 className="text-lg font-semibold mb-2">Owner workload</h2>
          <DataTable
            rows={owners}
            rowKey={(r, i) => String((r as OwnerRow).owner_role ?? i)}
            emptyMessage="No data"
            columns={[
              { key: 'owner_role', header: 'Owner', render: (r: OwnerRow) => r.owner_role },
              { key: 'open_count', header: 'Open', render: (r: OwnerRow) => fmt(r.open_count) },
              { key: 'total_count', header: 'Total', render: (r: OwnerRow) => fmt(r.total_count) },
              { key: 'total_assets_affected', header: 'Assets', render: (r: OwnerRow) => fmt(r.total_assets_affected) },
              { key: 'total_cost_rupees', header: 'Cost', render: (r: OwnerRow) => fmtRupees(r.total_cost_rupees) },
              { key: 'critical_count', header: 'Critical', render: (r: OwnerRow) => fmt(r.critical_count) },
            ]}
          />
        </div>
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Upcoming audits</h2>
        <DataTable
          rows={upcoming}
          rowKey={(r, i) => String((r as UpcomingRow).chain_code ?? i)}
          emptyMessage="No data"
          columns={[
            { key: 'chain_code', header: 'Code', render: (r: UpcomingRow) => r.chain_code },
            { key: 'chain_name', header: 'Chain', render: (r: UpcomingRow) => r.chain_name },
            { key: 'region', header: 'Region', render: (r: UpcomingRow) => r.region },
            { key: 'next_audit_due', header: 'Due', render: (r: UpcomingRow) => r.next_audit_due },
            { key: 'days_until', header: 'Days', render: (r: UpcomingRow) => fmt(r.days_until) },
            { key: 'current_status', header: 'Status', render: (r: UpcomingRow) => r.current_status },
            { key: 'auditor_name', header: 'Auditor', render: (r: UpcomingRow) => r.auditor_name ?? '—' },
          ]}
        />
      </section>
    </div>
  );
}
