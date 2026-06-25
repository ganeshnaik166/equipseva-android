import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Kpis = {
  total_events: number;
  gross_loss_rupees: number;
  recovery_rupees: number;
  net_loss_rupees: number;
  recovery_rate_pct: number;
  open_events: number;
  prevention_done_pct: number;
};

type ByHospital = {
  hospital_name: string;
  events: number;
  gross_loss: number;
  recovered: number;
  net_loss: number;
  open_count: number;
};

type ByLossType = {
  loss_type: string;
  events: number;
  gross_loss: number;
  net_loss: number;
  avg_recovery_pct: number;
};

type ByAssetCategory = {
  asset_category: string;
  events: number;
  gross_loss: number;
  net_loss: number;
  avg_unit_cost: number;
};

type OpenEvent = {
  id: string;
  hospital_name: string;
  asset_tag: string;
  asset_category: string;
  loss_type: string;
  net_loss_rupees: number;
  prevention_action: string;
  prevention_owner: string;
  prevention_due_date: string;
};

type PreventionRoi = {
  control_code: string;
  control_name: string;
  control_category: string;
  rollout_status: string;
  hospitals_covered: number;
  monthly_cost_rupees: number;
  estimated_loss_avoided_rupees: number;
  roi_multiple: number | null;
  effectiveness_score: number;
};

type EventRow = {
  id: string;
  reported_at: string;
  hospital_name: string;
  asset_tag: string;
  asset_category: string;
  last_seen_location: string;
  last_seen_custodian: string;
  loss_type: string;
  recovery_status: string;
  recovery_amount_rupees: number;
  net_loss_rupees: number;
  prevention_owner: string;
  prevention_done: boolean;
};

function rupees(n: number | null | undefined): string {
  const v = Number(n ?? 0);
  return '₹' + v.toLocaleString('en-IN');
}

function pct(n: number | null | undefined): string {
  const v = Number(n ?? 0);
  return v.toFixed(1) + '%';
}

