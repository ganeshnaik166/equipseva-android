import { requireFounder } from '@/lib/auth/requireFounder';
import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

type Kpi = { label: string; value: string | number };

async function safeRpc(sb: any, name: string, args: any = {}) {
  try {
    const { data, error } = await sb.rpc(name, args);
    if (error) return [];
    return data ?? [];
  } catch {
    return [];
  }
}

export default async function FounderEngineerEquipmentCertificationsPage() {
  await requireFounder();
  const sb = await getSupabaseServerClient();

  const certs = await safeRpc(sb, 'r1680_list_certs');
  const expiring = await safeRpc(sb, 'r1680_expiring_soon', { p_days: 90 });
  const coverage = await safeRpc(sb, 'r1680_cert_coverage_by_category');
  const lapsed = await safeRpc(sb, 'r1680_lapsed_certs');

  const certsArr: any[] = Array.isArray(certs) ? certs : [];
  const expiringArr: any[] = Array.isArray(expiring) ? expiring : [];
  const coverageArr: any[] = Array.isArray(coverage) ? coverage : [];
  const lapsedArr: any[] = Array.isArray(lapsed) ? lapsed : [];

  const totalCerts = certsArr.length;
  const activeCerts = certsArr.filter((c) => !c.is_lapsed).length;
  const lapsedCount = lapsedArr.length;
  const expiringCount = expiringArr.length;
  const uniqueEngineers = new Set(certsArr.map((c) => c.engineer_user_id)).size;
  const uniqueCategories = new Set(certsArr.map((c) => c.equipment_category)).size;
  const masterCount = certsArr.filter((c) => c.cert_level === 'master').length;
  const advancedCount = certsArr.filter((c) => c.cert_level === 'advanced').length;

  const kpis: Kpi[] = [
    { label: 'Total certs', value: totalCerts },
    { label: 'Active', value: activeCerts },
    { label: 'Lapsed', value: lapsedCount },
    { label: 'Expiring 90d', value: expiringCount },
    { label: 'Engineers', value: uniqueEngineers },
    { label: 'Categories', value: uniqueCategories },
    { label: 'Master', value: masterCount },
    { label: 'Advanced', value: advancedCount },
  ];

  const certCols: Column<any>[] = [
    { key: 'engineer_name', header: 'Engineer', render: (r: any) => r.engineer_name ?? '—' },
    { key: 'equipment_category', header: 'Category', render: (r: any) => r.equipment_category ?? '—' },
    { key: 'cert_level', header: 'Level', render: (r: any) => r.cert_level ?? '—' },
    { key: 'issued_on', header: 'Issued', render: (r: any) => r.issued_on ?? '—' },
    { key: 'expires_on', header: 'Expires', render: (r: any) => r.expires_on ?? '—' },
    { key: 'days_to_expiry', header: 'Days left', render: (r: any) => r.days_to_expiry ?? '—' },
    { key: 'issuer', header: 'Issuer', render: (r: any) => r.issuer ?? '—' },
  ];

  const expiringCols: Column<any>[] = [
    { key: 'engineer_name', header: 'Engineer', render: (r: any) => r.engineer_name ?? '—' },
    { key: 'equipment_category', header: 'Category', render: (r: any) => r.equipment_category ?? '—' },
    { key: 'cert_level', header: 'Level', render: (r: any) => r.cert_level ?? '—' },
    { key: 'expires_on', header: 'Expires', render: (r: any) => r.expires_on ?? '—' },
    { key: 'days_to_expiry', header: 'Days left', render: (r: any) => r.days_to_expiry ?? '—' },
    { key: 'window_bucket', header: 'Window', render: (r: any) => r.window_bucket ?? '—' },
    { key: 'issuer', header: 'Issuer', render: (r: any) => r.issuer ?? '—' },
  ];

  const coverageCols: Column<any>[] = [
    { key: 'equipment_category', header: 'Category', render: (r: any) => r.equipment_category ?? '—' },
    { key: 'total_certs', header: 'Total', render: (r: any) => r.total_certs ?? '—' },
    { key: 'basic_count', header: 'Basic', render: (r: any) => r.basic_count ?? '—' },
    { key: 'intermediate_count', header: 'Inter.', render: (r: any) => r.intermediate_count ?? '—' },
    { key: 'advanced_count', header: 'Adv.', render: (r: any) => r.advanced_count ?? '—' },
    { key: 'master_count', header: 'Master', render: (r: any) => r.master_count ?? '—' },
    { key: 'active_count', header: 'Active', render: (r: any) => r.active_count ?? '—' },
    { key: 'lapsed_count', header: 'Lapsed', render: (r: any) => r.lapsed_count ?? '—' },
    { key: 'unique_engineers', header: 'Engineers', render: (r: any) => r.unique_engineers ?? '—' },
  ];

  const lapsedCols: Column<any>[] = [
    { key: 'engineer_name', header: 'Engineer', render: (r: any) => r.engineer_name ?? '—' },
    { key: 'equipment_category', header: 'Category', render: (r: any) => r.equipment_category ?? '—' },
    { key: 'cert_level', header: 'Level', render: (r: any) => r.cert_level ?? '—' },
    { key: 'expires_on', header: 'Expired', render: (r: any) => r.expires_on ?? '—' },
    { key: 'days_lapsed', header: 'Days lapsed', render: (r: any) => r.days_lapsed ?? '—' },
    { key: 'queue_status', header: 'Queue', render: (r: any) => r.queue_status ?? '—' },
    { key: 'issuer', header: 'Issuer', render: (r: any) => r.issuer ?? '—' },
  ];

  return (
    <div className="p-6 space-y-6">
      <div>
        <h1 className="text-2xl font-bold">Engineer Equipment Certifications</h1>
        <p className="text-sm text-gray-500">Per-engineer cert per equipment category, expiry tracking, and renewal queue.</p>
      </div>

      <div className="grid grid-cols-2 md:grid-cols-4 lg:grid-cols-8 gap-3">
        {kpis.map((kp) => (
          <div key={kp.label} className="rounded-lg border p-3">
            <div className="text-xs text-gray-500">{kp.label}</div>
            <div className="text-lg font-semibold">{kp.value}</div>
          </div>
        ))}
      </div>

      <section className="space-y-2">
        <h2 className="text-lg font-semibold">All certifications</h2>
        <DataTable rows={certsArr} columns={certCols} rowKey={(r, i) => String(r.id ?? i)} />
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-semibold">Expiring in next 90 days</h2>
        <DataTable rows={expiringArr} columns={expiringCols} rowKey={(r, i) => String(r.id ?? i)} />
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-semibold">Coverage by equipment category</h2>
        <DataTable rows={coverageArr} columns={coverageCols} rowKey={(r, i) => String(r.equipment_category ?? i)} />
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-semibold">Lapsed certs (renewal queue)</h2>
        <DataTable rows={lapsedArr} columns={lapsedCols} rowKey={(r, i) => String(r.id ?? i)} />
      </section>
    </div>
  );
}
