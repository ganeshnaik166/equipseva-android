import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [visitsRes, rootCausesRes, summaryRes] = await Promise.all([
    sb.rpc('list_first_call_fix_visits_r2306'),
    sb.rpc('list_first_call_fix_root_causes_r2306', { p_visit_id: null }),
    sb.rpc('first_call_fix_rate_summary_r2306'),
  ]);

  const visits = (visitsRes.data ?? []) as any[];
  const rootCauses = (rootCausesRes.data ?? []) as any[];
  const summary = ((summaryRes.data ?? [])[0] ?? {}) as any;

  const visitColumns: Column<any>[] = [
    { key: 'visit_date', header: 'Visit date', render: (r: any) => r.visit_date ?? '—' },
    { key: 'job_label', header: 'Job', render: (r: any) => r.job_label ?? '—' },
    { key: 'engineer_email', header: 'Engineer', render: (r: any) => r.engineer_email ?? '—' },
    { key: 'engineer_tier', header: 'Tier', render: (r: any) => r.engineer_tier ?? '—' },
    { key: 'hospital_label', header: 'Hospital', render: (r: any) => r.hospital_label ?? '—' },
    { key: 'equipment_category', header: 'Equipment', render: (r: any) => r.equipment_category ?? '—' },
    { key: 'region', header: 'Region', render: (r: any) => r.region ?? '—' },
    { key: 'visit_number', header: 'Visit #', render: (r: any) => String(r.visit_number ?? '—') },
    { key: 'outcome', header: 'Outcome', render: (r: any) => r.outcome ?? '—' },
    { key: 'fixed_on_first_call', header: 'FCF?', render: (r: any) => (r.fixed_on_first_call ? 'YES' : 'no') },
    { key: 'needs_revisit', header: 'Revisit?', render: (r: any) => (r.needs_revisit ? 'YES' : 'no') },
    { key: 'on_site_minutes', header: 'On-site min', render: (r: any) => (r.on_site_minutes != null ? String(r.on_site_minutes) : '—') },
    { key: 'customer_satisfaction', header: 'CSAT', render: (r: any) => (r.customer_satisfaction != null ? `${r.customer_satisfaction}/5` : '—') },
    { key: 'parts_used_count', header: 'Parts used', render: (r: any) => `${r.parts_used_count ?? 0}/${r.parts_carried_count ?? 0}` },
    { key: 'diagnosis_confidence', header: 'Diag conf', render: (r: any) => r.diagnosis_confidence ?? '—' },
  ];

  const rootCauseColumns: Column<any>[] = [
    { key: 'detected_on', header: 'Detected', render: (r: any) => r.detected_on ?? '—' },
    { key: 'job_label', header: 'Job', render: (r: any) => r.job_label ?? '—' },
    { key: 'engineer_email', header: 'Engineer', render: (r: any) => r.engineer_email ?? '—' },
    { key: 'root_cause_category', header: 'Root cause', render: (r: any) => r.root_cause_category ?? '—' },
    { key: 'severity', header: 'Severity', render: (r: any) => r.severity ?? '—' },
    { key: 'responsible_party', header: 'Owner', render: (r: any) => r.responsible_party ?? '—' },
    { key: 'cost_of_revisit_rupees', header: 'Cost (rupees)', render: (r: any) => String(r.cost_of_revisit_rupees ?? 0) },
    { key: 'coaching_assigned', header: 'Coached?', render: (r: any) => (r.coaching_assigned ? 'YES' : 'no') },
    { key: 'resolved_on', header: 'Resolved', render: (r: any) => r.resolved_on ?? '—' },
    { key: 'prevented_future_count', header: 'Prevented', render: (r: any) => String(r.prevented_future_count ?? 0) },
    { key: 'preventive_action', header: 'Preventive action', render: (r: any) => r.preventive_action ?? '—' },
  ];

  const fcfRate = Number(summary.fcf_rate_pct ?? 0);
  const revisitRate = Number(summary.revisit_rate_pct ?? 0);
  const avgOnSite = Number(summary.avg_on_site_minutes ?? 0);
  const avgCsat = Number(summary.avg_customer_satisfaction ?? 0);
  const totalCost = Number(summary.total_revisit_cost_rupees ?? 0);
  const avgCost = Number(summary.avg_revisit_cost_rupees ?? 0);

  return (
    <main style={{ padding: 24, maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 4 }}>
        Engineer first-call-fix-rate tracker
      </h1>
      <p style={{ color: '#555', marginBottom: 16 }}>
        Round r2306 · jobs resolved on first visit vs needing 2nd visit, with revisit root-cause log by engineer.
        Lower is worse: revisit rate &gt;=25% triggers coaching review.
      </p>

      <section style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fill, minmax(200px, 1fr))', gap: 12, marginBottom: 24 }}>
        <Stat label="Total visits" value={String(summary.total_visits ?? 0)} />
        <Stat label="Unique jobs" value={String(summary.unique_jobs ?? 0)} />
        <Stat label="1st visits" value={String(summary.first_visit_count ?? 0)} />
        <Stat label="2nd visits" value={String(summary.second_visit_count ?? 0)} />
        <Stat label="3rd+ visits" value={String(summary.third_plus_visit_count ?? 0)} />
        <Stat label="FCF rate %" value={fcfRate.toFixed(1)} />
        <Stat label="Revisit rate %" value={revisitRate.toFixed(1)} />
        <Stat label="Avg on-site min" value={avgOnSite.toFixed(1)} />
        <Stat label="Avg CSAT" value={avgCsat.toFixed(2)} />
        <Stat label="Open root causes" value={String(summary.open_root_causes ?? 0)} />
        <Stat label="Critical root causes" value={String(summary.critical_root_causes ?? 0)} />
        <Stat label="Total revisit cost (rupees)" value={String(totalCost)} />
        <Stat label="Avg revisit cost (rupees)" value={avgCost.toFixed(0)} />
        <Stat label="Top root cause" value={String(summary.top_root_cause_category ?? '—')} />
        <Stat label="Best engineer" value={String(summary.best_engineer_email ?? '—')} />
        <Stat label="Worst engineer" value={String(summary.worst_engineer_email ?? '—')} />
        <Stat label="Hardest equipment" value={String(summary.worst_equipment_category ?? '—')} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>
          Visits ({visits.length})
        </h2>
        <p style={{ color: '#666', fontSize: 13, marginBottom: 8 }}>
          One row per engineer site visit. Visit number &gt;=2 means revisit; outcome captures why first visit failed.
        </p>
        <DataTable
          rows={visits}
          columns={visitColumns}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
          emptyMessage="No visits logged yet."
        />
      </section>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>
          Revisit root causes ({rootCauses.length})
        </h2>
        <p style={{ color: '#666', fontSize: 13, marginBottom: 8 }}>
          Root cause for every revisit &amp; preventive action. Cost &gt;=5000 rupees flags vendor or supplier escalation.
        </p>
        <DataTable
          rows={rootCauses}
          columns={rootCauseColumns}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
          emptyMessage="No root causes logged yet."
        />
      </section>
    </main>
  );
}

function Stat({ label, value }: { label: string; value: string }) {
  return (
    <div style={{ border: '1px solid #e5e7eb', borderRadius: 8, padding: 12, background: '#fff' }}>
      <div style={{ fontSize: 11, textTransform: 'uppercase', color: '#6b7280', letterSpacing: 0.5 }}>{label}</div>
      <div style={{ fontSize: 18, fontWeight: 600, marginTop: 4 }}>{value}</div>
    </div>
  );
}
