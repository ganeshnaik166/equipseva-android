import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function FounderEngineerEquipmentDamageLogPage() {
  const sb = await getSupabaseServerClient();

  const [damagesRes, summaryRes, queueRes, reviewsRes] = await Promise.all([
    sb.rpc('list_damages_r1704'),
    sb.rpc('damage_summary_per_engineer_r1704'),
    sb.rpc('open_damage_queue_r1704'),
    sb.rpc('list_reviews_r1704', { p_damage_id: null }),
  ]);

  const damages: any[] = Array.isArray(damagesRes.data) ? damagesRes.data : [];
  const summary: any[] = Array.isArray(summaryRes.data) ? summaryRes.data : [];
  const queue: any[] = Array.isArray(queueRes.data) ? queueRes.data : [];
  const reviews: any[] = Array.isArray(reviewsRes.data) ? reviewsRes.data : [];

  const damageCols: Column<any>[] = [
    { key: 'damaged_at', header: 'Damaged At', render: (r: any) => r.damaged_at ? new Date(r.damaged_at).toLocaleString() : '—' },
    { key: 'engineer_email', header: 'Engineer', render: (r: any) => r.engineer_email ?? '—' },
    { key: 'equipment_name', header: 'Equipment', render: (r: any) => r.equipment_name ?? '—' },
    { key: 'hospital_name', header: 'Hospital', render: (r: any) => r.hospital_name ?? '—' },
    { key: 'damage_severity', header: 'Severity', render: (r: any) => r.damage_severity ?? '—' },
    { key: 'cost_estimate_rupees', header: 'Cost (Rs)', render: (r: any) => Number(r.cost_estimate_rupees ?? 0).toLocaleString() },
    { key: 'status', header: 'Status', render: (r: any) => r.status ?? '—' },
    { key: 'recovered_amount_rupees', header: 'Recovered (Rs)', render: (r: any) => Number(r.recovered_amount_rupees ?? 0).toLocaleString() },
  ];

  const summaryCols: Column<any>[] = [
    { key: 'engineer_email', header: 'Engineer', render: (r: any) => r.engineer_email ?? '—' },
    { key: 'incident_count', header: 'Incidents', render: (r: any) => Number(r.incident_count ?? 0).toLocaleString() },
    { key: 'open_count', header: 'Open', render: (r: any) => Number(r.open_count ?? 0).toLocaleString() },
    { key: 'total_cost_rupees', header: 'Total Cost (Rs)', render: (r: any) => Number(r.total_cost_rupees ?? 0).toLocaleString() },
    { key: 'recovered_rupees', header: 'Recovered (Rs)', render: (r: any) => Number(r.recovered_rupees ?? 0).toLocaleString() },
    { key: 'outstanding_rupees', header: 'Outstanding (Rs)', render: (r: any) => Number(r.outstanding_rupees ?? 0).toLocaleString() },
  ];

  const queueCols: Column<any>[] = [
    { key: 'damaged_at', header: 'Damaged At', render: (r: any) => r.damaged_at ? new Date(r.damaged_at).toLocaleString() : '—' },
    { key: 'age_hours', header: 'Age (hrs)', render: (r: any) => Number(r.age_hours ?? 0).toLocaleString() },
    { key: 'engineer_email', header: 'Engineer', render: (r: any) => r.engineer_email ?? '—' },
    { key: 'equipment_name', header: 'Equipment', render: (r: any) => r.equipment_name ?? '—' },
    { key: 'hospital_name', header: 'Hospital', render: (r: any) => r.hospital_name ?? '—' },
    { key: 'damage_severity', header: 'Severity', render: (r: any) => r.damage_severity ?? '—' },
    { key: 'cost_estimate_rupees', header: 'Cost (Rs)', render: (r: any) => Number(r.cost_estimate_rupees ?? 0).toLocaleString() },
    { key: 'status', header: 'Status', render: (r: any) => r.status ?? '—' },
  ];

  const reviewCols: Column<any>[] = [
    { key: 'decided_at', header: 'Decided At', render: (r: any) => r.decided_at ? new Date(r.decided_at).toLocaleString() : '—' },
    { key: 'equipment_name', header: 'Equipment', render: (r: any) => r.equipment_name ?? '—' },
    { key: 'reviewer_email', header: 'Reviewer', render: (r: any) => r.reviewer_email ?? '—' },
    { key: 'decision', header: 'Decision', render: (r: any) => r.decision ?? '—' },
    { key: 'decision_note', header: 'Note', render: (r: any) => r.decision_note ?? '—' },
  ];

  const totalIncidents = damages.length;
  const openIncidents = damages.filter((d) => d.status === 'open' || d.status === 'reviewing').length;
  const totalCost = damages.reduce((s, d) => s + Number(d.cost_estimate_rupees ?? 0), 0);
  const totalRecovered = damages.reduce((s, d) => s + Number(d.recovered_amount_rupees ?? 0), 0);
  const outstanding = totalCost - totalRecovered;

  return (
    <div style={{ padding: 24, fontFamily: 'system-ui, sans-serif', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: 28, fontWeight: 700, marginBottom: 4 }}>Engineer Equipment Damage Log</h1>
      <p style={{ color: '#666', marginBottom: 24 }}>
        Per-engineer damaged equipment incidents and cost recovery tracking.
      </p>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Overview</h2>
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(180px, 1fr))', gap: 12 }}>
          <div style={{ border: '1px solid #e5e7eb', borderRadius: 8, padding: 16 }}>
            <div style={{ fontSize: 12, color: '#666' }}>Total Incidents</div>
            <div style={{ fontSize: 24, fontWeight: 700 }}>{totalIncidents.toLocaleString()}</div>
          </div>
          <div style={{ border: '1px solid #e5e7eb', borderRadius: 8, padding: 16 }}>
            <div style={{ fontSize: 12, color: '#666' }}>Open / Reviewing</div>
            <div style={{ fontSize: 24, fontWeight: 700 }}>{openIncidents.toLocaleString()}</div>
          </div>
          <div style={{ border: '1px solid #e5e7eb', borderRadius: 8, padding: 16 }}>
            <div style={{ fontSize: 12, color: '#666' }}>Total Cost (Rs)</div>
            <div style={{ fontSize: 24, fontWeight: 700 }}>{totalCost.toLocaleString()}</div>
          </div>
          <div style={{ border: '1px solid #e5e7eb', borderRadius: 8, padding: 16 }}>
            <div style={{ fontSize: 12, color: '#666' }}>Recovered (Rs)</div>
            <div style={{ fontSize: 24, fontWeight: 700 }}>{totalRecovered.toLocaleString()}</div>
          </div>
          <div style={{ border: '1px solid #e5e7eb', borderRadius: 8, padding: 16 }}>
            <div style={{ fontSize: 12, color: '#666' }}>Outstanding (Rs)</div>
            <div style={{ fontSize: 24, fontWeight: 700 }}>{outstanding.toLocaleString()}</div>
          </div>
        </div>
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Open Damage Queue</h2>
        <p style={{ color: '#666', fontSize: 13, marginBottom: 8 }}>
          Damages with status open or reviewing, ordered oldest first.
        </p>
        <DataTable
          rows={queue}
          columns={queueCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Per-Engineer Summary</h2>
        <p style={{ color: '#666', fontSize: 13, marginBottom: 8 }}>
          Outstanding amount = total cost minus recovered. Sorted by outstanding desc.
        </p>
        <DataTable
          rows={summary}
          columns={summaryCols}
          rowKey={(r: any, i: number) => String(r.engineer_user_id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>All Damage Incidents</h2>
        <DataTable
          rows={damages}
          columns={damageCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Recent Review Decisions</h2>
        <DataTable
          rows={reviews}
          columns={reviewCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>
    </div>
  );
}
