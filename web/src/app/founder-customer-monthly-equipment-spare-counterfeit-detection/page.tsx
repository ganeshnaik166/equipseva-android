import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type SignalsOverview = {
  total_signals: number;
  confirmed_count: number;
  pending_count: number;
  quarantined_count: number;
  total_loss_rupees: number;
  total_units_affected: number;
};

type SignalRow = {
  signal_code: string;
  customer_org: string;
  asset_model: string;
  spare_part_name: string;
  supplier_name: string;
  signal_type: string;
  severity: string;
  verification_status: string;
  quarantine_status: string;
  units_affected: number;
  estimated_loss_rupees: number;
};

type SignalByType = {
  signal_type: string;
  signal_count: number;
  total_units: number;
  total_loss: number;
};

type SupplierBreakdown = {
  supplier_name: string;
  signal_count: number;
  confirmed_count: number;
  total_loss: number;
  open_actions: number;
};

type ActionRow = {
  action_code: string;
  supplier_name: string;
  related_signal_code: string | null;
  action_type: string;
  monetary_recovery_rupees: number;
  action_status: string;
  responsible_owner: string;
  due_at: string;
};

type ActionsOverview = {
  total_actions: number;
  open_actions: number;
  recovered_count: number;
  escalated_count: number;
  total_recovery: number;
  pending_recovery: number;
};

type SeverityRow = {
  severity: string;
  signal_count: number;
  confirmed_count: number;
  quarantined_count: number;
  total_loss: number;
};

type CustomerExposureRow = {
  customer_org: string;
  signal_count: number;
  units_affected: number;
  loss_rupees: number;
  worst_severity: string;
};

