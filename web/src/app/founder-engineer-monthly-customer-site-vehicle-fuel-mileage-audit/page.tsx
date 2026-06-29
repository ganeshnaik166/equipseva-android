import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type FuelLog = {
  id?: string;
  engineer_code: string;
  engineer_name: string;
  log_month: string;
  vehicle_plate: string;
  claimed_km: number;
  gps_verified_km: number;
  fuel_cost_rupees: number;
  reimbursement_status: string;
};

type FlaggedLog = {
  id?: string;
  engineer_code: string;
  engineer_name: string;
  claimed_km: number;
  gps_verified_km: number;
  km_gap: number;
  flagged_reason: string | null;
};

type SiteVisit = {
  id?: string;
  engineer_code: string;
  hospital_name: string;
  city: string;
  visit_date: string;
  distance_one_way_km: number;
  claimed_amount_rupees: number;
  approved_amount_rupees: number;
  variance_rupees: number;
  audit_status: string;
};

type Totals = {
  id?: string;
  engineer_code: string;
  total_fuel_rupees: number;
  total_mileage_claimed: number;
  total_mileage_approved: number;
  total_variance: number;
};

type Receipt = {
  id?: string;
  engineer_code: string;
  engineer_name: string;
  receipts_uploaded: number;
  receipts_required: number;
  compliance_pct: number;
};

type Variance = {
  id?: string;
  engineer_code: string;
  hospital_name: string;
  visit_date: string;
  claimed_amount_rupees: number;
  approved_amount_rupees: number;
  variance_rupees: number;
  notes: string | null;
};

