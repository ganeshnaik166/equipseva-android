import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Kpis = {
  total_licenses: number;
  renewal_due: number;
  expired_or_grace: number;
  red_verdicts: number;
  total_fine_risk_rupees: number;
  critical_audit_events: number;
};

type License = {
  id: string;
  chain_name: string;
  hospital_unit: string;
  city: string;
  asset_category: string;
  asset_model: string;
  license_kind: string;
  license_number: string;
  valid_until: string;
  renewal_status: string;
  compliance_verdict: string;
  fine_risk_rupees: number;
};

type ByChain = {
  chain_name: string;
  total_licenses: number;
  red_count: number;
  amber_count: number;
  green_count: number;
  total_fine_risk: number;
};

type ByKind = {
  license_kind: string;
  total: number;
  due_or_expired: number;
  fine_risk: number;
};

type Renewal = {
  chain_name: string;
  hospital_unit: string;
  asset_model: string;
  license_kind: string;
  valid_until: string;
  days_to_expiry: number;
  renewal_status: string;
  fine_risk_rupees: number;
};

type AuditEvent = {
  id: string;
  chain_name: string;
  event_type: string;
  event_on: string;
  inspector_name: string | null;
  finding_summary: string;
  severity: string;
  resolution_status: string;
  resolution_owner: string | null;
  resolution_due_on: string | null;
};

type Quarter = {
  audit_quarter: string;
  licenses: number;
  green: number;
  amber: number;
  red: number;
  fine_risk: number;
};

type Critical = {
  chain_name: string;
  hospital_unit: string;
  asset_model: string;
  license_kind: string;
  license_number: string;
  valid_until: string;
  renewal_status: string;
  compliance_verdict: string;
  fine_risk_rupees: number;
  notes: string | null;
};

function fmtRupees(n: number | null | undefined) {
  if (!n) return '0';
  return '₹' + Number(n).toLocaleString('en-IN');
}

function badge(label: string, tone: 'green' | 'amber' | 'red' | 'gray') {
  const colors: Record<string, string> = {
    green: '#d1fae5',
    amber: '#fef3c7',
    red: '#fee2e2',
    gray: '#e5e7eb',
  };
  return (
    <span style={{ background: colors[tone], padding: '2px 8px', borderRadius: 6, fontSize: 12 }}>
      {label}
    </span>
  );
}

function verdictBadge(v: string) {
  if (v === 'green') return badge('green', 'green');
  if (v === 'amber') return badge('amber', 'amber');
  if (v === 'red' || v === 'blocked') return badge(v, 'red');
  return badge(v, 'gray');
}

function statusBadge(s: string) {
  if (s === 'current') return badge('current', 'green');
  if (s === 'renewal_due' || s === 'renewal_in_progress') return badge(s, 'amber');
  if (s === 'expired' || s === 'grace_period') return badge(s, 'red');
  return badge(s, 'gray');
}

