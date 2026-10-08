/// A fake `@supabase/supabase-js` client for unit/component tests (issue #349).
///
/// ## Why not type this as `SupabaseClient`
///
/// `@supabase/supabase-js`'s real `SupabaseClient`/`PostgrestQueryBuilder`
/// types are deeply generic over the project's database schema (see issue
/// #348's `src/types/database.ts`, landing separately) and expose dozens of
/// methods this app doesn't use yet. Claiming structural compatibility with
/// that full interface here would be either an unsafe cast or a lot of
/// unused surface to maintain. Instead this follows the same convention
/// `src/platform/session/secure-session-storage.ts` already uses for
/// `expo-secure-store`/`AsyncStorage` (`SecureKeyValueStore`,
/// `BulkKeyValueStore`): define the narrow shape a module actually needs
/// from its Supabase dependency, inject that, and let this fake satisfy it
/// structurally. A future data/repository module should do the same —
/// declare the `from`/`rpc` slice it needs (which this fake's `from`/`rpc`
/// signatures are written to match) rather than depending on the full
/// `SupabaseClient` type.
///
/// ## What this fakes
///
/// Supabase's query builder (`supabase.from('table').select(...).eq(...)`)
/// and `supabase.rpc('fn', params)` calls are both "thenable" chains: every
/// method returns a chainable builder that resolves to
/// `{ data, error }` only once it's awaited — no call actually hits the
/// network until that point, and no method name is special except that the
/// terminal `await`/`.then()` is what matters. This fake reproduces that
/// shape (so code under test that `await`s a query chain works unmodified),
/// while letting a test:
///
/// - queue up canned `{ data, error }` responses per table/RPC name
///   ({@link FakeSupabaseClient.queueTableResponse} /
///   {@link FakeSupabaseClient.queueRpcResponse}), consumed first-in,
///   first-out so a test can script a sequence of calls to the same table;
/// - set a fallback default response for when nothing was queued
///   ({@link FakeSupabaseClient.setDefaultTableResponse} /
///   {@link FakeSupabaseClient.setDefaultRpcResponse}) — unconfigured calls
///   resolve to `{ data: null, error: null }` otherwise, matching
///   `fake_merchant_repositories.dart`'s posture of a harmless default
///   rather than a hard failure for a query a test doesn't care about;
/// - inspect every call made ({@link FakeSupabaseClient.calls}), including
///   the table/RPC name and every chained method + its arguments, in order —
///   mirrors `FakeAdminAccountsRepository`'s recorded `searches`/`offsets`
///   arrays, generalized to an arbitrary chain instead of one repository's
///   fixed argument list.
///
/// This fake does not validate, filter, or transform data the way a real
/// Postgres/PostgREST query would (e.g. `.eq('id', 1)` does not actually
/// filter a seeded list) — it only records that the call happened and
/// returns whatever the test queued. A feature test that needs query-shaped
/// *filtering* behavior should seed the exact response that call should
/// produce, the same way `FakeMerchantOrdersRepository` seeds exact
/// in-memory state rather than re-deriving Postgres semantics.
///
/// ## Example
///
/// ```ts
/// const client = createFakeSupabaseClient();
/// client.queueTableResponse('profiles', fakeSupabaseOk([{ id: '1', name: 'Ada' }]));
///
/// const { data, error } = await client.from('profiles').select('*').eq('id', '1');
/// expect(data).toEqual([{ id: '1', name: 'Ada' }]);
/// expect(client.calls[0]).toEqual({
///   kind: 'table',
///   name: 'profiles',
///   steps: [
///     { method: 'select', args: ['*'] },
///     { method: 'eq', args: ['id', '1'] },
///   ],
/// });
/// ```

/** The error shape PostgREST (and so `@supabase/supabase-js`) returns on failure. */
export interface FakeSupabaseError {
  message: string;
  code?: string;
  details?: string | null;
  hint?: string | null;
}

/** What an awaited query/RPC chain resolves to — mirrors `PostgrestSingleResponse`/`PostgrestResponse`. */
export interface FakeSupabaseResult<T = unknown> {
  data: T | null;
  error: FakeSupabaseError | null;
  count?: number | null;
}

/** One chained method call recorded after `.from(table)` / `.rpc(name)`, e.g. `.eq('id', 1)`. */
export interface FakeSupabaseStep {
  method: string;
  args: unknown[];
}