type Kpi = {
  total_engineers: number;
  total_fuel_spend: number;
  total_km_claimed: number;
  total_km_verified: number;
  flagged_logs: number;
  total_visits: number;
  total_variance: number;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [fuelLogs, flagged, visits, totals, receipts, variance, kpis] = await Promise.all([
    supabase.rpc('rpc_r2918_fuel_log_overview'),
    supabase.rpc('rpc_r2918_flagged_fuel_logs'),
    supabase.rpc('rpc_r2918_site_visit_audit'),
    supabase.rpc('rpc_r2918_engineer_reimbursement_totals'),
    supabase.rpc('rpc_r2918_receipt_compliance'),
    supabase.rpc('rpc_r2918_top_variance_visits'),
    supabase.rpc('rpc_r2918_monthly_kpis'),
  ]);

  const fuelRows: FuelLog[] = (fuelLogs.data as FuelLog[]) ?? [];
  const flaggedRows: FlaggedLog[] = (flagged.data as FlaggedLog[]) ?? [];
  const visitRows: SiteVisit[] = (visits.data as SiteVisit[]) ?? [];
  const totalsRows: Totals[] = (totals.data as Totals[]) ?? [];
  const receiptRows: Receipt[] = (receipts.data as Receipt[]) ?? [];
  const varianceRows: Variance[] = (variance.data as Variance[]) ?? [];
  const kpi: Kpi | null = ((kpis.data as Kpi[]) ?? [])[0] ?? null;

  const fuelCols: Column<FuelLog>[] = [
    { key: 'engineer_code', header: 'Engineer', render: (r) => r.engineer_code },
    { key: 'engineer_name', header: 'Name', render: (r) => r.engineer_name },
    { key: 'log_month', header: 'Month', render: (r) => r.log_month },
    { key: 'vehicle_plate', header: 'Vehicle', render: (r) => r.vehicle_plate },
    { key: 'claimed_km', header: 'Claimed km', render: (r) => r.claimed_km },
    { key: 'gps_verified_km', header: 'GPS km', render: (r) => r.gps_verified_km },
    { key: 'fuel_cost_rupees', header: 'Fuel Rs', render: (r) => r.fuel_cost_rupees },
    { key: 'reimbursement_status', header: 'Status', render: (r) => r.reimbursement_status },
  ];

  const flaggedCols: Column<FlaggedLog>[] = [
    { key: 'engineer_code', header: 'Engineer', render: (r) => r.engineer_code },
    { key: 'engineer_name', header: 'Name', render: (r) => r.engineer_name },
    { key: 'claimed_km', header: 'Claimed km', render: (r) => r.claimed_km },
    { key: 'gps_verified_km', header: 'GPS km', render: (r) => r.gps_verified_km },
    { key: 'km_gap', header: 'Gap km', render: (r) => r.km_gap },
    { key: 'flagged_reason', header: 'Reason', render: (r) => r.flagged_reason ?? '' },
  ];

  const visitCols: Column<SiteVisit>[] = [
    { key: 'engineer_code', header: 'Engineer', render: (r) => r.engineer_code },
    { key: 'hospital_name', header: 'Hospital', render: (r) => r.hospital_name },
    { key: 'city', header: 'City', render: (r) => r.city },
    { key: 'visit_date', header: 'Visit', render: (r) => r.visit_date },
    { key: 'distance_one_way_km', header: 'One-way km', render: (r) => r.distance_one_way_km },
    { key: 'claimed_amount_rupees', header: 'Claimed Rs', render: (r) => r.claimed_amount_rupees },
    { key: 'approved_amount_rupees', header: 'Approved Rs', render: (r) => r.approved_amount_rupees },
    { key: 'variance_rupees', header: 'Variance Rs', render: (r) => r.variance_rupees },
    { key: 'audit_status', header: 'Audit', render: (r) => r.audit_status },
  ];

  const totalsCols: Column<Totals>[] = [
    { key: 'engineer_code', header: 'Engineer', render: (r) => r.engineer_code },
    { key: 'total_fuel_rupees', header: 'Fuel Rs', render: (r) => r.total_fuel_rupees },
    { key: 'total_mileage_claimed', header: 'Mileage Claimed', render: (r) => r.total_mileage_claimed },
    { key: 'total_mileage_approved', header: 'Mileage Approved', render: (r) => r.total_mileage_approved },
    { key: 'total_variance', header: 'Variance', render: (r) => r.total_variance },
  ];

  const receiptCols: Column<Receipt>[] = [
    { key: 'engineer_code', header: 'Engineer', render: (r) => r.engineer_code },
    { key: 'engineer_name', header: 'Name', render: (r) => r.engineer_name },
    { key: 'receipts_uploaded', header: 'Uploaded', render: (r) => r.receipts_uploaded },
    { key: 'receipts_required', header: 'Required', render: (r) => r.receipts_required },
    { key: 'compliance_pct', header: 'Compliance %', render: (r) => r.compliance_pct },
  ];

  const varianceCols: Column<Variance>[] = [
    { key: 'engineer_code', header: 'Engineer', render: (r) => r.engineer_code },
    { key: 'hospital_name', header: 'Hospital', render: (r) => r.hospital_name },
    { key: 'visit_date', header: 'Date', render: (r) => r.visit_date },
    { key: 'claimed_amount_rupees', header: 'Claimed', render: (r) => r.claimed_amount_rupees },
    { key: 'approved_amount_rupees', header: 'Approved', render: (r) => r.approved_amount_rupees },
    { key: 'variance_rupees', header: 'Variance', render: (r) => r.variance_rupees },
    { key: 'notes', header: 'Notes', render: (r) => r.notes ?? '' },
  ];

  return (
    <div style={{ padding: '24px', maxWidth: '1400px', margin: '0 auto' }}>
      <h1 style={{ fontSize: '28px', fontWeight: 700, marginBottom: '8px' }}>
        Engineer Monthly Customer Site Vehicle Fuel & Mileage Reimbursement Audit
      </h1>
      <p style={{ color: '#666', marginBottom: '24px' }}>
        Founder review of engineer-claimed fuel & mileage vs GPS-verified distance for
        customer site visits. Flag inflated claims, enforce receipt compliance, reconcile
        approved vs claimed Rs. r2918.
      </p>

      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(180px, 1fr))', gap: '12px', marginBottom: '32px' }}>
        <KpiCard label="Engineers" value={kpi?.total_engineers ?? 0} />
        <KpiCard label="Fuel Spend Rs" value={kpi?.total_fuel_spend ?? 0} />
        <KpiCard label="Km Claimed" value={kpi?.total_km_claimed ?? 0} />
        <KpiCard label="Km GPS-Verified" value={kpi?.total_km_verified ?? 0} />
        <KpiCard label="Flagged Logs" value={kpi?.flagged_logs ?? 0} />
        <KpiCard label="Site Visits" value={kpi?.total_visits ?? 0} />
        <KpiCard label="Total Variance Rs" value={kpi?.total_variance ?? 0} />
      </div>

      <Section title="Fuel Log Overview">
        <DataTable
          rows={fuelRows}
          columns={fuelCols}
          emptyMessage="No fuel logs"
          rowKey={(r, i) => String(r.id ?? i)}
        />
      </Section>

      <Section title="Flagged Fuel Logs (claimed km > GPS km)">
        <DataTable
          rows={flaggedRows}
          columns={flaggedCols}
          emptyMessage="No flagged logs"
          rowKey={(r, i) => String(r.id ?? i)}
        />
      </Section>

      <Section title="Site Visit Mileage Audit">
        <DataTable
          rows={visitRows}
          columns={visitCols}
          emptyMessage="No site visits"
          rowKey={(r, i) => String(r.id ?? i)}
        />
      </Section>

      <Section title="Engineer Reimbursement Totals">
        <DataTable
          rows={totalsRows}
          columns={totalsCols}
          emptyMessage="No totals"
          rowKey={(r, i) => String(r.id ?? i)}
        />
      </Section>

      <Section title="Receipt Compliance (uploaded vs required)">
        <DataTable
          rows={receiptRows}
          columns={receiptCols}
          emptyMessage="No data"
          rowKey={(r, i) => String(r.id ?? i)}
        />
      </Section>

      <Section title="Top Variance Visits (claim > approved)">
        <DataTable
          rows={varianceRows}
          columns={varianceCols}
          emptyMessage="No variance"
          rowKey={(r, i) => String(r.id ?? i)}
        />
      </Section>
    </div>
  );
}

function KpiCard({ label, value }: { label: string; value: number | string }) {
  return (
    <div style={{ border: '1px solid #e5e7eb', borderRadius: '8px', padding: '16px', background: '#fff' }}>
      <div style={{ fontSize: '12px', color: '#6b7280', marginBottom: '4px' }}>{label}</div>
      <div style={{ fontSize: '22px', fontWeight: 700 }}>{value}</div>
    </div>
  );
}

function Section({ title, children }: { title: string; children: React.ReactNode }) {
  return (
    <section style={{ marginBottom: '32px' }}>
      <h2 style={{ fontSize: '18px', fontWeight: 600, marginBottom: '12px' }}>{title}</h2>
      {children}
    </section>
  );
}
