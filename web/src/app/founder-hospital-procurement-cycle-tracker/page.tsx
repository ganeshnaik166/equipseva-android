import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type CycleRow = {
  id: string;
  hospital_id: string;
  cycle_label: string;
  cycle_start_date: string;
  cycle_end_date: string | null;
  total_value_rupees: number;
  status: string;
  captured_at: string;
};

type ActiveRow = {
  id: string;
  hospital_id: string;
  cycle_label: string;
  cycle_start_date: string;
  cycle_end_date: string | null;
  total_value_rupees: number;
  status: string;
};

type PhaseRow = {
  id: string;
  cycle_id: string;
  phase: string;
  taken_at: string;
  by_email: string | null;
};

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [cyclesRes, activeRes, phasesRes] = await Promise.all([
    sb.rpc('list_cycles_r2015'),
    sb.rpc('active_cycles_r2015'),
    sb.rpc('recent_phases_r2015'),
  ]);

  const cycles: CycleRow[] = (cyclesRes.data as CycleRow[]) ?? [];
  const active: ActiveRow[] = (activeRes.data as ActiveRow[]) ?? [];
  const phases: PhaseRow[] = (phasesRes.data as PhaseRow[]) ?? [];

  const cycleCols: Column<CycleRow>[] = [
    { key: 'cycle_label', header: 'Label', render: (r: any) => String(r.cycle_label ?? '') },
    { key: 'hospital_id', header: 'Hospital', render: (r: any) => String(r.hospital_id ?? '').slice(0, 8) },
    { key: 'cycle_start_date', header: 'Start', render: (r: any) => String(r.cycle_start_date ?? '') },
    { key: 'cycle_end_date', header: 'End', render: (r: any) => String(r.cycle_end_date ?? '') },
    { key: 'total_value_rupees', header: 'Value (rupees)', render: (r: any) => String(r.total_value_rupees ?? 0) },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
    { key: 'captured_at', header: 'Captured', render: (r: any) => String(r.captured_at ?? '').slice(0, 19) },
  ];

  const activeCols: Column<ActiveRow>[] = [
    { key: 'cycle_label', header: 'Label', render: (r: any) => String(r.cycle_label ?? '') },
    { key: 'hospital_id', header: 'Hospital', render: (r: any) => String(r.hospital_id ?? '').slice(0, 8) },
    { key: 'cycle_start_date', header: 'Start', render: (r: any) => String(r.cycle_start_date ?? '') },
    { key: 'cycle_end_date', header: 'End', render: (r: any) => String(r.cycle_end_date ?? '') },
    { key: 'total_value_rupees', header: 'Value (rupees)', render: (r: any) => String(r.total_value_rupees ?? 0) },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
  ];

  const phaseCols: Column<PhaseRow>[] = [
    { key: 'phase', header: 'Phase', render: (r: any) => String(r.phase ?? '') },
    { key: 'cycle_id', header: 'Cycle', render: (r: any) => String(r.cycle_id ?? '').slice(0, 8) },
    { key: 'by_email', header: 'By', render: (r: any) => String(r.by_email ?? '') },
    { key: 'taken_at', header: 'Taken', render: (r: any) => String(r.taken_at ?? '').slice(0, 19) },
  ];

  return (
    <main style={{ padding: 24, fontFamily: 'system-ui, sans-serif' }}>
      <h1 style={{ fontSize: 22, fontWeight: 700, marginBottom: 4 }}>Hospital Procurement Cycle Tracker</h1>
      <p style={{ color: '#555', marginBottom: 24 }}>
        Track procurement cycle per hospital across phases from needs assessment through installation.
      </p>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>Active cycles</h2>
        <DataTable rows={active} columns={activeCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>All cycles</h2>
        <DataTable rows={cycles} columns={cycleCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>Recent phase log</h2>
        <DataTable rows={phases} columns={phaseCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>
    </main>
  );
}
