/// In-memory fake Supabase client for repository/data-hook tests (issue
/// #349), so later issues can write unit tests against a `.from()`/`.rpc()`
/// call without a live Supabase project or network access — the TS/RN
/// equivalent of `flutter_app/test/helpers/fake_merchant_repositories.dart`'s
/// in-memory fake repositories (and, like that file's
/// `FakeMerchantOrdersRepository`, this tries to reject what the real
/// backend would reject, not just always succeed).
///
/// `src/platform/supabase/client.ts` (issue #347) only exercises `.auth`, so
/// there's no existing `.from()`/`.rpc()` call site yet to match the shape
/// of; this instead matches the general chainable builder shape
/// `@supabase/supabase-js`/`@supabase/postgrest-js` expose today (checked
/// against `@supabase/postgrest-js@2.117.3`'s `PostgrestQueryBuilder`/
/// `PostgrestFilterBuilder`, the version pinned by this app's
/// `@supabase/supabase-js@^2.117.3`), so a future repository written against
/// the real client can swap in `createFakeSupabaseClient()` for tests with no
/// code-shape surprises.
///
/// ## Scope
///
/// Covers `.from(table)` (`select`/`insert`/`update`/`upsert`/`delete`, the
/// common filters, `order`/`limit`/`range`/`single`/`maybeSingle`) and
/// `.rpc(fn, args)`. Does **not** cover `.auth`, `.storage`, or realtime
/// channels — nothing in this app calls those through a repository yet, and
/// `.auth` in particular is already covered for tests a different way (see
/// `src/platform/session/secure-session-storage.ts`'s injectable
/// `SecureKeyValueStore`/`BulkKeyValueStore`/`SessionCipher`).
///
/// ## Realism notes worth knowing before using this
///
/// - **`insert`/`update`/`upsert`/`delete` return `data: null` unless you
///   chain `.select()`** — this matches `@supabase/supabase-js`'s own
///   default (`Prefer: return=minimal`), not a bug. Chain `.select()` after
///   them to get the affected rows back, exactly as you would against a real
///   project.
/// - **`update`/`delete` without at least one filter is rejected** with a
///   fake `error`, mirroring Postgres/PostgREST's own "UPDATE/DELETE requires
///   a WHERE clause" safety check (`update_without_key_or_filter` /
///   `delete_without_key_or_filter`), rather than silently touching every
///   row. Use any always-true filter (e.g. `.neq('id', '__none__')`, assuming
///   no row really has that id) if you genuinely mean "all rows" — same
///   workaround a real project needs.
/// - Rows are plain objects; querying is done by scanning the in-memory
///   array as each call executes, not by eagerly re-evaluating anything, so
///   seeding a table (`client.seed(...)`) *after* building a query builder
///   but *before* awaiting it still works, the same as it would with a real
///   async round-trip.
/// - An inserted row with no `id` gets one auto-assigned as `fake-id-1`,
///   `fake-id-2`, ... (per table, counting up from however many rows that
///   table has ever held) — deliberately not a real UUID. Generating one
///   would mean pulling in `expo-crypto`, which jest-expo's native-module
///   mocking can't give a real random value to (every mocked native
///   function's return value is a single fixed stub), so every row would
///   collide on the same "random" id. Simple and predictable beats
///   UUID-shaped but secretly constant.

export interface PostgrestFakeError {
  message: string;
  details: string;
  hint: string;
  code: string;
}

export interface PostgrestFakeResponse<T> {
  data: T | null;
  error: PostgrestFakeError | null;
  count: number | null;
  status: number;
  statusText: string;
}

export type FakeRow = Record<string, unknown>;

type FilterOp =
  | 'eq'
  | 'neq'
  | 'gt'
  | 'gte'
  | 'lt'
  | 'lte'
  | 'like'
  | 'ilike'
  | 'is'
  | 'in'
  | 'contains';

interface Filter {
  column: string;
  op: FilterOp;
  value: unknown;
}

type Operation = 'select' | 'insert' | 'update' | 'upsert' | 'delete';

interface ErrorInput {
  message: string;
  details?: string;
  hint?: string;
  code?: string;
}

