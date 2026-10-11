/**
 * Ports `flutter_app/lib/features/merchant/shared/merchant_media_store.dart`
 * (issue #411 / P9-06): uploads merchant store/item photos to the
 * `merchant_media` storage bucket and deletes ones that end up unused.
 *
 * Bucket layout (`supabase/migrations/20260925000000_add_merchant_media_uploads.sql`):
 * `merchant_media/<auth.uid()>/<store|items>/<timestamp>.<ext>`. Every write
 * policy keys on the first path segment being the caller's own user id, so
 * this is the only place a merchant can create or delete files. The bucket
 * is public: the row stores the plain public URL and customers load it as-is.
 */
import { supabase } from '@/platform/supabase/client';

/**
 * Which of the merchant's media folders an upload belongs to. Also fixes the
 * crop shape: store photos are shown to customers as wide hero banners, item
 * photos as square thumbnails. Mirrors the Dart `MerchantMediaFolder` enum.
 */
export type MerchantMediaFolder = 'store' | 'items';

export const MERCHANT_MEDIA_FOLDER_CONFIG: Record<
  MerchantMediaFolder,
  { pathSegment: string; aspectX: number; aspectY: number; maxWidth: number }
> = {
  // `maxWidth` is the Dart `cropImage(maxWidth: ...)` cap.
  store: { pathSegment: 'store', aspectX: 16, aspectY: 9, maxWidth: 1600 },
  items: { pathSegment: 'items', aspectX: 1, aspectY: 1, maxWidth: 1000 },
};

export const MERCHANT_MEDIA_BUCKET = 'merchant_media';

export interface MerchantMediaUpload {
  bytes: Uint8Array;
  contentType: string;
  folder: MerchantMediaFolder;
}

/** Uploads merchant photos and deletes ones that are no longer used. */
export interface MerchantMediaStore {
  /** Uploads `bytes` and resolves the public URL to save on the row. */
  upload(input: MerchantMediaUpload): Promise<string>;

  /**
   * Deletes the file behind `url` if it is one of the signed-in merchant's
   * own uploads; any other URL (a legacy hosted link, someone else's file)
   * is left alone.
   */
  deleteIfOwned(url: string): Promise<void>;
}

type StorageResult = { error: unknown };

/** The slice of the Supabase client this store needs -- narrow so tests can fake it. */
export interface MerchantMediaClient {
  auth: {
    getSession(): Promise<{ data: { session: { user: { id: string } } | null } }>;
  };
  storage: {
    from(bucket: string): {
      upload(path: string, body: ArrayBuffer, options: { contentType: string }): Promise<StorageResult>;
      getPublicUrl(path: string): { data: { publicUrl: string } };
      remove(paths: string[]): Promise<StorageResult>;
    };
  };
}

export const SIGN_IN_TO_MANAGE_PHOTOS_MESSAGE = 'Sign in to manage photos.';

/**
 * Supabase-backed {@link MerchantMediaStore}. `client` defaults to the shared
 * app client, resolved only when a photo is actually uploaded or deleted --
 * so screens can build one eagerly without touching Supabase (e.g. in tests).
 */
export class SupabaseMerchantMediaStore implements MerchantMediaStore {
  constructor(
    private readonly clientOverride?: MerchantMediaClient,
    private readonly now: () => number = Date.now,
  ) {}

  private get client(): MerchantMediaClient {
    return this.clientOverride ?? (supabase as unknown as MerchantMediaClient);
  }

  private async userId(): Promise<string> {
    const { data } = await this.client.auth.getSession();
    const id = data.session?.user.id;
    if (id == null) throw new Error(SIGN_IN_TO_MANAGE_PHOTOS_MESSAGE);
    return id;
  }

  async upload({ bytes, contentType, folder }: MerchantMediaUpload): Promise<string> {
    const userId = await this.userId();
    const path = `${userId}/${MERCHANT_MEDIA_FOLDER_CONFIG[folder].pathSegment}/${this.now()}.${extensionFor(contentType)}`;
    const storage = this.client.storage.from(MERCHANT_MEDIA_BUCKET);
    // supabase-js on React Native uploads an ArrayBuffer (a Blob/File from a
    // local URI is not reliably readable there); copy so the buffer holds
    // exactly these bytes even if `bytes` is a view into a larger one.
    const { error } = await storage.upload(path, bytes.slice().buffer as ArrayBuffer, { contentType });
    if (error != null) throw error;
    return storage.getPublicUrl(path).data.publicUrl;
  }

