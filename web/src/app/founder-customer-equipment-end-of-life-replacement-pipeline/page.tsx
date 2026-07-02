import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function CustomerEquipmentEndOfLifeReplacementPipelinePage() {
  const supabase = await getSupabaseServerClient();

  const [
    eolRes,
    quotesRes,
    urgencyRes,
    upsellRes,
    pipelineRes,
    vendorRes,
    funnelRes,
  ] = await Promise.all([
    supabase.rpc('list_eol_r2472'),
    supabase.rpc('list_quotes_r2472'),
    supabase.rpc('top_urgency_focus_r2472'),
    supabase.rpc('top_upsell_opportunities_r2472'),
    supabase.rpc('monthly_replacement_pipeline_r2472'),
    supabase.rpc('vendor_quote_summary_r2472'),
    supabase.rpc('decision_funnel_r2472'),
  ]);

  const eol = (eolRes.data ?? []) as any[];
  const quotes = (quotesRes.data ?? []) as any[];
  const urgency = (urgencyRes.data ?? []) as any[];
  const upsell = (upsellRes.data ?? []) as any[];
  const pipeline = (pipelineRes.data ?? []) as any[];
  const vendor = (vendorRes.data ?? []) as any[];
  const funnel = (funnelRes.data ?? []) as any[];

  const fmtRupees = (n: number | null | undefined) =>
    n == null ? '—' : `₹${Number(n).toLocaleString('en-IN')}`;

  const eolCols: Column<any>[] = [
    { key: 'hospital_email', header: 'Hospital', render: (r: any) => r.hospital_email ?? '—' },
    { key: 'equipment_label', header: 'Equipment', render: (r: any) => r.equipment_label },
    { key: 'equipment_model', header: 'Model', render: (r: any) => r.equipment_model ?? '—' },
    { key: 'age_years', header: 'Age (y)', render: (r: any) => r.age_years },
    { key: 'mfg_eol_date', header: 'Mfg EOL', render: (r: any) => r.mfg_eol_date ?? '—' },
    { key: 'replacement_urgency', header: 'Urgency', render: (r: any) => r.replacement_urgency },
    { key: 'replacement_cost_rupees', header: 'Cost', render: (r: any) => fmtRupees(r.replacement_cost_rupees) },
    { key: 'upsell_opportunity_rupees', header: 'Upsell', render: (r: any) => fmtRupees(r.upsell_opportunity_rupees) },
    { key: 'decision_due_at', header: 'Decision Due', render: (r: any) => r.decision_due_at ? new Date(r.decision_due_at).toLocaleDateString() : '—' },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '—' },
    { key: 'notes', header: 'Notes', render: (r: any) => r.notes ?? '—' },
  ];

  const quoteCols: Column<any>[] = [
    { key: 'equipment_label', header: 'Equipment', render: (r: any) => r.equipment_label ?? '—' },
    { key: 'hospital_email', header: 'Hospital', render: (r: any) => r.hospital_email ?? '—' },
    { key: 'vendor_name', header: 'Vendor', render: (r: any) => r.vendor_name },
    { key: 'quote_external_ref', header: 'Ref', render: (r: any) => r.quote_external_ref ?? '—' },
    { key: 'quote_amount_rupees', header: 'Amount', render: (r: any) => fmtRupees(r.quote_amount_rupees) },
    { key: 'valid_until', header: 'Valid Until', render: (r: any) => r.valid_until ?? '—' },
    { key: 'decision', header: 'Decision', render: (r: any) => r.decision },
    { key: 'decided_at', header: 'Decided', render: (r: any) => r.decided_at ? new Date(r.decided_at).toLocaleDateString() : '—' },
    { key: 'decision_owner_email', header: 'Owner', render: (r: any) => r.decision_owner_email ?? '—' },
    { key: 'notes', header: 'Notes', render: (r: any) => r.notes ?? '—' },
  ];

  const urgencyCols: Column<any>[] = [
    { key: 'hospital_email', header: 'Hospital', render: (r: any) => r.hospital_email ?? '—' },
    { key: 'equipment_label', header: 'Equipment', render: (r: any) => r.equipment_label },
    { key: 'replacement_urgency', header: 'Urgency', render: (r: any) => r.replacement_urgency },
    { key: 'age_years', header: 'Age (y)', render: (r: any) => r.age_years },
    { key: 'mfg_eol_date', header: 'Mfg EOL', render: (r: any) => r.mfg_eol_date ?? '—' },
    { key: 'decision_due_at', header: 'Decision Due', render: (r: any) => r.decision_due_at ? new Date(r.decision_due_at).toLocaleDateString() : '—' },
    { key: 'replacement_cost_rupees', header: 'Cost', render: (r: any) => fmtRupees(r.replacement_cost_rupees) },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
  ];

  const upsellCols: Column<any>[] = [
    { key: 'hospital_email', header: 'Hospital', render: (r: any) => r.hospital_email ?? '—' },
    { key: 'equipment_label', header: 'Equipment', render: (r: any) => r.equipment_label },
    { key: 'upsell_opportunity_rupees', header: 'Upsell', render: (r: any) => fmtRupees(r.upsell_opportunity_rupees) },
    { key: 'replacement_cost_rupees', header: 'Cost', render: (r: any) => fmtRupees(r.replacement_cost_rupees) },
    { key: 'replacement_urgency', header: 'Urgency', render: (r: any) => r.replacement_urgency },
    { key: 'decision_due_at', header: 'Decision Due', render: (r: any) => r.decision_due_at ? new Date(r.decision_due_at).toLocaleDateString() : '—' },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
  ];

  const pipelineCols: Column<any>[] = [
    { key: 'decision_month', header: 'Month', render: (r: any) => r.decision_month },
    { key: 'pipeline_count', header: 'Count', render: (r: any) => r.pipeline_count },
    { key: 'total_replacement_cost_rupees', header: 'Replacement Cost', render: (r: any) => fmtRupees(r.total_replacement_cost_rupees) },
    { key: 'total_upsell_opportunity_rupees', header: 'Upsell Opp', render: (r: any) => fmtRupees(r.total_upsell_opportunity_rupees) },
  ];

  const vendorCols: Column<any>[] = [
    { key: 'vendor_name', header: 'Vendor', render: (r: any) => r.vendor_name },
    { key: 'quote_count', header: 'Quotes', render: (r: any) => r.quote_count },
    { key: 'accepted_count', header: 'Accepted', render: (r: any) => r.accepted_count },
    { key: 'rejected_count', header: 'Rejected', render: (r: any) => r.rejected_count },
    { key: 'total_accepted_rupees', header: 'Accepted Value', render: (r: any) => fmtRupees(r.total_accepted_rupees) },
    { key: 'avg_quote_rupees', header: 'Avg Quote', render: (r: any) => r.avg_quote_rupees ?? '—' },
  ];

  const funnelCols: Column<any>[] = [
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'eol_count', header: 'Count', render: (r: any) => r.eol_count },
    { key: 'pct', header: 'Percent', render: (r: any) => `${r.pct ?? 0}%` },
    { key: 'total_replacement_cost_rupees', header: 'Replacement Cost', render: (r: any) => fmtRupees(r.total_replacement_cost_rupees) },
  ];

  return (
    <div className="p-6 space-y-8">
      <header>
        <h1 className="text-2xl font-bold">Customer Equipment End-of-Life Replacement Pipeline</h1>
        <p className="text-sm text-gray-600">
          Equipment > age > replacement urgency > replacement cost > upsell opportunity > decision date.
        </p>
      </header>

      <section>
        <h2 className="text-lg font-semibold mb-2">Decision Funnel</h2>
        <DataTable
          rows={funnel}
          columns={funnelCols}
          emptyMessage="No EOL records yet."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Top Urgency Focus</h2>
        <DataTable
          rows={urgency}
          columns={urgencyCols}
          emptyMessage="No critical or high urgency items."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Top Upsell Opportunities</h2>
        <DataTable
          rows={upsell}
          columns={upsellCols}
          emptyMessage="No upsell opportunities tracked."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Monthly Replacement Pipeline</h2>
        <DataTable
          rows={pipeline}
          columns={pipelineCols}
          emptyMessage="No pipeline data yet."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Vendor Quote Summary</h2>
        <DataTable
          rows={vendor}
          columns={vendorCols}
          emptyMessage="No quotes recorded."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">All EOL Equipment</h2>
        <DataTable
          rows={eol}
          columns={eolCols}
          emptyMessage="No EOL equipment tracked yet."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">All Replacement Quotes</h2>
        <DataTable
          rows={quotes}
          columns={quoteCols}
          emptyMessage="No quotes recorded yet."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>
    </div>
  );
}
