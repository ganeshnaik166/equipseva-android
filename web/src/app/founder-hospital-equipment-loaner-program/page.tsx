import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const sb = await getSupabaseServerClient();
  const [loanersRes, byHospitalRes, recentRes] = await Promise.all([
    sb.rpc('list_loaners_r1971'),
    sb.rpc('active_loaners_by_hospital_r1971'),
    sb.rpc('recent_actions_r1971'),
  ]);

  const loaners: any[] = Array.isArray(loanersRes.data) ? loanersRes.data : [];
  const byHospital: any[] = Array.isArray(byHospitalRes.data) ? byHospitalRes.data : [];
  const recent: any[] = Array.isArray(recentRes.data) ? recentRes.data : [];

  const loanerCols: Column<any>[] = [
    { key: 'equipment_name', header: 'Equipment', render: (r: any) => String(r.equipment_name ?? '') },
    { key: 'hospital_name', header: 'Hospital', render: (r: any) => String(r.hospital_name ?? '') },
    { key: 'loan_value_rupees', header: 'Value (Rupees)', render: (r: any) => Number(r.loan_value_rupees ?? 0).toLocaleString('en-IN') },
    { key: 'loan_start_date', header: 'Start', render: (r: any) => String(r.loan_start_date ?? '') },
    { key: 'loan_end_date', header: 'End', render: (r: any) => String(r.loan_end_date ?? '-') },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
    { key: 'signed_at', header: 'Signed', render: (r: any) => r.signed_at ? new Date(r.signed_at).toLocaleDateString() : '-' },
  ];

  const hospitalCols: Column<any>[] = [
    { key: 'hospital_name', header: 'Hospital', render: (r: any) => String(r.hospital_name ?? '') },
    { key: 'active_count', header: 'Active Loaners', render: (r: any) => String(r.active_count ?? 0) },
    { key: 'total_value_rupees', header: 'Total Value (Rupees)', render: (r: any) => Number(r.total_value_rupees ?? 0).toLocaleString('en-IN') },
  ];

  const actionCols: Column<any>[] = [
    { key: 'equipment_name', header: 'Equipment', render: (r: any) => String(r.equipment_name ?? '') },
    { key: 'action_type', header: 'Action', render: (r: any) => String(r.action_type ?? '') },
    { key: 'taken_at', header: 'When', render: (r: any) => r.taken_at ? new Date(r.taken_at).toLocaleString() : '' },
    { key: 'by_email', header: 'By', render: (r: any) => String(r.by_email ?? '') },
  ];

  return (
    <main className="p-6 space-y-8">
      <header>
        <h1 className="text-2xl font-semibold">Hospital Equipment Loaner Program</h1>
        <p className="text-sm text-gray-600">Track loaners issued to hospitals, value at risk, and action history. Loaners above 90 days flagged for inspection.</p>
      </header>

      <section>
        <h2 className="text-lg font-medium mb-2">All Loaners</h2>
        <DataTable rows={loaners} columns={loanerCols} rowKey={(r, i) => String(r.id ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-medium mb-2">Active Loaners by Hospital</h2>
        <DataTable rows={byHospital} columns={hospitalCols} rowKey={(r, i) => String(r.hospital_id ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-medium mb-2">Recent Actions</h2>
        <DataTable rows={recent} columns={actionCols} rowKey={(r, i) => String(r.id ?? i)} />
      </section>
    </main>
  );
}
