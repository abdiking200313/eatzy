import { createFakeSupabaseClient } from './fake-supabase-client';

// A `type` alias, not an `interface` — only an object type (not an
// interface) satisfies `FakeSupabaseClient`'s `T extends FakeRow` generic
// constraint, since TypeScript treats an interface as potentially extended
// elsewhere and so never assumes it's closed enough to match an index
// signature, even when (as here) it structurally would be.
type Restaurant = {
  id?: string;
  name: string;
  city: string;
  rating: number;
};

describe('FakeSupabaseClient', () => {
  describe('select', () => {
    it('returns seeded rows matching chained filters', async () => {
      const client = createFakeSupabaseClient();
      client.seed<Restaurant>('restaurants', [
        { id: '1', name: 'Pasta Place', city: 'Austin', rating: 4 },
        { id: '2', name: 'Taco Town', city: 'Austin', rating: 5 },
        { id: '3', name: 'Sushi Spot', city: 'Dallas', rating: 5 },
      ]);

      const { data, error } = await client.from('restaurants').select().eq('city', 'Austin').eq('rating', 5);

      expect(error).toBeNull();
      expect(data).toEqual([{ id: '2', name: 'Taco Town', city: 'Austin', rating: 5 }]);
    });

    it('orders and limits results', async () => {
      const client = createFakeSupabaseClient();
      client.seed<Restaurant>('restaurants', [
        { id: '1', name: 'A', city: 'Austin', rating: 3 },
        { id: '2', name: 'B', city: 'Austin', rating: 5 },
        { id: '3', name: 'C', city: 'Austin', rating: 4 },
      ]);

      const { data } = await client.from('restaurants').select().order('rating', { ascending: false }).limit(2);

      expect((data as unknown as Restaurant[]).map((row) => row.name)).toEqual(['B', 'C']);
    });

    it('single() errors when not exactly one row matches', async () => {
      const client = createFakeSupabaseClient();
      client.seed<Restaurant>('restaurants', []);

      const { data, error } = await client.from('restaurants').select().eq('id', 'missing').single();

      expect(data).toBeNull();
      expect(error).not.toBeNull();
      expect(error?.code).toBe('PGRST116');
    });

    it('maybeSingle() returns null data (no error) when nothing matches', async () => {
      const client = createFakeSupabaseClient();
      client.seed<Restaurant>('restaurants', []);

      const { data, error } = await client.from('restaurants').select().eq('id', 'missing').maybeSingle();

      expect(error).toBeNull();
      expect(data).toBeNull();
    });
  });

  describe('insert', () => {
    it('auto-assigns an id and returns the inserted row only when .select() is chained', async () => {
      const client = createFakeSupabaseClient();

      const withoutSelect = await client.from('restaurants').insert({ name: 'New Place', city: 'Austin', rating: 4 });
      expect(withoutSelect.data).toBeNull();
      expect(withoutSelect.error).toBeNull();

      const { data } = await client
        .from('restaurants')
        .insert({ name: 'Another Place', city: 'Austin', rating: 3 })
        .select();

      expect(data).toMatchObject([{ name: 'Another Place', city: 'Austin', rating: 3 }]);
      expect((data as unknown as Restaurant[])[0].id).toBeDefined();
      expect(client.getRows('restaurants')).toHaveLength(2);
    });
  });

  describe('update', () => {
    it('merges values into matching rows and returns them when .select() is chained', async () => {
      const client = createFakeSupabaseClient();
      client.seed<Restaurant>('restaurants', [{ id: '1', name: 'Old Name', city: 'Austin', rating: 3 }]);

      const { data, error } = await client
        .from('restaurants')
        .update({ rating: 5 })
        .eq('id', '1')
        .select();

      expect(error).toBeNull();
      expect(data).toEqual([{ id: '1', name: 'Old Name', city: 'Austin', rating: 5 }]);
    });

    it('rejects an update with no filter, mirroring Postgres/PostgREST safe-update', async () => {
      const client = createFakeSupabaseClient();
      client.seed<Restaurant>('restaurants', [{ id: '1', name: 'Old Name', city: 'Austin', rating: 3 }]);

      const { data, error } = await client.from('restaurants').update({ rating: 1 });

      expect(data).toBeNull();
      expect(error).not.toBeNull();
      expect(client.getRows('restaurants')[0].rating).toBe(3);
    });
  });

  describe('delete', () => {
    it('removes matching rows', async () => {
      const client = createFakeSupabaseClient();
      client.seed<Restaurant>('restaurants', [
        { id: '1', name: 'A', city: 'Austin', rating: 3 },
        { id: '2', name: 'B', city: 'Dallas', rating: 4 },
      ]);

      await client.from('restaurants').delete().eq('id', '1');

      expect(client.getRows('restaurants')).toEqual([{ id: '2', name: 'B', city: 'Dallas', rating: 4 }]);
    });
  });

  describe('queueError', () => {
    it('fails the next call against the table once, then recovers', async () => {
      const client = createFakeSupabaseClient();
      client.seed<Restaurant>('restaurants', [{ id: '1', name: 'A', city: 'Austin', rating: 3 }]);
      client.queueError('restaurants', { message: 'network down', code: 'FAKE_NETWORK' });

      const first = await client.from('restaurants').select();
      expect(first.error?.message).toBe('network down');
      expect(first.data).toBeNull();

      const second = await client.from('restaurants').select();
      expect(second.error).toBeNull();
      expect(second.data).toEqual([{ id: '1', name: 'A', city: 'Austin', rating: 3 }]);
    });
  });

  describe('rpc', () => {
    it('invokes the registered handler with the call args', async () => {
      const client = createFakeSupabaseClient();
      client.setRpcHandler<number>('add_two_numbers', (args) => (args.a as number) + (args.b as number));

      const { data, error } = await client.rpc<number>('add_two_numbers', { a: 2, b: 3 });

      expect(error).toBeNull();
      expect(data).toBe(5);
    });

    it('errors when no handler was registered for the function', async () => {
      const client = createFakeSupabaseClient();

      const { data, error } = await client.rpc('unconfigured_fn');

      expect(data).toBeNull();
      expect(error?.code).toBe('FAKE_RPC_NOT_CONFIGURED');
    });

    it('queueRpcError fails the next rpc call once', async () => {
      const client = createFakeSupabaseClient();
      client.setRpcHandler('always_ok', () => 'ok');
      client.queueRpcError('always_ok', { message: 'boom' });

      const first = await client.rpc('always_ok');
      expect(first.error?.message).toBe('boom');

      const second = await client.rpc('always_ok');
      expect(second.error).toBeNull();
      expect(second.data).toBe('ok');
    });
  });
});
