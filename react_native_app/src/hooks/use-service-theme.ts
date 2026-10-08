/**
 * Per-service accent theming (issue #354 / P1-03).
 *
 * Ports the palette lookup from `ZivoServiceTheme`/`ServiceThemes` in
 * flutter_app/lib/config/service_theme.dart as a plain hook rather than a
 * provider: there is no existing "current service" context anywhere in
 * `src/` yet (screens that need a palette know their own `ServiceId` from
 * their route), so a hook that takes the service key directly is the
 * simplest port — no new context/provider is introduced for a single
 * derived value.
 *
 * Pass `slug` for a tile/store type with its own look on top of its
 * underlying service engine (e.g. Fresh Meat/Electronics on the grocery
 * engine) — mirrors `ServiceThemes.forSlug`. Omit it to theme by `service`
 * alone — mirrors `ServiceThemes.forId`.
 */

import { useMemo } from 'react';

import {
  forId,
  forSlug,
  type ServiceId,
  type ServiceThemeColors,
} from '@/theme/service-theme';

export function useServiceTheme(
  service: ServiceId,
  slug?: string,
): ServiceThemeColors {
  return useMemo(
    () => (slug ? forSlug(slug, service) : forId(service)),
    [service, slug],
  );
}
