import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable } from '@/components/DataTable';
import type { Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Kpi = {
  total_engineers: number;
  on_time_pct: number;
  overdue_count: number;
  avg_discipline_score: number;
  total_replacement_cost_rupees: number;
  certs_expired: number;
  certs_expiring_30d: number;
  super_specialty_blockers: number;
};

type LeaderRow = {
  id: string;
  engineer_code: string;
  cached_tier: string;
  discipline_score: number;
  status: string;
  tools_present: number;
  tools_required: number;
  replacement_cost_rupees: number;
  founder_notes: string | null;
};

type OverdueRow = {
  id: string;
  engineer_code: string;
  cached_tier: string;
  status: string;
  due_at: string;
  hours_overdue: number;
  tools_missing: number;
  replacement_cost_rupees: number;
};

type CertRow = {
  id: string;
  engineer_code: string;
  instrument_kind: string;
  serial_no: string;
  lab_name: string;
  expires_on: string;
  days_to_expiry: number;
  status: string;
  blocker_for_super_specialty: boolean;
  renewal_cost_rupees: number;
};

type TierRow = {
  cached_tier: string;
  engineer_count: number;
  avg_discipline_score: number;
  on_time_count: number;
  overdue_count: number;
  total_replacement_cost_rupees: number;
};

type BlockerRow = {
  id: string;
  engineer_code: string;
  instrument_kind: string;
  status: string;
  days_to_expiry: number;
  expires_on: string;
  renewal_cost_rupees: number;
  lab_name: string;
};

type LabRow = {
  lab_name: string;
  cert_count: number;
  expired_count: number;
  expiring_soon_count: number;
  total_renewal_spend_rupees: number;
  avg_days_to_expiry: number;
};

function fmtINR(n: number | null | undefined): string {
  if (n == null) return '-';
  return '₹' + n.toLocaleString('en-IN');
}

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [kpiRes, leaderRes, overdueRes, certRes, tierRes, blockerRes, labRes] = await Promise.all([
    supabase.rpc('founder_r2886_toolbox_kpi_summary'),
    supabase.rpc('founder_r2886_discipline_leaderboard'),
    supabase.rpc('founder_r2886_overdue_engineers'),
    supabase.rpc('founder_r2886_calibration_expiry_watch'),
    supabase.rpc('founder_r2886_tier_discipline_matrix'),
    supabase.rpc('founder_r2886_super_specialty_blockers'),
    supabase.rpc('founder_r2886_lab_partner_concentration'),
  ]);

  const kpi: Kpi | null = (kpiRes.data?.[0] as Kpi) ?? null;
  const leaders: LeaderRow[] = (leaderRes.data as LeaderRow[]) ?? [];
  const overdues: OverdueRow[] = (overdueRes.data as OverdueRow[]) ?? [];
  const certs: CertRow[] = (certRes.data as CertRow[]) ?? [];
  const tiers: TierRow[] = (tierRes.data as TierRow[]) ?? [];
  const blockers: BlockerRow[] = (blockerRes.data as BlockerRow[]) ?? [];
  const labs: LabRow[] = (labRes.data as LabRow[]) ?? [];

  const leaderCols: Column<LeaderRow>[] = [
    { key: 'engineer_code', header: 'Engineer', render: (r) => r.engineer_code },
    { key: 'cached_tier', header: 'Tier', render: (r) => r.cached_tier },
    { key: 'discipline_score', header: 'Score', render: (r) => r.discipline_score.toFixed(1) },
    { key: 'status', header: 'Status', render: (r) => r.status },
    { key: 'tools', header: 'Tools', render: (r) => r.tools_present + '/' + r.tools_required },
    { key: 'cost', header: 'Replacement', render: (r) => fmtINR(r.replacement_cost_rupees) },
    { key: 'notes', header: 'Notes', render: (r) => r.founder_notes ?? '-' },
  ];

  const overdueCols: Column<OverdueRow>[] = [
    { key: 'engineer_code', header: 'Engineer', render: (r) => r.engineer_code },
    { key: 'cached_tier', header: 'Tier', render: (r) => r.cached_tier },
    { key: 'status', header: 'Status', render: (r) => r.status },
    { key: 'due_at', header: 'Due', render: (r) => new Date(r.due_at).toLocaleDateString() },
    { key: 'hours_overdue', header: 'Hours Late', render: (r) => r.hours_overdue.toFixed(1) },
    { key: 'tools_missing', header: 'Missing', render: (r) => String(r.tools_missing) },
    { key: 'cost', header: 'Cost', render: (r) => fmtINR(r.replacement_cost_rupees) },
  ];

  const certCols: Column<CertRow>[] = [
    { key: 'engineer_code', header: 'Engineer', render: (r) => r.engineer_code },
    { key: 'instrument_kind', header: 'Instrument', render: (r) => r.instrument_kind },
    { key: 'serial_no', header: 'Serial', render: (r) => r.serial_no },
    { key: 'lab_name', header: 'Lab', render: (r) => r.lab_name },
    { key: 'expires_on', header: 'Expires', render: (r) => r.expires_on },
    { key: 'days_to_expiry', header: 'Days', render: (r) => String(r.days_to_expiry) },
    { key: 'status', header: 'Status', render: (r) => r.status },
    { key: 'blocker', header: 'SS Blocker', render: (r) => r.blocker_for_super_specialty ? 'YES' : 'no' },
    { key: 'renewal_cost_rupees', header: 'Renewal', render: (r) => fmtINR(r.renewal_cost_rupees) },
  ];

  const tierCols: Column<TierRow>[] = [
    { key: 'cached_tier', header: 'Tier', render: (r) => r.cached_tier },
    { key: 'engineer_count', header: 'Engineers', render: (r) => String(r.engineer_count) },
    { key: 'avg_discipline_score', header: 'Avg Score', render: (r) => r.avg_discipline_score.toFixed(1) },
    { key: 'on_time_count', header: 'On-time', render: (r) => String(r.on_time_count) },
    { key: 'overdue_count', header: 'Overdue', render: (r) => String(r.overdue_count) },
    { key: 'total_replacement_cost_rupees', header: 'Replacement', render: (r) => fmtINR(r.total_replacement_cost_rupees) },
  ];

  const blockerCols: Column<BlockerRow>[] = [
    { key: 'engineer_code', header: 'Engineer', render: (r) => r.engineer_code },
    { key: 'instrument_kind', header: 'Instrument', render: (r) => r.instrument_kind },
    { key: 'status', header: 'Status', render: (r) => r.status },
    { key: 'days_to_expiry', header: 'Days', render: (r) => String(r.days_to_expiry) },
    { key: 'expires_on', header: 'Expires', render: (r) => r.expires_on },
    { key: 'lab_name', header: 'Lab', render: (r) => r.lab_name },
    { key: 'renewal_cost_rupees', header: 'Renewal', render: (r) => fmtINR(r.renewal_cost_rupees) },
  ];

  const labCols: Column<LabRow>[] = [
    { key: 'lab_name', header: 'Lab', render: (r) => r.lab_name },
    { key: 'cert_count', header: 'Certs', render: (r) => String(r.cert_count) },
    { key: 'expired_count', header: 'Expired', render: (r) => String(r.expired_count) },
    { key: 'expiring_soon_count', header: 'Expiring <30d', render: (r) => String(r.expiring_soon_count) },
    { key: 'total_renewal_spend_rupees', header: 'Annual Spend', render: (r) => fmtINR(r.total_renewal_spend_rupees) },
    { key: 'avg_days_to_expiry', header: 'Avg Days', render: (r) => r.avg_days_to_expiry.toFixed(1) },
  ];

  return (
    <div style={{ padding: '24px', maxWidth: 1400, margin: '0 auto' }}>
      <header style={{ marginBottom: 28 }}>
        <h1 style={{ fontSize: 28, fontWeight: 700, margin: 0 }}>
          Engineer Monthly Tool-Box Maintenance & Calibration Discipline
        </h1>
        <p style={{ color: '#666', marginTop: 6 }}>
          Round r2886 — tool-box audits, calibration certs, super-specialty blockers, lab partner concentration. Built for founder accountability sweeps.
        </p>
      </header>

      <section style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(180px, 1fr))', gap: 12, marginBottom: 28 }}>
        <KpiCard label="Engineers" value={kpi?.total_engineers ?? 0} />
        <KpiCard label="On-time %" value={(kpi?.on_time_pct ?? 0) + '%'} />
        <KpiCard label="Overdue" value={kpi?.overdue_count ?? 0} tone={(kpi?.overdue_count ?? 0) > 0 ? 'warn' : 'ok'} />
        <KpiCard label="Avg Score" value={kpi?.avg_discipline_score ?? 0} />
        <KpiCard label="Replacement Cost" value={fmtINR(kpi?.total_replacement_cost_rupees ?? 0)} />
        <KpiCard label="Certs Expired" value={kpi?.certs_expired ?? 0} tone={(kpi?.certs_expired ?? 0) > 0 ? 'bad' : 'ok'} />
        <KpiCard label="Expiring <30d" value={kpi?.certs_expiring_30d ?? 0} tone={(kpi?.certs_expiring_30d ?? 0) > 0 ? 'warn' : 'ok'} />
        <KpiCard label="SS Blockers" value={kpi?.super_specialty_blockers ?? 0} tone={(kpi?.super_specialty_blockers ?? 0) > 0 ? 'bad' : 'ok'} />
      </section>

      <Section title="Discipline Leaderboard" subtitle="Every engineer ranked by monthly tool-box score">
        <DataTable
          rows={leaders}
          columns={leaderCols}
          emptyMessage="No audits this month"
          rowKey={(r, i) => String(r.id ?? i)}
        />
      </Section>

      <Section title="Overdue & Late Submissions" subtitle="Founder escalation queue">
        <DataTable
          rows={overdues}
          columns={overdueCols}
          emptyMessage="All engineers on time"
          rowKey={(r, i) => String(r.id ?? i)}
        />
      </Section>

      <Section title="Calibration Expiry Watch" subtitle="Instruments expired, expiring <30d, or in renewal">
        <DataTable
          rows={certs}
          columns={certCols}
          emptyMessage="All calibrations current"
          rowKey={(r, i) => String(r.id ?? i)}
        />
      </Section>

      <Section title="Tier x Discipline Matrix" subtitle="Are platinum engineers actually disciplined?">
        <DataTable
          rows={tiers}
          columns={tierCols}
          emptyMessage="No tier data"
          rowKey={(r, i) => String(r.cached_tier ?? i)}
        />
      </Section>

      <Section title="Super-Specialty Blockers" subtitle="Expired calibration => cannot accept oncology/cath-lab jobs">
        <DataTable
          rows={blockers}
          columns={blockerCols}
          emptyMessage="No blockers"
          rowKey={(r, i) => String(r.id ?? i)}
        />
      </Section>

      <Section title="Lab Partner Concentration" subtitle="Which NABL labs do we depend on most?">
        <DataTable
          rows={labs}
          columns={labCols}
          emptyMessage="No lab data"
          rowKey={(r, i) => String(r.lab_name ?? i)}
        />
      </Section>
    </div>
  );
}

function KpiCard({ label, value, tone }: { label: string; value: string | number; tone?: 'ok' | 'warn' | 'bad' }) {
  const bg = tone === 'bad' ? '#fef2f2' : tone === 'warn' ? '#fffbeb' : '#f8fafc';
  const border = tone === 'bad' ? '#fecaca' : tone === 'warn' ? '#fde68a' : '#e2e8f0';
  return (
    <div style={{ background: bg, border: '1px solid ' + border, borderRadius: 10, padding: 14 }}>
      <div style={{ fontSize: 12, color: '#64748b', textTransform: 'uppercase', letterSpacing: 0.4 }}>{label}</div>
      <div style={{ fontSize: 22, fontWeight: 700, marginTop: 4 }}>{value}</div>
    </div>
  );
}

function Section({ title, subtitle, children }: { title: string; subtitle?: string; children: React.ReactNode }) {
  return (
    <section style={{ marginBottom: 32 }}>
      <div style={{ marginBottom: 10 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, margin: 0 }}>{title}</h2>
        {subtitle ? <p style={{ color: '#64748b', fontSize: 13, marginTop: 2 }}>{subtitle}</p> : null}
      </div>
      {children}
    </section>
  );
}
