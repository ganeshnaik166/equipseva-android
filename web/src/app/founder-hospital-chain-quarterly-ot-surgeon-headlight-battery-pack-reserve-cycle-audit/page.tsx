import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable } from '@/components/founder/DataTable';
import type { Column } from '@/components/founder/DataTable';

export const dynamic = 'force-dynamic';

type ReserveRow = { chain_name: string; total_packs: number; primary_packs: number; reserve_packs: number; retired_packs: number; flagged_packs: number; avg_health: number };
type CycleRow = { chain_name: string; pack_serial: string; cycles_used: number; rated_max: number; cycle_pct: number; health_percent: number };
type ReplaceRow = { chain_name: string; branch: string; pack_serial: string; surgeon_name: string; health_percent: number; current_cycle_count: number; reserve_status: string };
type QuarterRow = { audit_quarter: string; event_type: string; event_count: number; total_cycles: number; avg_health_delta: number };
type ModelRow = { pack_model: string; pack_count: number; avg_cycles: number; avg_health: number; retired_count: number };
type AuditRow = { chain_name: string; branch: string; pack_serial: string; next_audit_due: string; days_until: number; reserve_status: string };
type EventRow = { event_at: string; chain_name: string; pack_serial: string; event_type: string; cycles_added: number; health_delta: number; auditor_name: string };

export default async function Page() {
  const supabase = await getSupabaseServerClient();
  const [overview, cycle, replaceQ, quarter, model, audits, events] = await Promise.all([
    supabase.rpc('founder_r3019_reserve_overview'),
    supabase.rpc('founder_r3019_cycle_consumption'),
    supabase.rpc('founder_r3019_replacement_queue'),
    supabase.rpc('founder_r3019_quarter_event_breakdown'),
    supabase.rpc('founder_r3019_pack_model_distribution'),
    supabase.rpc('founder_r3019_upcoming_audits'),
    supabase.rpc('founder_r3019_recent_audit_events'),
  ]);

  const overviewCols: Column<ReserveRow>[] = [
    { header: 'Chain', accessor: (r) => r.chain_name },
    { header: 'Total', accessor: (r) => r.total_packs },
    { header: 'Primary', accessor: (r) => r.primary_packs },
    { header: 'Reserve', accessor: (r) => r.reserve_packs },
    { header: 'Retired', accessor: (r) => r.retired_packs },
    { header: 'Flagged', accessor: (r) => r.flagged_packs },
    { header: 'Avg Health %', accessor: (r) => r.avg_health },
  ];
  const cycleCols: Column<CycleRow>[] = [
    { header: 'Chain', accessor: (r) => r.chain_name },
    { header: 'Pack', accessor: (r) => r.pack_serial },
    { header: 'Used', accessor: (r) => r.cycles_used },
    { header: 'Max', accessor: (r) => r.rated_max },
    { header: 'Cycle %', accessor: (r) => r.cycle_pct },
    { header: 'Health %', accessor: (r) => r.health_percent },
  ];
  const replaceCols: Column<ReplaceRow>[] = [
    { header: 'Chain', accessor: (r) => r.chain_name },
    { header: 'Branch', accessor: (r) => r.branch },
    { header: 'Pack', accessor: (r) => r.pack_serial },
    { header: 'Surgeon', accessor: (r) => r.surgeon_name },
    { header: 'Health %', accessor: (r) => r.health_percent },
    { header: 'Cycles', accessor: (r) => r.current_cycle_count },
    { header: 'Status', accessor: (r) => r.reserve_status },
  ];
  const quarterCols: Column<QuarterRow>[] = [
    { header: 'Quarter', accessor: (r) => r.audit_quarter },
    { header: 'Event Type', accessor: (r) => r.event_type },
    { header: 'Count', accessor: (r) => r.event_count },
    { header: 'Cycles Added', accessor: (r) => r.total_cycles },
    { header: 'Avg Health Delta', accessor: (r) => r.avg_health_delta },
  ];
  const modelCols: Column<ModelRow>[] = [
    { header: 'Model', accessor: (r) => r.pack_model },
    { header: 'Count', accessor: (r) => r.pack_count },
    { header: 'Avg Cycles', accessor: (r) => r.avg_cycles },
    { header: 'Avg Health %', accessor: (r) => r.avg_health },
    { header: 'Retired', accessor: (r) => r.retired_count },
  ];
  const auditCols: Column<AuditRow>[] = [
    { header: 'Chain', accessor: (r) => r.chain_name },
    { header: 'Branch', accessor: (r) => r.branch },
    { header: 'Pack', accessor: (r) => r.pack_serial },
    { header: 'Due', accessor: (r) => r.next_audit_due },
    { header: 'Days Until', accessor: (r) => r.days_until },
    { header: 'Status', accessor: (r) => r.reserve_status },
  ];
  const eventCols: Column<EventRow>[] = [
    { header: 'At', accessor: (r) => r.event_at },
    { header: 'Chain', accessor: (r) => r.chain_name },
    { header: 'Pack', accessor: (r) => r.pack_serial },
    { header: 'Type', accessor: (r) => r.event_type },
    { header: 'Cycles+', accessor: (r) => r.cycles_added },
    { header: 'Health Delta', accessor: (r) => r.health_delta },
    { header: 'Auditor', accessor: (r) => r.auditor_name },
  ];

  return (
    <div className="space-y-8 p-6">
      <header>
        <h1 className="text-2xl font-bold">Hospital Chain Quarterly OT Surgeon-Headlight Battery Pack Reserve & Cycle Audit</h1>
        <p className="text-sm text-gray-600">Round r3019 — quarterly reserve posture & cycle-count health across chain OT headlight packs.</p>
      </header>

      <section>
        <h2 className="text-lg font-semibold mb-2">Reserve overview by chain</h2>
        <DataTable<ReserveRow>
          rows={(overview.data as ReserveRow[]) ?? []}
          columns={overviewCols}
          emptyMessage="No reserve overview"
          rowKey={(r, i) => String((r as { id?: string }).id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Cycle consumption (used vs. max)</h2>
        <DataTable<CycleRow>
          rows={(cycle.data as CycleRow[]) ?? []}
          columns={cycleCols}
          emptyMessage="No cycle data"
          rowKey={(r, i) => String((r as { id?: string }).id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Replacement queue (flagged packs)</h2>
        <DataTable<ReplaceRow>
          rows={(replaceQ.data as ReplaceRow[]) ?? []}
          columns={replaceCols}
          emptyMessage="No flagged packs"
          rowKey={(r, i) => String((r as { id?: string }).id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Quarter audit event breakdown</h2>
        <DataTable<QuarterRow>
          rows={(quarter.data as QuarterRow[]) ?? []}
          columns={quarterCols}
          emptyMessage="No quarter data"
          rowKey={(r, i) => String((r as { id?: string }).id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Pack model distribution</h2>
        <DataTable<ModelRow>
          rows={(model.data as ModelRow[]) ?? []}
          columns={modelCols}
          emptyMessage="No model data"
          rowKey={(r, i) => String((r as { id?: string }).id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Upcoming audits</h2>
        <DataTable<AuditRow>
          rows={(audits.data as AuditRow[]) ?? []}
          columns={auditCols}
          emptyMessage="No upcoming audits"
          rowKey={(r, i) => String((r as { id?: string }).id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Recent audit events</h2>
        <DataTable<EventRow>
          rows={(events.data as EventRow[]) ?? []}
          columns={eventCols}
          emptyMessage="No recent events"
          rowKey={(r, i) => String((r as { id?: string }).id ?? i)}
        />
      </section>
    </div>
  );
}
