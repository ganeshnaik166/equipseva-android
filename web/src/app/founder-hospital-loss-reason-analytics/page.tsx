import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type LossRow = {
  id: string;
  hospital_id: string;
  hospital_email: string | null;
  loss_reason: string;
  loss_value_lost_rupees: number;
  status: string;
  captured_at: string;
  notes_md: string | null;
};

type ReasonRow = {
  loss_reason: string;
  loss_count: number;
  total_value_lost_rupees: number;
};

type LessonRow = {
  id: string;
  loss_id: string;
  lesson_type: string;
  taken_at: string;
  by_email: string | null;
  notes_md: string | null;
};

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [lossesRes, reasonsRes, lessonsRes] = await Promise.all([
    sb.rpc('list_losses_r1999'),
    sb.rpc('top_loss_reasons_r1999'),
    sb.rpc('recent_lessons_r1999'),
  ]);

  const losses: LossRow[] = (lossesRes.data as LossRow[] | null) ?? [];
  const reasons: ReasonRow[] = (reasonsRes.data as ReasonRow[] | null) ?? [];
  const lessons: LessonRow[] = (lessonsRes.data as LessonRow[] | null) ?? [];

  const lossColumns: Column<LossRow>[] = [
    { key: 'captured_at', header: 'Captured', render: (r: any) => new Date(r.captured_at).toLocaleString() },
    { key: 'hospital_email', header: 'Hospital', render: (r: any) => r.hospital_email ?? r.hospital_id },
    { key: 'loss_reason', header: 'Reason', render: (r: any) => r.loss_reason },
    { key: 'loss_value_lost_rupees', header: 'Value lost (rupees)', render: (r: any) => Number(r.loss_value_lost_rupees ?? 0).toLocaleString('en-IN') },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'notes_md', header: 'Notes', render: (r: any) => r.notes_md ?? '' },
  ];

  const reasonColumns: Column<ReasonRow>[] = [
    { key: 'loss_reason', header: 'Reason', render: (r: any) => r.loss_reason },
    { key: 'loss_count', header: 'Count', render: (r: any) => Number(r.loss_count ?? 0).toLocaleString('en-IN') },
    { key: 'total_value_lost_rupees', header: 'Total value lost (rupees)', render: (r: any) => Number(r.total_value_lost_rupees ?? 0).toLocaleString('en-IN') },
  ];

  const lessonColumns: Column<LessonRow>[] = [
    { key: 'taken_at', header: 'Taken at', render: (r: any) => new Date(r.taken_at).toLocaleString() },
    { key: 'lesson_type', header: 'Lesson type', render: (r: any) => r.lesson_type },
    { key: 'loss_id', header: 'Loss id', render: (r: any) => r.loss_id },
    { key: 'by_email', header: 'By', render: (r: any) => r.by_email ?? '' },
    { key: 'notes_md', header: 'Notes', render: (r: any) => r.notes_md ?? '' },
  ];

  return (
    <main style={{ padding: 24, maxWidth: 1200, margin: '0 auto' }}>
      <h1 style={{ fontSize: 24, fontWeight: 600, marginBottom: 8 }}>
        Hospital Loss Reason Analytics
      </h1>
      <p style={{ color: '#555', marginBottom: 24 }}>
        Track why hospitals are lost, how much value walked out the door, and the
        lessons captured so the same mistake is not repeated. Round 1999.
      </p>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>
          Top loss reasons
        </h2>
        <DataTable
          rows={reasons}
          columns={reasonColumns}
          rowKey={(r: any, i: number) => String(r.loss_reason ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>
          Recent losses
        </h2>
        <DataTable
          rows={losses}
          columns={lossColumns}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>
          Recent lessons learned
        </h2>
        <DataTable
          rows={lessons}
          columns={lessonColumns}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>
    </main>
  );
}
