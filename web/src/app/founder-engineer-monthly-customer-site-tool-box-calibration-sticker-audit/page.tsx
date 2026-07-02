import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Summary = {
  total_audits: number;
  passed: number;
  warn: number;
  failed: number;
  avg_compliance_pct: number;
};

type FailedAudit = {
  id: string;
  engineer_code: string;
  customer_site_code: string;
  city: string;
  compliance_pct: number;
  stickers_expired: number;
  stickers_missing: number;
  next_calibration_due: string | null;
};

type LeaderRow = {
  engineer_code: string;
  audits_done: number;
  avg_compliance: number;
  failed_count: number;
};

type CityRow = {
  city: string;
  sites_audited: number;
  avg_compliance: number;
  failed_count: number;
};

type OpenRow = {
  id: string;
  engineer_code: string;
  customer_site_code: string;
  tool_name: string;
  action_type: string;
  cost_rupees: number;
  status: string;
  due_date: string | null;
};

type CostRow = {
  action_type: string;
  open_count: number;
  total_cost_rupees: number;
};

type DueRow = {
  engineer_code: string;
  customer_site_code: string;
  city: string;
  next_calibration_due: string;
  days_until: number;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [summaryRes, failedRes, leaderRes, cityRes, openRes, costRes, dueRes] = await Promise.all([
    supabase.rpc('r2922_compliance_summary'),
    supabase.rpc('r2922_failed_audits'),
    supabase.rpc('r2922_engineer_leaderboard'),
    supabase.rpc('r2922_city_rollup'),
    supabase.rpc('r2922_open_remediation'),
    supabase.rpc('r2922_remediation_cost_by_type'),
    supabase.rpc('r2922_upcoming_due'),
  ]);

  const summary: Summary | null = (summaryRes.data?.[0] ?? null) as Summary | null;
  const failed: FailedAudit[] = (failedRes.data ?? []) as FailedAudit[];
  const leader: LeaderRow[] = (leaderRes.data ?? []) as LeaderRow[];
  const cities: CityRow[] = (cityRes.data ?? []) as CityRow[];
  const open: OpenRow[] = (openRes.data ?? []) as OpenRow[];
  const costs: CostRow[] = (costRes.data ?? []) as CostRow[];
  const due: DueRow[] = (dueRes.data ?? []) as DueRow[];

  const failedCols: Column<FailedAudit>[] = [
    { key: 'engineer_code', header: 'Engineer', render: (r) => r.engineer_code },
    { key: 'customer_site_code', header: 'Site', render: (r) => r.customer_site_code },
    { key: 'city', header: 'City', render: (r) => r.city },
    { key: 'compliance_pct', header: 'Compliance %', render: (r) => `${r.compliance_pct}%` },
    { key: 'stickers_expired', header: 'Expired', render: (r) => r.stickers_expired },
    { key: 'stickers_missing', header: 'Missing', render: (r) => r.stickers_missing },
    { key: 'next_calibration_due', header: 'Next Due', render: (r) => r.next_calibration_due ?? '—' },
  ];

  const leaderCols: Column<LeaderRow>[] = [
    { key: 'engineer_code', header: 'Engineer', render: (r) => r.engineer_code },
    { key: 'audits_done', header: 'Audits', render: (r) => r.audits_done },
    { key: 'avg_compliance', header: 'Avg Compliance %', render: (r) => `${r.avg_compliance}%` },
    { key: 'failed_count', header: 'Failed', render: (r) => r.failed_count },
  ];

  const cityCols: Column<CityRow>[] = [
    { key: 'city', header: 'City', render: (r) => r.city },
    { key: 'sites_audited', header: 'Sites Audited', render: (r) => r.sites_audited },
    { key: 'avg_compliance', header: 'Avg Compliance %', render: (r) => `${r.avg_compliance}%` },
    { key: 'failed_count', header: 'Failed', render: (r) => r.failed_count },
  ];

  const openCols: Column<OpenRow>[] = [
    { key: 'engineer_code', header: 'Engineer', render: (r) => r.engineer_code },
    { key: 'customer_site_code', header: 'Site', render: (r) => r.customer_site_code },
    { key: 'tool_name', header: 'Tool', render: (r) => r.tool_name },
    { key: 'action_type', header: 'Action', render: (r) => r.action_type },
    { key: 'cost_rupees', header: 'Cost (Rs)', render: (r) => `Rs ${r.cost_rupees}` },
    { key: 'status', header: 'Status', render: (r) => r.status },
    { key: 'due_date', header: 'Due', render: (r) => r.due_date ?? '—' },
  ];

  const costCols: Column<CostRow>[] = [
    { key: 'action_type', header: 'Action Type', render: (r) => r.action_type },
    { key: 'open_count', header: 'Open Count', render: (r) => r.open_count },
    { key: 'total_cost_rupees', header: 'Open Cost (Rs)', render: (r) => `Rs ${r.total_cost_rupees}` },
  ];

  const dueCols: Column<DueRow>[] = [
    { key: 'engineer_code', header: 'Engineer', render: (r) => r.engineer_code },
    { key: 'customer_site_code', header: 'Site', render: (r) => r.customer_site_code },
    { key: 'city', header: 'City', render: (r) => r.city },
    { key: 'next_calibration_due', header: 'Due Date', render: (r) => r.next_calibration_due },
    { key: 'days_until', header: 'Days Until', render: (r) => r.days_until },
  ];

  return (
    <div style={{ padding: '24px', maxWidth: 1200, margin: '0 auto' }}>
      <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 8 }}>
        Engineer Monthly Customer-Site Tool-Box Calibration Sticker Audit
      </h1>
      <p style={{ color: '#666', marginBottom: 20 }}>
        Round r2922 — founder ops console. Track field-engineer tool-box sticker
        compliance across all customer sites; flag failed audits and open remediation actions.
      </p>

      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(180px, 1fr))', gap: 12, marginBottom: 24 }}>
        <KpiCard label="Total Audits (latest month)" value={summary?.total_audits ?? 0} />
        <KpiCard label="Passed" value={summary?.passed ?? 0} />
        <KpiCard label="Warn" value={summary?.warn ?? 0} />
        <KpiCard label="Failed" value={summary?.failed ?? 0} />
        <KpiCard label="Avg Compliance %" value={`${summary?.avg_compliance_pct ?? 0}%`} />
      </div>

      <Section title="Failed audits — latest month">
        <DataTable
          rows={failed}
          columns={failedCols}
          emptyMessage="No failed audits"
          rowKey={(r, i) => String(r.id ?? i)}
        />
      </Section>

      <Section title="Engineer leaderboard (all-time)">
        <DataTable
          rows={leader}
          columns={leaderCols}
          emptyMessage="No engineer data"
          rowKey={(r, i) => String(r.engineer_code ?? i)}
        />
      </Section>

      <Section title="City rollup — latest month">
        <DataTable
          rows={cities}
          columns={cityCols}
          emptyMessage="No city data"
          rowKey={(r, i) => String(r.city ?? i)}
        />
      </Section>

      <Section title="Open remediation actions">
        <DataTable
          rows={open}
          columns={openCols}
          emptyMessage="No open actions"
          rowKey={(r, i) => String(r.id ?? i)}
        />
      </Section>

      <Section title="Remediation cost by action type">
        <DataTable
          rows={costs}
          columns={costCols}
          emptyMessage="No cost data"
          rowKey={(r, i) => String(r.action_type ?? i)}
        />
      </Section>

      <Section title="Upcoming calibration due (next 30 days)">
        <DataTable
          rows={due}
          columns={dueCols}
          emptyMessage="No upcoming due items"
          rowKey={(r, i) => `${r.engineer_code}-${r.customer_site_code}-${i}`}
        />
      </Section>
    </div>
  );
}

function KpiCard({ label, value }: { label: string; value: string | number }) {
  return (
    <div style={{ background: '#fff', border: '1px solid #e5e7eb', borderRadius: 8, padding: 16 }}>
      <div style={{ fontSize: 12, color: '#666', marginBottom: 4 }}>{label}</div>
      <div style={{ fontSize: 22, fontWeight: 700 }}>{value}</div>
    </div>
  );
}

function Section({ title, children }: { title: string; children: React.ReactNode }) {
  return (
    <section style={{ marginBottom: 28 }}>
      <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 10 }}>{title}</h2>
      {children}
    </section>
  );
}
