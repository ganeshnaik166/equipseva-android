import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type ChainOverview = { chain_name: string; total_responses: number; promoters: number; detractors: number; net_score: number };
type QuarterlyTrend = { quarter: string; surveys_count: number; total_responses: number; promoters: number; detractors: number; net_score: number };
type ResponseRate = { chain_name: string; quarter: string; invited: number; responded: number; response_pct: number; survey_status: string };
type Specialty = { specialty: string; responses: number; avg_score: number; promoters: number; detractors: number };
type DetractorAlert = { chain_name: string; quarter: string; specialty: string; equipment_class: string; downtime_concern: string; score: number };
type EquipClass = { equipment_class: string; responses: number; avg_score: number; net_score: number };
type Region = { region: string; chains: number; total_beds: number; total_responses: number; net_score: number };

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [overview, trend, rates, specialty, detractors, equipClass, region] = await Promise.all([
    supabase.rpc('r2947_chain_net_score_overview'),
    supabase.rpc('r2947_quarterly_trend'),
    supabase.rpc('r2947_response_rate_by_chain'),
    supabase.rpc('r2947_specialty_breakdown'),
    supabase.rpc('r2947_detractor_alerts'),
    supabase.rpc('r2947_equipment_class_confidence'),
    supabase.rpc('r2947_region_summary'),
  ]);

  const overviewRows: ChainOverview[] = overview.data ?? [];
  const trendRows: QuarterlyTrend[] = trend.data ?? [];
  const rateRows: ResponseRate[] = rates.data ?? [];
  const specialtyRows: Specialty[] = specialty.data ?? [];
  const detractorRows: DetractorAlert[] = detractors.data ?? [];
  const equipRows: EquipClass[] = equipClass.data ?? [];
  const regionRows: Region[] = region.data ?? [];

  const overviewCols: Column<ChainOverview>[] = [
    { header: 'Chain', accessor: (r) => r.chain_name },
    { header: 'Responses', accessor: (r) => r.total_responses },
    { header: 'Promoters', accessor: (r) => r.promoters },
    { header: 'Detractors', accessor: (r) => r.detractors },
    { header: 'Net Score', accessor: (r) => r.net_score },
  ];

  const trendCols: Column<QuarterlyTrend>[] = [
    { header: 'Quarter', accessor: (r) => r.quarter },
    { header: 'Surveys', accessor: (r) => r.surveys_count },
    { header: 'Responses', accessor: (r) => r.total_responses },
    { header: 'Promoters', accessor: (r) => r.promoters },
    { header: 'Detractors', accessor: (r) => r.detractors },
    { header: 'Net Score', accessor: (r) => r.net_score },
  ];

  const rateCols: Column<ResponseRate>[] = [
    { header: 'Chain', accessor: (r) => r.chain_name },
    { header: 'Quarter', accessor: (r) => r.quarter },
    { header: 'Invited', accessor: (r) => r.invited },
    { header: 'Responded', accessor: (r) => r.responded },
    { header: 'Response %', accessor: (r) => r.response_pct + '%' },
    { header: 'Status', accessor: (r) => r.survey_status },
  ];

  const specialtyCols: Column<Specialty>[] = [
    { header: 'Specialty', accessor: (r) => r.specialty },
    { header: 'Responses', accessor: (r) => r.responses },
    { header: 'Avg Score', accessor: (r) => r.avg_score },
    { header: 'Promoters', accessor: (r) => r.promoters },
    { header: 'Detractors', accessor: (r) => r.detractors },
  ];

  const detractorCols: Column<DetractorAlert>[] = [
    { header: 'Chain', accessor: (r) => r.chain_name },
    { header: 'Quarter', accessor: (r) => r.quarter },
    { header: 'Specialty', accessor: (r) => r.specialty },
    { header: 'Equipment', accessor: (r) => r.equipment_class },
    { header: 'Downtime', accessor: (r) => r.downtime_concern },
    { header: 'Score', accessor: (r) => r.score },
  ];

  const equipCols: Column<EquipClass>[] = [
    { header: 'Equipment Class', accessor: (r) => r.equipment_class },
    { header: 'Responses', accessor: (r) => r.responses },
    { header: 'Avg Score', accessor: (r) => r.avg_score },
    { header: 'Net Score', accessor: (r) => r.net_score },
  ];

  const regionCols: Column<Region>[] = [
    { header: 'Region', accessor: (r) => r.region },
    { header: 'Chains', accessor: (r) => r.chains },
    { header: 'Beds', accessor: (r) => r.total_beds },
    { header: 'Responses', accessor: (r) => r.total_responses },
    { header: 'Net Score', accessor: (r) => r.net_score },
  ];

  return (
    <div className="p-6 space-y-8">
      <header>
        <h1 className="text-2xl font-bold">Hospital Chain Quarterly Doctor-Survey Equipment-Confidence Net Score</h1>
        <p className="text-sm text-gray-600">Round r2947 — chain-level NPS-style confidence tracking from doctor surveys</p>
      </header>

      <section>
        <h2 className="text-lg font-semibold mb-2">Chain Net Score Overview</h2>
        <DataTable
          rows={overviewRows}
          columns={overviewCols}
          emptyMessage="No chain overview data"
          rowKey={(r, i) => String((r as { chain_name?: string }).chain_name ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Quarterly Trend</h2>
        <DataTable
          rows={trendRows}
          columns={trendCols}
          emptyMessage="No quarterly data"
          rowKey={(r, i) => String((r as { quarter?: string }).quarter ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Response Rate by Chain & Quarter</h2>
        <DataTable
          rows={rateRows}
          columns={rateCols}
          emptyMessage="No response rate data"
          rowKey={(r, i) => String(i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Specialty Breakdown</h2>
        <DataTable
          rows={specialtyRows}
          columns={specialtyCols}
          emptyMessage="No specialty data"
          rowKey={(r, i) => String((r as { specialty?: string }).specialty ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Detractor Alerts (score &lt;=6 with moderate/severe downtime)</h2>
        <DataTable
          rows={detractorRows}
          columns={detractorCols}
          emptyMessage="No detractor alerts"
          rowKey={(r, i) => String(i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Equipment Class Confidence</h2>
        <DataTable
          rows={equipRows}
          columns={equipCols}
          emptyMessage="No equipment class data"
          rowKey={(r, i) => String((r as { equipment_class?: string }).equipment_class ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Regional Summary</h2>
        <DataTable
          rows={regionRows}
          columns={regionCols}
          emptyMessage="No regional data"
          rowKey={(r, i) => String((r as { region?: string }).region ?? i)}
        />
      </section>
    </div>
  );
}
