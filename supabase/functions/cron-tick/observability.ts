// No Deno or Supabase dependency: exercise failure reporting without invoking jobs.
export type SlotResult = {
  slot: string;
  ok: boolean;
  rows?: number;
  error?: "slot_failed";
  error_code?: string;
  duration_ms: number;
};

export type PersistenceResult = {
  ok: boolean;
  error?: "run_persistence_failed";
  error_code?: string;
};

export type RunRecord = {
  slot: string;
  targets: string[];
  ok: boolean;
  failed_slots: string[];
  results: SlotResult[];
  duration_ms: number;
};

export type Diagnostic = {
  event: "slot_failed" | "run_persistence_failed";
  slot: string;
  error_code?: string;
};

// Preserve only SQLSTATE, PostgREST and our HTTP-wrapper code formats.
// Do not normalize input: even a valid code followed by a newline is rejected.
export function stableErrorCode(error: unknown): string | undefined {
  try {
    if (typeof error !== "object" || error === null) return undefined;
    const code = (error as { code?: unknown }).code;
    if (typeof code !== "string" || code !== code.trim()) return undefined;
    return /^(?:[0-9A-Z]{5}|PGRST[0-9]{3}|H[1-5][0-9]{2})$/.test(code)
      ? code
      : undefined;
  } catch {
    // A malformed error object must not hide the original job failure.
    return undefined;
  }
}

export async function runSlotsAndRecord(options: {
  slot: string;
  targets: string[];
  slots: Record<string, () => Promise<{ rows?: number }>>;
  persist: (record: RunRecord) => PromiseLike<{ error: unknown }>;
  invokedAt: number;
  now?: () => number;
  log?: (diagnostic: Diagnostic) => void;
}) {
  const { slot, targets, slots, persist, invokedAt } = options;
  const now = options.now ?? Date.now;
  const report = (diagnostic: Diagnostic) => {
    try {
      options.log?.(diagnostic);
    } catch {
      // Diagnostics must never interrupt later jobs or alter their outcomes.
    }
  };

  const results: SlotResult[] = [];
  for (const target of targets) {
    const start = now();
    try {
      const result = await slots[target]();
      results.push({ slot: target, ok: true, rows: result.rows, duration_ms: now() - start });
    } catch (error) {
      const error_code = stableErrorCode(error);
      results.push({ slot: target, ok: false, error: "slot_failed", error_code, duration_ms: now() - start });
      report({ event: "slot_failed", slot: target, error_code });
    }
  }

  // Persistence is diagnostic only. Its failure must neither retry a job nor
  // replace the original all-slots status. Surface it separately in the body.
  const ok = results.every((result) => result.ok);
  let persistence: PersistenceResult;
  try {
    const { error } = await persist({
      slot, targets, ok,
      failed_slots: results.filter((result) => !result.ok).map((result) => result.slot),
      results,
      duration_ms: now() - invokedAt,
    });
    if (error) throw error;
    persistence = { ok: true };
  } catch (error) {
    const error_code = stableErrorCode(error);
    persistence = { ok: false, error: "run_persistence_failed", error_code };
    report({ event: "run_persistence_failed", slot, error_code });
  }

  return { ok, slot, targets, results, persistence };
}
