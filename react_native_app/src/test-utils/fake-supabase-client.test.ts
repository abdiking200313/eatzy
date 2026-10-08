import { createFakeSupabaseClient, fakeSupabaseError, fakeSupabaseOk } from './fake-supabase-client';

describe('FakeSupabaseClient', () => {
  it('returns the default empty response and records the call chain when nothing was queued', async () => {
    const client = createFakeSupabaseClient();

    const result = await client.from('profiles').select('*').eq('id', '1').single();

    expect(result).toEqual({ data: null, error: null, count: null });
    expect(client.calls).toEqual([
      {
        kind: 'table',
        name: 'profiles',
        steps: [
          { method: 'select', args: ['*'] },
          { method: 'eq', args: ['id', '1'] },
          { method: 'single', args: [] },
        ],
      },
    ]);
  });

  it('consumes queued table responses first-in, first-out, then falls back to the default', async () => {
    const client = createFakeSupabaseClient();
    client.setDefaultTableResponse('profiles', fakeSupabaseOk([]));
    client.queueTableResponse('profiles', fakeSupabaseOk([{ id: '1', name: 'Ada' }]));
    client.queueTableResponse('profiles', fakeSupabaseError('not found', { code: 'PGRST116' }));

    const first = await client.from('profiles').select('*');
    const second = await client.from('profiles').select('*');
    const third = await client.from('profiles').select('*');

    expect(first.data).toEqual([{ id: '1', name: 'Ada' }]);
    expect(second.error?.message).toBe('not found');
    expect(second.error?.code).toBe('PGRST116');
    expect(third).toEqual(fakeSupabaseOk([]));
  });

  it('fakes rpc() calls independently of table calls, with their own queue/default and recorded params', async () => {
    const client = createFakeSupabaseClient();
    client.queueRpcResponse('advance_order_status', fakeSupabaseOk({ status: 'confirmed' }));

    const result = await client.rpc('advance_order_status', { order_id: 'o1', new_status: 'confirmed' });

    expect(result).toEqual(fakeSupabaseOk({ status: 'confirmed' }));
    expect(client.calls).toEqual([
      {
        kind: 'rpc',
        name: 'advance_order_status',
        params: { order_id: 'o1', new_status: 'confirmed' },
        steps: [],
      },
    ]);
  });
});
