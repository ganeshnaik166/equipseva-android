import { requireFounder } from '@/lib/auth/requireFounder';
import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable } from '@/components/DataTable';
import { formatRupees } from '@/lib/format';

function Kpi({ label, value }: { label: string; value: any }) {
  return (
    <div className="rounded-lg border border-neutral-200 bg-white p-3">
      <div className="text-xs text-neutral-500">{label}</div>
      <div className="text-lg font-semibold text-neutral-900">{value ?? "—"}</div>
    </div>
  );
}

function Section({ title, children }: { title: string; children: React.ReactNode }) {
  return (
    <section className="mt-6">
      <h2 className="mb-2 text-sm font-semibold uppercase tracking-wide text-neutral-600">{title}</h2>
      {children}
    </section>
  );
}

export default async function Page() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();

  const [kpis, red, yellow, interventions, followups, trend, signals] = await Promise.all([
    supabase.rpc('founder_attrition_kpis'),
    supabase.rpc('founder_attrition_red_list'),
    supabase.rpc('founder_attrition_yellow_list'),
    supabase.rpc('founder_attrition_recent_interventions'),
    supabase.rpc('founder_attrition_pending_followups'),
    supabase.rpc('founder_attrition_band_trend'),
    supabase.rpc('founder_attrition_top_signals'),
  ]);

  const k: any = (kpis.data && kpis.data[0]) || {};

  return (
    <div className="mx-auto max-w-7xl px-4 py-6">
      <header className="mb-4">
        <h1 className="text-2xl font-bold text-neutral-900">Engineer Attrition Risk</h1>
        <p className="text-sm text-neutral-600">Per-engineer risk scoring from login, accept-rate, NPS, payouts, mental-health and peer-feedback signals.</p>
      </header>

      <div className="grid grid-cols-2 md:grid-cols-4 gap-3">
        <Kpi label="Total engineers" value={k.total_engineers ?? "—"} />
        <Kpi label="Red band" value={k.red_count ?? "—"} />
        <Kpi label="Yellow band" value={k.yellow_count ?? "—"} />
        <Kpi label="Green band" value={k.green_count ?? "—"} />
        <Kpi label="Avg risk" value={k.avg_risk ?? "—"} />
        <Kpi label="Max risk" value={k.max_risk ?? "—"} />
        <Kpi label="Mental health flagged" value={k.flagged_mental_health ?? "—"} />
        <Kpi label="Stale login 30d+" value={k.stale_login_30d ?? "—"} />
        <Kpi label="Open interventions" value={k.open_interventions ?? "—"} />
        <Kpi label="Resolved 30d" value={k.resolved_30d ?? "—"} />
        <Kpi label="Escalated 30d" value={k.escalated_30d ?? "—"} />
        <Kpi label="Attrited 90d" value={k.attrited_90d ?? "—"} />
        <Kpi label="Avg accept rate" value={k.avg_accept_rate ?? "—"} />
        <Kpi label="Avg NPS" value={k.avg_nps ?? "—"} />
        <Kpi label="Late payouts 90d" value={k.total_late_payouts_90d ?? "—"} />
        <Kpi label="Peer neg fbk 90d" value={k.total_peer_neg_90d ?? "—"} />
      </div>

      <Section title="Red list (highest risk)">
        <DataTable
          rows={(red.data as any[]) ?? []}
          rowKey={(r: any) => r.id}
          columns={[
            { key: 'name', header: 'Engineer', render: (r: any) => r.full_name ?? "—" },
            { key: 'score', header: 'Risk', render: (r: any) => r.risk_score ?? "—" },
            { key: 'login', header: 'Login age (d)', render: (r: any) => r.last_login_age_days ?? "—" },
            { key: 'accept', header: 'Accept 30d %', render: (r: any) => r.accept_rate_30d ?? "—" },
            { key: 'nps', header: 'NPS', render: (r: any) => r.nps_score ?? "—" },
            { key: 'latepay', header: 'Late payouts', render: (r: any) => r.late_payout_count_90d ?? 0 },
            { key: 'mh', header: 'Mental health', render: (r: any) => r.mental_health_flag ? 'Yes' : 'No' },
            { key: 'when', header: 'Scored', render: (r: any) => r.scored_at ? new Date(r.scored_at).toLocaleString() : "—" },
          ]}
        />
      </Section>

      <Section title="Yellow list (watch)">
        <DataTable
          rows={(yellow.data as any[]) ?? []}
          rowKey={(r: any) => r.id}
          columns={[
            { key: 'name', header: 'Engineer', render: (r: any) => r.full_name ?? "—" },
            { key: 'score', header: 'Risk', render: (r: any) => r.risk_score ?? "—" },
            { key: 'login', header: 'Login age (d)', render: (r: any) => r.last_login_age_days ?? "—" },
            { key: 'accept', header: 'Accept 30d %', render: (r: any) => r.accept_rate_30d ?? "—" },
            { key: 'nps', header: 'NPS', render: (r: any) => r.nps_score ?? "—" },
            { key: 'latepay', header: 'Late payouts', render: (r: any) => r.late_payout_count_90d ?? 0 },
            { key: 'when', header: 'Scored', render: (r: any) => r.scored_at ? new Date(r.scored_at).toLocaleString() : "—" },
          ]}
        />
      </Section>

      <Section title="Recent interventions">
        <DataTable
          rows={(interventions.data as any[]) ?? []}
          rowKey={(r: any) => r.id}
          columns={[
            { key: 'name', header: 'Engineer', render: (r: any) => r.full_name ?? "—" },
            { key: 'type', header: 'Type', render: (r: any) => r.intervention_type ?? "—" },
            { key: 'notes', header: 'Notes', render: (r: any) => r.notes ?? "—" },
            { key: 'outcome', header: 'Outcome', render: (r: any) => r.outcome ?? 'open' },
            { key: 'when', header: 'When', render: (r: any) => r.performed_at ? new Date(r.performed_at).toLocaleString() : "—" },
            { key: 'fu', header: 'Follow-up', render: (r: any) => r.follow_up_at ? new Date(r.follow_up_at).toLocaleDateString() : "—" },
          ]}
        />
      </Section>

      <Section title="Pending follow-ups">
        <DataTable
          rows={(followups.data as any[]) ?? []}
          rowKey={(r: any) => r.id}
          columns={[
            { key: 'name', header: 'Engineer', render: (r: any) => r.full_name ?? "—" },
            { key: 'type', header: 'Type', render: (r: any) => r.intervention_type ?? "—" },
            { key: 'fu', header: 'Follow-up at', render: (r: any) => r.follow_up_at ? new Date(r.follow_up_at).toLocaleString() : "—" },
            { key: 'days', header: 'Days until', render: (r: any) => r.days_until_followup ?? 0 },
          ]}
        />
      </Section>

      <Section title="Top contributing signals">
        <DataTable
          rows={(signals.data as any[]) ?? []}
          rowKey={(r: any) => r.signal}
          columns={[
            { key: 'sig', header: 'Signal', render: (r: any) => r.signal ?? "—" },
            { key: 'eng', header: 'Affected engineers', render: (r: any) => r.affected_engineers ?? 0 },
            { key: 'avg', header: 'Avg contribution', render: (r: any) => r.avg_contribution ?? 0 },
          ]}
        />
      </Section>

      <Section title="12-week band trend">
        <DataTable
          rows={(trend.data as any[]) ?? []}
          rowKey={(r: any) => r.week_start}
          columns={[
            { key: 'wk', header: 'Week', render: (r: any) => r.week_start ?? "—" },
            { key: 'red', header: 'Red', render: (r: any) => r.red_count ?? 0 },
            { key: 'yel', header: 'Yellow', render: (r: any) => r.yellow_count ?? 0 },
            { key: 'grn', header: 'Green', render: (r: any) => r.green_count ?? 0 },
          ]}
        />
      </Section>

      <p className="mt-8 text-xs text-neutral-500">r1464 · attrition risk scoring · {formatRupees(0)} payout impact tracked separately</p>
    </div>
  );
}