function fmtDate(s: string | null | undefined): string {
  if (!s) return '—';
  try { return new Date(s).toLocaleString('en-IN'); } catch { return s; }
}

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [kpisRes, hospRes, lossRes, catRes, openRes, roiRes, eventsRes] = await Promise.all([
    supabase.rpc('rpc_r2756_monthly_kpis'),
    supabase.rpc('rpc_r2756_by_hospital'),
    supabase.rpc('rpc_r2756_by_loss_type'),
    supabase.rpc('rpc_r2756_by_asset_category'),
    supabase.rpc('rpc_r2756_open_events'),
    supabase.rpc('rpc_r2756_prevention_roi'),
    supabase.rpc('rpc_r2756_events_list'),
  ]);

  const kpis: Kpis = (kpisRes.data as Kpis[] | null)?.[0] ?? {
    total_events: 0, gross_loss_rupees: 0, recovery_rupees: 0,
    net_loss_rupees: 0, recovery_rate_pct: 0, open_events: 0, prevention_done_pct: 0,
  };
  const byHospital: ByHospital[] = (hospRes.data as ByHospital[] | null) ?? [];
  const byLossType: ByLossType[] = (lossRes.data as ByLossType[] | null) ?? [];
  const byCategory: ByAssetCategory[] = (catRes.data as ByAssetCategory[] | null) ?? [];
  const openEvents: OpenEvent[] = (openRes.data as OpenEvent[] | null) ?? [];
  const roi: PreventionRoi[] = (roiRes.data as PreventionRoi[] | null) ?? [];
  const events: EventRow[] = (eventsRes.data as EventRow[] | null) ?? [];

  return (
    <div className="p-6 space-y-8 max-w-7xl mx-auto">
      <header className="space-y-2">
        <h1 className="text-2xl font-semibold">
          Customer Monthly Portable Equipment Loss & Recovery
        </h1>
        <p className="text-sm text-gray-600">
          Asset × last-seen × loss type × recovery × cost × prevention action.
          Every portable probe, pump, glucometer, battery & loaner tracked month-by-month with
          recovery rate &gt;= 80% target.
        </p>
      </header>

      <section className="grid grid-cols-2 md:grid-cols-4 gap-4">
        <KpiCard label="Total Events" value={String(kpis.total_events)} />
        <KpiCard label="Gross Loss" value={rupees(kpis.gross_loss_rupees)} />
        <KpiCard label="Recovered" value={rupees(kpis.recovery_rupees)} />
        <KpiCard label="Net Loss" value={rupees(kpis.net_loss_rupees)} />
        <KpiCard label="Recovery Rate" value={pct(kpis.recovery_rate_pct)} />
        <KpiCard label="Open Events" value={String(kpis.open_events)} />
        <KpiCard label="Prevention Done" value={pct(kpis.prevention_done_pct)} />
        <KpiCard label="Target Recovery" value=">= 80%" />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-semibold">By Hospital</h2>
        <DataTable
          rows={byHospital}
          columns={[
            { key: 'hospital_name', header: 'Hospital', render: (r: ByHospital) => r.hospital_name },
            { key: 'events', header: 'Events', render: (r: ByHospital) => r.events },
            { key: 'gross_loss', header: 'Gross Loss', render: (r: ByHospital) => rupees(r.gross_loss) },
            { key: 'recovered', header: 'Recovered', render: (r: ByHospital) => rupees(r.recovered) },
            { key: 'net_loss', header: 'Net Loss', render: (r: ByHospital) => rupees(r.net_loss) },
            { key: 'open_count', header: 'Open', render: (r: ByHospital) => r.open_count },
          ]}
          emptyMessage="No data"
          rowKey={(r: ByHospital, i: number) => String((r as { hospital_name?: string }).hospital_name ?? i)}
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-semibold">By Loss Type</h2>
        <DataTable
          rows={byLossType}
          columns={[
            { key: 'loss_type', header: 'Loss Type', render: (r: ByLossType) => r.loss_type },
            { key: 'events', header: 'Events', render: (r: ByLossType) => r.events },
            { key: 'gross_loss', header: 'Gross Loss', render: (r: ByLossType) => rupees(r.gross_loss) },
            { key: 'net_loss', header: 'Net Loss', render: (r: ByLossType) => rupees(r.net_loss) },
            { key: 'avg_recovery_pct', header: 'Recovery %', render: (r: ByLossType) => pct(r.avg_recovery_pct) },
          ]}
          emptyMessage="No data"
          rowKey={(r: ByLossType, i: number) => String(r.loss_type ?? i)}
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-semibold">By Asset Category</h2>
        <DataTable
          rows={byCategory}
          columns={[
            { key: 'asset_category', header: 'Category', render: (r: ByAssetCategory) => r.asset_category },
            { key: 'events', header: 'Events', render: (r: ByAssetCategory) => r.events },
            { key: 'avg_unit_cost', header: 'Avg Unit Cost', render: (r: ByAssetCategory) => rupees(r.avg_unit_cost) },
            { key: 'gross_loss', header: 'Gross Loss', render: (r: ByAssetCategory) => rupees(r.gross_loss) },
            { key: 'net_loss', header: 'Net Loss', render: (r: ByAssetCategory) => rupees(r.net_loss) },
          ]}
          emptyMessage="No data"
          rowKey={(r: ByAssetCategory, i: number) => String(r.asset_category ?? i)}
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-semibold">Open Events & Prevention Actions Due</h2>
        <DataTable
          rows={openEvents}
          columns={[
            { key: 'hospital_name', header: 'Hospital', render: (r: OpenEvent) => r.hospital_name },
            { key: 'asset_tag', header: 'Asset Tag', render: (r: OpenEvent) => r.asset_tag },
            { key: 'asset_category', header: 'Category', render: (r: OpenEvent) => r.asset_category },
            { key: 'loss_type', header: 'Loss Type', render: (r: OpenEvent) => r.loss_type },
            { key: 'net_loss_rupees', header: 'Net Loss', render: (r: OpenEvent) => rupees(r.net_loss_rupees) },
            { key: 'prevention_action', header: 'Prevention Action', render: (r: OpenEvent) => r.prevention_action },
            { key: 'prevention_owner', header: 'Owner', render: (r: OpenEvent) => r.prevention_owner },
            { key: 'prevention_due_date', header: 'Due', render: (r: OpenEvent) => r.prevention_due_date },
          ]}
          emptyMessage="No data"
          rowKey={(r: OpenEvent, i: number) => String(r.id ?? i)}
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-semibold">Prevention Playbook ROI</h2>
        <p className="text-sm text-gray-600">
          ROI multiple = estimated loss avoided / monthly cost. Effectiveness score is 0–100.
          Aim controls with effectiveness &gt;= 80 and ROI multiple &gt;= 5×.
        </p>
        <DataTable
          rows={roi}
          columns={[
            { key: 'control_code', header: 'Code', render: (r: PreventionRoi) => r.control_code },
            { key: 'control_name', header: 'Control', render: (r: PreventionRoi) => r.control_name },
            { key: 'control_category', header: 'Category', render: (r: PreventionRoi) => r.control_category },
            { key: 'rollout_status', header: 'Status', render: (r: PreventionRoi) => r.rollout_status },
            { key: 'hospitals_covered', header: 'Hospitals', render: (r: PreventionRoi) => r.hospitals_covered },
            { key: 'monthly_cost_rupees', header: 'Monthly Cost', render: (r: PreventionRoi) => rupees(r.monthly_cost_rupees) },
            { key: 'estimated_loss_avoided_rupees', header: 'Loss Avoided', render: (r: PreventionRoi) => rupees(r.estimated_loss_avoided_rupees) },
            { key: 'roi_multiple', header: 'ROI x', render: (r: PreventionRoi) => r.roi_multiple == null ? '—' : (r.roi_multiple + 'x') },
            { key: 'effectiveness_score', header: 'Effectiveness', render: (r: PreventionRoi) => r.effectiveness_score + '/100' },
          ]}
          emptyMessage="No data"
          rowKey={(r: PreventionRoi, i: number) => String(r.control_code ?? i)}
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-semibold">All Loss Events</h2>
        <DataTable
          rows={events}
          columns={[
            { key: 'reported_at', header: 'Reported', render: (r: EventRow) => fmtDate(r.reported_at) },
            { key: 'hospital_name', header: 'Hospital', render: (r: EventRow) => r.hospital_name },
            { key: 'asset_tag', header: 'Tag', render: (r: EventRow) => r.asset_tag },
            { key: 'asset_category', header: 'Category', render: (r: EventRow) => r.asset_category },
            { key: 'last_seen_location', header: 'Last Seen', render: (r: EventRow) => r.last_seen_location },
            { key: 'last_seen_custodian', header: 'Custodian', render: (r: EventRow) => r.last_seen_custodian },
            { key: 'loss_type', header: 'Loss Type', render: (r: EventRow) => r.loss_type },
            { key: 'recovery_status', header: 'Status', render: (r: EventRow) => r.recovery_status },
            { key: 'recovery_amount_rupees', header: 'Recovered', render: (r: EventRow) => rupees(r.recovery_amount_rupees) },
            { key: 'net_loss_rupees', header: 'Net Loss', render: (r: EventRow) => rupees(r.net_loss_rupees) },
            { key: 'prevention_owner', header: 'Owner', render: (r: EventRow) => r.prevention_owner },
            { key: 'prevention_done', header: 'Done', render: (r: EventRow) => r.prevention_done ? 'yes' : 'no' },
          ]}
          emptyMessage="No data"
          rowKey={(r: EventRow, i: number) => String(r.id ?? i)}
        />
      </section>
    </div>
  );
}

function KpiCard({ label, value }: { label: string; value: string }) {
  return (
    <div className="rounded-lg border border-gray-200 bg-white p-4 shadow-sm">
      <div className="text-xs uppercase tracking-wide text-gray-500">{label}</div>
      <div className="mt-1 text-xl font-semibold text-gray-900">{value}</div>
    </div>
  );
}
