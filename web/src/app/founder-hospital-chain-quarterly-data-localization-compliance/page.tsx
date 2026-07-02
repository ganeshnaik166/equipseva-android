import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type OverviewRow = {
  total_audits: number;
  critical_count: number;
  high_count: number;
  open_gaps: number;
  avg_risk: number;
};

type AuditRow = {
  id: string;
  chain_name: string;
  policy_framework: string;
  quarter_label: string;
  audit_date: string;
  severity: string;
  outcome: string;
  gap_count: number;
};

type GapRow = {
  remediation_id: string;
  chain_name: string;
  gap_title: string;
  gap_category: string;
  owner_role: string;
  target_close_date: string;
  status: string;
  risk_score: number;
};

type FrameworkRow = {
  policy_framework: string;
  audit_count: number;
  avg_gaps: number;
  passed_rate: number;
};

type ResidencyRow = {
  data_residency_status: string;
  n: number;
};

type EscalationRow = {
  chain_name: string;
  severity: string;
  outcome: string;
  close_action: string;
  next_review_date: string | null;
};

type TrendRow = {
  quarter_label: string;
  audits: number;
  total_gaps: number;
  critical_high: number;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [overviewRes, auditsRes, gapsRes, frameworkRes, residencyRes, escalationsRes, trendRes] = await Promise.all([
    supabase.rpc('founder_chain_dataloc_overview_r2775'),
    supabase.rpc('founder_chain_dataloc_recent_audits_r2775', { p_limit: 20 }),
    supabase.rpc('founder_chain_dataloc_open_gaps_r2775'),
    supabase.rpc('founder_chain_dataloc_by_framework_r2775'),
    supabase.rpc('founder_chain_dataloc_residency_breakdown_r2775'),
    supabase.rpc('founder_chain_dataloc_escalations_r2775'),
    supabase.rpc('founder_chain_dataloc_quarter_trend_r2775'),
  ]);

  const overview: OverviewRow = (overviewRes.data?.[0] as OverviewRow) ?? {
    total_audits: 0,
    critical_count: 0,
    high_count: 0,
    open_gaps: 0,
    avg_risk: 0,
  };
  const audits: AuditRow[] = (auditsRes.data as AuditRow[]) ?? [];
  const gaps: GapRow[] = (gapsRes.data as GapRow[]) ?? [];
  const frameworks: FrameworkRow[] = (frameworkRes.data as FrameworkRow[]) ?? [];
  const residency: ResidencyRow[] = (residencyRes.data as ResidencyRow[]) ?? [];
  const escalations: EscalationRow[] = (escalationsRes.data as EscalationRow[]) ?? [];
  const trend: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];

  return (
    <div className="p-6 space-y-6">
      <div>
        <h1 className="text-2xl font-bold">Hospital Chain Quarterly Data-Localization Compliance</h1>
        <p className="text-sm text-gray-600">
          Chain × policy × audit × gaps × close action × verification × outcome.
          Tracks DPDP Act, RBI data localization, MeitY advisories & CERT-In directives across chain-level audits.
        </p>
      </div>

      <div className="grid grid-cols-2 md:grid-cols-5 gap-4">
        <div className="rounded border p-4">
          <div className="text-xs text-gray-500">Total Audits</div>
          <div className="text-2xl font-semibold">{overview.total_audits}</div>
        </div>
        <div className="rounded border p-4">
          <div className="text-xs text-gray-500">Critical</div>
          <div className="text-2xl font-semibold text-red-600">{overview.critical_count}</div>
        </div>
        <div className="rounded border p-4">
          <div className="text-xs text-gray-500">High</div>
          <div className="text-2xl font-semibold text-orange-600">{overview.high_count}</div>
        </div>
        <div className="rounded border p-4">
          <div className="text-xs text-gray-500">Open Gaps</div>
          <div className="text-2xl font-semibold">{overview.open_gaps}</div>
        </div>
        <div className="rounded border p-4">
          <div className="text-xs text-gray-500">Avg Risk Score</div>
          <div className="text-2xl font-semibold">{overview.avg_risk}</div>
        </div>
      </div>

      <section>
        <h2 className="text-lg font-semibold mb-2">Recent Quarterly Audits</h2>
        <DataTable
          rows={audits}
          columns={[
            { key: 'chain_name', header: 'Chain', render: (r: AuditRow) => r.chain_name },
            { key: 'policy_framework', header: 'Framework', render: (r: AuditRow) => r.policy_framework },
            { key: 'quarter_label', header: 'Quarter', render: (r: AuditRow) => r.quarter_label },
            { key: 'audit_date', header: 'Audit Date', render: (r: AuditRow) => r.audit_date },
            { key: 'severity', header: 'Severity', render: (r: AuditRow) => r.severity },
            { key: 'outcome', header: 'Outcome', render: (r: AuditRow) => r.outcome },
            { key: 'gap_count', header: 'Gaps', render: (r: AuditRow) => String(r.gap_count) },
          ]}
          emptyMessage="No data"
          rowKey={(r: AuditRow, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Open Gaps (risk score &gt;= threshold)</h2>
        <DataTable
          rows={gaps}
          columns={[
            { key: 'chain_name', header: 'Chain', render: (r: GapRow) => r.chain_name },
            { key: 'gap_title', header: 'Gap', render: (r: GapRow) => r.gap_title },
            { key: 'gap_category', header: 'Category', render: (r: GapRow) => r.gap_category },
            { key: 'owner_role', header: 'Owner', render: (r: GapRow) => r.owner_role },
            { key: 'target_close_date', header: 'Target Close', render: (r: GapRow) => r.target_close_date },
            { key: 'status', header: 'Status', render: (r: GapRow) => r.status },
            { key: 'risk_score', header: 'Risk', render: (r: GapRow) => String(r.risk_score) },
          ]}
          emptyMessage="No data"
          rowKey={(r: GapRow, i: number) => String(r.remediation_id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">By Policy Framework</h2>
        <DataTable
          rows={frameworks}
          columns={[
            { key: 'policy_framework', header: 'Framework', render: (r: FrameworkRow) => r.policy_framework },
            { key: 'audit_count', header: 'Audits', render: (r: FrameworkRow) => String(r.audit_count) },
            { key: 'avg_gaps', header: 'Avg Gaps', render: (r: FrameworkRow) => String(r.avg_gaps) },
            { key: 'passed_rate', header: 'Passed %', render: (r: FrameworkRow) => `${r.passed_rate}%` },
          ]}
          emptyMessage="No data"
          rowKey={(r: FrameworkRow, i: number) => String(r.policy_framework ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Data Residency Breakdown</h2>
        <DataTable
          rows={residency}
          columns={[
            { key: 'data_residency_status', header: 'Residency', render: (r: ResidencyRow) => r.data_residency_status },
            { key: 'n', header: 'Count', render: (r: ResidencyRow) => String(r.n) },
          ]}
          emptyMessage="No data"
          rowKey={(r: ResidencyRow, i: number) => String(r.data_residency_status ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Escalations & Critical/High</h2>
        <DataTable
          rows={escalations}
          columns={[
            { key: 'chain_name', header: 'Chain', render: (r: EscalationRow) => r.chain_name },
            { key: 'severity', header: 'Severity', render: (r: EscalationRow) => r.severity },
            { key: 'outcome', header: 'Outcome', render: (r: EscalationRow) => r.outcome },
            { key: 'close_action', header: 'Close Action', render: (r: EscalationRow) => r.close_action },
            { key: 'next_review_date', header: 'Next Review', render: (r: EscalationRow) => r.next_review_date ?? '-' },
          ]}
          emptyMessage="No data"
          rowKey={(r: EscalationRow, i: number) => String(`${r.chain_name}-${i}`)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Quarterly Trend</h2>
        <DataTable
          rows={trend}
          columns={[
            { key: 'quarter_label', header: 'Quarter', render: (r: TrendRow) => r.quarter_label },
            { key: 'audits', header: 'Audits', render: (r: TrendRow) => String(r.audits) },
            { key: 'total_gaps', header: 'Total Gaps', render: (r: TrendRow) => String(r.total_gaps) },
            { key: 'critical_high', header: 'Critical+High', render: (r: TrendRow) => String(r.critical_high) },
          ]}
          emptyMessage="No data"
          rowKey={(r: TrendRow, i: number) => String(r.quarter_label ?? i)}
        />
      </section>
    </div>
  );
}