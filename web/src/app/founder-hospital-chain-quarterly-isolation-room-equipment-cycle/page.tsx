import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Kpi = {
  total_rooms: number;
  active_rooms: number;
  suspended_rooms: number;
  total_cycles: number;
  pass_rate_pct: number;
  total_spend_rupees: number;
};

type Room = {
  id: string;
  chain_code: string;
  hospital_name: string;
  city: string;
  room_code: string;
  room_class: string;
  bed_count: number;
  hepa_pass_rate_pct: number;
  status: string;
  quarter_tag: string;
  last_audit_date: string;
};

type Cycle = {
  id: string;
  cycle_code: string;
  hospital_name: string;
  room_code: string;
  equipment_kind: string;
  decontam_method: string;
  outcome: string;
  cycle_minutes: number;
  spore_log_kill: number;
  technician: string;
  cost_rupees: number;
  cycle_started: string;
};

type ChainRollup = {
  chain_code: string;
  rooms: number;
  cycles: number;
  pass_rate_pct: number;
  avg_log_kill: number;
  total_spend_rupees: number;
};

type EquipMix = {
  equipment_kind: string;
  cycles: number;
  pass_cycles: number;
  fail_cycles: number;
  avg_minutes: number;
  avg_cost: number;
};

type Failure = {
  cycle_code: string;
  hospital_name: string;
  room_code: string;
  equipment_kind: string;
  outcome: string;
  spore_log_kill: number;
  notes: string | null;
  cycle_started: string;
};

type QuarterBreak = {
  quarter_tag: string;
  rooms: number;
  suspended: number;
  avg_hepa_pass: number;
};