function severityBadge(s: string) {
  if (s === 'critical' || s === 'major') return badge(s, 'red');
  if (s === 'minor') return badge(s, 'amber');
  return badge(s, 'green');
}

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [kpisRes, licRes, chainRes, kindRes, renewalRes, eventsRes, quarterRes, criticalRes] = await Promise.all([
    supabase.rpc('r2871_kpis'),
    supabase.rpc('r2871_licenses'),
    supabase.rpc('r2871_by_chain'),
    supabase.rpc('r2871_by_kind'),
    supabase.rpc('r2871_renewal_pipeline'),
    supabase.rpc('r2871_audit_events'),
    supabase.rpc('r2871_quarter_summary'),
    supabase.rpc('r2871_critical_blocklist'),
  ]);

  const kpis: Kpis | null = (kpisRes.data as Kpis[] | null)?.[0] ?? null;
  const licenses: License[] = (licRes.data as License[]) ?? [];
  const byChain: ByChain[] = (chainRes.data as ByChain[]) ?? [];
  const byKind: ByKind[] = (kindRes.data as ByKind[]) ?? [];
  const renewals: Renewal[] = (renewalRes.data as Renewal[]) ?? [];
  const events: AuditEvent[] = (eventsRes.data as AuditEvent[]) ?? [];
  const quarters: Quarter[] = (quarterRes.data as Quarter[]) ?? [];
  const criticals: Critical[] = (criticalRes.data as Critical[]) ?? [];

  return (
    <div style={{ padding: 24, fontFamily: 'system-ui, -apple-system, sans-serif', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 4 }}>
        Hospital Chain Quarterly Equipment PMD License Tracker
      </h1>
      <p style={{ color: '#6b7280', marginBottom: 24, fontSize: 14 }}>
        Chain × asset × license kind × validity × renewal × audit × compliance verdict.
        Track AERB, CDSCO, PCB, BMW, NABH and other PMD licenses across hospital chains; surface renewal pipeline,
        critical blocklist and quarterly audit posture.
      </p>

      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(6, 1fr)', gap: 12, marginBottom: 24 }}>
        <KPI label="Total Licenses" value={String(kpis?.total_licenses ?? 0)} />
        <KPI label="Renewal Due" value={String(kpis?.renewal_due ?? 0)} tone="amber" />
        <KPI label="Expired / Grace" value={String(kpis?.expired_or_grace ?? 0)} tone="red" />
        <KPI label="Red Verdicts" value={String(kpis?.red_verdicts ?? 0)} tone="red" />
        <KPI label="Total Fine Risk" value={fmtRupees(kpis?.total_fine_risk_rupees ?? 0)} tone="red" />
        <KPI label="Critical Audit Events" value={String(kpis?.critical_audit_events ?? 0)} tone="red" />
      </div>

      <Section title="Critical Blocklist (red & expired)">
        <DataTable
          rows={criticals}
          columns={[
            { key: 'chain_name', header: 'Chain', render: (r: Critical) => r.chain_name },
            { key: 'hospital_unit', header: 'Unit', render: (r: Critical) => r.hospital_unit },
            { key: 'asset_model', header: 'Asset', render: (r: Critical) => r.asset_model },
            { key: 'license_kind', header: 'Kind', render: (r: Critical) => r.license_kind.toUpperCase() },
            { key: 'license_number', header: 'License #', render: (r: Critical) => r.license_number },
            { key: 'valid_until', header: 'Valid Until', render: (r: Critical) => r.valid_until },
            { key: 'renewal_status', header: 'Status', render: (r: Critical) => statusBadge(r.renewal_status) },
            { key: 'compliance_verdict', header: 'Verdict', render: (r: Critical) => verdictBadge(r.compliance_verdict) },
            { key: 'fine_risk_rupees', header: 'Fine Risk', render: (r: Critical) => fmtRupees(r.fine_risk_rupees) },
            { key: 'notes', header: 'Notes', render: (r: Critical) => r.notes ?? '' },
          ]}
          emptyMessage="No critical licenses"
          rowKey={(r: Critical, i: number) => String(r.license_number ?? i)}
        />
      </Section>

      <Section title="Renewal Pipeline (due & in progress)">
        <DataTable
          rows={renewals}
          columns={[
            { key: 'chain_name', header: 'Chain', render: (r: Renewal) => r.chain_name },
            { key: 'hospital_unit', header: 'Unit', render: (r: Renewal) => r.hospital_unit },
            { key: 'asset_model', header: 'Asset', render: (r: Renewal) => r.asset_model },
            { key: 'license_kind', header: 'Kind', render: (r: Renewal) => r.license_kind.toUpperCase() },
            { key: 'valid_until', header: 'Valid Until', render: (r: Renewal) => r.valid_until },
            { key: 'days_to_expiry', header: 'Days to Expiry', render: (r: Renewal) => String(r.days_to_expiry) },
            { key: 'renewal_status', header: 'Status', render: (r: Renewal) => statusBadge(r.renewal_status) },
            { key: 'fine_risk_rupees', header: 'Fine Risk', render: (r: Renewal) => fmtRupees(r.fine_risk_rupees) },
          ]}
          emptyMessage="No renewals pending"
          rowKey={(r: Renewal, i: number) => String(i)}
        />
      </Section>

      <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 24, marginBottom: 24 }}>
        <Section title="By Chain">
          <DataTable
            rows={byChain}
            columns={[
              { key: 'chain_name', header: 'Chain', render: (r: ByChain) => r.chain_name },
              { key: 'total_licenses', header: 'Licenses', render: (r: ByChain) => String(r.total_licenses) },
              { key: 'green_count', header: 'Green', render: (r: ByChain) => String(r.green_count) },
              { key: 'amber_count', header: 'Amber', render: (r: ByChain) => String(r.amber_count) },
              { key: 'red_count', header: 'Red', render: (r: ByChain) => String(r.red_count) },
              { key: 'total_fine_risk', header: 'Fine Risk', render: (r: ByChain) => fmtRupees(r.total_fine_risk) },
            ]}
            emptyMessage="No chains"
            rowKey={(r: ByChain, i: number) => String(r.chain_name ?? i)}
          />
        </Section>

        <Section title="By License Kind">
          <DataTable
            rows={byKind}
            columns={[
              { key: 'license_kind', header: 'Kind', render: (r: ByKind) => r.license_kind.toUpperCase() },
              { key: 'total', header: 'Total', render: (r: ByKind) => String(r.total) },
              { key: 'due_or_expired', header: 'Due / Expired', render: (r: ByKind) => String(r.due_or_expired) },
              { key: 'fine_risk', header: 'Fine Risk', render: (r: ByKind) => fmtRupees(r.fine_risk) },
            ]}
            emptyMessage="No kinds"
            rowKey={(r: ByKind, i: number) => String(r.license_kind ?? i)}
          />
        </Section>
      </div>

      <Section title="Quarter Summary (FY26 cadence)">
        <DataTable
          rows={quarters}
          columns={[
            { key: 'audit_quarter', header: 'Quarter', render: (r: Quarter) => r.audit_quarter.toUpperCase() },
            { key: 'licenses', header: 'Licenses', render: (r: Quarter) => String(r.licenses) },
            { key: 'green', header: 'Green', render: (r: Quarter) => String(r.green) },
            { key: 'amber', header: 'Amber', render: (r: Quarter) => String(r.amber) },
            { key: 'red', header: 'Red', render: (r: Quarter) => String(r.red) },
            { key: 'fine_risk', header: 'Fine Risk', render: (r: Quarter) => fmtRupees(r.fine_risk) },
          ]}
          emptyMessage="No quarters"
          rowKey={(r: Quarter, i: number) => String(r.audit_quarter ?? i)}
        />
      </Section>

      <Section title="All Licenses">
        <DataTable
          rows={licenses}
          columns={[
            { key: 'chain_name', header: 'Chain', render: (r: License) => r.chain_name },
            { key: 'hospital_unit', header: 'Unit', render: (r: License) => r.hospital_unit },
            { key: 'city', header: 'City', render: (r: License) => r.city },
            { key: 'asset_category', header: 'Category', render: (r: License) => r.asset_category },
            { key: 'asset_model', header: 'Asset Model', render: (r: License) => r.asset_model },
            { key: 'license_kind', header: 'Kind', render: (r: License) => r.license_kind.toUpperCase() },
            { key: 'license_number', header: 'License #', render: (r: License) => r.license_number },
            { key: 'valid_until', header: 'Valid Until', render: (r: License) => r.valid_until },
            { key: 'renewal_status', header: 'Status', render: (r: License) => statusBadge(r.renewal_status) },
            { key: 'compliance_verdict', header: 'Verdict', render: (r: License) => verdictBadge(r.compliance_verdict) },
            { key: 'fine_risk_rupees', header: 'Fine Risk', render: (r: License) => fmtRupees(r.fine_risk_rupees) },
          ]}
          emptyMessage="No licenses"
          rowKey={(r: License, i: number) => String(r.id ?? i)}
        />
      </Section>

      <Section title="Recent Audit Events">
        <DataTable
          rows={events}
          columns={[
            { key: 'event_on', header: 'Date', render: (r: AuditEvent) => r.event_on },
            { key: 'chain_name', header: 'Chain', render: (r: AuditEvent) => r.chain_name },
            { key: 'event_type', header: 'Event', render: (r: AuditEvent) => r.event_type },
            { key: 'severity', header: 'Severity', render: (r: AuditEvent) => severityBadge(r.severity) },
            { key: 'inspector_name', header: 'Inspector', render: (r: AuditEvent) => r.inspector_name ?? '' },
            { key: 'finding_summary', header: 'Finding', render: (r: AuditEvent) => r.finding_summary },
            { key: 'resolution_owner', header: 'Owner', render: (r: AuditEvent) => r.resolution_owner ?? '' },
            { key: 'resolution_due_on', header: 'Due', render: (r: AuditEvent) => r.resolution_due_on ?? '' },
            { key: 'resolution_status', header: 'Status', render: (r: AuditEvent) => r.resolution_status },
          ]}
          emptyMessage="No audit events"
          rowKey={(r: AuditEvent, i: number) => String(r.id ?? i)}
        />
      </Section>
    </div>
  );
}

function KPI({ label, value, tone }: { label: string; value: string; tone?: 'amber' | 'red' }) {
  const bg = tone === 'red' ? '#fee2e2' : tone === 'amber' ? '#fef3c7' : '#f3f4f6';
  return (
    <div style={{ background: bg, borderRadius: 8, padding: 16 }}>
      <div style={{ fontSize: 11, color: '#6b7280', textTransform: 'uppercase', letterSpacing: 0.5 }}>{label}</div>
      <div style={{ fontSize: 22, fontWeight: 700, marginTop: 4 }}>{value}</div>
    </div>
  );
}

function Section({ title, children }: { title: string; children: React.ReactNode }) {
  return (
    <div style={{ marginBottom: 24 }}>
      <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>{title}</h2>
      {children}
    </div>
  );
}
