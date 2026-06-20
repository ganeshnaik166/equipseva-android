import { requireFounder } from '@/lib/auth/requireFounder';
import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable } from '@/components/DataTable';
import { formatRupees } from '@/lib/format';

export const dynamic = 'force-dynamic';

function Kpi({ label, value }: { label: string; value: string | number }) {
  return (
    <div className="rounded-lg border border-slate-200 bg-white p-4 shadow-sm">
      <div className="text-xs uppercase tracking-wide text-slate-500">{label}</div>
      <div className="mt-1 text-2xl font-semibold text-slate-900">{value}</div>
    </div>
  );
}

export default async function FounderEngineerSkillCertificationsPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();

  const [kpiRes, expiringRes, vendorRes, leaderRes, trendRes, breachRes, logRes] = await Promise.all([
    supabase.rpc('founder_cert_kpis'),
    supabase.rpc('founder_cert_expiring_soon'),
    supabase.rpc('founder_cert_by_vendor'),
    supabase.rpc('founder_cert_engineer_leaderboard'),
    supabase.rpc('founder_cert_cost_trend'),
    supabase.rpc('founder_cert_renewal_sla_breaches'),
    supabase.rpc('founder_cert_recent_renewal_log'),
  ]);

  const k = (kpiRes.data?.[0] ?? {}) as any;
  const expiring = (expiringRes.data ?? []) as any[];
  const vendors = (vendorRes.data ?? []) as any[];
  const leaders = (leaderRes.data ?? []) as any[];
  const trend = (trendRes.data ?? []) as any[];
  const breaches = (breachRes.data ?? []) as any[];
  const logs = (logRes.data ?? []) as any[];

  return (
    <main className="mx-auto max-w-7xl space-y-8 p-6">
      <header>
        <h1 className="text-2xl font-semibold text-slate-900">Engineer Skill Certifications</h1>
        <p className="mt-1 text-sm text-slate-600">
          External OEM certs (Siemens, GE, Philips, etc.) with expiry tracking, renewal SLA, and cost-per-engineer accounting.
        </p>
      </header>

      <section className="grid grid-cols-2 md:grid-cols-4 gap-3">
        <Kpi label="Total Certs" value={k.total_certs ?? 0} />
        <Kpi label="Active" value={k.active_certs ?? 0} />
        <Kpi label="Expired" value={k.expired_certs ?? 0} />
        <Kpi label="Revoked" value={k.revoked_certs ?? 0} />
        <Kpi label="Renewal Pending" value={k.renewal_pending ?? 0} />
        <Kpi label="Expiring 30d" value={k.expiring_30d ?? 0} />
        <Kpi label="Expiring 60d" value={k.expiring_60d ?? 0} />
        <Kpi label="Expiring 90d" value={k.expiring_90d ?? 0} />
        <Kpi label="Unique Engineers" value={k.unique_engineers ?? 0} />
        <Kpi label="Unique Vendors" value={k.unique_vendors ?? 0} />
        <Kpi label="Avg Cost / Cert" value={formatRupees(k.avg_cost_rupees ?? 0)} />
        <Kpi label="Total Cost" value={formatRupees(k.total_cost_rupees ?? 0)} />
        <Kpi label="Company Funded" value={formatRupees(k.company_funded_rupees ?? 0)} />
        <Kpi label="Engineer Funded" value={formatRupees(k.engineer_funded_rupees ?? 0)} />
        <Kpi label="Expert Level" value={k.expert_level_count ?? 0} />
        <Kpi label="Vendor Sponsored" value={k.vendor_sponsored_count ?? 0} />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-semibold text-slate-900">Expiring in next 90 days</h2>
        <DataTable
          rows={expiring}
          rowKey={(r: any) => r.id}
          columns={[
            { key: 'engineer_name', header: 'Engineer', render: (r: any) => r.engineer_name },
            { key: 'oem_vendor', header: 'Vendor', render: (r: any) => r.oem_vendor },
            { key: 'cert_name', header: 'Cert', render: (r: any) => r.cert_name },
            { key: 'cert_level', header: 'Level', render: (r: any) => r.cert_level },
            { key: 'modality', header: 'Modality', render: (r: any) => r.modality },
            { key: 'expires_on', header: 'Expires', render: (r: any) => r.expires_on },
            { key: 'days_remaining', header: 'Days Left', render: (r: any) => r.days_remaining },
            { key: 'cost_rupees', header: 'Cost', render: (r: any) => formatRupees(r.cost_rupees ?? 0) },
            { key: 'status', header: 'Status', render: (r: any) => r.status },
          ]}
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-semibold text-slate-900">By OEM vendor</h2>
        <DataTable
          rows={vendors}
          rowKey={(r: any) => r.id}
          columns={[
            { key: 'oem_vendor', header: 'Vendor', render: (r: any) => r.oem_vendor },
            { key: 'cert_count', header: 'Certs', render: (r: any) => r.cert_count },
            { key: 'engineer_count', header: 'Engineers', render: (r: any) => r.engineer_count },
            { key: 'expert_count', header: 'Expert', render: (r: any) => r.expert_count },
            { key: 'total_cost_rupees', header: 'Total Cost', render: (r: any) => formatRupees(r.total_cost_rupees ?? 0) },
            { key: 'expiring_60d', header: 'Expiring 60d', render: (r: any) => r.expiring_60d },
          ]}
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-semibold text-slate-900">Engineer leaderboard</h2>
        <DataTable
          rows={leaders}
          rowKey={(r: any) => r.id}
          columns={[
            { key: 'engineer_name', header: 'Engineer', render: (r: any) => r.engineer_name },
            { key: 'total_certs', header: 'Total', render: (r: any) => r.total_certs },
            { key: 'active_certs', header: 'Active', render: (r: any) => r.active_certs },
            { key: 'expert_certs', header: 'Expert', render: (r: any) => r.expert_certs },
            { key: 'unique_vendors', header: 'Vendors', render: (r: any) => r.unique_vendors },
            { key: 'total_cost_rupees', header: 'Cost Invested', render: (r: any) => formatRupees(r.total_cost_rupees ?? 0) },
            { key: 'next_expiry', header: 'Next Expiry', render: (r: any) => r.next_expiry ?? '-' },
          ]}
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-semibold text-slate-900">Cost trend (last 12 months)</h2>
        <DataTable
          rows={trend}
          rowKey={(r: any) => r.id}
          columns={[
            { key: 'month_label', header: 'Month', render: (r: any) => r.month_label },
            { key: 'cert_count', header: 'Certs', render: (r: any) => r.cert_count },
            { key: 'total_cost_rupees', header: 'Total Cost', render: (r: any) => formatRupees(r.total_cost_rupees ?? 0) },
            { key: 'company_share_rupees', header: 'Company Share', render: (r: any) => formatRupees(r.company_share_rupees ?? 0) },
            { key: 'vendor_sponsored', header: 'Vendor Sponsored', render: (r: any) => r.vendor_sponsored },
          ]}
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-semibold text-slate-900">Renewal SLA breaches</h2>
        <DataTable
          rows={breaches}
          rowKey={(r: any) => r.id}
          columns={[
            { key: 'engineer_name', header: 'Engineer', render: (r: any) => r.engineer_name },
            { key: 'oem_vendor', header: 'Vendor', render: (r: any) => r.oem_vendor },
            { key: 'cert_name', header: 'Cert', render: (r: any) => r.cert_name },
            { key: 'expires_on', header: 'Expired On', render: (r: any) => r.expires_on },
            { key: 'days_overdue', header: 'Days Overdue', render: (r: any) => r.days_overdue },
            { key: 'status', header: 'Status', render: (r: any) => r.status },
            { key: 'last_reminder', header: 'Last Reminder', render: (r: any) => r.last_reminder ?? '-' },
          ]}
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-semibold text-slate-900">Recent renewal log</h2>
        <DataTable
          rows={logs}
          rowKey={(r: any) => r.id}
          columns={[
            { key: 'created_at', header: 'When', render: (r: any) => r.created_at },
            { key: 'engineer_name', header: 'Engineer', render: (r: any) => r.engineer_name },
            { key: 'cert_name', header: 'Cert', render: (r: any) => r.cert_name },
            { key: 'event_type', header: 'Event', render: (r: any) => r.event_type },
            { key: 'due_on', header: 'Due', render: (r: any) => r.due_on ?? '-' },
            { key: 'sla_days', header: 'SLA Days', render: (r: any) => r.sla_days ?? '-' },
            { key: 'note', header: 'Note', render: (r: any) => r.note ?? '-' },
          ]}
        />
      </section>
    </main>
  );
}
