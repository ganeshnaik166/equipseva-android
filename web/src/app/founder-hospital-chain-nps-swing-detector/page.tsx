import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [qRes, swingRes, planRes, topRes] = await Promise.all([
    sb.rpc('list_chain_nps_quarters_r2407'),
    sb.rpc('detect_chain_nps_swings_r2407'),
    sb.rpc('list_chain_interventions_r2407'),
    sb.rpc('top_chain_arr_at_risk_r2407'),
  ]);

  const quarters: any[] = Array.isArray(qRes.data) ? qRes.data : [];
  const swings: any[] = Array.isArray(swingRes.data) ? swingRes.data : [];
  const plans: any[] = Array.isArray(planRes.data) ? planRes.data : [];
  const topRisk: any[] = Array.isArray(topRes.data) ? topRes.data : [];

  const promoterToDetractor = swings.filter((s) => s.swing_kind === 'promoter_to_detractor').length;
  const promoterToPassive = swings.filter((s) => s.swing_kind === 'promoter_to_passive').length;
  const passiveToDetractor = swings.filter((s) => s.swing_kind === 'passive_to_detractor').length;
  const recovered = swings.filter((s) => s.swing_kind === 'recovered').length;
  const openPlans = plans.filter((p) => p.status === 'open' || p.status === 'in_progress').length;
  const totalArrAtRisk = plans
    .filter((p) => p.status === 'open' || p.status === 'in_progress')
    .reduce((sum, p) => sum + Number(p.arr_at_risk_rupees ?? 0), 0);

  const fmtRupees = (n: number | bigint | null | undefined) => {
    const v = Number(n ?? 0);
    return '₹' + v.toLocaleString('en-IN');
  };

  const fmtPct = (n: number | null | undefined) => {
    const v = Number(n ?? 0);
    return v.toFixed(2);
  };

  const qColumns: Column<any>[] = [
    { key: 'quarter_start', header: 'Quarter', render: (r: any) => r.quarter_label ?? r.quarter_start },
    { key: 'chain_name', header: 'Chain', render: (r: any) => r.chain_name },
    { key: 'hospital_email', header: 'Hospital', render: (r: any) => r.hospital_email ?? r.hospital_user_id?.slice(0, 8) },
    { key: 'promoter_count', header: 'Promoters', render: (r: any) => String(r.promoter_count ?? 0) },
    { key: 'passive_count', header: 'Passives', render: (r: any) => String(r.passive_count ?? 0) },
    { key: 'detractor_count', header: 'Detractors', render: (r: any) => String(r.detractor_count ?? 0) },
    { key: 'total_responses', header: 'Total', render: (r: any) => String(r.total_responses ?? 0) },
    { key: 'nps_score', header: 'NPS', render: (r: any) => fmtPct(r.nps_score) },
    { key: 'nps_segment', header: 'Segment', render: (r: any) => r.nps_segment },
    { key: 'arr_rupees', header: 'ARR', render: (r: any) => fmtRupees(r.arr_rupees) },
    { key: 'notes', header: 'Notes', render: (r: any) => (r.notes ?? '').slice(0, 100) },
  ];

  const swingColumns: Column<any>[] = [
    { key: 'chain_name', header: 'Chain', render: (r: any) => r.chain_name },
    { key: 'hospital_email', header: 'Hospital', render: (r: any) => r.hospital_email ?? r.hospital_user_id?.slice(0, 8) },
    { key: 'prior_quarter_start', header: 'Prior Q', render: (r: any) => r.prior_quarter_start },
    { key: 'prior_segment', header: 'Prior Seg', render: (r: any) => r.prior_segment },
    { key: 'prior_nps', header: 'Prior NPS', render: (r: any) => fmtPct(r.prior_nps) },
    { key: 'current_quarter_start', header: 'Current Q', render: (r: any) => r.current_quarter_start },
    { key: 'current_segment', header: 'Current Seg', render: (r: any) => r.current_segment },
    { key: 'current_nps', header: 'Current NPS', render: (r: any) => fmtPct(r.current_nps) },
    { key: 'nps_delta', header: 'Delta', render: (r: any) => fmtPct(r.nps_delta) },
    { key: 'swing_kind', header: 'Swing', render: (r: any) => r.swing_kind },
    { key: 'arr_at_risk_rupees', header: 'ARR at risk', render: (r: any) => fmtRupees(r.arr_at_risk_rupees) },
  ];

  const planColumns: Column<any>[] = [
    { key: 'detected_quarter_start', header: 'Detected Q', render: (r: any) => r.detected_quarter_start },
    { key: 'hospital_email', header: 'Hospital', render: (r: any) => r.hospital_email ?? r.hospital_user_id?.slice(0, 8) },
    { key: 'swing_kind', header: 'Swing', render: (r: any) => r.swing_kind },
    { key: 'prior_segment', header: 'Prior', render: (r: any) => r.prior_segment },
    { key: 'current_segment', header: 'Current', render: (r: any) => r.current_segment },
    { key: 'nps_delta', header: 'Delta', render: (r: any) => fmtPct(r.nps_delta) },
    { key: 'arr_at_risk_rupees', header: 'ARR at risk', render: (r: any) => fmtRupees(r.arr_at_risk_rupees) },
    { key: 'intervention_owner_email', header: 'Owner', render: (r: any) => r.intervention_owner_email ?? '—' },
    { key: 'intervention_plan', header: 'Plan', render: (r: any) => (r.intervention_plan ?? '').slice(0, 140) },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'due_at', header: 'Due', render: (r: any) => (r.due_at ? new Date(r.due_at).toLocaleString() : '—') },
    { key: 'closed_at', header: 'Closed', render: (r: any) => (r.closed_at ? new Date(r.closed_at).toLocaleString() : '—') },
    { key: 'closed_by_email', header: 'Closed By', render: (r: any) => r.closed_by_email ?? '—' },
  ];

  const topColumns: Column<any>[] = [
    { key: 'hospital_email', header: 'Hospital', render: (r: any) => r.hospital_email ?? r.hospital_user_id?.slice(0, 8) },
    { key: 'swing_kind', header: 'Swing', render: (r: any) => r.swing_kind },
    { key: 'nps_delta', header: 'Delta', render: (r: any) => fmtPct(r.nps_delta) },
    { key: 'arr_at_risk_rupees', header: 'ARR at risk', render: (r: any) => fmtRupees(r.arr_at_risk_rupees) },
    { key: 'intervention_owner_email', header: 'Owner', render: (r: any) => r.intervention_owner_email ?? '—' },
    { key: 'due_at', header: 'Due', render: (r: any) => (r.due_at ? new Date(r.due_at).toLocaleString() : '—') },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
  ];

  return (
    <main style={{ padding: '24px', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: 28, fontWeight: 700, marginBottom: 8 }}>Hospital Chain NPS Swing Detector</h1>
      <p style={{ color: '#666', marginBottom: 24 }}>
        Quarter-over-quarter NPS movement per hospital chain. Catch promoter =&gt; detractor flips early, attach an intervention owner, and track recovery before the ARR walks.
      </p>

      <section style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(180px, 1fr))', gap: 12, marginBottom: 24 }}>
        <div style={{ padding: 16, border: '1px solid #e5e5e5', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#666' }}>Promoter =&gt; Detractor</div>
          <div style={{ fontSize: 24, fontWeight: 700 }}>{promoterToDetractor}</div>
        </div>
        <div style={{ padding: 16, border: '1px solid #e5e5e5', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#666' }}>Promoter =&gt; Passive</div>
          <div style={{ fontSize: 24, fontWeight: 700 }}>{promoterToPassive}</div>
        </div>
        <div style={{ padding: 16, border: '1px solid #e5e5e5', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#666' }}>Passive =&gt; Detractor</div>
          <div style={{ fontSize: 24, fontWeight: 700 }}>{passiveToDetractor}</div>
        </div>
        <div style={{ padding: 16, border: '1px solid #e5e5e5', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#666' }}>Recovered</div>
          <div style={{ fontSize: 24, fontWeight: 700 }}>{recovered}</div>
        </div>
        <div style={{ padding: 16, border: '1px solid #e5e5e5', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#666' }}>Open interventions</div>
          <div style={{ fontSize: 24, fontWeight: 700 }}>{openPlans}</div>
        </div>
        <div style={{ padding: 16, border: '1px solid #e5e5e5', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#666' }}>ARR at risk (open)</div>
          <div style={{ fontSize: 24, fontWeight: 700 }}>{fmtRupees(totalArrAtRisk)}</div>
        </div>
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>Detected swings (latest vs prior quarter)</h2>
        <p style={{ color: '#666', marginBottom: 8, fontSize: 14 }}>
          Worst delta first. Recovered rows show chains that climbed back to promoter — keep tabs on them too.
        </p>
        <DataTable rows={swings} columns={swingColumns} rowKey={(r, i) => `${r.hospital_user_id}-${r.current_quarter_start}-${i}`} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>Top ARR at risk</h2>
        <p style={{ color: '#666', marginBottom: 8, fontSize: 14 }}>
          Open and in-progress interventions ranked by rupee impact. Founder should know each owner by name.
        </p>
        <DataTable rows={topRisk} columns={topColumns} rowKey={(r, i) => String(r.id ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>Intervention plans</h2>
        <DataTable rows={plans} columns={planColumns} rowKey={(r, i) => String(r.id ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>Quarterly NPS history</h2>
        <p style={{ color: '#666', marginBottom: 8, fontSize: 14 }}>
          NPS = (% promoters &minus; % detractors). Segment is promoter when NPS &gt;= 50, passive when 0 &lt;= NPS &lt; 50, detractor when NPS &lt; 0.
        </p>
        <DataTable rows={quarters} columns={qColumns} rowKey={(r, i) => String(r.id ?? i)} />
      </section>
    </main>
  );
}
