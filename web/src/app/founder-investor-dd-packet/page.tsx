import { requireFounder } from '@/lib/auth/requireFounder';
import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

type Kpi = { label: string; value: string };

export const dynamic = 'force-dynamic';

export default async function FounderInvestorDDPacketPage() {
  await requireFounder();
  const sb = await getSupabaseServerClient();

  let kpis: any = {};
  let packetList: any[] = [];
  let pending: any[] = [];
  let accessLog: any[] = [];
  let engagement: any[] = [];

  try {
    const { data } = await sb.rpc('rpc_founder_dd_packet_kpis');
    kpis = data ?? {};
  } catch {}
  try {
    const { data } = await sb.rpc('rpc_founder_dd_packet_list');
    packetList = Array.isArray(data) ? data : [];
  } catch {}
  try {
    const { data } = await sb.rpc('rpc_founder_dd_packet_pending_approval');
    pending = Array.isArray(data) ? data : [];
  } catch {}
  try {
    const { data } = await sb.rpc('rpc_founder_dd_packet_access_recent');
    accessLog = Array.isArray(data) ? data : [];
  } catch {}
  try {
    const { data } = await sb.rpc('rpc_founder_dd_packet_engagement');
    engagement = Array.isArray(data) ? data : [];
  } catch {}

  const cards: Kpi[] = [
    { label: 'Total Packets', value: String(kpis.total_packets ?? 0) },
    { label: 'Draft', value: String(kpis.draft ?? 0) },
    { label: 'In Review', value: String(kpis.in_review ?? 0) },
    { label: 'Approved', value: String(kpis.approved ?? 0) },
    { label: 'Sent', value: String(kpis.sent ?? 0) },
    { label: 'Revoked', value: String(kpis.revoked ?? 0) },
    { label: 'Sent 24h', value: String(kpis.sent_24h ?? 0) },
    { label: 'Sent 7d', value: String(kpis.sent_7d ?? 0) },
    { label: 'Sent 30d', value: String(kpis.sent_30d ?? 0) },
    { label: 'Access 24h', value: String(kpis.access_24h ?? 0) },
    { label: 'Access 7d', value: String(kpis.access_7d ?? 0) },
    { label: 'Unique Investors 30d', value: String(kpis.unique_investors_30d ?? 0) },
    { label: 'Avg Q&A Items', value: String(kpis.avg_qa_items ?? 0) },
    { label: 'Avg Docs', value: String(kpis.avg_docs ?? 0) },
    { label: 'Awaiting Approval', value: String(kpis.awaiting_approval ?? 0) },
    { label: 'Sent, Never Accessed', value: String(kpis.never_accessed ?? 0) },
  ];

  const packetCols: Column<any>[] = [
    { key: 'investor_name', header: 'Investor', render: (r: any) => r.investor_name ?? "—" },
    { key: 'investor_firm', header: 'Firm', render: (r: any) => r.investor_firm ?? "—" },
    { key: 'packet_status', header: 'Status', render: (r: any) => r.packet_status ?? "—" },
    { key: 'qa_count', header: 'Q&A', render: (r: any) => String(r.qa_count ?? 0) },
    { key: 'doc_count', header: 'Docs', render: (r: any) => String(r.doc_count ?? 0) },
    { key: 'created_at', header: 'Created', render: (r: any) => r.created_at ? new Date(r.created_at).toLocaleString() : "—" },
    { key: 'sent_at', header: 'Sent', render: (r: any) => r.sent_at ? new Date(r.sent_at).toLocaleString() : "—" },
  ];

  const pendingCols: Column<any>[] = [
    { key: 'investor_name', header: 'Investor', render: (r: any) => r.investor_name ?? "—" },
    { key: 'investor_firm', header: 'Firm', render: (r: any) => r.investor_firm ?? "—" },
    { key: 'qa_count', header: 'Q&A Items', render: (r: any) => String(r.qa_count ?? 0) },
    { key: 'doc_count', header: 'Docs', render: (r: any) => String(r.doc_count ?? 0) },
    { key: 'age_hours', header: 'Age (hrs)', render: (r: any) => String(r.age_hours ?? 0) },
  ];

  const accessCols: Column<any>[] = [
    { key: 'investor_name', header: 'Investor', render: (r: any) => r.investor_name ?? "—" },
    { key: 'investor_firm', header: 'Firm', render: (r: any) => r.investor_firm ?? "—" },
    { key: 'action', header: 'Action', render: (r: any) => r.action ?? "—" },
    { key: 'accessed_at', header: 'When', render: (r: any) => r.accessed_at ? new Date(r.accessed_at).toLocaleString() : "—" },
    { key: 'ip_address', header: 'IP', render: (r: any) => r.ip_address ?? "—" },
  ];

  const engagementCols: Column<any>[] = [
    { key: 'investor_name', header: 'Investor', render: (r: any) => r.investor_name ?? "—" },
    { key: 'investor_firm', header: 'Firm', render: (r: any) => r.investor_firm ?? "—" },
    { key: 'sent_at', header: 'Sent', render: (r: any) => r.sent_at ? new Date(r.sent_at).toLocaleString() : "—" },
    { key: 'access_count', header: 'Accesses', render: (r: any) => String(r.access_count ?? 0) },
    { key: 'last_access', header: 'Last Access', render: (r: any) => r.last_access ? new Date(r.last_access).toLocaleString() : "—" },
  ];

  return (
    <div style={{ padding: 24 }}>
      <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 4 }}>Investor Due Diligence Packet</h1>
      <p style={{ color: '#666', marginBottom: 20 }}>Centralized Q&A, docs, and access log. Founder approval required before send.</p>

      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: 12, marginBottom: 24 }}>
        {cards.map((k) => (
          <div key={k.label} style={{ border: '1px solid #e5e5e5', borderRadius: 8, padding: 12 }}>
            <div style={{ fontSize: 12, color: '#666' }}>{k.label}</div>
            <div style={{ fontSize: 20, fontWeight: 600 }}>{k.value}</div>
          </div>
        ))}
      </div>

      <section style={{ marginBottom: 24 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Pending Founder Approval</h2>
        <DataTable columns={pendingCols} rows={pending} rowKey={(r: any) => r.id} />
      </section>

      <section style={{ marginBottom: 24 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>All Packets</h2>
        <DataTable columns={packetCols} rows={packetList} rowKey={(r: any) => r.id} />
      </section>

      <section style={{ marginBottom: 24 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Investor Engagement</h2>
        <DataTable columns={engagementCols} rows={engagement} rowKey={(r: any) => r.id} />
      </section>

      <section style={{ marginBottom: 24 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Recent Access Log</h2>
        <DataTable columns={accessCols} rows={accessLog} rowKey={(r: any) => `${r.packet_id}-${r.accessed_at}`} />
      </section>
    </div>
  );
}