function makeError({ message, details = '', hint = '', code = 'FAKE_ERROR' }: ErrorInput): PostgrestFakeError {
  return { message, details, hint, code };
}

function errorResponse<T>(error: PostgrestFakeError): PostgrestFakeResponse<T> {
  return { data: null, error, count: null, status: 400, statusText: 'Bad Request' };
}

function okResponse<T>(data: T | null, count: number | null = null): PostgrestFakeResponse<T> {
  return { data, error: null, count, status: 200, statusText: 'OK' };
}

function likeToRegExp(pattern: string, caseInsensitive: boolean): RegExp {
  const escaped = pattern.replace(/[.*+?^${}()|[\]\\]/g, '\\$&').replace(/%/g, '.*').replace(/_/g, '.');
  return new RegExp(`^${escaped}$`, caseInsensitive ? 'is' : 's');
}

function matchesFilter(row: FakeRow, filter: Filter): boolean {
  const actual = row[filter.column];
  switch (filter.op) {
    case 'eq':
      return actual === filter.value;
    case 'neq':
      return actual !== filter.value;
    case 'gt':
      return compareDefined(actual, filter.value, (a, b) => a > b);
    case 'gte':
      return compareDefined(actual, filter.value, (a, b) => a >= b);
    case 'lt':
      return compareDefined(actual, filter.value, (a, b) => a < b);
    case 'lte':
      return compareDefined(actual, filter.value, (a, b) => a <= b);
    case 'is':
      return actual === filter.value;
    case 'in':
      return Array.isArray(filter.value) && filter.value.includes(actual);
    case 'contains':
      return (
        Array.isArray(actual) &&
        Array.isArray(filter.value) &&
        filter.value.every((value) => (actual as unknown[]).includes(value))
      );
    case 'like':
      return typeof actual === 'string' && typeof filter.value === 'string'
        ? likeToRegExp(filter.value, false).test(actual)
        : false;
    case 'ilike':
      return typeof actual === 'string' && typeof filter.value === 'string'
        ? likeToRegExp(filter.value, true).test(actual)
        : false;
    default:
      return true;
  }
}

function compareDefined(
  a: unknown,
  b: unknown,
  compare: (a: string | number, b: string | number) => boolean,
): boolean {
  if ((typeof a !== 'number' && typeof a !== 'string') || (typeof b !== 'number' && typeof b !== 'string')) {
    return false;
  }
  return compare(a, b);
}

function applyFilters(rows: FakeRow[], filters: Filter[]): FakeRow[] {
  return rows.filter((row) => filters.every((filter) => matchesFilter(row, filter)));
}

/** One table's rows plus the errors queued against it. Not exported — reached only through `FakeSupabaseClient`. */
class FakeTable {
  rows: FakeRow[] = [];
  private readonly queuedErrors: PostgrestFakeError[] = [];
  private nextAutoId = 1;

  queueError(error: PostgrestFakeError): void {
    this.queuedErrors.push(error);
  }

  /** Pops and returns the next queued error, if any — each queued error fires exactly once. */
  consumeError(): PostgrestFakeError | null {
    return this.queuedErrors.length > 0 ? (this.queuedErrors.shift() ?? null) : null;
  }

  insertRows(values: FakeRow[]): FakeRow[] {
    const inserted = values.map((value) => {
      const row: FakeRow = { ...value };
      if (row.id === undefined) {
        row.id = `fake-id-${this.nextAutoId++}`;
      }
      return row;
    });
    this.rows.push(...inserted);
    return inserted;
  }

  updateRows(filters: Filter[], values: Partial<FakeRow>): FakeRow[] {
    const updated: FakeRow[] = [];
    this.rows = this.rows.map((row) => {
      if (!filters.every((filter) => matchesFilter(row, filter))) {
        return row;
      }
      const merged = { ...row, ...values };
      updated.push(merged);
      return merged;
    });
    return updated;
  }

