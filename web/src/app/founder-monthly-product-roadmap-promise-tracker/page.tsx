import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Kpi = {
  total_promises: number;
  delivered: number;
  missed: number;
  in_progress: number;
  descoped: number;
  reslipped: number;
  on_time_rate_pct: number | null;
  avg_variance_days: number | null;
  net_trust_delta_pp: number | null;
};

type Promise = {
  promise_code: string;
  promise_title: string;
  audience: string;
  commit_month: string;
  delivered_at: string | null;
  variance_days: number | null;
  status: string;
  severity: string;
  trust_delta_pp: number;
};

type ByAudience = {
  audience: string;
  total: number;
  delivered: number;
  missed_or_slipped: number;
  net_trust_delta_pp: number;
  on_time_rate_pct: number | null;
};

type Variance = {
  bucket: string;
  promise_count: number;
  pct_of_delivered: number | null;
};

type Comm = {
  promise_code: string;
  comm_channel: string;
  comm_kind: string;
  audience: string;
  sent_at: string;
  recipient_count: number;
  honest_tone_score: number;
  trust_impact_pp: number;
};

type Leader = {
  promise_code: string;
  promise_title: string;
  audience: string;
  trust_delta_pp: number;
  status: string;
};

type AtRisk = {
  promise_code: string;
  promise_title: string;
  audience: string;
  commit_month: string;
  days_to_commit: number;
  status: string;
  severity: string;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [kpiR, promR, audR, varR, commR, leadR, riskR] = await Promise.all([
    supabase.rpc('founder_roadmap_kpi_r2753'),
    supabase.rpc('founder_roadmap_promises_r2753'),
    supabase.rpc('founder_roadmap_by_audience_r2753'),
    supabase.rpc('founder_roadmap_variance_buckets_r2753'),
    supabase.rpc('founder_roadmap_communications_r2753'),
    supabase.rpc('founder_roadmap_trust_leaders_r2753'),
    supabase.rpc('founder_roadmap_at_risk_r2753'),
  ]);

  const kpi: Kpi | null = (kpiR.data ?? [])[0] ?? null;
  const promises: Promise[] = promR.data ?? [];
  const byAudience: ByAudience[] = audR.data ?? [];
  const variance: Variance[] = varR.data ?? [];
  const comms: Comm[] = commR.data ?? [];
  const leaders: Leader[] = leadR.data ?? [];
  const atRisk: AtRisk[] = riskR.data ?? [];

  return (
    <div style={{ padding: 24, maxWidth: 1280, margin: '0 auto' }}>
      <h1 style={{ fontSize: 28, fontWeight: 700, marginBottom: 4 }}>
        Founder Monthly Product Roadmap Promise Tracker
      </h1>
      <p style={{ color: '#666', marginBottom: 20 }}>
        Promise × audience × commit date × actual × variance × communicate × trust delta. On-time delivery is how trust compounds; honest slip notices preserve it when reality slips.
      </p>

      <section style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(180px, 1fr))', gap: 12, marginBottom: 24 }}>
        <KpiCard label="Total promises" value={kpi?.total_promises ?? 0} />
        <KpiCard label="Delivered" value={kpi?.delivered ?? 0} />
        <KpiCard label="In progress" value={kpi?.in_progress ?? 0} />
        <KpiCard label="Reslipped" value={kpi?.reslipped ?? 0} />
        <KpiCard label="Descoped" value={kpi?.descoped ?? 0} />
        <KpiCard label="On-time rate" value={`${kpi?.on_time_rate_pct ?? 0}%`} />
        <KpiCard label="Avg variance (days)" value={kpi?.avg_variance_days ?? 0} />
        <KpiCard label="Net trust delta (pp)" value={kpi?.net_trust_delta_pp ?? 0} />
      </section>

      <Section title="All promises (commit month asc)">
        <DataTable
          rows={promises}
          columns={[
            { key: 'promise_code', header: 'Code', render: (r: Promise) => r.promise_code },
            { key: 'promise_title', header: 'Title', render: (r: Promise) => r.promise_title },
            { key: 'audience', header: 'Audience', render: (r: Promise) => r.audience },
            { key: 'commit_month', header: 'Commit month', render: (r: Promise) => r.commit_month },
            { key: 'delivered_at', header: 'Delivered', render: (r: Promise) => r.delivered_at ?? '-' },
            { key: 'variance_days', header: 'Variance (d)', render: (r: Promise) => r.variance_days ?? '-' },
            { key: 'status', header: 'Status', render: (r: Promise) => r.status },
            { key: 'severity', header: 'Sev', render: (r: Promise) => r.severity },
            { key: 'trust_delta_pp', header: 'Trust Δ (pp)', render: (r: Promise) => r.trust_delta_pp },
          ]}
          emptyMessage="No data"
          rowKey={(r: Promise, i: number) => String(r.promise_code ?? i)}
        />
      </Section>

      <Section title="At-risk (commit within 30 days, not delivered)">
        <DataTable
          rows={atRisk}
          columns={[
            { key: 'promise_code', header: 'Code', render: (r: AtRisk) => r.promise_code },
            { key: 'promise_title', header: 'Title', render: (r: AtRisk) => r.promise_title },
            { key: 'audience', header: 'Audience', render: (r: AtRisk) => r.audience },
            { key: 'commit_month', header: 'Commit', render: (r: AtRisk) => r.commit_month },
            { key: 'days_to_commit', header: 'Days left', render: (r: AtRisk) => r.days_to_commit },
            { key: 'status', header: 'Status', render: (r: AtRisk) => r.status },
            { key: 'severity', header: 'Sev', render: (r: AtRisk) => r.severity },
          ]}
          emptyMessage="No data"
          rowKey={(r: AtRisk, i: number) => String(r.promise_code ?? i)}
        />
      </Section>

      <Section title="By audience (lowest trust delta first)">
        <DataTable
          rows={byAudience}
          columns={[
            { key: 'audience', header: 'Audience', render: (r: ByAudience) => r.audience },
            { key: 'total', header: 'Total', render: (r: ByAudience) => r.total },
            { key: 'delivered', header: 'Delivered', render: (r: ByAudience) => r.delivered },
            { key: 'missed_or_slipped', header: 'Missed / slipped', render: (r: ByAudience) => r.missed_or_slipped },
            { key: 'on_time_rate_pct', header: 'On-time %', render: (r: ByAudience) => r.on_time_rate_pct ?? '-' },
            { key: 'net_trust_delta_pp', header: 'Net trust (pp)', render: (r: ByAudience) => r.net_trust_delta_pp },
          ]}
          emptyMessage="No data"
          rowKey={(r: ByAudience, i: number) => String(r.audience ?? i)}
        />
      </Section>

      <Section title="Variance buckets (delivered promises)">
        <DataTable
          rows={variance}
          columns={[
            { key: 'bucket', header: 'Bucket', render: (r: Variance) => r.bucket },
            { key: 'promise_count', header: 'Count', render: (r: Variance) => r.promise_count },
            { key: 'pct_of_delivered', header: '% of delivered', render: (r: Variance) => r.pct_of_delivered ?? '-' },
          ]}
          emptyMessage="No data"
          rowKey={(r: Variance, i: number) => String(r.bucket ?? i)}
        />
      </Section>

      <Section title="Trust leaders (top moves, positive or negative)">
        <DataTable
          rows={leaders}
          columns={[
            { key: 'promise_code', header: 'Code', render: (r: Leader) => r.promise_code },
            { key: 'promise_title', header: 'Title', render: (r: Leader) => r.promise_title },
            { key: 'audience', header: 'Audience', render: (r: Leader) => r.audience },
            { key: 'status', header: 'Status', render: (r: Leader) => r.status },
            { key: 'trust_delta_pp', header: 'Trust Δ (pp)', render: (r: Leader) => r.trust_delta_pp },
          ]}
          emptyMessage="No data"
          rowKey={(r: Leader, i: number) => String(r.promise_code ?? i)}
        />
      </Section>

      <Section title="Communications log (most recent first)">
        <DataTable
          rows={comms}
          columns={[
            { key: 'sent_at', header: 'Sent', render: (r: Comm) => r.sent_at },
            { key: 'promise_code', header: 'Promise', render: (r: Comm) => r.promise_code },
            { key: 'comm_kind', header: 'Kind', render: (r: Comm) => r.comm_kind },
            { key: 'comm_channel', header: 'Channel', render: (r: Comm) => r.comm_channel },
            { key: 'audience', header: 'Audience', render: (r: Comm) => r.audience },
            { key: 'recipient_count', header: 'Recipients', render: (r: Comm) => r.recipient_count },
            { key: 'honest_tone_score', header: 'Honest tone (0-1)', render: (r: Comm) => r.honest_tone_score },
            { key: 'trust_impact_pp', header: 'Trust impact (pp)', render: (r: Comm) => r.trust_impact_pp },
          ]}
          emptyMessage="No data"
          rowKey={(r: Comm, i: number) => `${r.promise_code}-${r.sent_at}-${i}`}
        />
      </Section>
    </div>
  );
}

function KpiCard({ label, value }: { label: string; value: number | string | null }) {
  return (
    <div style={{ background: '#fff', border: '1px solid #e5e7eb', borderRadius: 8, padding: 12 }}>
      <div style={{ fontSize: 12, color: '#6b7280', marginBottom: 4 }}>{label}</div>
      <div style={{ fontSize: 22, fontWeight: 700 }}>{value ?? '-'}</div>
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
