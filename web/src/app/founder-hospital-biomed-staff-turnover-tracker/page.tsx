import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [kpis, highRisk, recent, byHospital, reasons, primary, gaps] = await Promise.all([
    sb.rpc('founder_biomed_turnover_kpis_r2235'),
    sb.rpc('founder_biomed_high_risk_staff_r2235'),
    sb.rpc('founder_biomed_recent_transitions_r2235'),
    sb.rpc('founder_biomed_by_hospital_r2235'),
    sb.rpc('founder_biomed_departure_reasons_r2235'),
    sb.rpc('founder_biomed_primary_contacts_r2235'),
    sb.rpc('founder_biomed_handover_gaps_r2235'),
  ]);

  const kpiRows = (kpis.data ?? []) as any[];
  const highRiskRows = (highRisk.data ?? []) as any[];
  const recentRows = (recent.data ?? []) as any[];
  const hospitalRows = (byHospital.data ?? []) as any[];
  const reasonRows = (reasons.data ?? []) as any[];
  const primaryRows = (primary.data ?? []) as any[];
  const gapRows = (gaps.data ?? []) as any[];

  const kpiCols: Column<any>[] = [
    { key: 'metric', header: 'Metric', render: (r: any) => String(r.metric ?? '') },
    { key: 'value', header: 'Value', render: (r: any) => String(r.value ?? '') },
  ];

  const highRiskCols: Column<any>[] = [
    { key: 'hospital', header: 'Hospital', render: (r: any) => String(r.hospital ?? '') },
    { key: 'staff', header: 'Staff', render: (r: any) => String(r.staff ?? '') },
    { key: 'role', header: 'Role', render: (r: any) => String(r.role ?? '') },
    { key: 'risk', header: 'Risk', render: (r: any) => String(r.risk ?? '') },
    { key: 'amc_rupees', header: 'AMC Rupees', render: (r: any) => String(r.amc_rupees ?? '') },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
    { key: 'is_primary', header: 'Primary', render: (r: any) => r.is_primary ? 'yes' : 'no' },
  ];

  const recentCols: Column<any>[] = [
    { key: 'when_date', header: 'Date', render: (r: any) => String(r.when_date ?? '') },
    { key: 'hospital', header: 'Hospital', render: (r: any) => String(r.hospital ?? '') },
    { key: 'staff', header: 'Staff', render: (r: any) => String(r.staff ?? '') },
    { key: 'transition', header: 'Transition', render: (r: any) => String(r.transition ?? '') },
    { key: 'reason', header: 'Reason', render: (r: any) => String(r.reason ?? '') },
    { key: 'exposure', header: 'Exposure', render: (r: any) => String(r.exposure ?? '') },
    { key: 'mitigation', header: 'Mitigation', render: (r: any) => String(r.mitigation ?? '') },
  ];

  const hospitalCols: Column<any>[] = [
    { key: 'hospital', header: 'Hospital', render: (r: any) => String(r.hospital ?? '') },
    { key: 'total_staff', header: 'Total Staff', render: (r: any) => String(r.total_staff ?? '') },
    { key: 'active', header: 'Active', render: (r: any) => String(r.active ?? '') },
    { key: 'departed_90d', header: 'Left 90d', render: (r: any) => String(r.departed_90d ?? '') },
    { key: 'max_risk', header: 'Max Risk', render: (r: any) => String(r.max_risk ?? '') },
    { key: 'amc_at_risk', header: 'AMC At Risk', render: (r: any) => String(r.amc_at_risk ?? '') },
  ];

  const reasonCols: Column<any>[] = [
    { key: 'reason', header: 'Reason', render: (r: any) => String(r.reason ?? '') },
    { key: 'count', header: 'Count', render: (r: any) => String(r.count ?? '') },
    { key: 'total_exposure', header: 'Total Exposure', render: (r: any) => String(r.total_exposure ?? '') },
  ];

  const primaryCols: Column<any>[] = [
    { key: 'hospital', header: 'Hospital', render: (r: any) => String(r.hospital ?? '') },
    { key: 'staff', header: 'Staff', render: (r: any) => String(r.staff ?? '') },
    { key: 'role', header: 'Role', render: (r: any) => String(r.role ?? '') },
    { key: 'relationship', header: 'Relationship', render: (r: any) => String(r.relationship ?? '') },
    { key: 'amc_rupees', header: 'AMC Rupees', render: (r: any) => String(r.amc_rupees ?? '') },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
  ];

  const gapCols: Column<any>[] = [
    { key: 'hospital', header: 'Hospital', render: (r: any) => String(r.hospital ?? '') },
    { key: 'staff', header: 'Staff', render: (r: any) => String(r.staff ?? '') },
    { key: 'transition', header: 'Transition', render: (r: any) => String(r.transition ?? '') },
    { key: 'when_date', header: 'Date', render: (r: any) => String(r.when_date ?? '') },
    { key: 'exposure', header: 'Exposure', render: (r: any) => String(r.exposure ?? '') },
    { key: 'mitigation', header: 'Mitigation', render: (r: any) => String(r.mitigation ?? '') },
  ];

  return (
    <div style={{ padding: 24, maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 8 }}>Hospital Biomed Staff Turnover Tracker</h1>
      <p style={{ color: '#555', marginBottom: 24 }}>
        Track biomedical engineers joining &amp; leaving hospitals. When key contact leaves &gt; AMC at risk.
        Departure reasons, mitigation plans &amp; handover gaps captured.
      </p>

      <h2 style={{ fontSize: 18, fontWeight: 600, marginTop: 16 }}>Turnover KPIs</h2>
      <DataTable columns={kpiCols} rows={kpiRows} rowKey={(_, i) => String(i)} />

      <h2 style={{ fontSize: 18, fontWeight: 600, marginTop: 24 }}>High Risk Staff (risk &gt;= 70)</h2>
      <DataTable columns={highRiskCols} rows={highRiskRows} rowKey={(_, i) => String(i)} />

      <h2 style={{ fontSize: 18, fontWeight: 600, marginTop: 24 }}>Recent Transitions</h2>
      <DataTable columns={recentCols} rows={recentRows} rowKey={(_, i) => String(i)} />

      <h2 style={{ fontSize: 18, fontWeight: 600, marginTop: 24 }}>By Hospital</h2>
      <DataTable columns={hospitalCols} rows={hospitalRows} rowKey={(_, i) => String(i)} />

      <h2 style={{ fontSize: 18, fontWeight: 600, marginTop: 24 }}>Departure Reasons</h2>
      <DataTable columns={reasonCols} rows={reasonRows} rowKey={(_, i) => String(i)} />

      <h2 style={{ fontSize: 18, fontWeight: 600, marginTop: 24 }}>Primary Hospital Contacts</h2>
      <DataTable columns={primaryCols} rows={primaryRows} rowKey={(_, i) => String(i)} />

      <h2 style={{ fontSize: 18, fontWeight: 600, marginTop: 24 }}>Unmitigated Handover Gaps</h2>
      <DataTable columns={gapCols} rows={gapRows} rowKey={(_, i) => String(i)} />
    </div>
  );
}