function rupees(n: number | null | undefined) {
  const v = Number(n ?? 0);
  return '₹' + v.toLocaleString('en-IN');
}

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    signalsOverviewRes,
    signalsListRes,
    signalsByTypeRes,
    supplierBreakdownRes,
    actionsListRes,
    actionsOverviewRes,
    severityRes,
    customerExposureRes,
  ] = await Promise.all([
    supabase.rpc('founder_r2812_signals_overview'),
    supabase.rpc('founder_r2812_signals_list'),
    supabase.rpc('founder_r2812_signals_by_type'),
    supabase.rpc('founder_r2812_supplier_breakdown'),
    supabase.rpc('founder_r2812_actions_list'),
    supabase.rpc('founder_r2812_actions_overview'),
    supabase.rpc('founder_r2812_severity_breakdown'),
    supabase.rpc('founder_r2812_customer_exposure'),
  ]);

  const overview: SignalsOverview = (signalsOverviewRes.data?.[0] ?? {
    total_signals: 0,
    confirmed_count: 0,
    pending_count: 0,
    quarantined_count: 0,
    total_loss_rupees: 0,
    total_units_affected: 0,
  }) as SignalsOverview;

  const signals = (signalsListRes.data ?? []) as SignalRow[];
  const byType = (signalsByTypeRes.data ?? []) as SignalByType[];
  const suppliers = (supplierBreakdownRes.data ?? []) as SupplierBreakdown[];
  const actions = (actionsListRes.data ?? []) as ActionRow[];
  const actionsOv: ActionsOverview = (actionsOverviewRes.data?.[0] ?? {
    total_actions: 0,
    open_actions: 0,
    recovered_count: 0,
    escalated_count: 0,
    total_recovery: 0,
    pending_recovery: 0,
  }) as ActionsOverview;
  const severity = (severityRes.data ?? []) as SeverityRow[];
  const customers = (customerExposureRes.data ?? []) as CustomerExposureRow[];

  return (
    <main className="p-6 space-y-6">
      <header>
        <h1 className="text-2xl font-bold">Counterfeit Spare Detection — r2812</h1>
        <p className="text-sm text-gray-600 mt-1">
          Asset × part × counterfeit signal × verification × quarantine × supplier action. Monthly cadence.
        </p>
      </header>

      <section className="grid grid-cols-2 md:grid-cols-4 gap-4">
        <div className="rounded border p-4">
          <div className="text-xs uppercase text-gray-500">Total signals</div>
          <div className="text-2xl font-semibold">{overview.total_signals}</div>
        </div>
        <div className="rounded border p-4">
          <div className="text-xs uppercase text-gray-500">Confirmed counterfeit</div>
          <div className="text-2xl font-semibold text-red-600">{overview.confirmed_count}</div>
        </div>
        <div className="rounded border p-4">
          <div className="text-xs uppercase text-gray-500">Quarantined</div>
          <div className="text-2xl font-semibold">{overview.quarantined_count}</div>
        </div>
        <div className="rounded border p-4">
          <div className="text-xs uppercase text-gray-500">Total loss</div>
          <div className="text-2xl font-semibold">{rupees(overview.total_loss_rupees)}</div>
        </div>
        <div className="rounded border p-4">
          <div className="text-xs uppercase text-gray-500">Units affected</div>
          <div className="text-2xl font-semibold">{overview.total_units_affected}</div>
        </div>
        <div className="rounded border p-4">
          <div className="text-xs uppercase text-gray-500">Open actions</div>
          <div className="text-2xl font-semibold">{actionsOv.open_actions}</div>
        </div>
        <div className="rounded border p-4">
          <div className="text-xs uppercase text-gray-500">Recovered</div>
          <div className="text-2xl font-semibold text-green-600">{rupees(actionsOv.total_recovery)}</div>
        </div>
        <div className="rounded border p-4">
          <div className="text-xs uppercase text-gray-500">Pending recovery</div>
          <div className="text-2xl font-semibold">{rupees(actionsOv.pending_recovery)}</div>
        </div>
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Counterfeit signals</h2>
        <DataTable
          rows={signals}
          rowKey={(r, i) => String((r as SignalRow).signal_code ?? i)}
          emptyMessage="No data"
          columns={[
            { key: 'signal_code', header: 'Code', render: (r: SignalRow) => r.signal_code },
            { key: 'customer_org', header: 'Customer', render: (r: SignalRow) => r.customer_org },
            { key: 'asset_model', header: 'Asset', render: (r: SignalRow) => r.asset_model },
            { key: 'spare_part_name', header: 'Spare part', render: (r: SignalRow) => r.spare_part_name },
            { key: 'supplier_name', header: 'Supplier', render: (r: SignalRow) => r.supplier_name },
            { key: 'signal_type', header: 'Signal type', render: (r: SignalRow) => r.signal_type },
            { key: 'severity', header: 'Severity', render: (r: SignalRow) => r.severity.toUpperCase() },
            { key: 'verification_status', header: 'Verification', render: (r: SignalRow) => r.verification_status },
            { key: 'quarantine_status', header: 'Quarantine', render: (r: SignalRow) => r.quarantine_status },
            { key: 'units_affected', header: 'Units', render: (r: SignalRow) => r.units_affected },
            { key: 'estimated_loss_rupees', header: 'Loss', render: (r: SignalRow) => rupees(r.estimated_loss_rupees) },
          ]}
        />
      </section>

      <section className="grid grid-cols-1 md:grid-cols-2 gap-6">
        <div>
          <h2 className="text-lg font-semibold mb-2">Signals by type</h2>
          <DataTable
            rows={byType}
            rowKey={(r, i) => String((r as SignalByType).signal_type ?? i)}
            emptyMessage="No data"
            columns={[
              { key: 'signal_type', header: 'Type', render: (r: SignalByType) => r.signal_type },
              { key: 'signal_count', header: 'Count', render: (r: SignalByType) => r.signal_count },
              { key: 'total_units', header: 'Units', render: (r: SignalByType) => r.total_units },
              { key: 'total_loss', header: 'Loss', render: (r: SignalByType) => rupees(r.total_loss) },
            ]}
          />
        </div>

        <div>
          <h2 className="text-lg font-semibold mb-2">Severity breakdown</h2>
          <DataTable
            rows={severity}
            rowKey={(r, i) => String((r as SeverityRow).severity ?? i)}
            emptyMessage="No data"
            columns={[
              { key: 'severity', header: 'Severity', render: (r: SeverityRow) => r.severity.toUpperCase() },
              { key: 'signal_count', header: 'Signals', render: (r: SeverityRow) => r.signal_count },
              { key: 'confirmed_count', header: 'Confirmed', render: (r: SeverityRow) => r.confirmed_count },
              { key: 'quarantined_count', header: 'Quarantined', render: (r: SeverityRow) => r.quarantined_count },
              { key: 'total_loss', header: 'Loss', render: (r: SeverityRow) => rupees(r.total_loss) },
            ]}
          />
        </div>
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Supplier breakdown</h2>
        <p className="text-xs text-gray-500 mb-2">
          Suppliers ranked by confirmed counterfeit count. Open actions = queued, in-progress, or escalated.
        </p>
        <DataTable
          rows={suppliers}
          rowKey={(r, i) => String((r as SupplierBreakdown).supplier_name ?? i)}
          emptyMessage="No data"
          columns={[
            { key: 'supplier_name', header: 'Supplier', render: (r: SupplierBreakdown) => r.supplier_name },
            { key: 'signal_count', header: 'Signals', render: (r: SupplierBreakdown) => r.signal_count },
            { key: 'confirmed_count', header: 'Confirmed', render: (r: SupplierBreakdown) => r.confirmed_count },
            { key: 'total_loss', header: 'Loss', render: (r: SupplierBreakdown) => rupees(r.total_loss) },
            { key: 'open_actions', header: 'Open actions', render: (r: SupplierBreakdown) => r.open_actions },
          ]}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Customer exposure</h2>
        <DataTable
          rows={customers}
          rowKey={(r, i) => String((r as CustomerExposureRow).customer_org ?? i)}
          emptyMessage="No data"
          columns={[
            { key: 'customer_org', header: 'Customer', render: (r: CustomerExposureRow) => r.customer_org },
            { key: 'signal_count', header: 'Signals', render: (r: CustomerExposureRow) => r.signal_count },
            { key: 'units_affected', header: 'Units', render: (r: CustomerExposureRow) => r.units_affected },
            { key: 'loss_rupees', header: 'Loss', render: (r: CustomerExposureRow) => rupees(r.loss_rupees) },
            { key: 'worst_severity', header: 'Worst severity', render: (r: CustomerExposureRow) => r.worst_severity.toUpperCase() },
          ]}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Supplier quarantine actions</h2>
        <DataTable
          rows={actions}
          rowKey={(r, i) => String((r as ActionRow).action_code ?? i)}
          emptyMessage="No data"
          columns={[
            { key: 'action_code', header: 'Code', render: (r: ActionRow) => r.action_code },
            { key: 'supplier_name', header: 'Supplier', render: (r: ActionRow) => r.supplier_name },
            { key: 'related_signal_code', header: 'Linked signal', render: (r: ActionRow) => r.related_signal_code ?? '—' },
            { key: 'action_type', header: 'Action', render: (r: ActionRow) => r.action_type },
            { key: 'monetary_recovery_rupees', header: 'Recovery', render: (r: ActionRow) => rupees(r.monetary_recovery_rupees) },
            { key: 'action_status', header: 'Status', render: (r: ActionRow) => r.action_status },
            { key: 'responsible_owner', header: 'Owner', render: (r: ActionRow) => r.responsible_owner },
            { key: 'due_at', header: 'Due', render: (r: ActionRow) => r.due_at },
          ]}
        />
      </section>
    </main>
  );
}