/** One full call chain recorded by a {@link FakeSupabaseClient}. */
export type FakeSupabaseCall =
  | { kind: 'table'; name: string; steps: FakeSupabaseStep[] }
  | { kind: 'rpc'; name: string; params: Record<string, unknown> | undefined; steps: FakeSupabaseStep[] };

/** Builds a successful {@link FakeSupabaseResult}. */
export function fakeSupabaseOk<T>(data: T, count: number | null = null): FakeSupabaseResult<T> {
  return { data, error: null, count };
}

/** Builds a failing {@link FakeSupabaseResult} (`data: null`), as a real Postgrest error would. */
export function fakeSupabaseError(
  message: string,
  overrides: Partial<Omit<FakeSupabaseError, 'message'>> = {},
): FakeSupabaseResult<never> {
  return { data: null, error: { message, ...overrides } };
}

/** The slice of {@link FakeSupabaseClient} the builders below need back-channel access to. */
interface ResultSource {
  resolveTable(name: string, steps: FakeSupabaseStep[]): FakeSupabaseResult;
  resolveRpc(name: string, params: Record<string, unknown> | undefined, steps: FakeSupabaseStep[]): FakeSupabaseResult;
}

/**
 * A chainable, thenable query builder matching the shape of
 * `@supabase/supabase-js`'s `PostgrestFilterBuilder`: every call records
 * itself and returns `this`, and the chain only resolves once awaited
 * (`.then()` called) — not on any particular method.
 */
class FakeQueryBuilder<T> implements PromiseLike<FakeSupabaseResult<T>> {
  private readonly steps: FakeSupabaseStep[] = [];

  constructor(
    private readonly table: string,
    private readonly source: ResultSource,
  ) {}

  private chain(method: string, args: unknown[]): this {
    this.steps.push({ method, args });
    return this;
  }

  select(...args: unknown[]): this {
    return this.chain('select', args);
  }
  insert(...args: unknown[]): this {
    return this.chain('insert', args);
  }
  upsert(...args: unknown[]): this {
    return this.chain('upsert', args);
  }
  update(...args: unknown[]): this {
    return this.chain('update', args);
  }
  delete(...args: unknown[]): this {
    return this.chain('delete', args);
  }
  eq(...args: unknown[]): this {
    return this.chain('eq', args);
  }
  neq(...args: unknown[]): this {
    return this.chain('neq', args);
  }
  gt(...args: unknown[]): this {
    return this.chain('gt', args);
  }
  gte(...args: unknown[]): this {
    return this.chain('gte', args);
  }
  lt(...args: unknown[]): this {
    return this.chain('lt', args);
  }
  lte(...args: unknown[]): this {
    return this.chain('lte', args);
  }
  like(...args: unknown[]): this {
    return this.chain('like', args);
  }
  ilike(...args: unknown[]): this {
    return this.chain('ilike', args);
  }
  is(...args: unknown[]): this {
    return this.chain('is', args);
  }
  in(...args: unknown[]): this {
    return this.chain('in', args);
  }
  contains(...args: unknown[]): this {
    return this.chain('contains', args);
  }
  match(...args: unknown[]): this {
    return this.chain('match', args);
  }
  not(...args: unknown[]): this {
    return this.chain('not', args);
  }
  or(...args: unknown[]): this {
    return this.chain('or', args);
  }
  order(...args: unknown[]): this {
    return this.chain('order', args);
  }
  limit(...args: unknown[]): this {
    return this.chain('limit', args);
  }
  range(...args: unknown[]): this {
    return this.chain('range', args);
  }
  single(...args: unknown[]): this {
    return this.chain('single', args);
  }
  maybeSingle(...args: unknown[]): this {
    return this.chain('maybeSingle', args);
  }

  then<TResult1 = FakeSupabaseResult<T>, TResult2 = never>(
    onfulfilled?: ((value: FakeSupabaseResult<T>) => TResult1 | PromiseLike<TResult1>) | null,
    onrejected?: ((reason: unknown) => TResult2 | PromiseLike<TResult2>) | null,
  ): PromiseLike<TResult1 | TResult2> {
    const result = this.source.resolveTable(this.table, this.steps) as FakeSupabaseResult<T>;
    return Promise.resolve(result).then(onfulfilled, onrejected);
  }
}

/** As {@link FakeQueryBuilder}, but for `supabase.rpc(name, params)`. */
class FakeRpcCall<T> implements PromiseLike<FakeSupabaseResult<T>> {
  private readonly steps: FakeSupabaseStep[] = [];

