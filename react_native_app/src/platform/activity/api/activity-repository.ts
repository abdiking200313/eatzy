/**
 * Ports the read path of
 * `flutter_app/lib/platform/activity/data/activity_repository.dart`'s
 * `SupabaseActivityRepository.fetchActivities` (issue #373 / P4-02, for the
 * home screen's Recent Activity preview; #397 / P8-01 reuses this for the
 * full activity feed). The write path (`record`), realtime order-watching,
 * and single-order lookups are out of this issue's scope -- #397 and the
 * order-tracking issues build those when they need them.
 */
import { ErrorReporting } from '@/platform/error-reporting/error-reporter';
import { supabase } from '@/platform/supabase/client';

import { parseActivityItem, type ActivityItem } from './activity-item';

interface CustomerActivityRow {
  id: string;
  profile_id: string;
  service_id: string;
  title: string;
  subtitle: string | null;
  status: string;
  occurred_at: string;
  amount: number;
  details_route: string;
  payment_method: string | null;
  payment_status: string | null;
}

/**
 * The slice of `supabase` {@link fetchActivities} depends on, narrowed the
 * same way `merchant-role-service.ts`'s `ProfileRoleSource` narrows its own
 * Supabase dependency -- lets a test inject a fake (e.g.
 * `src/test-utils/fake-supabase-client.ts`, plus a plain `auth.getSession`
 * stub, since the fake itself has no `auth` namespace) instead of the real
 * client.
 */
export interface ActivitySource {
  auth: {
    getSession(): Promise<{ data: { session: { user: { id: string } } | null } }>;
  };
  from(table: 'customer_activity'): {
    select(columns: string): {
      eq(
        column: 'profile_id',
        value: string,
      ): {
        order(
          column: 'occurred_at',
          options: { ascending: boolean },
        ): {
          limit(count: number): PromiseLike<{ data: CustomerActivityRow[] | null; error: { message: string } | null }>;
        };
      };
    };
  };
}

/** Mirrors `SupabaseActivityRepository.fetchActivities`'s `RangeError`. */
export class InvalidActivityLimitError extends RangeError {
  constructor(limit: number) {
    super(`limit must be between 1 and 100, got ${limit}`);
  }
}

/**
 * Fetches the signed-in user's cross-vertical activity feed, most recent
 * first. Parses each row independently: one malformed row (missing/blank
 * field, an unparseable date or amount, etc.) must not blank the whole
 * activity list -- it's skipped and reported instead.
 */
export async function fetchActivities(
  client: ActivitySource = supabase as unknown as ActivitySource,
  limit = 100,
): Promise<ActivityItem[]> {
  if (limit < 1 || limit > 100) {
    throw new InvalidActivityLimitError(limit);
  }
  const {
    data: { session },
  } = await client.auth.getSession();
  const profileId = session?.user.id;
  if (!profileId) {
    throw new Error('Sign in before loading customer activity.');
  }

  const { data, error } = await client
    .from('customer_activity')
    .select('id, profile_id, service_id, title, subtitle, status, occurred_at, amount, details_route, payment_method, payment_status')
    .eq('profile_id', profileId)
    .order('occurred_at', { ascending: false })
    .limit(limit);
  if (error) throw error;

  const items: ActivityItem[] = [];
  for (const row of data ?? []) {
    try {
      items.push(parseActivityItem(row as unknown as Record<string, unknown>));
    } catch (parseError) {
      ErrorReporting.instance.reportError(
        parseError,
        parseError instanceof Error ? parseError.stack : undefined,
        'fetchActivities',
      );
    }
  }
  return items;
}
