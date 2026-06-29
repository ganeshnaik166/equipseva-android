import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable } from '@/components/ui/data-table';
import type { Column } from '@/components/ui/data-table';

export const dynamic = 'force-dynamic';

type Verdict = { verdict: string; inspections: number; replacement_required: number; share_pct: number };
type CityRow = { hospital_city: string; inspections: number; fails: number; condemns: number; avg_fabric_wear: number };
type EngRow = { engineer_name: string; inspections: number; photos_avg: number; pass_rate_pct: number };
type ModelRow = { sling_model: string; units: number; avg_age_months: number; avg_wear: number; condemned: number };
type PipeRow = { status: string; replacements: number; cost_rupees_total: number; avg_warranty_months: number };
type ReasonRow = { reason: string; replacements: number; signed_off: number; open_or_progress: number };
type FailRow = { inspection_date: string; customer_site: string; sling_model: string; verdict: string; fabric_wear_score: number; engineer_name: string };
type LoadRow = { customer_site: string; sling_serial: string; rated_load_kg: number; load_test_kg: number; margin_kg: number; verdict: string };

export default async function Page() {
  const supabase = await getSupabaseServerClient();
  const [v, c, e, m, p, r, f, l] = await Promise.all([
    supabase.rpc('r3002_verdict_distribution'),
    supabase.rpc('r3002_city_risk_heatmap'),
    supabase.rpc('r3002_engineer_scorecard'),
    supabase.rpc('r3002_model_fleet_wear'),
    supabase.rpc('r3002_replacement_pipeline'),
    supabase.rpc('r3002_replacement_reason_breakdown'),
    supabase.rpc('r3002_recent_fails_feed'),
    supabase.rpc('r3002_load_margin_watch'),
  ]);

  const verdicts = (v.data ?? []) as Verdict[];
  const cities = (c.data ?? []) as CityRow[];
  const engineers = (e.data ?? []) as EngRow[];
  const models = (m.data ?? []) as ModelRow[];
  const pipeline = (p.data ?? []) as PipeRow[];
  const reasons = (r.data ?? []) as ReasonRow[];
  const fails = (f.data ?? []) as FailRow[];
  const loads = (l.data ?? []) as LoadRow[];

  const verdictCols: Column<Verdict>[] = [
    { header: 'Verdict', accessor: (x) => x.verdict },
    { header: 'Inspections', accessor: (x) => x.inspections },
    { header: 'Replacement Required', accessor: (x) => x.replacement_required },
    { header: 'Share %', accessor: (x) => x.share_pct },
  ];
  const cityCols: Column<CityRow>[] = [
    { header: 'City', accessor: (x) => x.hospital_city },
    { header: 'Inspections', accessor: (x) => x.inspections },
    { header: 'Fails', accessor: (x) => x.fails },
    { header: 'Condemns', accessor: (x) => x.condemns },
    { header: 'Avg Fabric Wear', accessor: (x) => x.avg_fabric_wear },
  ];
  const engCols: Column<EngRow>[] = [
    { header: 'Engineer', accessor: (x) => x.engineer_name },
    { header: 'Inspections', accessor: (x) => x.inspections },
    { header: 'Avg Photos', accessor: (x) => x.photos_avg },
    { header: 'Pass Rate %', accessor: (x) => x.pass_rate_pct },
  ];
  const modelCols: Column<ModelRow>[] = [
    { header: 'Model', accessor: (x) => x.sling_model },
    { header: 'Units', accessor: (x) => x.units },
    { header: 'Avg Age (mo)', accessor: (x) => x.avg_age_months },
    { header: 'Avg Wear', accessor: (x) => x.avg_wear },
    { header: 'Condemned', accessor: (x) => x.condemned },
  ];
  const pipeCols: Column<PipeRow>[] = [
    { header: 'Status', accessor: (x) => x.status },
    { header: 'Replacements', accessor: (x) => x.replacements },
    { header: 'Cost Total (Rs)', accessor: (x) => x.cost_rupees_total },
    { header: 'Avg Warranty (mo)', accessor: (x) => x.avg_warranty_months },
  ];
  const reasonCols: Column<ReasonRow>[] = [
    { header: 'Reason', accessor: (x) => x.reason },
    { header: 'Replacements', accessor: (x) => x.replacements },
    { header: 'Signed Off / Installed', accessor: (x) => x.signed_off },
    { header: 'Open / In-Progress / Dispatched', accessor: (x) => x.open_or_progress },
  ];
  const failCols: Column<FailRow>[] = [
    { header: 'Date', accessor: (x) => x.inspection_date },
    { header: 'Site', accessor: (x) => x.customer_site },
    { header: 'Model', accessor: (x) => x.sling_model },
    { header: 'Verdict', accessor: (x) => x.verdict },
    { header: 'Fabric Wear', accessor: (x) => x.fabric_wear_score },
    { header: 'Engineer', accessor: (x) => x.engineer_name },
  ];
  const loadCols: Column<LoadRow>[] = [
    { header: 'Site', accessor: (x) => x.customer_site },
    { header: 'Serial', accessor: (x) => x.sling_serial },
    { header: 'Rated kg', accessor: (x) => x.rated_load_kg },
    { header: 'Tested kg', accessor: (x) => x.load_test_kg },
    { header: 'Margin kg', accessor: (x) => x.margin_kg },
    { header: 'Verdict', accessor: (x) => x.verdict },
  ];

  return (
    <div className="p-6 space-y-8">
      <header>
        <h1 className="text-2xl font-semibold">Bath-Lift Sling Inspection &amp; Replacement Audit</h1>
        <p className="text-sm text-gray-600">Monthly engineer site audit — fabric, straps, buckles, labels, load. Pass &gt;= 7 scores; condemn on load fail.</p>
      </header>

      <section>
        <h2 className="text-lg font-medium mb-2">Verdict Distribution</h2>
        <DataTable rows={verdicts} columns={verdictCols} emptyMessage="No verdicts." rowKey={(r,i)=>String((r as any).verdict ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-medium mb-2">City Risk Heatmap</h2>
        <DataTable rows={cities} columns={cityCols} emptyMessage="No city data." rowKey={(r,i)=>String((r as any).hospital_city ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-medium mb-2">Engineer Scorecard</h2>
        <DataTable rows={engineers} columns={engCols} emptyMessage="No engineers." rowKey={(r,i)=>String((r as any).engineer_name ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-medium mb-2">Model Fleet Wear</h2>
        <DataTable rows={models} columns={modelCols} emptyMessage="No models." rowKey={(r,i)=>String((r as any).sling_model ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-medium mb-2">Replacement Pipeline</h2>
        <DataTable rows={pipeline} columns={pipeCols} emptyMessage="No pipeline." rowKey={(r,i)=>String((r as any).status ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-medium mb-2">Replacement Reasons</h2>
        <DataTable rows={reasons} columns={reasonCols} emptyMessage="No reasons." rowKey={(r,i)=>String((r as any).reason ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-medium mb-2">Recent Fails & Condemns</h2>
        <DataTable rows={fails} columns={failCols} emptyMessage="No fails." rowKey={(r,i)=>String(i)} />
      </section>

      <section>
        <h2 className="text-lg font-medium mb-2">Load Margin Watch (lowest margin first)</h2>
        <DataTable rows={loads} columns={loadCols} emptyMessage="No load tests." rowKey={(r,i)=>String((r as any).sling_serial ?? i)} />
      </section>
    </div>
  );
}
