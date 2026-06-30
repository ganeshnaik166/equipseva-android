import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type ResidencySummary = {
  id?: string;
  audit_quarter: string;
  total_profiles: number;
  dual_or_deemed: number;
  high_pe_risk: number;
  avg_days_primary: number | null;
};

type JurisdictionRow = {
  id?: string;
  jurisdiction: string;
  engineer_count: number;
  high_risk_count: number;
  total_days_present: number;
};

type CategoryRow = {
  id?: string;
  finding_category: string;
  open_count: number;
  critical_count: number;
  total_exposure_usd: number | null;
};

type CriticalRow = {
  id?: string;
  engineer_label: string;
  finding_title: string;
  severity: string;
  status: string;
  estimated_exposure_usd: number | null;
  due_date: string | null;
};

type OwnershipRow = {
  id?: string;
  remediation_owner: string;
  open_findings: number;
  total_exposure_usd: number | null;
  earliest_due: string | null;
};

type TreatyRow = {
  id?: string;
  treaty_tiebreaker_position: string;
  profile_count: number;
  high_pe_count: number;
};

type BurndownRow = {
  id?: string;
  audit_quarter: string;
  total_findings: number;
  closed_findings: number;
  open_exposure_usd: number | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    summaryRes,
    jurisdictionRes,
    categoryRes,
    criticalRes,
    ownershipRes,
    treatyRes,
    burndownRes,
  ] = await Promise.all([
    supabase.rpc('get_tax_residency_summary_r3089'),
    supabase.rpc('get_jurisdiction_concentration_r3089'),
    supabase.rpc('get_findings_by_category_r3089'),
    supabase.rpc('get_critical_findings_r3089'),
    supabase.rpc('get_remediation_ownership_r3089'),
    supabase.rpc('get_treaty_position_breakdown_r3089'),
    supabase.rpc('get_quarterly_burndown_r3089'),
  ]);

  const summary: ResidencySummary[] = (summaryRes.data ?? []) as ResidencySummary[];
  const jurisdictions: JurisdictionRow[] = (jurisdictionRes.data ?? []) as JurisdictionRow[];
  const categories: CategoryRow[] = (categoryRes.data ?? []) as CategoryRow[];
  const critical: CriticalRow[] = (criticalRes.data ?? []) as CriticalRow[];
  const ownership: OwnershipRow[] = (ownershipRes.data ?? []) as OwnershipRow[];
  const treaty: TreatyRow[] = (treatyRes.data ?? []) as TreatyRow[];
  const burndown: BurndownRow[] = (burndownRes.data ?? []) as BurndownRow[];

  const summaryCols: Column<ResidencySummary>[] = [
    { key: 'audit_quarter', header: 'Quarter' },
    { key: 'total_profiles', header: 'Profiles' },
    { key: 'dual_or_deemed', header: 'Dual / Deemed' },
    { key: 'high_pe_risk', header: 'High PE Risk' },
    { key: 'avg_days_primary', header: 'Avg Days Primary' },
  ];

  const jurisdictionCols: Column<JurisdictionRow>[] = [
    { key: 'jurisdiction', header: 'Jurisdiction' },
    { key: 'engineer_count', header: 'Engineers' },
    { key: 'high_risk_count', header: 'High Risk' },
    { key: 'total_days_present', header: 'Total Days Present' },
  ];

  const categoryCols: Column<CategoryRow>[] = [
    { key: 'finding_category', header: 'Category' },
    { key: 'open_count', header: 'Open' },
    { key: 'critical_count', header: 'Critical' },
    {
      key: 'total_exposure_usd',
      header: 'Open Exposure (USD)',
      render: (r) => (r.total_exposure_usd ?? 0).toLocaleString(),
    },
  ];

  const criticalCols: Column<CriticalRow>[] = [
    { key: 'engineer_label', header: 'Engineer' },
    { key: 'finding_title', header: 'Finding' },
    { key: 'severity', header: 'Severity' },
    { key: 'status', header: 'Status' },
    {
      key: 'estimated_exposure_usd',
      header: 'Exposure (USD)',
      render: (r) => (r.estimated_exposure_usd ?? 0).toLocaleString(),
    },
    { key: 'due_date', header: 'Due' },
  ];

  const ownershipCols: Column<OwnershipRow>[] = [
    { key: 'remediation_owner', header: 'Owner' },
    { key: 'open_findings', header: 'Open' },
    {
      key: 'total_exposure_usd',
      header: 'Open Exposure (USD)',
      render: (r) => (r.total_exposure_usd ?? 0).toLocaleString(),
    },
    { key: 'earliest_due', header: 'Earliest Due' },
  ];

  const treatyCols: Column<TreatyRow>[] = [
    { key: 'treaty_tiebreaker_position', header: 'Treaty Position' },
    { key: 'profile_count', header: 'Profiles' },
    { key: 'high_pe_count', header: 'High PE' },
  ];

  const burndownCols: Column<BurndownRow>[] = [
    { key: 'audit_quarter', header: 'Quarter' },
    { key: 'total_findings', header: 'Total Findings' },
    { key: 'closed_findings', header: 'Closed' },
    {
      key: 'open_exposure_usd',
      header: 'Open Exposure (USD)',
      render: (r) => (r.open_exposure_usd ?? 0).toLocaleString(),
    },
  ];

  return (
    <div className="p-6 space-y-8">
      <header>
        <h1 className="text-2xl font-bold">
          Quarterly Strategic Engineer-Founder Cross-Border Tax-Residency Compliance Audit
        </h1>
        <p className="text-sm text-gray-600 mt-1">
          Founder-only view. Tracks engineer & founder tax residency across jurisdictions,
          treaty tiebreaker positions, PE exposure, and quarterly remediation burndown.
        </p>
      </header>

      <section>
        <h2 className="text-lg font-semibold mb-2">Residency Summary by Quarter</h2>
        <DataTable
          rows={summary}
          columns={summaryCols}
          emptyMessage="No residency summary."
          rowKey={(r, i) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Jurisdiction Concentration</h2>
        <DataTable
          rows={jurisdictions}
          columns={jurisdictionCols}
          emptyMessage="No jurisdiction data."
          rowKey={(r, i) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Findings by Category</h2>
        <DataTable
          rows={categories}
          columns={categoryCols}
          emptyMessage="No findings."
          rowKey={(r, i) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Critical & High-Severity Findings</h2>
        <DataTable
          rows={critical}
          columns={criticalCols}
          emptyMessage="No critical findings."
          rowKey={(r, i) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Remediation Ownership Load</h2>
        <DataTable
          rows={ownership}
          columns={ownershipCols}
          emptyMessage="No remediation load."
          rowKey={(r, i) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Treaty Tiebreaker Positions</h2>
        <DataTable
          rows={treaty}
          columns={treatyCols}
          emptyMessage="No treaty positions."
          rowKey={(r, i) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Quarterly Burndown</h2>
        <DataTable
          rows={burndown}
          columns={burndownCols}
          emptyMessage="No burndown data."
          rowKey={(r, i) => String(r.id ?? i)}
        />
      </section>
    </div>
  );
}
