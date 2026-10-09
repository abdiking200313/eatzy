import { formatOrderDateTime, formatShortDate } from './date-format';

describe('formatOrderDateTime', () => {
  it('formats a local date/time as "MMM d, yyyy · h:mm a"', () => {
    const date = new Date(2024, 0, 5, 15, 45);
    expect(formatOrderDateTime(date)).toBe('Jan 5, 2024 · 3:45 PM');
  });

  it('pads single-digit minutes but not hours', () => {
    const date = new Date(2024, 11, 31, 9, 5);
    expect(formatOrderDateTime(date)).toBe('Dec 31, 2024 · 9:05 AM');
  });
});

describe('formatShortDate', () => {
  it('formats a local date as "MMM d, yyyy"', () => {
    expect(formatShortDate(new Date(2007, 5, 15))).toBe('Jun 15, 2007');
  });
});
