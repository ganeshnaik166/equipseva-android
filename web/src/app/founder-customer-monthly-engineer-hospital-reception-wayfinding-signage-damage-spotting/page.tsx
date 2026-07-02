import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable } from '@/components/data-table';
import type { Column } from '@/components/data-table';

export const dynamic = 'force-dynamic';

type SeverityRow = {
  damage_severity: string;
  report_count: number;
  total_replacement_rupees: number;
  avg_confusion_score: number;
  total_complaints: number;
};

type ZoneRow = {
  reception_zone: string;
  damage_count: number;
  critical_count: number;
  total_estimate_rupees: number;
  avg_priority: number;
};

type PipelineRow = {
  hospital_name: string;
  hospital_city: string;
  reception_zone: string;
  signage_type: string;
  damage_severity: string;
  replacement_cost_rupees: number;
  repair_priority: number;
  status: string;
};

type LeaderboardRow = {
  engineer_name: string;
  engineer_region: string;
  audits_count: number;
  total_hospitals_walked: number;
  total_items_inspected: number;
  total_damage_logged: number;
  avg_wayfinding_score: number;
  signoffs_obtained: number;
};

type TrendRow = {
  audit_month: string;
  audit_count: number;
  hospitals_total: number;
  items_inspected: number;
  damage_logged: number;
  total_estimate_rupees: number;
  customer_shared_count: number;
};

type KindRow = {
  damage_kind: string;
  signage_type: string;
  occurrences: number;
  avg_cost_rupees: number;
  worst_confusion_score: number;
};