  constructor(
    private readonly name: string,
    private readonly params: Record<string, unknown> | undefined,
    private readonly source: ResultSource,
  ) {}

  // `.rpc(...)` returns the same kind of filter builder as `.from(...)`, so
  // calling e.g. `.select()` on the result (uncommon, but valid) chains too.
  select(...args: unknown[]): this {
    this.steps.push({ method: 'select', args });
    return this;
  }
  single(...args: unknown[]): this {
    this.steps.push({ method: 'single', args });
    return this;
  }
  maybeSingle(...args: unknown[]): this {
    this.steps.push({ method: 'maybeSingle', args });
    return this;
  }

  then<TResult1 = FakeSupabaseResult<T>, TResult2 = never>(
    onfulfilled?: ((value: FakeSupabaseResult<T>) => TResult1 | PromiseLike<TResult1>) | null,
    onrejected?: ((reason: unknown) => TResult2 | PromiseLike<TResult2>) | null,
  ): PromiseLike<TResult1 | TResult2> {
    const result = this.source.resolveRpc(this.name, this.params, this.steps) as FakeSupabaseResult<T>;
    return Promise.resolve(result).then(onfulfilled, onrejected);
  }
}

/**
 * A fake `@supabase/supabase-js` client double. Build one with
 * {@link createFakeSupabaseClient}, queue responses, pass it to the code
 * under test (as whatever narrow dependency type that code declares — see
 * this file's top comment), then assert on {@link FakeSupabaseClient.calls}.
 */
export class FakeSupabaseClient implements ResultSource {
  /** Every `.from()`/`.rpc()` chain resolved so far, in call order. */
  readonly calls: FakeSupabaseCall[] = [];

  private readonly tableQueues = new Map<string, FakeSupabaseResult[]>();
  private readonly tableDefaults = new Map<string, FakeSupabaseResult>();
  private readonly rpcQueues = new Map<string, FakeSupabaseResult[]>();
  private readonly rpcDefaults = new Map<string, FakeSupabaseResult>();

  from<T = unknown>(table: string): FakeQueryBuilder<T> {
    return new FakeQueryBuilder<T>(table, this);
  }

  rpc<T = unknown>(name: string, params?: Record<string, unknown>): FakeRpcCall<T> {
    return new FakeRpcCall<T>(name, params, this);
  }

  /** Queues `response` to be returned by the next unconsumed `.from(table)` chain, FIFO. */
  queueTableResponse(table: string, response: FakeSupabaseResult): void {
    const queue = this.tableQueues.get(table) ?? [];
    queue.push(response);
    this.tableQueues.set(table, queue);
  }

  /** Sets the response returned by `.from(table)` once its queue (if any) is exhausted. */
  setDefaultTableResponse(table: string, response: FakeSupabaseResult): void {
    this.tableDefaults.set(table, response);
  }

  /** Queues `response` to be returned by the next unconsumed `.rpc(name)` call, FIFO. */
  queueRpcResponse(name: string, response: FakeSupabaseResult): void {
    const queue = this.rpcQueues.get(name) ?? [];
    queue.push(response);
    this.rpcQueues.set(name, queue);
  }

  /** Sets the response returned by `.rpc(name)` once its queue (if any) is exhausted. */
  setDefaultRpcResponse(name: string, response: FakeSupabaseResult): void {
    this.rpcDefaults.set(name, response);
  }

  /** @internal called by {@link FakeQueryBuilder}; not part of this fake's public test API. */
  resolveTable(name: string, steps: FakeSupabaseStep[]): FakeSupabaseResult {
    this.calls.push({ kind: 'table', name, steps });
    const queue = this.tableQueues.get(name);
    if (queue && queue.length > 0) {
      return queue.shift()!;
    }
    return this.tableDefaults.get(name) ?? fakeSupabaseOk(null);
  }

  /** @internal called by {@link FakeRpcCall}; not part of this fake's public test API. */
  resolveRpc(name: string, params: Record<string, unknown> | undefined, steps: FakeSupabaseStep[]): FakeSupabaseResult {
    this.calls.push({ kind: 'rpc', name, params, steps });
    const queue = this.rpcQueues.get(name);
    if (queue && queue.length > 0) {
      return queue.shift()!;
    }
    return this.rpcDefaults.get(name) ?? fakeSupabaseOk(null);
  }
}

/** Builds a fresh {@link FakeSupabaseClient} with no queued responses or recorded calls. */
export function createFakeSupabaseClient(): FakeSupabaseClient {
  return new FakeSupabaseClient();
}
