import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type TripRow = {
  id: string;
  engineer_user_id: string | null;
  trip_at: string;
  from_label: string;
  to_label: string;
  km_driven: number;
  rate_per_km_rupees: number;
  claimed_rupees: number;
  paid_rupees: number;
  discrepancy_rupees: number;
  status: string;
  approver_email: string | null;
  paid_at: string | null;
  notes: string | null;
};

type CapRow = {
  id: string;
  engineer_user_id: string | null;
  month_start: string;
  total_km: number;
  total_claimed_rupees: number;
  total_paid_rupees: number;
  monthly_cap_rupees: number;
  cap_exceeded: boolean;
  cap_exceeded_rupees: number;
  status: string;
  notes: string | null;
};

type TopRow = {
  engineer_user_id: string;
  trip_count: number;
  total_km: number;
  total_claimed_rupees: number;
  total_paid_rupees: number;
};

type DiscrepancyRow = {
  id: string;
  engineer_user_id: string | null;
  trip_at: string;
  from_label: string;
  to_label: string;
  claimed_rupees: number;
  paid_rupees: number;
  discrepancy_rupees: number;
  status: string;
  notes: string | null;
};

type TrendRow = {
  month_start: string;
  engineer_count: number;
  total_km: number;
  total_claimed_rupees: number;
  total_paid_rupees: number;
  over_cap_count: number;
};

type BreachRow = {
  id: string;
  engineer_user_id: string | null;
  month_start: string;
  total_claimed_rupees: number;
  monthly_cap_rupees: number;
  cap_exceeded_rupees: number;
  status: string;
  notes: string | null;
};

