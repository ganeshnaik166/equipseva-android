import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type MonthRollup = {
  month_label: string;
  claims: number;
  oem_total: number;
  our_total: number;
  gross_total: number;
  approved_pct: number;
};

type EquipmentBreakdown = {
  equipment_kind: string;
  claims: number;
  total_rs: number;
  avg_resolution_days: number;
};

type ClaimKindMix = {
  claim_kind: string;
  claims: number;
  oem_share: number;
  our_share: number;
};

type DisputeHeatmap = {
  dispute_state: string;
  claims: number;
  open_amount_rs: number;
};

type OutcomeFunnel = {
  outcome: string;
  claims: number;
  amount_rs: number;
  pct: number;
};

type OpenClaim = {
  claim_code: string;
  customer_org: string;
  equipment_kind: string;
  claim_kind: string;
  dispute_state: string;
  total_claim_rs: number;
  filed_at: string;
};

type DisputeNote = {
  claim_code: string;
  note_kind: string;
  severity: string;
  author_role: string;
  note_body: string;
  created_at: string;
};

type CostSplit = {
  metric: string;
  value_rs: number;
};

function rupees(n: number | null | undefined): string {
  if (n == null) return '0';
  return '₹' + Number(n).toLocaleString('en-IN');
}

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [monthRes, equipRes, kindRes, dispRes, outcomeRes, openRes, notesRes, costRes] = await Promise.all([
    supabase.rpc('r2680_month_rollup'),
    supabase.rpc('r2680_equipment_breakdown'),
    supabase.rpc('r2680_claim_kind_mix'),
    supabase.rpc('r2680_dispute_heatmap'),
    supabase.rpc('r2680_outcome_funnel'),
    supabase.rpc('r2680_open_claims'),
    supabase.rpc('r2680_recent_dispute_notes'),
    supabase.rpc('r2680_cost_split_summary'),
  ]);

  const months = (monthRes.data ?? []) as MonthRollup[];
  const equipment = (equipRes.data ?? []) as EquipmentBreakdown[];
  const kinds = (kindRes.data ?? []) as ClaimKindMix[];
  const disputes = (dispRes.data ?? []) as DisputeHeatmap[];
  const outcomes = (outcomeRes.data ?? []) as OutcomeFunnel[];
  const openClaims = (openRes.data ?? []) as OpenClaim[];
  const notes = (notesRes.data ?? []) as DisputeNote[];
  const cost = (costRes.data ?? []) as CostSplit[];

  const totalClaims = months.reduce((acc, m) => acc + (m.claims ?? 0), 0);
  const grossTotal = months.reduce((acc, m) => acc + Number(m.gross_total ?? 0), 0);
  const openCount = openClaims.length;
  const escalated = disputes.find((d) => d.dispute_state === 'escalated')?.claims ?? 0;

  return (
    <div className="mx-auto max-w-7xl space-y-8 p-6">
      <header className="space-y-2">
        <h1 className="text-2xl font-semibold">Customer Monthly Warranty Claim Disposition</h1>
        <p className="text-sm text-gray-600">
          Round r2680 founder console. Equipment kind, claim kind, OEM vs our cover, dispute state and outcome.
        </p>
      </header>

      <section className="grid grid-cols-2 gap-4 md:grid-cols-4">
        <div className="rounded-lg border bg-white p-4">
          <div className="text-xs uppercase text-gray-500">Total claims</div>
          <div className="text-2xl font-semibold">{totalClaims}</div>
        </div>
        <div className="rounded-lg border bg-white p-4">
          <div className="text-xs uppercase text-gray-500">Gross claim value</div>
          <div className="text-2xl font-semibold">{rupees(grossTotal)}</div>
        </div>
        <div className="rounded-lg border bg-white p-4">
          <div className="text-xs uppercase text-gray-500">Open claims</div>
          <div className="text-2xl font-semibold">{openCount}</div>
        </div>
        <div className="rounded-lg border bg-white p-4">
          <div className="text-xs uppercase text-gray-500">Escalated</div>
          <div className="text-2xl font-semibold">{escalated}</div>
        </div>
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-medium">Monthly rollup</h2>
        <DataTable
          rows={months}
          columns={[
            { key: 'month_label', header: 'Month', render: (r: MonthRollup) => r.month_label },
            { key: 'claims', header: 'Claims', render: (r: MonthRollup) => String(r.claims) },
            { key: 'oem_total', header: 'OEM covered', render: (r: MonthRollup) => rupees(r.oem_total) },
            { key: 'our_total', header: 'Our covered', render: (r: MonthRollup) => rupees(r.our_total) },
            { key: 'gross_total', header: 'Gross', render: (r: MonthRollup) => rupees(r.gross_total) },
            { key: 'approved_pct', header: 'Approved pct', render: (r: MonthRollup) => String(r.approved_pct) + '%' },
          ]}
          emptyMessage="No data"
          rowKey={(r, i) => String((r as MonthRollup).month_label ?? i)}
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-medium">Cost split summary</h2>
        <DataTable
          rows={cost}
          columns={[
            { key: 'metric', header: 'Metric', render: (r: CostSplit) => r.metric },
            { key: 'value_rs', header: 'Amount', render: (r: CostSplit) => rupees(r.value_rs) },
          ]}
          emptyMessage="No data"
          rowKey={(r, i) => String((r as CostSplit).metric ?? i)}
        />
      </section>

      <section className="grid gap-6 md:grid-cols-2">
        <div className="space-y-3">
          <h2 className="text-lg font-medium">Equipment breakdown</h2>
          <DataTable
            rows={equipment}
            columns={[
              { key: 'equipment_kind', header: 'Equipment', render: (r: EquipmentBreakdown) => r.equipment_kind },
              { key: 'claims', header: 'Claims', render: (r: EquipmentBreakdown) => String(r.claims) },
              { key: 'total_rs', header: 'Total', render: (r: EquipmentBreakdown) => rupees(r.total_rs) },
              { key: 'avg_resolution_days', header: 'Avg days', render: (r: EquipmentBreakdown) => String(r.avg_resolution_days) },
            ]}
            emptyMessage="No data"
            rowKey={(r, i) => String((r as EquipmentBreakdown).equipment_kind ?? i)}
          />
        </div>

        <div className="space-y-3">
          <h2 className="text-lg font-medium">Claim kind mix</h2>
          <DataTable
            rows={kinds}
            columns={[
              { key: 'claim_kind', header: 'Kind', render: (r: ClaimKindMix) => r.claim_kind },
              { key: 'claims', header: 'Claims', render: (r: ClaimKindMix) => String(r.claims) },
              { key: 'oem_share', header: 'OEM share', render: (r: ClaimKindMix) => rupees(r.oem_share) },
              { key: 'our_share', header: 'Our share', render: (r: ClaimKindMix) => rupees(r.our_share) },
            ]}
            emptyMessage="No data"
            rowKey={(r, i) => String((r as ClaimKindMix).claim_kind ?? i)}
          />
        </div>
      </section>

      <section className="grid gap-6 md:grid-cols-2">
        <div className="space-y-3">
          <h2 className="text-lg font-medium">Dispute heatmap</h2>
          <DataTable
            rows={disputes}
            columns={[
              { key: 'dispute_state', header: 'State', render: (r: DisputeHeatmap) => r.dispute_state },
              { key: 'claims', header: 'Claims', render: (r: DisputeHeatmap) => String(r.claims) },
              { key: 'open_amount_rs', header: 'Open amount', render: (r: DisputeHeatmap) => rupees(r.open_amount_rs) },
            ]}
            emptyMessage="No data"
            rowKey={(r, i) => String((r as DisputeHeatmap).dispute_state ?? i)}
          />
        </div>

        <div className="space-y-3">
          <h2 className="text-lg font-medium">Outcome funnel</h2>
          <DataTable
            rows={outcomes}
            columns={[
              { key: 'outcome', header: 'Outcome', render: (r: OutcomeFunnel) => r.outcome },
              { key: 'claims', header: 'Claims', render: (r: OutcomeFunnel) => String(r.claims) },
              { key: 'amount_rs', header: 'Amount', render: (r: OutcomeFunnel) => rupees(r.amount_rs) },
              { key: 'pct', header: 'Share', render: (r: OutcomeFunnel) => String(r.pct) + '%' },
            ]}
            emptyMessage="No data"
            rowKey={(r, i) => String((r as OutcomeFunnel).outcome ?? i)}
          />
        </div>
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-medium">Open and disputed claims</h2>
        <DataTable
          rows={openClaims}
          columns={[
            { key: 'claim_code', header: 'Code', render: (r: OpenClaim) => r.claim_code },
            { key: 'customer_org', header: 'Customer', render: (r: OpenClaim) => r.customer_org },
            { key: 'equipment_kind', header: 'Equipment', render: (r: OpenClaim) => r.equipment_kind },
            { key: 'claim_kind', header: 'Kind', render: (r: OpenClaim) => r.claim_kind },
            { key: 'dispute_state', header: 'Dispute', render: (r: OpenClaim) => r.dispute_state },
            { key: 'total_claim_rs', header: 'Amount', render: (r: OpenClaim) => rupees(r.total_claim_rs) },
            { key: 'filed_at', header: 'Filed', render: (r: OpenClaim) => new Date(r.filed_at).toLocaleDateString('en-IN') },
          ]}
          emptyMessage="No data"
          rowKey={(r, i) => String((r as OpenClaim).claim_code ?? i)}
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-medium">Recent dispute notes</h2>
        <DataTable
          rows={notes}
          columns={[
            { key: 'claim_code', header: 'Claim', render: (r: DisputeNote) => r.claim_code },
            { key: 'note_kind', header: 'Kind', render: (r: DisputeNote) => r.note_kind },
            { key: 'severity', header: 'Severity', render: (r: DisputeNote) => r.severity },
            { key: 'author_role', header: 'Author', render: (r: DisputeNote) => r.author_role },
            { key: 'note_body', header: 'Note', render: (r: DisputeNote) => r.note_body },
            { key: 'created_at', header: 'When', render: (r: DisputeNote) => new Date(r.created_at).toLocaleDateString('en-IN') },
          ]}
          emptyMessage="No data"
          rowKey={(r, i) => String(i)}
        />
      </section>
    </div>
  );
}
