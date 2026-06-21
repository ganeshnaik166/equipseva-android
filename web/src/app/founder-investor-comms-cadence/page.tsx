import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Commitment = {
  id: string;
  investor_id: string;
  investor_email: string | null;
  commitment_type: string;
  frequency_days: number;
  last_promised_at: string | null;
  next_due_at: string | null;
  active: boolean;
  notes: string | null;
  created_at: string;
};

type Delivery = {
  id: string;
  commitment_id: string;
  investor_email: string | null;
  commitment_type: string;
  delivered_at: string;
  delivery_channel: string;
  summary: string | null;
  on_time: boolean;
};

type Overdue = {
  id: string;
  investor_id: string;
  investor_email: string | null;
  commitment_type: string;
  next_due_at: string | null;
  days_overdue: number;
};

type OnTimeKpi = {
  total_deliveries: number;
  on_time_count: number;
  on_time_pct: number;
};

type PerInvestor = {
  investor_id: string;
  investor_email: string | null;
  commitments_count: number;
  deliveries_count: number;
  on_time_count: number;
  on_time_pct: number;
  overdue_count: number;
};

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [commitmentsRes, deliveriesRes, overdueRes, kpiRes, perInvestorRes] = await Promise.all([
    sb.rpc('list_commitments_r1681'),
    sb.rpc('list_deliveries_r1681', { p_limit: 100 }),
    sb.rpc('overdue_commitments_r1681'),
    sb.rpc('on_time_pct_r1681'),
    sb.rpc('per_investor_cadence_summary_r1681'),
  ]);

  const commitments: Commitment[] = (commitmentsRes.data ?? []) as Commitment[];
  const deliveries: Delivery[] = (deliveriesRes.data ?? []) as Delivery[];
  const overdue: Overdue[] = (overdueRes.data ?? []) as Overdue[];
  const kpi: OnTimeKpi = ((kpiRes.data ?? [])[0] ?? { total_deliveries: 0, on_time_count: 0, on_time_pct: 0 }) as OnTimeKpi;
  const perInvestor: PerInvestor[] = (perInvestorRes.data ?? []) as PerInvestor[];

  const activeCommitments = commitments.filter((c) => c.active).length;

  const commitmentCols: Column<Commitment>[] = [
    { key: 'investor', header: 'Investor', render: (r: any) => r.investor_email ?? r.investor_id.slice(0, 8)  },
    { key: 'type', header: 'Type', render: (r: any) => r.commitment_type  },
    { key: 'freq_days', header: 'Freq (days)', render: (r: any) => String(r.frequency_days)  },
    { key: 'last_promised', header: 'Last promised', render: (r: any) => (r.last_promised_at ? new Date(r.last_promised_at).toLocaleDateString() : '—')  },
    { key: 'next_due', header: 'Next due', render: (r: any) => (r.next_due_at ? new Date(r.next_due_at).toLocaleDateString() : '—')  },
    { key: 'active', header: 'Active', render: (r: any) => (r.active ? 'yes' : 'no')  },
  ];

  const overdueCols: Column<Overdue>[] = [
    { key: 'investor', header: 'Investor', render: (r: any) => r.investor_email ?? r.investor_id.slice(0, 8)  },
    { key: 'type', header: 'Type', render: (r: any) => r.commitment_type  },
    { key: 'next_due', header: 'Next due', render: (r: any) => (r.next_due_at ? new Date(r.next_due_at).toLocaleDateString() : '—')  },
    { key: 'days_overdue', header: 'Days overdue', render: (r: any) => String(r.days_overdue)  },
  ];

  const deliveryCols: Column<Delivery>[] = [
    { key: 'investor', header: 'Investor', render: (r: any) => r.investor_email ?? '—'  },
    { key: 'type', header: 'Type', render: (r: any) => r.commitment_type  },
    { key: 'delivered', header: 'Delivered', render: (r: any) => new Date(r.delivered_at).toLocaleString()  },
    { key: 'channel', header: 'Channel', render: (r: any) => r.delivery_channel  },
    { key: 'on_time', header: 'On-time', render: (r: any) => (r.on_time ? 'yes' : 'late')  },
    { key: 'summary', header: 'Summary', render: (r: any) => r.summary ?? '—'  },
  ];

  const perInvestorCols: Column<PerInvestor>[] = [
    { key: 'investor', header: 'Investor', render: (r: any) => r.investor_email ?? r.investor_id.slice(0, 8)  },
    { key: 'commitments', header: 'Commitments', render: (r: any) => String(r.commitments_count)  },
    { key: 'deliveries', header: 'Deliveries', render: (r: any) => String(r.deliveries_count)  },
    { key: 'on_time', header: 'On-time', render: (r: any) => String(r.on_time_count)  },
    { key: 'on_time_pct', header: 'On-time %', render: (r: any) => `${r.on_time_pct}%` },
    { key: 'overdue', header: 'Overdue', render: (r: any) => String(r.overdue_count)  },
  ];

  return (
    <main className="p-6 space-y-8">
      <header>
        <h1 className="text-2xl font-bold">Investor Comms Cadence Tracker</h1>
        <p className="text-sm text-gray-500">r1681 · promised vs actual cadence per investor</p>
      </header>

      <section className="grid grid-cols-2 md:grid-cols-4 gap-4">
        <div className="rounded-lg border p-4">
          <div className="text-xs uppercase text-gray-500">Active commitments</div>
          <div className="text-2xl font-semibold">{activeCommitments}</div>
        </div>
        <div className="rounded-lg border p-4">
          <div className="text-xs uppercase text-gray-500">Overdue</div>
          <div className="text-2xl font-semibold text-red-600">{overdue.length}</div>
        </div>
        <div className="rounded-lg border p-4">
          <div className="text-xs uppercase text-gray-500">Deliveries (all-time)</div>
          <div className="text-2xl font-semibold">{kpi.total_deliveries}</div>
        </div>
        <div className="rounded-lg border p-4">
          <div className="text-xs uppercase text-gray-500">On-time %</div>
          <div className="text-2xl font-semibold">{kpi.on_time_pct}%</div>
        </div>
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Overdue queue</h2>
        <DataTable rows={overdue} columns={overdueCols} rowKey={(r, i) => String(r.id ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">All commitments</h2>
        <DataTable rows={commitments} columns={commitmentCols} rowKey={(r, i) => String(r.id ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Per-investor cadence summary</h2>
        <DataTable rows={perInvestor} columns={perInvestorCols} rowKey={(r, i) => String(r.investor_id ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Recent deliveries</h2>
        <DataTable rows={deliveries} columns={deliveryCols} rowKey={(r, i) => String(r.id ?? i)} />
      </section>
    </main>
  );
}
