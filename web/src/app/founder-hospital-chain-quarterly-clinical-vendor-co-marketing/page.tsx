import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Kpi = {
  total_campaigns: number;
  active_campaigns: number;
  total_shared_cost_rupees: number;
  total_revenue_attributed_rupees: number;
  blended_roi_multiple: number;
  total_leads_actual: number;
  blended_lead_attainment_pct: number;
};

type CampaignRow = {
  id: string;
  chain_name: string;
  vendor_name: string;
  campaign_name: string;
  quarter: string;
  clinical_focus: string;
  campaign_type: string;
  shared_cost_rupees: number;
  leads_actual: number;
  leads_target: number;
  revenue_attributed_rupees: number;
  roi_multiple: number;
  status: string;
  outcome_grade: string | null;
};

type ChainRow = {
  chain_name: string;
  campaigns: number;
  shared_cost_rupees: number;
  revenue_attributed_rupees: number;
  roi_multiple: number;
  total_leads: number;
};

type VendorRow = {
  vendor_name: string;
  campaigns: number;
  shared_cost_rupees: number;
  revenue_attributed_rupees: number;
  roi_multiple: number;
  total_leads: number;
};

type ClinicalRow = {
  clinical_focus: string;
  campaigns: number;
  shared_cost_rupees: number;
  revenue_attributed_rupees: number;
  roi_multiple: number;
};

type FunnelRow = {
  campaign_name: string;
  funnel_stage: string;
  leads_count: number;
  cost_per_lead_rupees: number;
  conversion_pct: number;
};

type OutcomeRow = {
  outcome_grade: string;
  campaigns: number;
  shared_cost_rupees: number;
  revenue_attributed_rupees: number;
};

type QuarterRow = {
  quarter: string;
  campaigns: number;
  shared_cost_rupees: number;
  revenue_attributed_rupees: number;
  roi_multiple: number;
};

function fmtINR(n: number | null | undefined) {
  if (n == null) return '-';
  return '₹' + Number(n).toLocaleString('en-IN', { maximumFractionDigits: 0 });
}

function fmtNum(n: number | null | undefined) {
  if (n == null) return '-';
  return Number(n).toLocaleString('en-IN');
}