  async deleteIfOwned(url: string): Promise<void> {
    const path = ownedPathFromUrl(url, await this.userId());
    if (path == null) return;
    const { error } = await this.client.storage.from(MERCHANT_MEDIA_BUCKET).remove([path]);
    if (error != null) throw error;
  }
}

/**
 * The object path inside `merchant_media` for a public URL of one of
 * `userId`'s own files, or `null` if `url` is anything else.
 */
export function ownedPathFromUrl(url: string, userId: string): string | null {
  const marker = `/storage/v1/object/public/${MERCHANT_MEDIA_BUCKET}/`;
  const index = url.indexOf(marker);
  if (index === -1) return null;
  let path: string;
  try {
    path = decodeURIComponent(url.substring(index + marker.length).split('?')[0]);
  } catch {
    // Dart's `Uri.decodeComponent` throws on a malformed escape too; treat
    // such a URL as not ours rather than failing the (best-effort) delete.
    return null;
  }
  return path.startsWith(`${userId}/`) ? path : null;
}

/** The file extension for an upload's content type; JPEG for anything unrecognised. */
export function extensionFor(contentType: string): string {
  switch (contentType) {
    case 'image/png':
      return 'png';
    case 'image/webp':
      return 'webp';
    default:
      return 'jpg';
  }
}

function blankToNull(value: string | null | undefined): string | null {
  const trimmed = value?.trim() ?? '';
  return trimmed.length === 0 ? null : trimmed;
}

/**
 * Tracks the photos uploaded while one store/item form is open, so files
 * that end up unused are deleted instead of piling up in storage:
 *   - after a save, every upload except the saved one, plus the row's
 *     previous photo if it was replaced or removed ({@link commit});
 *   - when the form closes without saving, every upload ({@link discard}).
 * Cleanup is best-effort -- a failed delete never blocks the merchant.
 */
export class MerchantPhotoSession {
  private savedUrl: string | null;
  private readonly uploads = new Set<string>();
  private saveInFlight = false;
  private discardRequested = false;

  constructor(
    readonly media: MerchantMediaStore,
    savedUrl?: string | null,
  ) {
    this.savedUrl = blankToNull(savedUrl);
  }

  async upload(input: MerchantMediaUpload): Promise<string> {
    const url = await this.media.upload(input);
    this.uploads.add(url);
    return url;
  }

  /** The row was saved with `url` as its photo. */
  commit(url: string | null | undefined): void {
    const saved = blankToNull(url);
    const stale = new Set(this.uploads);
    if (this.savedUrl != null) stale.add(this.savedUrl);
    if (saved != null) stale.delete(saved);
    this.uploads.clear();
    this.savedUrl = saved;
    this.deleteAll(stale);
  }

  /**
   * Runs `save` (which persists the row with `url` as its photo, resolving
   * whether it succeeded) and {@link commit}s on success.
   *
   * RN addition: a successful save can unmount the form before the code
   * after its `await` runs (e.g. creating a store swaps My Store's create
   * view for the edit form), and that unmount calls {@link discard}. Going
   * through here defers such a discard until the save settles, so the
   * photo just saved is never deleted out from under the row.
   */
  async save(url: string | null | undefined, save: () => Promise<boolean>): Promise<boolean> {
    this.saveInFlight = true;
    let succeeded = false;
    try {
      succeeded = await save();
    } finally {
      this.saveInFlight = false;
      if (succeeded) this.commit(url);
      if (this.discardRequested) {
        this.discardRequested = false;
        this.discard();
      }
    }
    return succeeded;
  }

  /** The form closed without saving. */
  discard(): void {
    if (this.saveInFlight) {
      this.discardRequested = true;
      return;
    }
    const stale = new Set(this.uploads);
    this.uploads.clear();
    this.deleteAll(stale);
  }

  private deleteAll(urls: Iterable<string>): void {
    for (const url of urls) {
      deleteIfOwnedQuietly(this.media, url);
    }
  }
}

/** Best-effort {@link MerchantMediaStore.deleteIfOwned}: logs instead of throwing (the Dart `catchError` + `debugPrint`). */
export function deleteIfOwnedQuietly(media: MerchantMediaStore, url: string): void {
  media.deleteIfOwned(url).catch((error: unknown) => {
    console.warn(`Could not delete merchant photo ${url}:`, error);
  });
}