  upsertRows(values: FakeRow[], conflictColumn: string): FakeRow[] {
    const result: FakeRow[] = [];
    for (const value of values) {
      const existingIndex = this.rows.findIndex((row) => row[conflictColumn] === value[conflictColumn]);
      if (existingIndex === -1) {
        result.push(...this.insertRows([value]));
        continue;
      }
      const merged = { ...this.rows[existingIndex], ...value };
      this.rows[existingIndex] = merged;
      result.push(merged);
    }
    return result;
  }

  deleteRows(filters: Filter[]): FakeRow[] {
    const removed: FakeRow[] = [];
    this.rows = this.rows.filter((row) => {
      const matches = filters.every((filter) => matchesFilter(row, filter));
      if (matches) removed.push(row);
      return !matches;
    });
    return removed;
  }
}

/**
 * The chainable query builder `FakeSupabaseClient.from()` returns. Mirrors
 * `@supabase/postgrest-js`'s `PostgrestQueryBuilder`/`PostgrestFilterBuilder`
 * closely enough to be a drop-in for code written against the real thing:
 * every modifier returns `this`, and the builder itself is a `PromiseLike` —
 * nothing executes until the caller `await`s (or `.then()`s) it, exactly like
 * the real builder's lazy HTTP request.
 */
export class FakeQueryBuilder implements PromiseLike<PostgrestFakeResponse<FakeRow[] | FakeRow>> {
  private operation: Operation = 'select';
  private readonly filters: Filter[] = [];
  private insertPayload: FakeRow[] = [];
  private updatePayload: Partial<FakeRow> = {};
  private upsertOnConflict = 'id';
  private wantsDataBack = false;
  private singleMode: 'single' | 'maybeSingle' | null = null;
  private orderColumn: { column: string; ascending: boolean } | null = null;
  private limitCount: number | null = null;
  private rangeBounds: { from: number; to: number } | null = null;

  constructor(private readonly table: FakeTable) {}

  select(_columns?: string, _options?: { count?: 'exact' | 'planned' | 'estimated'; head?: boolean }): this {
    this.wantsDataBack = true;
    return this;
  }

  insert(values: FakeRow | FakeRow[]): this {
    this.operation = 'insert';
    this.insertPayload = Array.isArray(values) ? values : [values];
    return this;
  }

  update(values: Partial<FakeRow>): this {
    this.operation = 'update';
    this.updatePayload = values;
    return this;
  }

  upsert(values: FakeRow | FakeRow[], options?: { onConflict?: string }): this {
    this.operation = 'upsert';
    this.insertPayload = Array.isArray(values) ? values : [values];
    this.upsertOnConflict = options?.onConflict ?? 'id';
    return this;
  }

  delete(): this {
    this.operation = 'delete';
    return this;
  }

  eq(column: string, value: unknown): this {
    return this.pushFilter(column, 'eq', value);
  }

  neq(column: string, value: unknown): this {
    return this.pushFilter(column, 'neq', value);
  }

  gt(column: string, value: unknown): this {
    return this.pushFilter(column, 'gt', value);
  }

  gte(column: string, value: unknown): this {
    return this.pushFilter(column, 'gte', value);
  }

  lt(column: string, value: unknown): this {
    return this.pushFilter(column, 'lt', value);
  }

  lte(column: string, value: unknown): this {
    return this.pushFilter(column, 'lte', value);
  }

  like(column: string, pattern: string): this {
    return this.pushFilter(column, 'like', pattern);
  }

  ilike(column: string, pattern: string): this {
    return this.pushFilter(column, 'ilike', pattern);
  }

  is(column: string, value: unknown): this {
    return this.pushFilter(column, 'is', value);
  }

  in(column: string, values: unknown[]): this {
    return this.pushFilter(column, 'in', values);
  }

  contains(column: string, values: unknown[]): this {
    return this.pushFilter(column, 'contains', values);
  }

  order(column: string, options?: { ascending?: boolean }): this {
    this.orderColumn = { column, ascending: options?.ascending ?? true };
    return this;
  }

  limit(count: number): this {
    this.limitCount = count;
    return this;
  }

  range(from: number, to: number): this {
    this.rangeBounds = { from, to };
    return this;
  }

  single(): this {
    this.singleMode = 'single';
    return this;
  }