type MethodOutcome = {
  decontam_method: string;
  cycles: number;
  pass_rate_pct: number;
  avg_log_kill: number;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [kpisRes, roomsRes, cyclesRes, chainRes, equipRes, failRes, quarterRes, methodRes] = await Promise.all([
    supabase.rpc('founder_r2795_kpis'),
    supabase.rpc('founder_r2795_rooms'),
    supabase.rpc('founder_r2795_cycles'),
    supabase.rpc('founder_r2795_chain_rollup'),
    supabase.rpc('founder_r2795_equipment_mix'),
    supabase.rpc('founder_r2795_failures'),
    supabase.rpc('founder_r2795_quarter_breakdown'),
    supabase.rpc('founder_r2795_method_outcomes'),
  ]);

  const kpi: Kpi = (kpisRes.data?.[0] as Kpi) ?? {
    total_rooms: 0,
    active_rooms: 0,
    suspended_rooms: 0,
    total_cycles: 0,
    pass_rate_pct: 0,
    total_spend_rupees: 0,
  };
  const rooms: Room[] = (roomsRes.data as Room[]) ?? [];
  const cycles: Cycle[] = (cyclesRes.data as Cycle[]) ?? [];
  const chains: ChainRollup[] = (chainRes.data as ChainRollup[]) ?? [];
  const equip: EquipMix[] = (equipRes.data as EquipMix[]) ?? [];
  const failures: Failure[] = (failRes.data as Failure[]) ?? [];
  const quarters: QuarterBreak[] = (quarterRes.data as QuarterBreak[]) ?? [];
  const methods: MethodOutcome[] = (methodRes.data as MethodOutcome[]) ?? [];

  const inr = (n: number) =>
    new Intl.NumberFormat('en-IN', { style: 'currency', currency: 'INR', maximumFractionDigits: 0 }).format(n || 0);

  return (
    <div className="mx-auto max-w-7xl space-y-8 p-6">
      <header className="space-y-1">
        <h1 className="text-2xl font-bold">Hospital Chain Quarterly Isolation Room Equipment Cycle</h1>
        <p className="text-sm text-gray-600">
          Chain × isolation room × biohazard equipment × decontam method × quarterly cycle &amp;
          outcome rollup. Spore log-kill targets &gt;=6.0 for pass.
        </p>
      </header>

      <section className="grid grid-cols-2 gap-4 md:grid-cols-3 lg:grid-cols-6">
        <KpiCard label="Rooms" value={String(kpi.total_rooms)} />
        <KpiCard label="Active" value={String(kpi.active_rooms)} />
        <KpiCard label="Suspended" value={String(kpi.suspended_rooms)} />
        <KpiCard label="Cycles" value={String(kpi.total_cycles)} />
        <KpiCard label="Pass rate" value={`${kpi.pass_rate_pct}%`} />
        <KpiCard label="Spend" value={inr(kpi.total_spend_rupees)} />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-semibold">Chain rollup</h2>
        <DataTable
          rows={chains}
          columns={[
            { key: 'chain_code', header: 'Chain', render: (r: ChainRollup) => r.chain_code },
            { key: 'rooms', header: 'Rooms', render: (r: ChainRollup) => r.rooms },
            { key: 'cycles', header: 'Cycles', render: (r: ChainRollup) => r.cycles },
            { key: 'pass_rate_pct', header: 'Pass %', render: (r: ChainRollup) => `${r.pass_rate_pct}%` },
            { key: 'avg_log_kill', header: 'Avg log-kill', render: (r: ChainRollup) => r.avg_log_kill },
            { key: 'spend', header: 'Spend', render: (r: ChainRollup) => inr(r.total_spend_rupees) },
          ]}
          emptyMessage="No data"
          rowKey={(r: ChainRollup, i: number) => String(r.chain_code ?? i)}
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-semibold">Isolation rooms</h2>
        <DataTable
          rows={rooms}
          columns={[
            { key: 'chain_code', header: 'Chain', render: (r: Room) => r.chain_code },
            { key: 'hospital_name', header: 'Hospital', render: (r: Room) => r.hospital_name },
            { key: 'city', header: 'City', render: (r: Room) => r.city },
            { key: 'room_code', header: 'Room', render: (r: Room) => r.room_code },
            { key: 'room_class', header: 'Class', render: (r: Room) => r.room_class },
            { key: 'bed_count', header: 'Beds', render: (r: Room) => r.bed_count },
            { key: 'hepa_pass_rate_pct', header: 'HEPA %', render: (r: Room) => `${r.hepa_pass_rate_pct}%` },
            { key: 'status', header: 'Status', render: (r: Room) => r.status },
            { key: 'quarter_tag', header: 'Quarter', render: (r: Room) => r.quarter_tag },
            { key: 'last_audit_date', header: 'Last audit', render: (r: Room) => r.last_audit_date },
          ]}
          emptyMessage="No data"
          rowKey={(r: Room, i: number) => String(r.id ?? i)}
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-semibold">Decontam cycles</h2>
        <DataTable
          rows={cycles}
          columns={[
            { key: 'cycle_code', header: 'Cycle', render: (r: Cycle) => r.cycle_code },
            { key: 'hospital_name', header: 'Hospital', render: (r: Cycle) => r.hospital_name },
            { key: 'room_code', header: 'Room', render: (r: Cycle) => r.room_code },
            { key: 'equipment_kind', header: 'Equipment', render: (r: Cycle) => r.equipment_kind },
            { key: 'decontam_method', header: 'Method', render: (r: Cycle) => r.decontam_method },
            { key: 'outcome', header: 'Outcome', render: (r: Cycle) => r.outcome },
            { key: 'cycle_minutes', header: 'Min', render: (r: Cycle) => r.cycle_minutes },
            { key: 'spore_log_kill', header: 'Log-kill', render: (r: Cycle) => r.spore_log_kill },
            { key: 'technician', header: 'Tech', render: (r: Cycle) => r.technician },
            { key: 'cost_rupees', header: 'Cost', render: (r: Cycle) => inr(r.cost_rupees) },
            { key: 'cycle_started', header: 'Started', render: (r: Cycle) => new Date(r.cycle_started).toLocaleString('en-IN') },
          ]}
          emptyMessage="No data"
          rowKey={(r: Cycle, i: number) => String(r.id ?? i)}
        />
      </section>

      <section className="grid gap-6 md:grid-cols-2">
        <div className="space-y-3">
          <h2 className="text-lg font-semibold">Equipment mix</h2>
          <DataTable
            rows={equip}
            columns={[
              { key: 'equipment_kind', header: 'Equipment', render: (r: EquipMix) => r.equipment_kind },
              { key: 'cycles', header: 'Cycles', render: (r: EquipMix) => r.cycles },
              { key: 'pass_cycles', header: 'Pass', render: (r: EquipMix) => r.pass_cycles },
              { key: 'fail_cycles', header: 'Fail', render: (r: EquipMix) => r.fail_cycles },
              { key: 'avg_minutes', header: 'Avg min', render: (r: EquipMix) => r.avg_minutes },
              { key: 'avg_cost', header: 'Avg cost', render: (r: EquipMix) => inr(r.avg_cost) },
            ]}
            emptyMessage="No data"
            rowKey={(r: EquipMix, i: number) => String(r.equipment_kind ?? i)}
          />
        </div>
        <div className="space-y-3">
          <h2 className="text-lg font-semibold">Method outcomes</h2>
          <DataTable
            rows={methods}
            columns={[
              { key: 'decontam_method', header: 'Method', render: (r: MethodOutcome) => r.decontam_method },
              { key: 'cycles', header: 'Cycles', render: (r: MethodOutcome) => r.cycles },
              { key: 'pass_rate_pct', header: 'Pass %', render: (r: MethodOutcome) => `${r.pass_rate_pct}%` },
              { key: 'avg_log_kill', header: 'Avg log-kill', render: (r: MethodOutcome) => r.avg_log_kill },
            ]}
            emptyMessage="No data"
            rowKey={(r: MethodOutcome, i: number) => String(r.decontam_method ?? i)}
          />
        </div>
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-semibold">Quarter breakdown</h2>
        <DataTable
          rows={quarters}
          columns={[
            { key: 'quarter_tag', header: 'Quarter', render: (r: QuarterBreak) => r.quarter_tag },
            { key: 'rooms', header: 'Rooms', render: (r: QuarterBreak) => r.rooms },
            { key: 'suspended', header: 'Suspended', render: (r: QuarterBreak) => r.suspended },
            { key: 'avg_hepa_pass', header: 'Avg HEPA %', render: (r: QuarterBreak) => `${r.avg_hepa_pass}%` },
          ]}
          emptyMessage="No data"
          rowKey={(r: QuarterBreak, i: number) => String(r.quarter_tag ?? i)}
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-semibold">Failures &amp; reruns</h2>
        <p className="text-sm text-gray-600">
          Cycles where outcome is fail, partial, or rerun_required. Anything with log-kill &lt; 6.0 needs review.
        </p>
        <DataTable
          rows={failures}
          columns={[
            { key: 'cycle_code', header: 'Cycle', render: (r: Failure) => r.cycle_code },
            { key: 'hospital_name', header: 'Hospital', render: (r: Failure) => r.hospital_name },
            { key: 'room_code', header: 'Room', render: (r: Failure) => r.room_code },
            { key: 'equipment_kind', header: 'Equipment', render: (r: Failure) => r.equipment_kind },
            { key: 'outcome', header: 'Outcome', render: (r: Failure) => r.outcome },
            { key: 'spore_log_kill', header: 'Log-kill', render: (r: Failure) => r.spore_log_kill },
            { key: 'notes', header: 'Notes', render: (r: Failure) => r.notes ?? '' },
            { key: 'cycle_started', header: 'Started', render: (r: Failure) => new Date(r.cycle_started).toLocaleString('en-IN') },
          ]}
          emptyMessage="No data"
          rowKey={(r: Failure, i: number) => String(r.cycle_code ?? i)}
        />
      </section>
    </div>
  );
}

function KpiCard({ label, value }: { label: string; value: string }) {
  return (
    <div className="rounded-xl border border-gray-200 bg-white p-4 shadow-sm">
      <div className="text-xs uppercase tracking-wide text-gray-500">{label}</div>
      <div className="mt-1 text-xl font-semibold text-gray-900">{value}</div>
    </div>
  );
}
