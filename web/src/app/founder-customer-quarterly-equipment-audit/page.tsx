import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function FounderCustomerQuarterlyEquipmentAuditPage() {
  const supabase = await getSupabaseServerClient();

  const [
    auditsRes,
    actionsRes,
    topNonCompliantRes,
    findingBreakdownRes,
    nabhSummaryRes,
    monthlyTrendRes,
    severeFocusRes,
  ] = await Promise.all([
    supabase.rpc('list_audits_r2516'),
    supabase.rpc('list_corrective_actions_r2516'),
    supabase.rpc('top_non_compliant_hospitals_r2516'),
    supabase.rpc('finding_kind_breakdown_r2516'),
    supabase.rpc('nabh_alignment_summary_r2516'),
    supabase.rpc('monthly_completion_trend_r2516'),
    supabase.rpc('severe_findings_focus_r2516'),
  ]);

  const audits = (auditsRes.data ?? []) as any[];
  const actions = (actionsRes.data ?? []) as any[];
  const topNonCompliant = (topNonCompliantRes.data ?? []) as any[];
  const findingBreakdown = (findingBreakdownRes.data ?? []) as any[];
  const nabhSummary = (nabhSummaryRes.data ?? []) as any[];
  const monthlyTrend = (monthlyTrendRes.data ?? []) as any[];
  const severeFocus = (severeFocusRes.data ?? []) as any[];

  const auditCols: Column<any>[] = [
    { key: 'hospital_email', header: 'Hospital', render: (r: any) => r.hospital_email ?? '—' },
    { key: 'quarter_label', header: 'Quarter', render: (r: any) => r.quarter_label },
    { key: 'total_equipment_audited', header: 'Equip Audited', render: (r: any) => r.total_equipment_audited },
    { key: 'findings_count', header: 'Findings', render: (r: any) => r.findings_count },
    { key: 'compliance_score', header: 'Score', render: (r: any) => `${r.compliance_score}/100` },
    { key: 'nabh_alignment', header: 'NABH', render: (r: any) => r.nabh_alignment },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '—' },
    { key: 'notes', header: 'Notes', render: (r: any) => r.notes ?? '—' },
  ];

  const actionCols: Column<any>[] = [
    { key: 'hospital_email', header: 'Hospital', render: (r: any) => r.hospital_email ?? '—' },
    { key: 'quarter_label', header: 'Quarter', render: (r: any) => r.quarter_label },
    { key: 'finding_kind', header: 'Finding', render: (r: any) => r.finding_kind },
    { key: 'severity', header: 'Severity', render: (r: any) => r.severity },
    { key: 'action_md', header: 'Action', render: (r: any) => r.action_md ?? '—' },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '—' },
    { key: 'due_at', header: 'Due', render: (r: any) => r.due_at ? new Date(r.due_at).toLocaleDateString() : '—' },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'closed_at', header: 'Closed', render: (r: any) => r.closed_at ? new Date(r.closed_at).toLocaleDateString() : '—' },
  ];

  const topNonCompliantCols: Column<any>[] = [
    { key: 'hospital_email', header: 'Hospital', render: (r: any) => r.hospital_email ?? '—' },
    { key: 'audits_count', header: 'Audits', render: (r: any) => r.audits_count },
    { key: 'avg_compliance_score', header: 'Avg Score', render: (r: any) => `${r.avg_compliance_score}/100` },
    { key: 'total_findings', header: 'Total Findings', render: (r: any) => r.total_findings },
    { key: 'worst_alignment', header: 'Worst NABH', render: (r: any) => r.worst_alignment },
  ];

  const findingBreakdownCols: Column<any>[] = [
    { key: 'finding_kind', header: 'Finding Kind', render: (r: any) => r.finding_kind },
    { key: 'action_count', header: 'Actions', render: (r: any) => r.action_count },
    { key: 'open_count', header: 'Still Open', render: (r: any) => r.open_count },
    { key: 'critical_count', header: 'Critical', render: (r: any) => r.critical_count },
    { key: 'done_count', header: 'Done', render: (r: any) => r.done_count },
  ];

  const nabhSummaryCols: Column<any>[] = [
    { key: 'nabh_alignment', header: 'NABH Alignment', render: (r: any) => r.nabh_alignment },
    { key: 'audits_count', header: 'Audits', render: (r: any) => r.audits_count },
    { key: 'avg_compliance', header: 'Avg Score', render: (r: any) => `${r.avg_compliance}/100` },
    { key: 'avg_findings', header: 'Avg Findings', render: (r: any) => r.avg_findings },
  ];

  const monthlyTrendCols: Column<any>[] = [
    { key: 'month_label', header: 'Month', render: (r: any) => r.month_label },
    { key: 'audits_completed', header: 'Audits', render: (r: any) => r.audits_completed },
    { key: 'avg_compliance', header: 'Avg Score', render: (r: any) => `${r.avg_compliance}/100` },
    { key: 'total_findings', header: 'Findings', render: (r: any) => r.total_findings },
  ];

  const severeFocusCols: Column<any>[] = [
    { key: 'hospital_email', header: 'Hospital', render: (r: any) => r.hospital_email ?? '—' },
    { key: 'quarter_label', header: 'Quarter', render: (r: any) => r.quarter_label },
    { key: 'finding_kind', header: 'Finding', render: (r: any) => r.finding_kind },
    { key: 'severity', header: 'Severity', render: (r: any) => r.severity },
    { key: 'action_md', header: 'Action', render: (r: any) => r.action_md ?? '—' },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '—' },
    { key: 'due_at', header: 'Due', render: (r: any) => r.due_at ? new Date(r.due_at).toLocaleDateString() : '—' },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'days_open', header: 'Days Open', render: (r: any) => r.days_open },
  ];

  return (
    <div className="space-y-8 p-6">
      <header>
        <h1 className="text-2xl font-bold">Customer Quarterly Equipment Audit</h1>
        <p className="text-sm text-gray-600 mt-1">
          Hospital &gt; audit cycle &gt; findings &gt; compliance score &gt; corrective actions &gt; NABH alignment.
        </p>
      </header>

      <section>
        <h2 className="text-lg font-semibold mb-2">Audits</h2>
        <DataTable
          rows={audits}
          columns={auditCols}
          emptyMessage="No audits scheduled yet."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Corrective Actions</h2>
        <DataTable
          rows={actions}
          columns={actionCols}
          emptyMessage="No corrective actions logged."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Top Non-Compliant Hospitals</h2>
        <DataTable
          rows={topNonCompliant}
          columns={topNonCompliantCols}
          emptyMessage="No completed audits yet."
          rowKey={(r: any, i: number) => String(r.hospital_email ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Finding-Kind Breakdown</h2>
        <DataTable
          rows={findingBreakdown}
          columns={findingBreakdownCols}
          emptyMessage="No finding data."
          rowKey={(r: any, i: number) => String(r.finding_kind ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">NABH Alignment Summary</h2>
        <DataTable
          rows={nabhSummary}
          columns={nabhSummaryCols}
          emptyMessage="No NABH data yet."
          rowKey={(r: any, i: number) => String(r.nabh_alignment ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Monthly Completion Trend</h2>
        <DataTable
          rows={monthlyTrend}
          columns={monthlyTrendCols}
          emptyMessage="No completed audits in last 12 months."
          rowKey={(r: any, i: number) => String(r.month_label ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Severe Findings Focus (high & critical, still open)</h2>
        <DataTable
          rows={severeFocus}
          columns={severeFocusCols}
          emptyMessage="No severe findings still open."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>
    </div>
  );
}
