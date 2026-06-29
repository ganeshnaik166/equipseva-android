import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable } from '@/components/DataTable';
import type { Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type PortfolioRow = {
  jurisdiction: string;
  total_filings: number;
  granted_count: number;
  filed_count: number;
  draft_count: number;
  abandoned_count: number;
  total_legal_spend_rupees: number;
};

type DeadlineRow = {
  id: string;
  filing_code: string;
  title: string;
  jurisdiction: string;
  filing_status: string;
  examination_due_date: string | null;
  days_until_due: number;
  strategic_priority: string;
};

type HighPriorityRow = {
  id: string;
  filing_code: string;
  title: string;
  strategic_priority: string;
  blocking_competitor: string | null;
  filing_status: string;
  legal_spend_rupees: number;
};

type VaultSummaryRow = {
  audit_status: string;
  secret_count: number;
  avg_leak_risk: number;
  total_business_value_rupees: number;
};

type RotationRow = {
  id: string;
  secret_code: string;
  secret_name: string;
  access_tier: string;
  next_rotation_due: string | null;
  days_overdue: number;
  leak_risk_score: number;
  audit_status: string;
};

type CategoryRow = {
  category: string;
  secret_count: number;
  founder_only_count: number;
  avg_ndas: number;
  total_value_rupees: number;
};

type KpiRow = {
  total_filings: number;
  granted_count: number;
  p0_p1_count: number;
  total_legal_spend_rupees: number;
  total_secrets: number;
  red_secrets: number;
  founder_only_secrets: number;
  total_secret_value_rupees: number;
  avg_leak_risk: number;
  filings_due_90d: number;
};

const rupees = (n: number | null | undefined) =>
  n == null ? '-' : '₹' + Number(n).toLocaleString('en-IN');

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    portfolioRes,
    deadlinesRes,
    highPriorityRes,
    vaultSummaryRes,
    rotationRes,
    categoryRes,
    kpisRes,
  ] = await Promise.all([
    supabase.rpc('patent_portfolio_overview_r2909'),
    supabase.rpc('upcoming_patent_deadlines_r2909'),
    supabase.rpc('high_priority_filings_r2909'),
    supabase.rpc('vault_audit_summary_r2909'),
    supabase.rpc('red_secrets_needing_rotation_r2909'),
    supabase.rpc('vault_by_category_r2909'),
    supabase.rpc('quarterly_audit_kpis_r2909'),
  ]);

  const portfolio = (portfolioRes.data ?? []) as PortfolioRow[];
  const deadlines = (deadlinesRes.data ?? []) as DeadlineRow[];
  const highPriority = (highPriorityRes.data ?? []) as HighPriorityRow[];
  const vaultSummary = (vaultSummaryRes.data ?? []) as VaultSummaryRow[];
  const rotation = (rotationRes.data ?? []) as RotationRow[];
  const category = (categoryRes.data ?? []) as CategoryRow[];
  const kpis = ((kpisRes.data ?? [])[0] ?? null) as KpiRow | null;

  const portfolioCols: Column<PortfolioRow>[] = [
    { key: 'jurisdiction', header: 'Jurisdiction', render: (r) => r.jurisdiction },
    { key: 'total_filings', header: 'Total', render: (r) => r.total_filings },
    { key: 'granted_count', header: 'Granted', render: (r) => r.granted_count },
    { key: 'filed_count', header: 'Filed', render: (r) => r.filed_count },
    { key: 'draft_count', header: 'Draft', render: (r) => r.draft_count },
    { key: 'abandoned_count', header: 'Abandoned', render: (r) => r.abandoned_count },
    { key: 'total_legal_spend_rupees', header: 'Legal Spend', render: (r) => rupees(r.total_legal_spend_rupees) },
  ];

  const deadlineCols: Column<DeadlineRow>[] = [
    { key: 'filing_code', header: 'Code', render: (r) => r.filing_code },
    { key: 'title', header: 'Title', render: (r) => r.title },
    { key: 'jurisdiction', header: 'Jur', render: (r) => r.jurisdiction },
    { key: 'filing_status', header: 'Status', render: (r) => r.filing_status },
    { key: 'examination_due_date', header: 'Due Date', render: (r) => r.examination_due_date ?? '-' },
    { key: 'days_until_due', header: 'Days Left', render: (r) => r.days_until_due },
    { key: 'strategic_priority', header: 'Priority', render: (r) => r.strategic_priority },
  ];

  const highPriorityCols: Column<HighPriorityRow>[] = [
    { key: 'filing_code', header: 'Code', render: (r) => r.filing_code },
    { key: 'title', header: 'Title', render: (r) => r.title },
    { key: 'strategic_priority', header: 'Priority', render: (r) => r.strategic_priority },
    { key: 'blocking_competitor', header: 'Blocking Competitor', render: (r) => r.blocking_competitor ?? '-' },
    { key: 'filing_status', header: 'Status', render: (r) => r.filing_status },
    { key: 'legal_spend_rupees', header: 'Legal Spend', render: (r) => rupees(r.legal_spend_rupees) },
  ];

  const vaultSummaryCols: Column<VaultSummaryRow>[] = [
    { key: 'audit_status', header: 'Audit Status', render: (r) => r.audit_status },
    { key: 'secret_count', header: 'Secret Count', render: (r) => r.secret_count },
    { key: 'avg_leak_risk', header: 'Avg Leak Risk', render: (r) => r.avg_leak_risk },
    { key: 'total_business_value_rupees', header: 'Business Value', render: (r) => rupees(r.total_business_value_rupees) },
  ];

  const rotationCols: Column<RotationRow>[] = [
    { key: 'secret_code', header: 'Code', render: (r) => r.secret_code },
    { key: 'secret_name', header: 'Name', render: (r) => r.secret_name },
    { key: 'access_tier', header: 'Tier', render: (r) => r.access_tier },
    { key: 'next_rotation_due', header: 'Rotation Due', render: (r) => r.next_rotation_due ?? '-' },
    { key: 'days_overdue', header: 'Days Overdue', render: (r) => r.days_overdue },
    { key: 'leak_risk_score', header: 'Leak Risk', render: (r) => r.leak_risk_score },
    { key: 'audit_status', header: 'Status', render: (r) => r.audit_status },
  ];

  const categoryCols: Column<CategoryRow>[] = [
    { key: 'category', header: 'Category', render: (r) => r.category },
    { key: 'secret_count', header: 'Count', render: (r) => r.secret_count },
    { key: 'founder_only_count', header: 'Founder-Only', render: (r) => r.founder_only_count },
    { key: 'avg_ndas', header: 'Avg NDAs', render: (r) => r.avg_ndas },
    { key: 'total_value_rupees', header: 'Total Value', render: (r) => rupees(r.total_value_rupees) },
  ];

  return (
    <div className="p-6 space-y-6">
      <header className="space-y-1">
        <h1 className="text-2xl font-semibold">Quarterly Strategic Patent-Filing &amp; Trade-Secret Vault Audit</h1>
        <p className="text-sm text-gray-600">
          Founder-only quarterly review of patent portfolio health &amp; trade-secret vault integrity. Flags filings &lt;= 90d to deadline and secrets with leak-risk &gt;= amber.
        </p>
      </header>

      <section className="grid grid-cols-2 md:grid-cols-5 gap-3">
        <div className="rounded-lg border p-3">
          <div className="text-xs text-gray-500">Total Filings</div>
          <div className="text-xl font-semibold">{kpis?.total_filings ?? 0}</div>
        </div>
        <div className="rounded-lg border p-3">
          <div className="text-xs text-gray-500">Granted</div>
          <div className="text-xl font-semibold">{kpis?.granted_count ?? 0}</div>
        </div>
        <div className="rounded-lg border p-3">
          <div className="text-xs text-gray-500">P0/P1 Priority</div>
          <div className="text-xl font-semibold">{kpis?.p0_p1_count ?? 0}</div>
        </div>
        <div className="rounded-lg border p-3">
          <div className="text-xs text-gray-500">Legal Spend</div>
          <div className="text-xl font-semibold">{rupees(kpis?.total_legal_spend_rupees ?? 0)}</div>
        </div>
        <div className="rounded-lg border p-3">
          <div className="text-xs text-gray-500">Due &lt;= 90d</div>
          <div className="text-xl font-semibold">{kpis?.filings_due_90d ?? 0}</div>
        </div>
        <div className="rounded-lg border p-3">
          <div className="text-xs text-gray-500">Total Secrets</div>
          <div className="text-xl font-semibold">{kpis?.total_secrets ?? 0}</div>
        </div>
        <div className="rounded-lg border p-3">
          <div className="text-xs text-gray-500">Red Secrets</div>
          <div className="text-xl font-semibold">{kpis?.red_secrets ?? 0}</div>
        </div>
        <div className="rounded-lg border p-3">
          <div className="text-xs text-gray-500">Founder-Only</div>
          <div className="text-xl font-semibold">{kpis?.founder_only_secrets ?? 0}</div>
        </div>
        <div className="rounded-lg border p-3">
          <div className="text-xs text-gray-500">Secret Value</div>
          <div className="text-xl font-semibold">{rupees(kpis?.total_secret_value_rupees ?? 0)}</div>
        </div>
        <div className="rounded-lg border p-3">
          <div className="text-xs text-gray-500">Avg Leak Risk</div>
          <div className="text-xl font-semibold">{kpis?.avg_leak_risk ?? 0}</div>
        </div>
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-semibold">Patent Portfolio by Jurisdiction</h2>
        <DataTable
          rows={portfolio}
          columns={portfolioCols}
          emptyMessage="No patent filings."
          rowKey={(r, i) => String((r as PortfolioRow).jurisdiction ?? i)}
        />
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-semibold">Upcoming Examination Deadlines</h2>
        <DataTable
          rows={deadlines}
          columns={deadlineCols}
          emptyMessage="No upcoming deadlines."
          rowKey={(r, i) => String((r as DeadlineRow).id ?? i)}
        />
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-semibold">High-Priority Filings (P0 & P1)</h2>
        <DataTable
          rows={highPriority}
          columns={highPriorityCols}
          emptyMessage="No high-priority filings."
          rowKey={(r, i) => String((r as HighPriorityRow).id ?? i)}
        />
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-semibold">Vault Audit Summary</h2>
        <DataTable
          rows={vaultSummary}
          columns={vaultSummaryCols}
          emptyMessage="No vault entries."
          rowKey={(r, i) => String((r as VaultSummaryRow).audit_status ?? i)}
        />
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-semibold">Secrets Needing Rotation (Amber & Red)</h2>
        <DataTable
          rows={rotation}
          columns={rotationCols}
          emptyMessage="All secrets healthy."
          rowKey={(r, i) => String((r as RotationRow).id ?? i)}
        />
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-semibold">Vault by Category</h2>
        <DataTable
          rows={category}
          columns={categoryCols}
          emptyMessage="No categories."
          rowKey={(r, i) => String((r as CategoryRow).category ?? i)}
        />
      </section>
    </div>
  );
}
