import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable } from '@/components/ui/DataTable';
import type { Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type PipelineRow = { status: string; candidates: number; total_monthly_rent_rupees: number; total_sqft: number };
type AboveMarketRow = { property_code: string; city: string; current_rate: number; market_rate: number; premium_pct: number; monthly_rent_rupees: number };
type AskRow = { property_code: string; landlord_ask_hike_pct: number; founder_target_hike_pct: number; gap_pct: number; priority: string };
type FindingsRow = { severity: string; category: string; open_count: number; total_savings_rupees: number };
type OwnerRow = { owner_role: string; open_findings: number; savings_at_stake_rupees: number; overdue_count: number };
type CalRow = { property_code: string; city: string; renewal_window_start: string; days_until_start: number; status: string; strategic_priority: string };
type CityRow = { city: string; properties: number; total_sqft: number; total_monthly_rent_rupees: number; avg_rate: number };
type ActionRow = { property_code: string; finding_code: string; severity: string; estimated_savings_rupees: number; due_date: string; owner_role: string };

export default async function Page() {
  const sb = await getSupabaseServerClient();
  const [pipeline, aboveMkt, asks, findings, owners, cal, city, actions] = await Promise.all([
    sb.rpc('rpc_r2953_renewal_pipeline'),
    sb.rpc('rpc_r2953_above_market_properties'),
    sb.rpc('rpc_r2953_landlord_ask_vs_target'),
    sb.rpc('rpc_r2953_findings_by_severity'),
    sb.rpc('rpc_r2953_savings_by_owner'),
    sb.rpc('rpc_r2953_renewal_calendar'),
    sb.rpc('rpc_r2953_city_portfolio'),
    sb.rpc('rpc_r2953_p0_critical_actions'),
  ]);

  const pipelineCols: Column<PipelineRow>[] = [
    { header: 'Status', accessor: (r) => r.status },
    { header: 'Candidates', accessor: (r) => r.candidates },
    { header: 'Monthly Rent', accessor: (r) => `Rs ${Number(r.total_monthly_rent_rupees ?? 0).toLocaleString('en-IN')}` },
    { header: 'Total Sqft', accessor: (r) => r.total_sqft },
  ];
  const aboveCols: Column<AboveMarketRow>[] = [
    { header: 'Property', accessor: (r) => r.property_code },
    { header: 'City', accessor: (r) => r.city },
    { header: 'Current', accessor: (r) => r.current_rate },
    { header: 'Market', accessor: (r) => r.market_rate },
    { header: 'Premium %', accessor: (r) => r.premium_pct },
    { header: 'Rent', accessor: (r) => `Rs ${Number(r.monthly_rent_rupees ?? 0).toLocaleString('en-IN')}` },
  ];
  const askCols: Column<AskRow>[] = [
    { header: 'Property', accessor: (r) => r.property_code },
    { header: 'Landlord Ask %', accessor: (r) => r.landlord_ask_hike_pct },
    { header: 'Founder Target %', accessor: (r) => r.founder_target_hike_pct },
    { header: 'Gap %', accessor: (r) => r.gap_pct },
    { header: 'Priority', accessor: (r) => r.priority },
  ];
  const findCols: Column<FindingsRow>[] = [
    { header: 'Severity', accessor: (r) => r.severity },
    { header: 'Category', accessor: (r) => r.category },
    { header: 'Open', accessor: (r) => r.open_count },
    { header: 'Savings', accessor: (r) => `Rs ${Number(r.total_savings_rupees ?? 0).toLocaleString('en-IN')}` },
  ];
  const ownerCols: Column<OwnerRow>[] = [
    { header: 'Owner', accessor: (r) => r.owner_role },
    { header: 'Open Findings', accessor: (r) => r.open_findings },
    { header: 'Savings At Stake', accessor: (r) => `Rs ${Number(r.savings_at_stake_rupees ?? 0).toLocaleString('en-IN')}` },
    { header: 'Overdue', accessor: (r) => r.overdue_count },
  ];
  const calCols: Column<CalRow>[] = [
    { header: 'Property', accessor: (r) => r.property_code },
    { header: 'City', accessor: (r) => r.city },
    { header: 'Renewal Start', accessor: (r) => r.renewal_window_start },
    { header: 'Days Until', accessor: (r) => r.days_until_start },
    { header: 'Status', accessor: (r) => r.status },
    { header: 'Priority', accessor: (r) => r.strategic_priority },
  ];
  const cityCols: Column<CityRow>[] = [
    { header: 'City', accessor: (r) => r.city },
    { header: 'Properties', accessor: (r) => r.properties },
    { header: 'Sqft', accessor: (r) => r.total_sqft },
    { header: 'Monthly Rent', accessor: (r) => `Rs ${Number(r.total_monthly_rent_rupees ?? 0).toLocaleString('en-IN')}` },
    { header: 'Avg Rate', accessor: (r) => r.avg_rate },
  ];
  const actCols: Column<ActionRow>[] = [
    { header: 'Property', accessor: (r) => r.property_code },
    { header: 'Finding', accessor: (r) => r.finding_code },
    { header: 'Severity', accessor: (r) => r.severity },
    { header: 'Savings', accessor: (r) => `Rs ${Number(r.estimated_savings_rupees ?? 0).toLocaleString('en-IN')}` },
    { header: 'Due', accessor: (r) => r.due_date },
    { header: 'Owner', accessor: (r) => r.owner_role },
  ];

  return (
    <div className="p-6 space-y-8">
      <header>
        <h1 className="text-2xl font-bold">Quarterly Strategic India HQ Office Real-Estate Lease Renewal Audit</h1>
        <p className="text-sm text-gray-600">Founder console — portfolio across India HQ & satellite offices.</p>
      </header>

      <section>
        <h2 className="text-lg font-semibold mb-2">Renewal Pipeline</h2>
        <DataTable<PipelineRow> rows={(pipeline.data ?? []) as PipelineRow[]} columns={pipelineCols} emptyMessage="No pipeline data" rowKey={(r, i) => String(r.status ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Above-Market Properties</h2>
        <DataTable<AboveMarketRow> rows={(aboveMkt.data ?? []) as AboveMarketRow[]} columns={aboveCols} emptyMessage="None above market" rowKey={(r, i) => String(r.property_code ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Landlord Ask vs Founder Target</h2>
        <DataTable<AskRow> rows={(asks.data ?? []) as AskRow[]} columns={askCols} emptyMessage="No active negotiations" rowKey={(r, i) => String(r.property_code ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Findings by Severity & Category</h2>
        <DataTable<FindingsRow> rows={(findings.data ?? []) as FindingsRow[]} columns={findCols} emptyMessage="No findings" rowKey={(r, i) => `${r.severity}-${r.category}-${i}`} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Savings At Stake by Owner</h2>
        <DataTable<OwnerRow> rows={(owners.data ?? []) as OwnerRow[]} columns={ownerCols} emptyMessage="No owners" rowKey={(r, i) => String(r.owner_role ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Renewal Calendar</h2>
        <DataTable<CalRow> rows={(cal.data ?? []) as CalRow[]} columns={calCols} emptyMessage="Calendar empty" rowKey={(r, i) => String(r.property_code ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">City Portfolio</h2>
        <DataTable<CityRow> rows={(city.data ?? []) as CityRow[]} columns={cityCols} emptyMessage="No cities" rowKey={(r, i) => String(r.city ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">P0 / Critical Actions</h2>
        <DataTable<ActionRow> rows={(actions.data ?? []) as ActionRow[]} columns={actCols} emptyMessage="No critical actions" rowKey={(r, i) => `${r.property_code}-${r.finding_code}-${i}`} />
      </section>
    </div>
  );
}
