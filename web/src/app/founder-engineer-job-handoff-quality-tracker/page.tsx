import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Kpi = {
  total_handoffs: number;
  clean_handoffs: number;
  stalled_handoffs: number;
  avg_quality_score: number;
  pct_with_gaps: number;
  total_recovery_cost_rupees: number;
};

type Handoff = {
  handoff_code: string;
  job_code: string;
  hospital_name: string;
  device_kind: string;
  outgoing_engineer: string;
  incoming_engineer: string;
  handoff_reason: string;
  quality_score: number;
  quality_grade: string;
  handoff_status: string;
  customer_impact: string;
};

type Gap = {
  handoff_code: string;
  gap_category: string;
  gap_description: string;
  severity: string;
  detected_by: string;
  recovery_action: string;
  recovery_owner: string;
  recovery_status: string;
  cost_to_recover_rupees: number;
};

type ByOutgoing = {
  outgoing_engineer: string;
  outgoing_tier: string;
  handoff_count: number;
  avg_quality: number;
  clean_count: number;
  stalled_count: number;
};

type ByReason = {
  handoff_reason: string;
  handoff_count: number;
  avg_quality: number;
  gap_count: number;
};

type BySeverity = {
  severity: string;
  gap_count: number;
  resolved_count: number;
  open_count: number;
  total_cost_rupees: number;
};

type OpenRecovery = {
  handoff_code: string;
  gap_category: string;
  severity: string;
  recovery_action: string;
  recovery_owner: string;
  recovery_status: string;
  cost_to_recover_rupees: number;
};

type Impact = {
  customer_impact: string;
  handoff_count: number;
  avg_quality: number;
};

