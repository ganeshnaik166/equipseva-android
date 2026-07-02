import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/founder/DataTable';

export const dynamic = 'force-dynamic';

type Overview = { metric: string; value: string };
type WearDist = { wear_grade: string; audits: number; avg_wear_score: number; condemn_share_pct: number };
type SiteRisk = { customer_site_name: string; audits: number; urgent_count: number; condemn_count: number; recall_hits: number };
type EngThru = { engineer_name: string; audits: number; urgent_share_pct: number; avg_wear_score: number };
type RecallProg = { recall_batch_code: string; vendor_name: string; severity: string; action_status: string; total_units_affected: number; units_outstanding: number; recovery_pct: number };
type MonthlyTrend = { audit_month: string; audits: number; urgent_count: number; condemn_count: number; avg_wear_score: number };
type ActionBreak = { action_taken: string; audits: number; urgent_count: number; share_pct: number };

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [ov, wd, sr, et, rp, mt, ab] = await Promise.all([
    supabase.rpc('r3054_overview'),
    supabase.rpc('r3054_wear_grade_distribution'),
    supabase.rpc('r3054_site_risk_ranking'),
    supabase.rpc('r3054_engineer_audit_throughput'),
    supabase.rpc('r3054_recall_batch_progress'),
    supabase.rpc('r3054_monthly_trend'),
    supabase.rpc('r3054_action_taken_breakdown'),
  ]);

  const overview = (ov.data ?? []) as Overview[];
  const wearDist = (wd.data ?? []) as WearDist[];
  const siteRisk = (sr.data ?? []) as SiteRisk[];
  const engThru = (et.data ?? []) as EngThru[];
  const recallProg = (rp.data ?? []) as RecallProg[];
  const monthly = (mt.data ?? []) as MonthlyTrend[];
  const actionBreak = (ab.data ?? []) as ActionBreak[];

  const ovCols: Column<Overview>[] = [
    { header: 'Metric', accessor: (r) => r.metric },
    { header: 'Value', accessor: (r) => r.value },
  ];

  const wdCols: Column<WearDist>[] = [
    { header: 'Wear Grade', accessor: (r) => r.wear_grade },
    { header: 'Audits', accessor: (r) => r.audits },
    { header: 'Avg Wear Score', accessor: (r) => r.avg_wear_score },
    { header: 'Condemn Share %', accessor: (r) => r.condemn_share_pct },
  ];

  const srCols: Column<SiteRisk>[] = [
    { header: 'Site', accessor: (r) => r.customer_site_name },
    { header: 'Audits', accessor: (r) => r.audits },
    { header: 'Urgent', accessor: (r) => r.urgent_count },
    { header: 'Condemn', accessor: (r) => r.condemn_count },
    { header: 'Recall Hits', accessor: (r) => r.recall_hits },
  ];

  const etCols: Column<EngThru>[] = [
    { header: 'Engineer', accessor: (r) => r.engineer_name },
    { header: 'Audits', accessor: (r) => r.audits },
    { header: 'Urgent Share %', accessor: (r) => r.urgent_share_pct },
    { header: 'Avg Wear Score', accessor: (r) => r.avg_wear_score },
  ];

  const rpCols: Column<RecallProg>[] = [
    { header: 'Batch Code', accessor: (r) => r.recall_batch_code },
    { header: 'Vendor', accessor: (r) => r.vendor_name },
    { header: 'Severity', accessor: (r) => r.severity },
    { header: 'Status', accessor: (r) => r.action_status },
    { header: 'Units Affected', accessor: (r) => r.total_units_affected },
    { header: 'Outstanding', accessor: (r) => r.units_outstanding },
    { header: 'Recovery %', accessor: (r) => r.recovery_pct },
  ];

  const mtCols: Column<MonthlyTrend>[] = [
    { header: 'Month', accessor: (r) => r.audit_month },
    { header: 'Audits', accessor: (r) => r.audits },
    { header: 'Urgent', accessor: (r) => r.urgent_count },
    { header: 'Condemn', accessor: (r) => r.condemn_count },
    { header: 'Avg Wear Score', accessor: (r) => r.avg_wear_score },
  ];

  const abCols: Column<ActionBreak>[] = [
    { header: 'Action Taken', accessor: (r) => r.action_taken },
    { header: 'Audits', accessor: (r) => r.audits },
    { header: 'Urgent', accessor: (r) => r.urgent_count },
    { header: 'Share %', accessor: (r) => r.share_pct },
  ];

  return (
    <div className="space-y-8 p-6">
      <header>
        <h1 className="text-2xl font-bold">Engineer Monthly Patient-Lift Sling Strap Wear & Recall Audit</h1>
        <p className="text-sm text-gray-600">Round r3054 — sling-strap inspection results, wear scoring & vendor recall progress.</p>
      </header>

      <section>
        <h2 className="text-lg font-semibold mb-2">Overview</h2>
        <DataTable
          rows={overview}
          columns={ovCols}
          emptyMessage="No overview metrics."
          rowKey={(r, i) => String((r as { metric?: string }).metric ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Wear Grade Distribution</h2>
        <DataTable
          rows={wearDist}
          columns={wdCols}
          emptyMessage="No wear-grade data."
          rowKey={(r, i) => String((r as { wear_grade?: string }).wear_grade ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Site Risk Ranking</h2>
        <DataTable
          rows={siteRisk}
          columns={srCols}
          emptyMessage="No site risk data."
          rowKey={(r, i) => String((r as { customer_site_name?: string }).customer_site_name ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Engineer Audit Throughput</h2>
        <DataTable
          rows={engThru}
          columns={etCols}
          emptyMessage="No engineer data."
          rowKey={(r, i) => String((r as { engineer_name?: string }).engineer_name ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Recall Batch Progress</h2>
        <DataTable
          rows={recallProg}
          columns={rpCols}
          emptyMessage="No recall batches."
          rowKey={(r, i) => String((r as { recall_batch_code?: string }).recall_batch_code ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Monthly Trend</h2>
        <DataTable
          rows={monthly}
          columns={mtCols}
          emptyMessage="No monthly trend data."
          rowKey={(r, i) => String((r as { audit_month?: string }).audit_month ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Action Taken Breakdown</h2>
        <DataTable
          rows={actionBreak}
          columns={abCols}
          emptyMessage="No action breakdown data."
          rowKey={(r, i) => String((r as { action_taken?: string }).action_taken ?? i)}
        />
      </section>
    </div>
  );
}