  maybeSingle(): this {
    this.singleMode = 'maybeSingle';
    return this;
  }

  then<TResult1 = PostgrestFakeResponse<FakeRow[] | FakeRow>, TResult2 = never>(
    onfulfilled?:
      | ((value: PostgrestFakeResponse<FakeRow[] | FakeRow>) => TResult1 | PromiseLike<TResult1>)
      | null,
    onrejected?: ((reason: unknown) => TResult2 | PromiseLike<TResult2>) | null,
  ): PromiseLike<TResult1 | TResult2> {
    return this.execute().then(onfulfilled, onrejected);
  }

  private pushFilter(column: string, op: FilterOp, value: unknown): this {
    this.filters.push({ column, op, value });
    return this;
  }

  private async execute(): Promise<PostgrestFakeResponse<FakeRow[] | FakeRow>> {
    const queuedError = this.table.consumeError();
    if (queuedError) {
      return errorResponse(queuedError);
    }

    if ((this.operation === 'update' || this.operation === 'delete') && this.filters.length === 0) {
      return errorResponse(
        makeError({
          message: `${this.operation} requires at least one filter — refusing to ${
            this.operation === 'update' ? 'update' : 'delete'
          } every row in the table. Add a filter (e.g. .eq('id', ...)), matching PostgREST's own safe-update/-delete check.`,
          code: '21000',
        }),
      );
    }

    let rows: FakeRow[];
    let dataIncluded = this.wantsDataBack;

    switch (this.operation) {
      case 'select': {
        rows = applyFilters(this.table.rows, this.filters);
        dataIncluded = true;
        break;
      }
      case 'insert': {
        rows = this.table.insertRows(this.insertPayload);
        break;
      }
      case 'update': {
        rows = this.table.updateRows(this.filters, this.updatePayload);
        break;
      }
      case 'upsert': {
        rows = this.table.upsertRows(this.insertPayload, this.upsertOnConflict);
        break;
      }
      case 'delete': {
        rows = this.table.deleteRows(this.filters);
        break;
      }
    }

    if (this.operation === 'select') {
      if (this.orderColumn) {
        const { column, ascending } = this.orderColumn;
        rows = [...rows].sort((a, b) => {
          const left = a[column];
          const right = b[column];
          if (left === right) return 0;
          if (left === undefined || left === null) return ascending ? -1 : 1;
          if (right === undefined || right === null) return ascending ? 1 : -1;
          return (left < right ? -1 : 1) * (ascending ? 1 : -1);
        });
      }
      if (this.rangeBounds) {
        rows = rows.slice(this.rangeBounds.from, this.rangeBounds.to + 1);
      } else if (this.limitCount != null) {
        rows = rows.slice(0, this.limitCount);
      }
    }

    const count = this.operation === 'select' ? rows.length : null;

    if (!dataIncluded) {
      return okResponse<FakeRow[] | FakeRow>(null, count);
    }

    if (this.singleMode === 'single') {
      if (rows.length !== 1) {
        return errorResponse(
          makeError({
            message: `Expected exactly 1 row from .single(), got ${rows.length}.`,
            code: rows.length === 0 ? 'PGRST116' : 'PGRST117',
          }),
        );
      }
      return okResponse(rows[0], count);
    }

    if (this.singleMode === 'maybeSingle') {
      if (rows.length > 1) {
        return errorResponse(
          makeError({ message: `Expected 0 or 1 rows from .maybeSingle(), got ${rows.length}.`, code: 'PGRST117' }),
        );
      }
      return okResponse<FakeRow[] | FakeRow>(rows.length === 1 ? rows[0] : null, count);
    }

    return okResponse(rows, count);
  }
}

/** The chainable builder `FakeSupabaseClient.rpc()` returns — same lazy-`PromiseLike` shape as `FakeQueryBuilder`, minus the filter/select surface a Postgres function call doesn't have. */
export class FakeRpcBuilder<T> implements PromiseLike<PostgrestFakeResponse<T>> {
  constructor(private readonly executor: () => PostgrestFakeResponse<T>) {}

