import { EmptyState } from '@/components/empty-state';

export type MyStoreScreenProps = {
  /** The signed-in merchant's `profiles.id`. Unused until P9-02 (#407) resolves "my store" from it. */
  ownerId: string;
};

/**
 * Placeholder for `flutter_app/lib/features/merchant/store/presentation/
 * my_store_screen.dart`'s `MyStoreScreen` -- the real store-profile editing
 * screen lands in P9-02 (#407). The merchant shell (P9-01, #406) only needs
 * a destination to route its "My Store" tab to.
 */
export function MyStoreScreen(_props: MyStoreScreenProps) {
  return (
    <EmptyState
      icon="storefront"
      title="Store management is coming soon"
      message="You'll be able to set up and edit your store here."
    />
  );
}
