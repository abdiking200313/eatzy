/**
 * Lightweight, dev-only cold-start measurement (issue #417 / P10-05).
 *
 * Measures "app start -> first screen ready", where *ready* is the moment
 * the root layout's startup gate opens (`useStartupGate().status ===
 * 'ready'`) -- the point at which `AnimatedSplashOverlay` mounts and
 * dismisses the native splash, i.e. the user first sees a real screen.
 *
 * Two figures are reported, both on `performance.now()`'s clock:
 *  - **JS**: from this module's evaluation (it is imported first by the root
 *    `_layout.tsx`, so this is effectively "JS bundle started running") to
 *    ready. Always available.
 *  - **native**: from React Native's own `performance.rnStartupTiming
 *    .startTime` (native app start) to ready, when the runtime exposes a
 *    usable value; omitted otherwise (web, older runtimes).
 *
 * Also records a `performance.mark`/`measure` pair (when the User Timing API
 * exists) so the span shows up in React Native DevTools' Performance panel.
 *
 * Production builds do nothing: {@link markFirstScreenReady} is gated on
 * `__DEV__` by default, never logs or reports to Crashlytics, and only ever
 * runs once per launch.
 */

type PerformanceLike = {
  now(): number;
  mark?: (name: string, options?: { startTime?: number }) => unknown;
  measure?: (name: string, startMark?: string, endMark?: string) => unknown;
  rnStartupTiming?: { startTime?: number | null };
};

export const STARTUP_MARK_JS_START = 'zivo:startup:js-start';
export const STARTUP_MARK_FIRST_SCREEN = 'zivo:startup:first-screen-ready';
export const STARTUP_MEASURE = 'zivo:startup:time-to-first-screen';

export type StartupTiming = {
  /** ms from JS bundle start (this module's evaluation) to first screen ready. */
  jsMs: number;
  /** ms from native app start to first screen ready, when the runtime exposes it. */
  nativeMs: number | null;
};

function currentPerformance(): PerformanceLike | undefined {
  return typeof performance === 'undefined' ? undefined : (performance as unknown as PerformanceLike);
}

const jsStart = currentPerformance()?.now() ?? 0;
safely(() => currentPerformance()?.mark?.(STARTUP_MARK_JS_START));

let reported = false;

export type MarkFirstScreenReadyOptions = {
  /** Defaults to `__DEV__` (and off under Jest); production builds skip the measurement entirely. */
  enabled?: boolean;
  /** Test seam: defaults to the global `performance`. */
  perf?: PerformanceLike;
  /** Test seam: defaults to `console.log`. */
  log?: (message: string) => void;
  /** Test seam: defaults to this module's own load time. */
  jsStartMs?: number;
};

/**
 * Records and (in dev) logs the time to first screen. Idempotent: only the
 * first call per launch measures anything; later calls return `null`.
 */
export function markFirstScreenReady({
  enabled = isDevBuild(),
  perf = currentPerformance(),
  log = console.log,
  jsStartMs = jsStart,
}: MarkFirstScreenReadyOptions = {}): StartupTiming | null {
  if (!enabled || reported || perf == null) return null;
  reported = true;

  const now = perf.now();
  const jsMs = now - jsStartMs;
  const nativeStart = safely(() => perf.rnStartupTiming?.startTime);
  const nativeMs =
    typeof nativeStart === 'number' && Number.isFinite(nativeStart) && nativeStart > 0 && nativeStart <= now ? now - nativeStart : null;

  safely(() => {
    perf.mark?.(STARTUP_MARK_FIRST_SCREEN);
    perf.measure?.(STARTUP_MEASURE, STARTUP_MARK_JS_START, STARTUP_MARK_FIRST_SCREEN);
  });

  const nativePart = nativeMs == null ? '' : `, ${Math.round(nativeMs)} ms since native start`;
  log(`[startup] first screen ready: ${Math.round(jsMs)} ms since JS start${nativePart}`);
  return { jsMs, nativeMs };
}

/** `__DEV__`, minus Jest runs -- keeps the log line out of every route-tree test's output. */
function isDevBuild(): boolean {
  return typeof __DEV__ !== 'undefined' && __DEV__ && process.env.NODE_ENV !== 'test';
}

/** Test-only: lets a test measure a fresh "launch" again. */
export function resetStartupTimingForTests(): void {
  reported = false;
}

function safely<T>(run: () => T): T | undefined {
  try {
    return run();
  } catch {
    // Instrumentation must never break startup (e.g. a missing mark name).
    return undefined;
  }
}
