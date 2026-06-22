import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [staffRes, hospitalsRes, bucketsRes, recentRes] = await Promise.all([
    sb.rpc('list_biomed_staff_r2199'),
    sb.rpc('top_hospitals_r2199'),
    sb.rpc('cert_expiry_buckets_r2199'),
    sb.rpc('recent_actions_r2199'),
  ]);

  const staff: any[] = staffRes.data ?? [];
  const hospitals: any[] = hospitalsRes.data ?? [];
  const buckets: any[] = bucketsRes.data ?? [];
  const recent: any[] = recentRes.data ?? [];

  const totalStaff = staff.length;
  const gapStaff = staff.filter((s) => s.gap_flag && s.gap_flag !== 'ok').length;
  const avgCompetency =
    totalStaff > 0
      ? (
          staff.reduce((acc, s) => acc + (Number(s.competency_score) || 0), 0) /
          totalStaff
        ).toFixed(1)
      : '0.0';
  const expiringSoon = buckets
    .filter((b) => b.bucket === 'expired' || b.bucket === 'lt_30d' || b.bucket === 'lt_60d')
    .reduce((acc, b) => acc + (Number(b.cert_count) || 0), 0);

  const staffCols: Column<any>[] = [
    { key: 'staff_name', header: 'Staff', render: (r: any) => String(r.staff_name ?? '') },
    { key: 'hospital_name', header: 'Hospital', render: (r: any) => String(r.hospital_name ?? '') },
    { key: 'role_title', header: 'Role', render: (r: any) => String(r.role_title ?? '') },
    { key: 'years_experience', header: 'Years', render: (r: any) => String(r.years_experience ?? '') },
    {
      key: 'modalities_covered',
      header: 'Modalities',
      render: (r) => (Array.isArray(r.modalities_covered) ? r.modalities_covered.join(', ') : ''),
    },
    { key: 'competency_score', header: 'Score', render: (r: any) => String(r.competency_score ?? '') },
    { key: 'gap_flag', header: 'Gap', render: (r: any) => String(r.gap_flag ?? '') },
  ];

  const hospitalCols: Column<any>[] = [
    { key: 'hospital_name', header: 'Hospital', render: (r: any) => String(r.hospital_name ?? '') },
    { key: 'staff_count', header: 'Staff', render: (r: any) => String(r.staff_count ?? '') },
    { key: 'avg_competency', header: 'Avg Score', render: (r: any) => String(r.avg_competency ?? '') },
    { key: 'expiring_cert_count', header: 'Expiring (<=60d)', render: (r: any) => String(r.expiring_cert_count ?? '') },
    { key: 'gap_count', header: 'Gaps', render: (r: any) => String(r.gap_count ?? '') },
  ];

  const bucketCols: Column<any>[] = [
    { key: 'bucket', header: 'Bucket', render: (r: any) => String(r.bucket ?? '') },
    { key: 'cert_count', header: 'Certs', render: (r: any) => String(r.cert_count ?? '') },
    { key: 'hospitals_affected', header: 'Hospitals', render: (r: any) => String(r.hospitals_affected ?? '') },
  ];

  const recentCols: Column<any>[] = [
    { key: 'op_name', header: 'Op', render: (r: any) => String(r.op_name ?? '') },
    { key: 'actor_email', header: 'Actor', render: (r: any) => String(r.actor_email ?? '') },
    {
      key: 'after_value',
      header: 'Payload',
      render: (r) => (r.after_value ? JSON.stringify(r.after_value) : ''),
    },
    { key: 'created_at', header: 'When', render: (r: any) => String(r.created_at ?? '') },
  ];

  return (
    <main className="p-6 space-y-6">
      <header>
        <h1 className="text-2xl font-semibold">
          Hospital biomedical staff competency tracker
        </h1>
        <p className="text-sm text-gray-600">
          Track in-house biomed engineers at each hospital, their certifications &
          expiry windows, and surface competency gaps before they bite.
        </p>
      </header>

      <section className="grid grid-cols-2 md:grid-cols-4 gap-4">
        <div className="rounded-xl border p-4">
          <div className="text-xs uppercase text-gray-500">Total staff tracked</div>
          <div className="text-2xl font-semibold">{totalStaff}</div>
        </div>
        <div className="rounded-xl border p-4">
          <div className="text-xs uppercase text-gray-500">Staff flagged with gap</div>
          <div className="text-2xl font-semibold">{gapStaff}</div>
        </div>
        <div className="rounded-xl border p-4">
          <div className="text-xs uppercase text-gray-500">Avg competency score</div>
          <div className="text-2xl font-semibold">{avgCompetency}</div>
        </div>
        <div className="rounded-xl border p-4">
          <div className="text-xs uppercase text-gray-500">Certs expiring &lt;=60d</div>
          <div className="text-2xl font-semibold">{expiringSoon}</div>
        </div>
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-medium">Staff roster</h2>
        <DataTable columns={staffCols} rows={staff} rowKey={(_, i) => String(i)} />
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-medium">Top hospitals by staff coverage</h2>
        <DataTable columns={hospitalCols} rows={hospitals} rowKey={(_, i) => String(i)} />
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-medium">Certification expiry buckets</h2>
        <DataTable columns={bucketCols} rows={buckets} rowKey={(_, i) => String(i)} />
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-medium">Recent founder actions</h2>
        <DataTable columns={recentCols} rows={recent} rowKey={(_, i) => String(i)} />
      </section>
    </main>
  );
}