type SummaryRow = {
  total_damage_reports: number;
  critical_open_count: number;
  pipeline_estimate_rupees: number;
  unique_hospitals: number;
  active_engineers: number;
  audits_in_review: number;
  avg_reception_rating: number;
  total_patron_complaints: number;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [severity, zones, pipeline, leaderboard, trend, kinds, summary] = await Promise.all([
    supabase.rpc('r2992_damage_by_severity'),
    supabase.rpc('r2992_zone_hotspots'),
    supabase.rpc('r2992_open_repair_pipeline'),
    supabase.rpc('r2992_engineer_leaderboard'),
    supabase.rpc('r2992_walkthrough_monthly_trend'),
    supabase.rpc('r2992_damage_kind_breakdown'),
    supabase.rpc('r2992_founder_summary'),
  ]);

  const severityRows: SeverityRow[] = (severity.data as SeverityRow[]) ?? [];
  const zoneRows: ZoneRow[] = (zones.data as ZoneRow[]) ?? [];
  const pipelineRows: PipelineRow[] = (pipeline.data as PipelineRow[]) ?? [];
  const leaderboardRows: LeaderboardRow[] = (leaderboard.data as LeaderboardRow[]) ?? [];
  const trendRows: TrendRow[] = (trend.data as TrendRow[]) ?? [];
  const kindRows: KindRow[] = (kinds.data as KindRow[]) ?? [];
  const summaryRows: SummaryRow[] = (summary.data as SummaryRow[]) ?? [];
  const s = summaryRows[0];

  const severityCols: Column<SeverityRow>[] = [
    { header: 'Severity', accessor: (r) => r.damage_severity },
    { header: 'Reports', accessor: (r) => r.report_count },
    { header: 'Replacement Cost', accessor: (r) => `Rs ${r.total_replacement_rupees.toLocaleString('en-IN')}` },
    { header: 'Avg Confusion', accessor: (r) => r.avg_confusion_score },
    { header: 'Complaints (30d)', accessor: (r) => r.total_complaints },
  ];

  const zoneCols: Column<ZoneRow>[] = [
    { header: 'Reception Zone', accessor: (r) => r.reception_zone },
    { header: 'Damage Count', accessor: (r) => r.damage_count },
    { header: 'Critical', accessor: (r) => r.critical_count },
    { header: 'Estimate', accessor: (r) => `Rs ${r.total_estimate_rupees.toLocaleString('en-IN')}` },
    { header: 'Avg Priority', accessor: (r) => r.avg_priority },
  ];

  const pipelineCols: Column<PipelineRow>[] = [
    { header: 'Hospital', accessor: (r) => r.hospital_name },
    { header: 'City', accessor: (r) => r.hospital_city },
    { header: 'Zone', accessor: (r) => r.reception_zone },
    { header: 'Signage', accessor: (r) => r.signage_type },
    { header: 'Severity', accessor: (r) => r.damage_severity },
    { header: 'Cost', accessor: (r) => `Rs ${r.replacement_cost_rupees.toLocaleString('en-IN')}` },
    { header: 'Priority', accessor: (r) => r.repair_priority },
    { header: 'Status', accessor: (r) => r.status },
  ];

  const leaderboardCols: Column<LeaderboardRow>[] = [
    { header: 'Engineer', accessor: (r) => r.engineer_name },
    { header: 'Region', accessor: (r) => r.engineer_region },
    { header: 'Audits', accessor: (r) => r.audits_count },
    { header: 'Hospitals', accessor: (r) => r.total_hospitals_walked },
    { header: 'Items Inspected', accessor: (r) => r.total_items_inspected },
    { header: 'Damage Logged', accessor: (r) => r.total_damage_logged },
    { header: 'Avg Wayfinding', accessor: (r) => r.avg_wayfinding_score },
    { header: 'Signoffs', accessor: (r) => r.signoffs_obtained },
  ];

  const trendCols: Column<TrendRow>[] = [
    { header: 'Month', accessor: (r) => r.audit_month },
    { header: 'Audits', accessor: (r) => r.audit_count },
    { header: 'Hospitals', accessor: (r) => r.hospitals_total },
    { header: 'Items', accessor: (r) => r.items_inspected },
    { header: 'Damage', accessor: (r) => r.damage_logged },
    { header: 'Estimate', accessor: (r) => `Rs ${r.total_estimate_rupees.toLocaleString('en-IN')}` },
    { header: 'Shared w/ Customer', accessor: (r) => r.customer_shared_count },
  ];

  const kindCols: Column<KindRow>[] = [
    { header: 'Damage Kind', accessor: (r) => r.damage_kind },
    { header: 'Signage Type', accessor: (r) => r.signage_type },
    { header: 'Occurrences', accessor: (r) => r.occurrences },
    { header: 'Avg Cost', accessor: (r) => `Rs ${Number(r.avg_cost_rupees).toLocaleString('en-IN')}` },
    { header: 'Worst Confusion', accessor: (r) => r.worst_confusion_score },
  ];

  return (
    <div className="p-6 space-y-8">
      <header>
        <h1 className="text-2xl font-bold">Wayfinding & Signage Damage Spotting — r2992</h1>
        <p className="text-sm text-gray-600">
          Monthly engineer walkthroughs at hospital receptions — spot damaged signage, score wayfinding confusion,
          quote replacements, share with customer.
        </p>
      </header>

      {s && (
        <section className="grid grid-cols-2 md:grid-cols-4 gap-4">
          <div className="border rounded p-3">
            <div className="text-xs text-gray-500">Damage Reports</div>
            <div className="text-xl font-semibold">{s.total_damage_reports}</div>
          </div>
          <div className="border rounded p-3">
            <div className="text-xs text-gray-500">Critical Open</div>
            <div className="text-xl font-semibold">{s.critical_open_count}</div>
          </div>
          <div className="border rounded p-3">
            <div className="text-xs text-gray-500">Pipeline Estimate</div>
            <div className="text-xl font-semibold">Rs {Number(s.pipeline_estimate_rupees).toLocaleString('en-IN')}</div>
          </div>
          <div className="border rounded p-3">
            <div className="text-xs text-gray-500">Hospitals Covered</div>
            <div className="text-xl font-semibold">{s.unique_hospitals}</div>
          </div>
          <div className="border rounded p-3">
            <div className="text-xs text-gray-500">Active Engineers</div>
            <div className="text-xl font-semibold">{s.active_engineers}</div>
          </div>
          <div className="border rounded p-3">
            <div className="text-xs text-gray-500">Audits In Review</div>
            <div className="text-xl font-semibold">{s.audits_in_review}</div>
          </div>
          <div className="border rounded p-3">
            <div className="text-xs text-gray-500">Avg Reception Rating</div>
            <div className="text-xl font-semibold">{s.avg_reception_rating} / 10</div>
          </div>
          <div className="border rounded p-3">
            <div className="text-xs text-gray-500">Patron Complaints (30d)</div>
            <div className="text-xl font-semibold">{s.total_patron_complaints}</div>
          </div>
        </section>
      )}

      <section>
        <h2 className="text-lg font-semibold mb-2">Damage by Severity</h2>
        <DataTable
          rows={severityRows}
          columns={severityCols}
          emptyMessage="No severity data"
          rowKey={(r, i) => String(i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Reception Zone Hotspots</h2>
        <DataTable
          rows={zoneRows}
          columns={zoneCols}
          emptyMessage="No zone data"
          rowKey={(r, i) => String(i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Open Repair Pipeline</h2>
        <DataTable
          rows={pipelineRows}
          columns={pipelineCols}
          emptyMessage="No open repairs"
          rowKey={(r, i) => String(i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Engineer Leaderboard</h2>
        <DataTable
          rows={leaderboardRows}
          columns={leaderboardCols}
          emptyMessage="No engineer audits"
          rowKey={(r, i) => String(i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Walkthrough Monthly Trend</h2>
        <DataTable
          rows={trendRows}
          columns={trendCols}
          emptyMessage="No trend data"
          rowKey={(r, i) => String(i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Damage Kind & Signage Type Breakdown</h2>
        <DataTable
          rows={kindRows}
          columns={kindCols}
          emptyMessage="No breakdown"
          rowKey={(r, i) => String(i)}
        />
      </section>
    </div>
  );
}