type StatusRow = {
  status: string;
  trip_count: number;
  total_claimed_rupees: number;
  total_paid_rupees: number;
  total_discrepancy_rupees: number;
};

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [tripsRes, capsRes, topRes, discRes, trendRes, breachRes, statusRes] = await Promise.all([
    sb.rpc('list_trips_r2474'),
    sb.rpc('list_monthly_caps_r2474'),
    sb.rpc('top_claim_engineers_r2474'),
    sb.rpc('discrepancy_focus_r2474'),
    sb.rpc('monthly_total_trend_r2474'),
    sb.rpc('cap_breach_focus_r2474'),
    sb.rpc('status_breakdown_r2474'),
  ]);

  const trips: TripRow[] = (tripsRes.data as TripRow[] | null) ?? [];
  const caps: CapRow[] = (capsRes.data as CapRow[] | null) ?? [];
  const tops: TopRow[] = (topRes.data as TopRow[] | null) ?? [];
  const discs: DiscrepancyRow[] = (discRes.data as DiscrepancyRow[] | null) ?? [];
  const trends: TrendRow[] = (trendRes.data as TrendRow[] | null) ?? [];
  const breaches: BreachRow[] = (breachRes.data as BreachRow[] | null) ?? [];
  const statuses: StatusRow[] = (statusRes.data as StatusRow[] | null) ?? [];

  const tripCols: Column<TripRow>[] = [
    { key: 'trip_at', header: 'Trip At', render: (r: any) => r.trip_at ? String(r.trip_at).slice(0, 16).replace('T', ' ') : '—' },
    { key: 'engineer_user_id', header: 'Engineer', render: (r: any) => r.engineer_user_id ? String(r.engineer_user_id).slice(0, 8) : '—' },
    { key: 'from_label', header: 'From', render: (r: any) => r.from_label },
    { key: 'to_label', header: 'To', render: (r: any) => r.to_label },
    { key: 'km_driven', header: 'KM', render: (r: any) => r.km_driven },
    { key: 'rate_per_km_rupees', header: 'Rate/km', render: (r: any) => `Rs ${r.rate_per_km_rupees}` },
    { key: 'claimed_rupees', header: 'Claimed', render: (r: any) => `Rs ${r.claimed_rupees}` },
    { key: 'paid_rupees', header: 'Paid', render: (r: any) => `Rs ${r.paid_rupees}` },
    { key: 'discrepancy_rupees', header: 'Gap', render: (r: any) => `Rs ${r.discrepancy_rupees}` },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'approver_email', header: 'Approver', render: (r: any) => r.approver_email ?? '—' },
  ];

  const capCols: Column<CapRow>[] = [
    { key: 'month_start', header: 'Month', render: (r: any) => r.month_start },
    { key: 'engineer_user_id', header: 'Engineer', render: (r: any) => r.engineer_user_id ? String(r.engineer_user_id).slice(0, 8) : '—' },
    { key: 'total_km', header: 'KM', render: (r: any) => r.total_km },
    { key: 'total_claimed_rupees', header: 'Claimed', render: (r: any) => `Rs ${r.total_claimed_rupees}` },
    { key: 'total_paid_rupees', header: 'Paid', render: (r: any) => `Rs ${r.total_paid_rupees}` },
    { key: 'monthly_cap_rupees', header: 'Cap', render: (r: any) => `Rs ${r.monthly_cap_rupees}` },
    { key: 'cap_exceeded', header: 'Over?', render: (r: any) => r.cap_exceeded ? 'yes' : 'no' },
    { key: 'cap_exceeded_rupees', header: 'Over By', render: (r: any) => `Rs ${r.cap_exceeded_rupees}` },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
  ];

  const topCols: Column<TopRow>[] = [
    { key: 'engineer_user_id', header: 'Engineer', render: (r: any) => String(r.engineer_user_id).slice(0, 8) },
    { key: 'trip_count', header: 'Trips', render: (r: any) => r.trip_count },
    { key: 'total_km', header: 'Total KM', render: (r: any) => r.total_km },
    { key: 'total_claimed_rupees', header: 'Claimed', render: (r: any) => `Rs ${r.total_claimed_rupees}` },
    { key: 'total_paid_rupees', header: 'Paid', render: (r: any) => `Rs ${r.total_paid_rupees}` },
  ];

  const discCols: Column<DiscrepancyRow>[] = [
    { key: 'trip_at', header: 'Trip At', render: (r: any) => r.trip_at ? String(r.trip_at).slice(0, 16).replace('T', ' ') : '—' },
    { key: 'engineer_user_id', header: 'Engineer', render: (r: any) => r.engineer_user_id ? String(r.engineer_user_id).slice(0, 8) : '—' },
    { key: 'from_label', header: 'From', render: (r: any) => r.from_label },
    { key: 'to_label', header: 'To', render: (r: any) => r.to_label },
    { key: 'claimed_rupees', header: 'Claimed', render: (r: any) => `Rs ${r.claimed_rupees}` },
    { key: 'paid_rupees', header: 'Paid', render: (r: any) => `Rs ${r.paid_rupees}` },
    { key: 'discrepancy_rupees', header: 'Gap', render: (r: any) => `Rs ${r.discrepancy_rupees}` },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'notes', header: 'Notes', render: (r: any) => r.notes ?? '—' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'month_start', header: 'Month', render: (r: any) => r.month_start },
    { key: 'engineer_count', header: 'Engineers', render: (r: any) => r.engineer_count },
    { key: 'total_km', header: 'KM', render: (r: any) => r.total_km },
    { key: 'total_claimed_rupees', header: 'Claimed', render: (r: any) => `Rs ${r.total_claimed_rupees}` },
    { key: 'total_paid_rupees', header: 'Paid', render: (r: any) => `Rs ${r.total_paid_rupees}` },
    { key: 'over_cap_count', header: 'Over Cap', render: (r: any) => r.over_cap_count },
  ];

  const breachCols: Column<BreachRow>[] = [
    { key: 'month_start', header: 'Month', render: (r: any) => r.month_start },
    { key: 'engineer_user_id', header: 'Engineer', render: (r: any) => r.engineer_user_id ? String(r.engineer_user_id).slice(0, 8) : '—' },
    { key: 'total_claimed_rupees', header: 'Claimed', render: (r: any) => `Rs ${r.total_claimed_rupees}` },
    { key: 'monthly_cap_rupees', header: 'Cap', render: (r: any) => `Rs ${r.monthly_cap_rupees}` },
    { key: 'cap_exceeded_rupees', header: 'Over By', render: (r: any) => `Rs ${r.cap_exceeded_rupees}` },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'notes', header: 'Notes', render: (r: any) => r.notes ?? '—' },
  ];

  const statusCols: Column<StatusRow>[] = [
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'trip_count', header: 'Trips', render: (r: any) => r.trip_count },
    { key: 'total_claimed_rupees', header: 'Claimed', render: (r: any) => `Rs ${r.total_claimed_rupees}` },
    { key: 'total_paid_rupees', header: 'Paid', render: (r: any) => `Rs ${r.total_paid_rupees}` },
    { key: 'total_discrepancy_rupees', header: 'Discrepancy', render: (r: any) => `Rs ${r.total_discrepancy_rupees}` },
  ];

  return (
    <div className="p-6 space-y-8">
      <header>
        <h1 className="text-2xl font-bold">Engineer Mileage Reimbursement Ledger</h1>
        <p className="text-sm text-gray-600">Per-trip km & rate & INR claimed & paid & discrepancy & monthly cap.</p>
      </header>

      <section>
        <h2 className="text-lg font-semibold mb-2">Trips</h2>
        <DataTable
          rows={trips}
          columns={tripCols}
          emptyMessage="No trips logged yet."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Monthly Caps</h2>
        <DataTable
          rows={caps}
          columns={capCols}
          emptyMessage="No monthly caps yet."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Top Claim Engineers</h2>
        <DataTable
          rows={tops}
          columns={topCols}
          emptyMessage="No engineer claim data yet."
          rowKey={(r: any, i: number) => String(r.engineer_user_id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Discrepancy Focus</h2>
        <DataTable
          rows={discs}
          columns={discCols}
          emptyMessage="No discrepancies flagged."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Monthly Total Trend</h2>
        <DataTable
          rows={trends}
          columns={trendCols}
          emptyMessage="No monthly trend yet."
          rowKey={(r: any, i: number) => String(r.month_start ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Cap Breach Focus</h2>
        <DataTable
          rows={breaches}
          columns={breachCols}
          emptyMessage="No cap breaches."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Status Breakdown</h2>
        <DataTable
          rows={statuses}
          columns={statusCols}
          emptyMessage="No status data yet."
          rowKey={(r: any, i: number) => String(r.status ?? i)}
        />
      </section>
    </div>
  );
}
