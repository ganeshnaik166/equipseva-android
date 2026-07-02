import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [visits, summary, followups, tempBreak, typeBreak, topHospitals, overdue] = await Promise.all([
    sb.rpc('list_hospital_vip_visits_r2243'),
    sb.rpc('summary_hospital_vip_visits_r2243'),
    sb.rpc('list_hospital_vip_followups_r2243'),
    sb.rpc('temperature_breakdown_hospital_vip_r2243'),
    sb.rpc('visit_type_breakdown_hospital_vip_r2243'),
    sb.rpc('top_hospitals_by_visit_count_r2243'),
    sb.rpc('overdue_visits_hospital_vip_r2243'),
  ]);

  const visitsRows = (visits.data ?? []) as any[];
  const s = (summary.data?.[0] ?? {}) as any;
  const followupsRows = (followups.data ?? []) as any[];
  const tempRows = (tempBreak.data ?? []) as any[];
  const typeRows = (typeBreak.data ?? []) as any[];
  const topRows = (topHospitals.data ?? []) as any[];
  const overdueRows = (overdue.data ?? []) as any[];

  const visitCols: Column<any>[] = [
    { key: 'visit_date', header: 'Date', render: (r: any) => String(r.visit_date ?? '') },
    { key: 'hospital_name', header: 'Hospital', render: (r: any) => String(r.hospital_name ?? '') },
    { key: 'hospital_tier', header: 'Tier', render: (r: any) => String(r.hospital_tier ?? '') },
    { key: 'hospital_city', header: 'City', render: (r: any) => String(r.hospital_city ?? '') },
    { key: 'visit_type', header: 'Type', render: (r: any) => String(r.visit_type ?? '') },
    { key: 'visited_by_name', header: 'Visited By', render: (r: any) => String(r.visited_by_name ?? '') },
    { key: 'counterpart_name', header: 'Counterpart', render: (r: any) => `${r.counterpart_name ?? ''} (${r.counterpart_title ?? ''})` },
    { key: 'relationship_temperature', header: 'Temp', render: (r: any) => String(r.relationship_temperature ?? '') },
    { key: 'satisfaction_score', header: 'CSAT', render: (r: any) => String(r.satisfaction_score ?? '') },
    { key: 'churn_risk', header: 'Churn Risk', render: (r: any) => String(r.churn_risk ?? '') },
    { key: 'next_visit_due_date', header: 'Next Due', render: (r: any) => String(r.next_visit_due_date ?? '') },
    { key: 'contract_value_rupees', header: 'Contract Rs', render: (r: any) => String(r.contract_value_rupees ?? 0) },
  ];

  const followupCols: Column<any>[] = [
    { key: 'hospital_name', header: 'Hospital', render: (r: any) => String(r.hospital_name ?? '') },
    { key: 'followup_type', header: 'Type', render: (r: any) => String(r.followup_type ?? '') },
    { key: 'description', header: 'Description', render: (r: any) => String(r.description ?? '') },
    { key: 'owner_name', header: 'Owner', render: (r: any) => String(r.owner_name ?? '') },
    { key: 'due_date', header: 'Due', render: (r: any) => String(r.due_date ?? '') },
    { key: 'priority', header: 'Priority', render: (r: any) => String(r.priority ?? '') },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
  ];

  const tempCols: Column<any>[] = [
    { key: 'temperature', header: 'Temperature', render: (r: any) => String(r.temperature ?? '') },
    { key: 'visit_count', header: 'Visits', render: (r: any) => String(r.visit_count ?? 0) },
    { key: 'avg_satisfaction', header: 'Avg CSAT', render: (r: any) => String(r.avg_satisfaction ?? '') },
    { key: 'total_contract_value', header: 'Total Contract Rs', render: (r: any) => String(r.total_contract_value ?? 0) },
  ];

  const typeCols: Column<any>[] = [
    { key: 'visit_type', header: 'Visit Type', render: (r: any) => String(r.visit_type ?? '') },
    { key: 'visit_count', header: 'Count', render: (r: any) => String(r.visit_count ?? 0) },
    { key: 'avg_satisfaction', header: 'Avg CSAT', render: (r: any) => String(r.avg_satisfaction ?? '') },
    { key: 'hot_count', header: 'Hot Outcomes', render: (r: any) => String(r.hot_count ?? 0) },
  ];

  const topCols: Column<any>[] = [
    { key: 'hospital_name', header: 'Hospital', render: (r: any) => String(r.hospital_name ?? '') },
    { key: 'hospital_tier', header: 'Tier', render: (r: any) => String(r.hospital_tier ?? '') },
    { key: 'visit_count', header: 'Visits', render: (r: any) => String(r.visit_count ?? 0) },
    { key: 'last_visit_date', header: 'Last Visit', render: (r: any) => String(r.last_visit_date ?? '') },
    { key: 'last_temperature', header: 'Last Temp', render: (r: any) => String(r.last_temperature ?? '') },
    { key: 'last_churn_risk', header: 'Last Risk', render: (r: any) => String(r.last_churn_risk ?? '') },
    { key: 'total_contract_value', header: 'Total Contract Rs', render: (r: any) => String(r.total_contract_value ?? 0) },
  ];

  const overdueCols: Column<any>[] = [
    { key: 'hospital_name', header: 'Hospital', render: (r: any) => String(r.hospital_name ?? '') },
    { key: 'hospital_tier', header: 'Tier', render: (r: any) => String(r.hospital_tier ?? '') },
    { key: 'last_visit_date', header: 'Last Visit', render: (r: any) => String(r.last_visit_date ?? '') },
    { key: 'next_visit_due_date', header: 'Was Due', render: (r: any) => String(r.next_visit_due_date ?? '') },
    { key: 'days_overdue', header: 'Days Overdue', render: (r: any) => String(r.days_overdue ?? 0) },
    { key: 'last_temperature', header: 'Last Temp', render: (r: any) => String(r.last_temperature ?? '') },
    { key: 'last_churn_risk', header: 'Last Risk', render: (r: any) => String(r.last_churn_risk ?? '') },
  ];

  return (
    <div style={{ padding: '24px', maxWidth: '1400px', margin: '0 auto' }}>
      <h1 style={{ fontSize: '24px', fontWeight: 'bold', marginBottom: '8px' }}>Hospital VIP Visit Log</h1>
      <p style={{ color: '#666', marginBottom: '24px' }}>
        Founder and CEO visits to top hospitals. Track agenda, outcomes, follow-ups and relationship temperature.
      </p>

      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: '12px', marginBottom: '24px' }}>
        <div style={{ padding: '16px', background: '#f8f9fa', borderRadius: '8px' }}>
          <div style={{ color: '#666', fontSize: '12px' }}>Total Visits</div>
          <div style={{ fontSize: '24px', fontWeight: 'bold' }}>{String(s.total_visits ?? 0)}</div>
        </div>
        <div style={{ padding: '16px', background: '#f8f9fa', borderRadius: '8px' }}>
          <div style={{ color: '#666', fontSize: '12px' }}>Visits Last 30d</div>
          <div style={{ fontSize: '24px', fontWeight: 'bold' }}>{String(s.visits_30d ?? 0)}</div>
        </div>
        <div style={{ padding: '16px', background: '#f8f9fa', borderRadius: '8px' }}>
          <div style={{ color: '#666', fontSize: '12px' }}>Visits Last 90d</div>
          <div style={{ fontSize: '24px', fontWeight: 'bold' }}>{String(s.visits_90d ?? 0)}</div>
        </div>
        <div style={{ padding: '16px', background: '#fff5e6', borderRadius: '8px' }}>
          <div style={{ color: '#666', fontSize: '12px' }}>Avg CSAT (out of 10)</div>
          <div style={{ fontSize: '24px', fontWeight: 'bold' }}>{String(s.avg_satisfaction ?? '0')}</div>
        </div>
        <div style={{ padding: '16px', background: '#fee2e2', borderRadius: '8px' }}>
          <div style={{ color: '#666', fontSize: '12px' }}>Hot / On Fire</div>
          <div style={{ fontSize: '24px', fontWeight: 'bold' }}>{String(s.hot_relationships ?? 0)}</div>
        </div>
        <div style={{ padding: '16px', background: '#dbeafe', borderRadius: '8px' }}>
          <div style={{ color: '#666', fontSize: '12px' }}>Cold / Cool</div>
          <div style={{ fontSize: '24px', fontWeight: 'bold' }}>{String(s.cold_relationships ?? 0)}</div>
        </div>
        <div style={{ padding: '16px', background: '#fecaca', borderRadius: '8px' }}>
          <div style={{ color: '#666', fontSize: '12px' }}>Critical Churn Risk</div>
          <div style={{ fontSize: '24px', fontWeight: 'bold' }}>{String(s.critical_churn_risks ?? 0)}</div>
        </div>
        <div style={{ padding: '16px', background: '#fed7aa', borderRadius: '8px' }}>
          <div style={{ color: '#666', fontSize: '12px' }}>Overdue Next Visits</div>
          <div style={{ fontSize: '24px', fontWeight: 'bold' }}>{String(s.overdue_next_visits ?? 0)}</div>
        </div>
      </div>

      <h2 style={{ fontSize: '18px', fontWeight: 'bold', marginTop: '24px', marginBottom: '8px' }}>Visit Log</h2>
      <p style={{ color: '#666', fontSize: '13px', marginBottom: '12px' }}>
        Last 200 visits. Higher CSAT &gt;= 8 signals warm relationship. Churn risk critical needs founder follow-up within 7 days.
      </p>
      <DataTable columns={visitCols} rows={visitsRows} rowKey={(_, i) => String(i)} />

      <h2 style={{ fontSize: '18px', fontWeight: 'bold', marginTop: '32px', marginBottom: '8px' }}>Open Follow-ups</h2>
      <p style={{ color: '#666', fontSize: '13px', marginBottom: '12px' }}>
        Commitments made during visits. Urgent and overdue items surface first.
      </p>
      <DataTable columns={followupCols} rows={followupsRows} rowKey={(_, i) => String(i)} />

      <h2 style={{ fontSize: '18px', fontWeight: 'bold', marginTop: '32px', marginBottom: '8px' }}>Relationship Temperature Breakdown</h2>
      <p style={{ color: '#666', fontSize: '13px', marginBottom: '12px' }}>
        On fire &gt; hot &gt; warm &gt; neutral &gt; cool &gt; cold. Total contract value tied to each tier.
      </p>
      <DataTable columns={tempCols} rows={tempRows} rowKey={(_, i) => String(i)} />

      <h2 style={{ fontSize: '18px', fontWeight: 'bold', marginTop: '32px', marginBottom: '8px' }}>Visit Type Breakdown</h2>
      <p style={{ color: '#666', fontSize: '13px', marginBottom: '12px' }}>
        Hot outcomes &gt;= 1 means at least one visit of that type ended warm or better.
      </p>
      <DataTable columns={typeCols} rows={typeRows} rowKey={(_, i) => String(i)} />

      <h2 style={{ fontSize: '18px', fontWeight: 'bold', marginTop: '32px', marginBottom: '8px' }}>Top Hospitals by Visit Count</h2>
      <p style={{ color: '#666', fontSize: '13px', marginBottom: '12px' }}>
        Top 50 hospitals ranked by visit frequency. Last temperature reading and churn risk shown.
      </p>
      <DataTable columns={topCols} rows={topRows} rowKey={(_, i) => String(i)} />

      <h2 style={{ fontSize: '18px', fontWeight: 'bold', marginTop: '32px', marginBottom: '8px' }}>Overdue Next Visits</h2>
      <p style={{ color: '#666', fontSize: '13px', marginBottom: '12px' }}>
        Hospitals where next_visit_due_date &lt; today. Days overdue &gt;= 30 is high priority.
      </p>
      <DataTable columns={overdueCols} rows={overdueRows} rowKey={(_, i) => String(i)} />
    </div>
  );
}