  then<TResult1 = PostgrestFakeResponse<T>, TResult2 = never>(
    onfulfilled?: ((value: PostgrestFakeResponse<T>) => TResult1 | PromiseLike<TResult1>) | null,
    onrejected?: ((reason: unknown) => TResult2 | PromiseLike<TResult2>) | null,
  ): PromiseLike<TResult1 | TResult2> {
    return Promise.resolve(this.executor()).then(onfulfilled, onrejected);
  }
}

export type RpcHandler<T = unknown> = (args: Record<string, unknown>) => T;

/**
 * Drop-in test double for the slice of `@supabase/supabase-js`'s
 * `SupabaseClient` this app's repositories are expected to use:
 * `.from(table)` and `.rpc(fn, args)`. See this file's top comment for scope
 * and the realism notes (`.select()`-gated data, the WHERE-clause safety
 * check) before relying on exact response shapes in a test.
 */
export class FakeSupabaseClient {
  private readonly tables = new Map<string, FakeTable>();
  private readonly rpcHandlers = new Map<string, RpcHandler>();
  private readonly rpcErrors = new Map<string, PostgrestFakeError[]>();

  /** Replaces `table`'s rows outright. Call again to reset between tests/cases instead of building a new client. */
  seed<T extends FakeRow>(table: string, rows: T[]): void {
    this.getOrCreateTable(table).rows = rows.map((row) => ({ ...row }));
  }

  /** The table's current rows, e.g. to assert on what a tested repository call wrote. */
  getRows<T extends FakeRow = FakeRow>(table: string): T[] {
    return this.getOrCreateTable(table).rows as T[];
  }

  /** The next call against `table` (whatever `.from(table)` operation it is) resolves with `error` instead of succeeding. Queue several to fail more than one call in a row. */
  queueError(table: string, error: ErrorInput): void {
    this.getOrCreateTable(table).queueError(makeError(error));
  }

  from(table: string): FakeQueryBuilder {
    return new FakeQueryBuilder(this.getOrCreateTable(table));
  }

  /** Registers what `.rpc(fn, ...)` should compute from its `args` — required before any test calls that `fn`, there being no real Postgres function behind this fake to fall back to. */
  setRpcHandler<T>(fn: string, handler: RpcHandler<T>): void {
    this.rpcHandlers.set(fn, handler as RpcHandler);
  }

  /** The next call to `.rpc(fn, ...)` resolves with `error` instead of invoking its handler. */
  queueRpcError(fn: string, error: ErrorInput): void {
    const queue = this.rpcErrors.get(fn) ?? [];
    queue.push(makeError(error));
    this.rpcErrors.set(fn, queue);
  }

  rpc<T = unknown>(
    fn: string,
    args: Record<string, unknown> = {},
    _options?: { head?: boolean; count?: 'exact' | 'planned' | 'estimated' },
  ): FakeRpcBuilder<T> {
    return new FakeRpcBuilder<T>(() => this.executeRpc<T>(fn, args));
  }

  private executeRpc<T>(fn: string, args: Record<string, unknown>): PostgrestFakeResponse<T> {
    const queue = this.rpcErrors.get(fn);
    const queuedError = queue && queue.length > 0 ? (queue.shift() ?? null) : null;
    if (queuedError) {
      return errorResponse(queuedError);
    }
    const handler = this.rpcHandlers.get(fn);
    if (!handler) {
      return errorResponse(
        makeError({
          message: `No fake handler registered for rpc "${fn}". Call setRpcHandler("${fn}", ...) before awaiting it.`,
          code: 'FAKE_RPC_NOT_CONFIGURED',
        }),
      );
    }
    return okResponse(handler(args) as T);
  }

  private getOrCreateTable(table: string): FakeTable {
    let existing = this.tables.get(table);
    if (!existing) {
      existing = new FakeTable();
      this.tables.set(table, existing);
    }
    return existing;
  }
}

/** Builds a fresh, empty `FakeSupabaseClient`. Prefer a fresh one per test over sharing one, the same reason `renderWithProviders` builds a fresh `QueryClient` per render — see `src/test-utils/render.tsx`. */
export function createFakeSupabaseClient(): FakeSupabaseClient {
  return new FakeSupabaseClient();
}