function fmtRupees(n: number | null | undefined): string {
  if (!n) return '₹0';
  return '₹' + Number(n).toLocaleString('en-IN');
}

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [kpiR, listR, gapsR, byOutR, byReasonR, sevR, openR, impactR] = await Promise.all([
    supabase.rpc('founder_handoff_kpis_r2674'),
    supabase.rpc('founder_handoff_list_r2674'),
    supabase.rpc('founder_handoff_gap_list_r2674'),
    supabase.rpc('founder_handoff_by_outgoing_r2674'),
    supabase.rpc('founder_handoff_by_reason_r2674'),
    supabase.rpc('founder_handoff_gap_severity_r2674'),
    supabase.rpc('founder_handoff_open_recovery_r2674'),
    supabase.rpc('founder_handoff_impact_breakdown_r2674'),
  ]);

  const kpi: Kpi = (kpiR.data?.[0] ?? {
    total_handoffs: 0,
    clean_handoffs: 0,
    stalled_handoffs: 0,
    avg_quality_score: 0,
    pct_with_gaps: 0,
    total_recovery_cost_rupees: 0,
  }) as Kpi;

  const handoffs: Handoff[] = (listR.data ?? []) as Handoff[];
  const gaps: Gap[] = (gapsR.data ?? []) as Gap[];
  const byOutgoing: ByOutgoing[] = (byOutR.data ?? []) as ByOutgoing[];
  const byReason: ByReason[] = (byReasonR.data ?? []) as ByReason[];
  const bySeverity: BySeverity[] = (sevR.data ?? []) as BySeverity[];
  const openRecovery: OpenRecovery[] = (openR.data ?? []) as OpenRecovery[];
  const impact: Impact[] = (impactR.data ?? []) as Impact[];

  return (
    <div style={{ padding: 24, fontFamily: 'ui-sans-serif, system-ui', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 4 }}>
        Engineer Job Handoff Quality Tracker
      </h1>
      <p style={{ color: '#555', marginBottom: 24 }}>
        job × outgoing eng × incoming eng × handoff quality × gaps × recovery action — founder round r2674
      </p>

      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(6, 1fr)', gap: 12, marginBottom: 24 }}>
        <KpiCard label="Total handoffs" value={String(kpi.total_handoffs)} />
        <KpiCard label="Clean" value={String(kpi.clean_handoffs)} />
        <KpiCard label="Stalled" value={String(kpi.stalled_handoffs)} tone="bad" />
        <KpiCard label="Avg quality" value={String(kpi.avg_quality_score)} />
        <KpiCard label="% with gaps" value={String(kpi.pct_with_gaps) + '%'} />
        <KpiCard label="Recovery cost" value={fmtRupees(kpi.total_recovery_cost_rupees)} />
      </div>

      <Section title="Handoffs (quality & status)">
        <DataTable
          rows={handoffs}
          rowKey={(r, i) => String((r as Handoff).handoff_code ?? i)}
          emptyMessage="No data"
          columns={[
            { key: 'handoff_code', header: 'Code', render: (r: Handoff) => <code>{r.handoff_code}</code> },
            { key: 'job_code', header: 'Job', render: (r: Handoff) => <code>{r.job_code}</code> },
            { key: 'hospital_name', header: 'Hospital', render: (r: Handoff) => <span>{r.hospital_name}</span> },
            { key: 'device_kind', header: 'Device', render: (r: Handoff) => <span>{r.device_kind}</span> },
            { key: 'outgoing_engineer', header: 'Outgoing', render: (r: Handoff) => <span>{r.outgoing_engineer}</span> },
            { key: 'incoming_engineer', header: 'Incoming', render: (r: Handoff) => <span>{r.incoming_engineer}</span> },
            { key: 'handoff_reason', header: 'Reason', render: (r: Handoff) => <span>{r.handoff_reason}</span> },
            { key: 'quality_score', header: 'Score', render: (r: Handoff) => <strong>{r.quality_score}</strong> },
            { key: 'quality_grade', header: 'Grade', render: (r: Handoff) => <span>{r.quality_grade}</span> },
            { key: 'handoff_status', header: 'Status', render: (r: Handoff) => <span>{r.handoff_status}</span> },
            { key: 'customer_impact', header: 'Impact', render: (r: Handoff) => <span>{r.customer_impact}</span> },
          ]}
        />
      </Section>

      <Section title="Gaps (all)">
        <DataTable
          rows={gaps}
          rowKey={(r, i) => String(i)}
          emptyMessage="No data"
          columns={[
            { key: 'handoff_code', header: 'Handoff', render: (r: Gap) => <code>{r.handoff_code}</code> },
            { key: 'gap_category', header: 'Category', render: (r: Gap) => <span>{r.gap_category}</span> },
            { key: 'gap_description', header: 'Description', render: (r: Gap) => <span>{r.gap_description}</span> },
            { key: 'severity', header: 'Severity', render: (r: Gap) => <strong>{r.severity}</strong> },
            { key: 'detected_by', header: 'Detected by', render: (r: Gap) => <span>{r.detected_by}</span> },
            { key: 'recovery_action', header: 'Recovery action', render: (r: Gap) => <span>{r.recovery_action}</span> },
            { key: 'recovery_owner', header: 'Owner', render: (r: Gap) => <span>{r.recovery_owner}</span> },
            { key: 'recovery_status', header: 'Status', render: (r: Gap) => <span>{r.recovery_status}</span> },
            { key: 'cost_to_recover_rupees', header: 'Cost', render: (r: Gap) => <span>{fmtRupees(r.cost_to_recover_rupees)}</span> },
          ]}
        />
      </Section>

      <Section title="By outgoing engineer">
        <DataTable
          rows={byOutgoing}
          rowKey={(r, i) => String((r as ByOutgoing).outgoing_engineer ?? i)}
          emptyMessage="No data"
          columns={[
            { key: 'outgoing_engineer', header: 'Outgoing', render: (r: ByOutgoing) => <span>{r.outgoing_engineer}</span> },
            { key: 'outgoing_tier', header: 'Tier', render: (r: ByOutgoing) => <span>{r.outgoing_tier}</span> },
            { key: 'handoff_count', header: 'Handoffs', render: (r: ByOutgoing) => <span>{r.handoff_count}</span> },
            { key: 'avg_quality', header: 'Avg quality', render: (r: ByOutgoing) => <span>{r.avg_quality}</span> },
            { key: 'clean_count', header: 'Clean', render: (r: ByOutgoing) => <span>{r.clean_count}</span> },
            { key: 'stalled_count', header: 'Stalled', render: (r: ByOutgoing) => <span>{r.stalled_count}</span> },
          ]}
        />
      </Section>

      <Section title="By reason">
        <DataTable
          rows={byReason}
          rowKey={(r, i) => String((r as ByReason).handoff_reason ?? i)}
          emptyMessage="No data"
          columns={[
            { key: 'handoff_reason', header: 'Reason', render: (r: ByReason) => <span>{r.handoff_reason}</span> },
            { key: 'handoff_count', header: 'Handoffs', render: (r: ByReason) => <span>{r.handoff_count}</span> },
            { key: 'avg_quality', header: 'Avg quality', render: (r: ByReason) => <span>{r.avg_quality}</span> },
            { key: 'gap_count', header: 'Gaps', render: (r: ByReason) => <span>{r.gap_count}</span> },
          ]}
        />
      </Section>

      <Section title="Gaps by severity">
        <DataTable
          rows={bySeverity}
          rowKey={(r, i) => String((r as BySeverity).severity ?? i)}
          emptyMessage="No data"
          columns={[
            { key: 'severity', header: 'Severity', render: (r: BySeverity) => <strong>{r.severity}</strong> },
            { key: 'gap_count', header: 'Total', render: (r: BySeverity) => <span>{r.gap_count}</span> },
            { key: 'resolved_count', header: 'Resolved', render: (r: BySeverity) => <span>{r.resolved_count}</span> },
            { key: 'open_count', header: 'Open', render: (r: BySeverity) => <span>{r.open_count}</span> },
            { key: 'total_cost_rupees', header: 'Cost', render: (r: BySeverity) => <span>{fmtRupees(r.total_cost_rupees)}</span> },
          ]}
        />
      </Section>

      <Section title="Open recovery queue">
        <DataTable
          rows={openRecovery}
          rowKey={(r, i) => String(i)}
          emptyMessage="No data"
          columns={[
            { key: 'handoff_code', header: 'Handoff', render: (r: OpenRecovery) => <code>{r.handoff_code}</code> },
            { key: 'gap_category', header: 'Gap', render: (r: OpenRecovery) => <span>{r.gap_category}</span> },
            { key: 'severity', header: 'Severity', render: (r: OpenRecovery) => <strong>{r.severity}</strong> },
            { key: 'recovery_action', header: 'Action', render: (r: OpenRecovery) => <span>{r.recovery_action}</span> },
            { key: 'recovery_owner', header: 'Owner', render: (r: OpenRecovery) => <span>{r.recovery_owner}</span> },
            { key: 'recovery_status', header: 'Status', render: (r: OpenRecovery) => <span>{r.recovery_status}</span> },
            { key: 'cost_to_recover_rupees', header: 'Cost', render: (r: OpenRecovery) => <span>{fmtRupees(r.cost_to_recover_rupees)}</span> },
          ]}
        />
      </Section>

      <Section title="Customer impact breakdown">
        <DataTable
          rows={impact}
          rowKey={(r, i) => String((r as Impact).customer_impact ?? i)}
          emptyMessage="No data"
          columns={[
            { key: 'customer_impact', header: 'Impact', render: (r: Impact) => <span>{r.customer_impact}</span> },
            { key: 'handoff_count', header: 'Handoffs', render: (r: Impact) => <span>{r.handoff_count}</span> },
            { key: 'avg_quality', header: 'Avg quality', render: (r: Impact) => <span>{r.avg_quality}</span> },
          ]}
        />
      </Section>
    </div>
  );
}

function KpiCard({ label, value, tone }: { label: string; value: string; tone?: 'good' | 'bad' }) {
  const color = tone === 'bad' ? '#b91c1c' : tone === 'good' ? '#047857' : '#111';
  return (
    <div style={{ border: '1px solid #e5e7eb', borderRadius: 8, padding: 12, background: '#fff' }}>
      <div style={{ fontSize: 11, color: '#6b7280', textTransform: 'uppercase', letterSpacing: 0.4 }}>{label}</div>
      <div style={{ fontSize: 20, fontWeight: 700, color, marginTop: 4 }}>{value}</div>
    </div>
  );
}

function Section({ title, children }: { title: string; children: React.ReactNode }) {
  return (
    <section style={{ marginBottom: 28 }}>
      <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>{title}</h2>
      {children}
    </section>
  );
}
