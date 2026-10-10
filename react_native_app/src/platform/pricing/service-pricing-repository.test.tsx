/**
 * Tests for `service-pricing-repository.ts` (issue #377 / P5-02). The Dart
 * source has no dedicated test file for `ServicePricingRepository` itself
 * (its own acceptance criterion is just "fees shown match Flutter", checked
 * indirectly through the cart controllers that consume it) -- this covers
 * the repository's own `peek`/`load` contract directly instead, since this
 * port backs it with a different cache mechanism (the shared TanStack Query
 * `queryClient`) than the Dart source's hand-rolled `QueryCache`.
 *
 * `@/platform/supabase/client` is mocked with a `FakeSupabaseClient` (see
 * that file's own top comment) built inside the mock factory, since
 * `jest.mock` factories run before this file's own imports.
 */
import { QueryClientProvider } from '@tanstack/react-query';
import { renderHook, waitFor } from '@testing-library/react-native';
import type { ReactNode } from 'react';

import { queryClient } from '@/platform/query/query-client';
import { supabase } from '@/platform/supabase/client';
import { createFakeSupabaseClient, fakeSupabaseError, fakeSupabaseOk } from '@/test-utils/fake-supabase-client';

import { ServicePricingRepository, useServicePricing } from './service-pricing-repository';

// `jest.mock` factories are hoisted above every import in this file, so a
// module-scoped helper (the `createFakeSupabaseClient` import above) isn't
// reachable from inside one -- this has to require() lazily inside the
// factory instead, same pattern as `dev-gallery.test.tsx`.
jest.mock('@/platform/supabase/client', () => ({
  // eslint-disable-next-line @typescript-eslint/no-require-imports
  supabase: require('@/test-utils/fake-supabase-client').createFakeSupabaseClient(),
}));

function Wrapper({ children }: { children: ReactNode }) {
  return <QueryClientProvider client={queryClient}>{children}</QueryClientProvider>;
}

const fakeClient = supabase as unknown as ReturnType<typeof createFakeSupabaseClient>;

beforeEach(() => {
  queryClient.clear();
});

// `queryClient` is the real app-wide singleton, not a disposable
// per-test instance -- clearing only `beforeEach` leaves the *last*
// test's cache entries (and their internal `gcTime` cleanup timers)
// behind after the suite finishes, which Jest reports as a leaked timer.
// `clear()` also cancels each entry's pending gc timeout, so this closes
// that gap.
afterAll(() => {
  queryClient.clear();
});

describe('ServicePricingRepository', () => {
  it('peek returns undefined until load has succeeded at least once', async () => {
    expect(ServicePricingRepository.peek('food')).toBeUndefined();

    fakeClient.queueTableResponse(
      'service_pricing',
      fakeSupabaseOk({ service_id: 'food', delivery_fee_cents: 499, tax_rate: 0.1 }),
    );
    const loaded = await ServicePricingRepository.load('food');

    expect(loaded).toEqual({ serviceId: 'food', deliveryFeeCents: 499, taxRate: 0.1 });
    expect(ServicePricingRepository.peek('food')).toEqual(loaded);
  });

  it('a failed load falls back to the last known value instead of throwing', async () => {
    fakeClient.queueTableResponse(
      'service_pricing',
      fakeSupabaseOk({ service_id: 'grocery', delivery_fee_cents: 350, tax_rate: 0 }),
    );
    await ServicePricingRepository.load('grocery');

    // Force a refetch past staleTime by invalidating, then fail the next call.
    await queryClient.invalidateQueries({ queryKey: ['service-pricing', 'grocery'] });
    fakeClient.queueTableResponse('service_pricing', fakeSupabaseError('network down'));

    const result = await ServicePricingRepository.load('grocery');

    expect(result).toEqual({ serviceId: 'grocery', deliveryFeeCents: 350, taxRate: 0 });
  });

  it('peek for an unconfigured service stays undefined on a failed first load', async () => {
    fakeClient.queueTableResponse('service_pricing', fakeSupabaseError('offline'));

    const result = await ServicePricingRepository.load('pharmacy');

    expect(result).toBeUndefined();
    expect(ServicePricingRepository.peek('pharmacy')).toBeUndefined();
  });

  it('useServicePricing loads and returns the same shape as peek/load', async () => {
    fakeClient.queueTableResponse(
      'service_pricing',
      fakeSupabaseOk({ service_id: 'food', delivery_fee_cents: 150, tax_rate: 0.2 }),
    );

    const { result } = await renderHook(() => useServicePricing('food'), { wrapper: Wrapper });

    await waitFor(() => expect(result.current.data).toBeDefined());

    expect(result.current.data).toEqual({ serviceId: 'food', deliveryFeeCents: 150, taxRate: 0.2 });
    // The hook populated the exact cache entry `peek` reads.
    expect(ServicePricingRepository.peek('food')).toEqual(result.current.data);
  });
});
