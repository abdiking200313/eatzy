/**
 * Ports `flutter_app/lib/features/addresses/models/delivery_address.dart`
 * (issue #545).
 *
 * A saved delivery address, mapped from a `public.delivery_addresses` row --
 * the shared platform table every vertical's order-placement RPC can
 * optionally resolve a fulfilment snapshot from. This is a *platform* model,
 * distinct from the per-checkout delivery details each vertical's checkout
 * builds from its own text fields (`src/platform/orders/delivery-details.ts`):
 * this is the one persisted, reusable-across-verticals record of the same
 * recipient/phone/street/district/city baseline.
 */

export interface DeliveryAddress {
  id: string;
  /** e.g. "Home" / "Work". `undefined` when the address was saved without one. */
  label?: string;
  recipientName: string;
  phone: string;
  street: string;
  district: string;
  city: string;
  isDefault: boolean;
  createdAt: Date;
  updatedAt: Date;
}

/**
 * The fields a caller supplies to create or update a {@link DeliveryAddress}.
 * `id`/`profile_id`/`created_at`/`updated_at` are server-managed and never
 * part of this input. Mirrors Dart's `NewDeliveryAddress`.
 */
export interface NewDeliveryAddress {
  label?: string | null;
  recipientName: string;
  phone: string;
  street: string;
  district: string;
  city: string;
  /** Defaults to `false`, as in Dart. */
  isDefault?: boolean;
}

/** The writable `delivery_addresses` columns {@link newDeliveryAddressToRow} produces. */
export interface DeliveryAddressWriteRow {
  label: string | null;
  recipient_name: string;
  phone: string;
  street: string;
  district: string;
  city: string;
  is_default: boolean;
}

/**
 * Thrown by {@link parseDeliveryAddress} for a malformed row -- the port of
 * Dart's `FormatException`. The repository skips (and reports) only this
 * error type per row, as Flutter's `on FormatException` does.
 */
export class DeliveryAddressFormatError extends Error {
  constructor(message: string) {
    super(message);
    this.name = 'DeliveryAddressFormatError';
  }
}

function requiredString(row: Record<string, unknown>, key: string): string {
  const value = row[key]?.toString().trim();
  if (!value) {
    throw new DeliveryAddressFormatError(`Missing required delivery address field: ${key}`);
  }
  return value;
}

function optionalString(row: Record<string, unknown>, key: string): string | undefined {
  const value = row[key]?.toString().trim();
  return value ? value : undefined;
}

function requiredDate(row: Record<string, unknown>, key: string, message: string): Date {
  const date = new Date(requiredString(row, key));
  if (Number.isNaN(date.getTime())) {
    throw new DeliveryAddressFormatError(message);
  }
  return date;
}

/** Mirrors `DeliveryAddress.fromMap`. Throws {@link DeliveryAddressFormatError} for a malformed row. */
export function parseDeliveryAddress(row: Record<string, unknown>): DeliveryAddress {
  const createdAt = requiredDate(row, 'created_at', 'Invalid delivery address creation time.');
  const updatedAt = requiredDate(row, 'updated_at', 'Invalid delivery address update time.');

  return {
    id: requiredString(row, 'id'),
    label: optionalString(row, 'label'),
    recipientName: requiredString(row, 'recipient_name'),
    phone: requiredString(row, 'phone'),
    street: requiredString(row, 'street'),
    district: requiredString(row, 'district'),
    city: requiredString(row, 'city'),
    isDefault: row.is_default === true,
    createdAt,
    updatedAt,
  };
}

/** Mirrors `NewDeliveryAddress.toMap`: trims every text field and normalizes a blank label to `null`. */
export function newDeliveryAddressToRow(address: NewDeliveryAddress): DeliveryAddressWriteRow {
  const label = address.label?.trim();
  return {
    label: label ? label : null,
    recipient_name: address.recipientName.trim(),
    phone: address.phone.trim(),
    street: address.street.trim(),
    district: address.district.trim(),
    city: address.city.trim(),
    is_default: address.isDefault ?? false,
  };
}
