import {
  markFirstScreenReady,
  resetStartupTimingForTests,
  STARTUP_MARK_FIRST_SCREEN,
  STARTUP_MARK_JS_START,
  STARTUP_MEASURE,
} from './startup-timing';

function fakePerf(now: number, nativeStart?: number | null) {
  return {
    now: jest.fn(() => now),
    mark: jest.fn(),
    measure: jest.fn(),
    rnStartupTiming: nativeStart === undefined ? undefined : { startTime: nativeStart },
  };
}

describe('markFirstScreenReady', () => {
  beforeEach(() => resetStartupTimingForTests());

  it('logs JS and native time to first screen and records a User Timing measure', () => {
    const perf = fakePerf(1500, 200);
    const log = jest.fn();

    const timing = markFirstScreenReady({ enabled: true, perf, log, jsStartMs: 700 });

    expect(timing).toEqual({ jsMs: 800, nativeMs: 1300 });
    expect(log).toHaveBeenCalledWith('[startup] first screen ready: 800 ms since JS start, 1300 ms since native start');
    expect(perf.mark).toHaveBeenCalledWith(STARTUP_MARK_FIRST_SCREEN);
    expect(perf.measure).toHaveBeenCalledWith(STARTUP_MEASURE, STARTUP_MARK_JS_START, STARTUP_MARK_FIRST_SCREEN);
  });

  it('omits the native figure when the runtime has no usable startup timing', () => {
    const log = jest.fn();

    expect(markFirstScreenReady({ enabled: true, perf: fakePerf(900, null), log, jsStartMs: 400 })).toEqual({ jsMs: 500, nativeMs: null });
    expect(log).toHaveBeenCalledWith('[startup] first screen ready: 500 ms since JS start');
  });

  it('measures only once per launch', () => {
    const log = jest.fn();
    markFirstScreenReady({ enabled: true, perf: fakePerf(900), log, jsStartMs: 0 });

    expect(markFirstScreenReady({ enabled: true, perf: fakePerf(5000), log, jsStartMs: 0 })).toBeNull();
    expect(log).toHaveBeenCalledTimes(1);
  });

  it('does nothing when disabled (production builds)', () => {
    const perf = fakePerf(900);
    const log = jest.fn();

    expect(markFirstScreenReady({ enabled: false, perf, log })).toBeNull();
    expect(log).not.toHaveBeenCalled();
    expect(perf.mark).not.toHaveBeenCalled();
  });

  it('never throws when the User Timing API rejects a mark', () => {
    const perf = { ...fakePerf(900), measure: jest.fn(() => { throw new Error('no such mark'); }) };
    const log = jest.fn();

    expect(() => markFirstScreenReady({ enabled: true, perf, log, jsStartMs: 100 })).not.toThrow();
    expect(log).toHaveBeenCalledTimes(1);
  });
});