function fmtPct(n: number | null | undefined) {
  if (n == null) return '-';
  return Number(n).toFixed(2) + '%';
}

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    kpiRes,
    campaignsRes,
    chainRes,
    vendorRes,
    clinicalRes,
    funnelRes,
    outcomeRes,
    quarterRes,
  ] = await Promise.all([
    supabase.rpc('founder_r2827_kpi_overview'),
    supabase.rpc('founder_r2827_campaigns_list'),
    supabase.rpc('founder_r2827_chain_rollup'),
    supabase.rpc('founder_r2827_vendor_rollup'),
    supabase.rpc('founder_r2827_clinical_focus_mix'),
    supabase.rpc('founder_r2827_funnel_summary'),
    supabase.rpc('founder_r2827_outcome_distribution'),
    supabase.rpc('founder_r2827_quarter_trend'),
  ]);

  const kpi: Kpi | null = (kpiRes.data as Kpi[] | null)?.[0] ?? null;
  const campaigns: CampaignRow[] = (campaignsRes.data as CampaignRow[] | null) ?? [];
  const chains: ChainRow[] = (chainRes.data as ChainRow[] | null) ?? [];
  const vendors: VendorRow[] = (vendorRes.data as VendorRow[] | null) ?? [];
  const clinical: ClinicalRow[] = (clinicalRes.data as ClinicalRow[] | null) ?? [];
  const funnel: FunnelRow[] = (funnelRes.data as FunnelRow[] | null) ?? [];
  const outcomes: OutcomeRow[] = (outcomeRes.data as OutcomeRow[] | null) ?? [];
  const quarters: QuarterRow[] = (quarterRes.data as QuarterRow[] | null) ?? [];

  return (
    <main className="p-6 space-y-8">
      <header>
        <h1 className="text-2xl font-bold">Hospital Chain Quarterly Clinical Vendor Co-Marketing</h1>
        <p className="text-sm text-gray-600 mt-1">
          Chain × vendor × campaign tracker — shared cost, leads, ROI & outcome
          grade across quarters. Founder-only console.
        </p>
      </header>

      <section className="grid grid-cols-2 md:grid-cols-4 gap-4">
        <div className="border rounded p-4">
          <div className="text-xs text-gray-500">Campaigns</div>
          <div className="text-2xl font-semibold">{fmtNum(kpi?.total_campaigns)}</div>
          <div className="text-xs text-gray-500 mt-1">
            Active: {fmtNum(kpi?.active_campaigns)}
          </div>
        </div>
        <div className="border rounded p-4">
          <div className="text-xs text-gray-500">Total Shared Cost</div>
          <div className="text-2xl font-semibold">{fmtINR(kpi?.total_shared_cost_rupees)}</div>
        </div>
        <div className="border rounded p-4">
          <div className="text-xs text-gray-500">Revenue Attributed</div>
          <div className="text-2xl font-semibold">
            {fmtINR(kpi?.total_revenue_attributed_rupees)}
          </div>
          <div className="text-xs text-gray-500 mt-1">
            Blended ROI: {kpi?.blended_roi_multiple?.toFixed(2) ?? '-'}x
          </div>
        </div>
        <div className="border rounded p-4">
          <div className="text-xs text-gray-500">Total Leads</div>
          <div className="text-2xl font-semibold">{fmtNum(kpi?.total_leads_actual)}</div>
          <div className="text-xs text-gray-500 mt-1">
            Attainment: {fmtPct(kpi?.blended_lead_attainment_pct)}
          </div>
        </div>
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-3">Campaigns</h2>
        <DataTable
          rows={campaigns}
          columns={[
            { key: 'campaign_name', header: 'Campaign', render: (r: CampaignRow) => r.campaign_name },
            { key: 'chain_name', header: 'Chain', render: (r: CampaignRow) => r.chain_name },
            { key: 'vendor_name', header: 'Vendor', render: (r: CampaignRow) => r.vendor_name },
            { key: 'quarter', header: 'Quarter', render: (r: CampaignRow) => r.quarter },
            {
              key: 'clinical_focus',
              header: 'Clinical Focus',
              render: (r: CampaignRow) => r.clinical_focus,
            },
            {
              key: 'campaign_type',
              header: 'Type',
              render: (r: CampaignRow) => r.campaign_type,
            },
            {
              key: 'shared_cost_rupees',
              header: 'Shared Cost',
              render: (r: CampaignRow) => fmtINR(r.shared_cost_rupees),
            },
            {
              key: 'leads_actual',
              header: 'Leads (act/tgt)',
              render: (r: CampaignRow) => fmtNum(r.leads_actual) + ' / ' + fmtNum(r.leads_target),
            },
            {
              key: 'revenue_attributed_rupees',
              header: 'Revenue',
              render: (r: CampaignRow) => fmtINR(r.revenue_attributed_rupees),
            },
            {
              key: 'roi_multiple',
              header: 'ROI',
              render: (r: CampaignRow) => (r.roi_multiple ?? 0).toFixed(2) + 'x',
            },
            { key: 'status', header: 'Status', render: (r: CampaignRow) => r.status },
            {
              key: 'outcome_grade',
              header: 'Grade',
              render: (r: CampaignRow) => r.outcome_grade ?? '-',
            },
          ]}
          emptyMessage="No data"
          rowKey={(r: CampaignRow, i: number) => String(r.id ?? i)}
        />
      </section>

      <section className="grid grid-cols-1 md:grid-cols-2 gap-6">
        <div>
          <h2 className="text-lg font-semibold mb-3">By Chain</h2>
          <DataTable
            rows={chains}
            columns={[
              { key: 'chain_name', header: 'Chain', render: (r: ChainRow) => r.chain_name },
              { key: 'campaigns', header: 'Campaigns', render: (r: ChainRow) => fmtNum(r.campaigns) },
              {
                key: 'shared_cost_rupees',
                header: 'Spend',
                render: (r: ChainRow) => fmtINR(r.shared_cost_rupees),
              },
              {
                key: 'revenue_attributed_rupees',
                header: 'Revenue',
                render: (r: ChainRow) => fmtINR(r.revenue_attributed_rupees),
              },
              {
                key: 'roi_multiple',
                header: 'ROI',
                render: (r: ChainRow) => (r.roi_multiple ?? 0).toFixed(2) + 'x',
              },
              {
                key: 'total_leads',
                header: 'Leads',
                render: (r: ChainRow) => fmtNum(r.total_leads),
              },
            ]}
            emptyMessage="No data"
            rowKey={(r: ChainRow, i: number) => String(r.chain_name ?? i)}
          />
        </div>
        <div>
          <h2 className="text-lg font-semibold mb-3">By Vendor</h2>
          <DataTable
            rows={vendors}
            columns={[
              { key: 'vendor_name', header: 'Vendor', render: (r: VendorRow) => r.vendor_name },
              {
                key: 'campaigns',
                header: 'Campaigns',
                render: (r: VendorRow) => fmtNum(r.campaigns),
              },
              {
                key: 'shared_cost_rupees',
                header: 'Spend',
                render: (r: VendorRow) => fmtINR(r.shared_cost_rupees),
              },
              {
                key: 'revenue_attributed_rupees',
                header: 'Revenue',
                render: (r: VendorRow) => fmtINR(r.revenue_attributed_rupees),
              },
              {
                key: 'roi_multiple',
                header: 'ROI',
                render: (r: VendorRow) => (r.roi_multiple ?? 0).toFixed(2) + 'x',
              },
              {
                key: 'total_leads',
                header: 'Leads',
                render: (r: VendorRow) => fmtNum(r.total_leads),
              },
            ]}
            emptyMessage="No data"
            rowKey={(r: VendorRow, i: number) => String(r.vendor_name ?? i)}
          />
        </div>
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-3">Clinical Focus Mix</h2>
        <DataTable
          rows={clinical}
          columns={[
            {
              key: 'clinical_focus',
              header: 'Focus',
              render: (r: ClinicalRow) => r.clinical_focus,
            },
            {
              key: 'campaigns',
              header: 'Campaigns',
              render: (r: ClinicalRow) => fmtNum(r.campaigns),
            },
            {
              key: 'shared_cost_rupees',
              header: 'Spend',
              render: (r: ClinicalRow) => fmtINR(r.shared_cost_rupees),
            },
            {
              key: 'revenue_attributed_rupees',
              header: 'Revenue',
              render: (r: ClinicalRow) => fmtINR(r.revenue_attributed_rupees),
            },
            {
              key: 'roi_multiple',
              header: 'ROI',
              render: (r: ClinicalRow) => (r.roi_multiple ?? 0).toFixed(2) + 'x',
            },
          ]}
          emptyMessage="No data"
          rowKey={(r: ClinicalRow, i: number) => String(r.clinical_focus ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-3">Lead Funnel</h2>
        <DataTable
          rows={funnel}
          columns={[
            {
              key: 'campaign_name',
              header: 'Campaign',
              render: (r: FunnelRow) => r.campaign_name,
            },
            { key: 'funnel_stage', header: 'Stage', render: (r: FunnelRow) => r.funnel_stage },
            {
              key: 'leads_count',
              header: 'Leads',
              render: (r: FunnelRow) => fmtNum(r.leads_count),
            },
            {
              key: 'cost_per_lead_rupees',
              header: 'CPL',
              render: (r: FunnelRow) => fmtINR(r.cost_per_lead_rupees),
            },
            {
              key: 'conversion_pct',
              header: 'Conv %',
              render: (r: FunnelRow) => fmtPct(r.conversion_pct),
            },
          ]}
          emptyMessage="No data"
          rowKey={(r: FunnelRow, i: number) =>
            String((r.campaign_name ?? '') + '-' + (r.funnel_stage ?? '') + '-' + i)
          }
        />
      </section>

      <section className="grid grid-cols-1 md:grid-cols-2 gap-6">
        <div>
          <h2 className="text-lg font-semibold mb-3">Outcome Grades</h2>
          <DataTable
            rows={outcomes}
            columns={[
              {
                key: 'outcome_grade',
                header: 'Grade',
                render: (r: OutcomeRow) => r.outcome_grade,
              },
              {
                key: 'campaigns',
                header: 'Campaigns',
                render: (r: OutcomeRow) => fmtNum(r.campaigns),
              },
              {
                key: 'shared_cost_rupees',
                header: 'Spend',
                render: (r: OutcomeRow) => fmtINR(r.shared_cost_rupees),
              },
              {
                key: 'revenue_attributed_rupees',
                header: 'Revenue',
                render: (r: OutcomeRow) => fmtINR(r.revenue_attributed_rupees),
              },
            ]}
            emptyMessage="No data"
            rowKey={(r: OutcomeRow, i: number) => String(r.outcome_grade ?? i)}
          />
        </div>
        <div>
          <h2 className="text-lg font-semibold mb-3">Quarter Trend</h2>
          <DataTable
            rows={quarters}
            columns={[
              { key: 'quarter', header: 'Quarter', render: (r: QuarterRow) => r.quarter },
              {
                key: 'campaigns',
                header: 'Campaigns',
                render: (r: QuarterRow) => fmtNum(r.campaigns),
              },
              {
                key: 'shared_cost_rupees',
                header: 'Spend',
                render: (r: QuarterRow) => fmtINR(r.shared_cost_rupees),
              },
              {
                key: 'revenue_attributed_rupees',
                header: 'Revenue',
                render: (r: QuarterRow) => fmtINR(r.revenue_attributed_rupees),
              },
              {
                key: 'roi_multiple',
                header: 'ROI',
                render: (r: QuarterRow) => (r.roi_multiple ?? 0).toFixed(2) + 'x',
              },
            ]}
            emptyMessage="No data"
            rowKey={(r: QuarterRow, i: number) => String(r.quarter ?? i)}
          />
        </div>
      </section>
    </main>
  );
}
