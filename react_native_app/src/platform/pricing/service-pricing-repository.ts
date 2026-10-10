/**
 * Ports `flutter_app/lib/services/shared/data/service_pricing_repository.dart`
 * and `.../models/service_pricing.dart` (issue #377 / P5-02): the single
 * source of truth for each vertical's delivery fee and tax rate, read from
 * `public.service_pricing` instead of a hardcoded per-vertical constant.
 *
 * The Dart source backs `peek`/`load` with its own hand-rolled
 * `QueryCache`/`CachedQuery` (stale-while-revalidate, 1-hour max age).
 * react_native_app already has an app-wide caching layer for exactly this
 * shape -- the shared TanStack Query `queryClient` (issue #347,
 * `src/platform/query/query-client.ts`) -- so this reuses that instead of
 * porting a second cache mechanism: `peek` reads the client's cache
 * synchronously (never touches the network, mirroring the Dart contract),
 * and `load`/`useServicePricing` go through `queryClient.fetchQuery`/
 * `useQuery` respectively. Both read and write the exact same cache entry
 * (same `queryKey`), so a cart store's `peek()` sees whatever a screen's
 * `useServicePricing()` already loaded, and vice versa.
 */
import { useQuery } from '@tanstack/react-query';

import { queryClient } from '@/platform/query/query-client';
import { supabase } from '@/platform/supabase/client';
import type { ServiceId } from '@/theme/service-theme';

export interface ServicePricing {
  /** `'food' | 'grocery' | 'pharmacy'` -- matches `service_pricing.service_id`. */
  serviceId: Exclude<ServiceId, 'unknown'>;
  /** In integer cents. */
  deliveryFeeCents: number;
  /** A fraction (0.10 = 10%), not a percentage. `0` for a vertical that charges no tax. */
  taxRate: number;
}

interface ServicePricingRow {
  service_id: string;
  delivery_fee_cents: number;
  tax_rate: number;
}

/** Mirrors the Dart repository's 1-hour `_maxAge`: pricing changes rarely enough that this is an acceptable staleness window within a session. */
const MAX_AGE_MS = 60 * 60 * 1000;

function queryKey(serviceId: Exclude<ServiceId, 'unknown'>) {
  return ['service-pricing', serviceId] as const;
}

async function fetchServicePricing(serviceId: Exclude<ServiceId, 'unknown'>): Promise<ServicePricing> {
  const { data, error } = await supabase
    .from('service_pricing')
    .select('service_id, delivery_fee_cents, tax_rate')
    .eq('service_id', serviceId)
    .single<ServicePricingRow>();
  if (error) throw error;
  return {
    serviceId: data.service_id as Exclude<ServiceId, 'unknown'>,
    deliveryFeeCents: Math.round(data.delivery_fee_cents),
    taxRate: Number(data.tax_rate),
  };
}

export const ServicePricingRepository = {
  /**
   * The most recently loaded pricing for `serviceId`, or `undefined` if
   * nothing has loaded successfully yet. Never touches the network --
   * callers outside a React render (e.g. a Zustand cart store) use this to
   * read whatever a screen's `useServicePricing` (or an earlier `load`)
   * already populated.
   */
  peek(serviceId: Exclude<ServiceId, 'unknown'>): ServicePricing | undefined {
    return queryClient.getQueryData(queryKey(serviceId));
  },

  /**
   * Loads (or refreshes, once stale) pricing for `serviceId`. Resolves to
   * the freshly loaded value, or the last known value if this attempt
   * failed, or `undefined` if nothing has ever loaded successfully.
   * Never throws -- mirrors the Dart repository's `load` contract.
   */
  async load(serviceId: Exclude<ServiceId, 'unknown'>): Promise<ServicePricing | undefined> {
    try {
      return await queryClient.fetchQuery({
        queryKey: queryKey(serviceId),
        queryFn: () => fetchServicePricing(serviceId),
        staleTime: MAX_AGE_MS,
        // Single attempt, like the Dart `CachedQuery.refresh()` this mirrors
        // -- not the app-wide `queryClient` default of 2 retries with
        // backoff. A failure falls back to `peek()` immediately below
        // rather than spending several seconds retrying first.
        retry: false,
      });
    } catch {
      return this.peek(serviceId);
    }
  },
};

/**
 * Ports this issue's own `useServicePricing(service)` task: the hook a
 * cart/checkout screen uses to show (and keep fresh) the delivery-fee/tax
 * estimate for one vertical.
 */
export function useServicePricing(serviceId: Exclude<ServiceId, 'unknown'>) {
  return useQuery({
    queryKey: queryKey(serviceId),
    queryFn: () => fetchServicePricing(serviceId),
    staleTime: MAX_AGE_MS,
    retry: false,
  });
}
