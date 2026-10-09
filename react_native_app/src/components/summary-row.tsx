import { Text, View } from 'react-native';

export type SummaryRowProps = {
  label: string;
  value: string;
  isBold?: boolean;
};

/**
 * Ports flutter_app/lib/widgets/app_misc.dart's `SummaryRow`: a small
 * label/value row used in order summary blocks.
 *
 * The bold/total row intentionally uses the fixed platform `primary` token
 * rather than the active theme's resolved primary color — under a future
 * `ZivoServiceTheme`-equivalent, a per-service accent there would break the
 * "accent confined to the 48px icon chip" rule for every cart/checkout
 * summary using this row (same rationale as the Flutter source). `primary`
 * still flips with light/dark mode via NativeWind's CSS variables, same as
 * every other semantic token here.
 */
export function SummaryRow({ label, value, isBold = false }: SummaryRowProps) {
  return (
    <View className="flex-row items-start">
      <Text
        className={`flex-1 text-text ${
          isBold ? 'text-fontBoldBase font-outfitSemiBold' : 'text-textSm font-outfitRegular'
        }`}>
        {label}
      </Text>
      <Text
        className={`ml-x3 ${
          isBold ? 'text-fontBoldBase font-outfitSemiBold text-primary' : 'text-fontBoldSm font-outfitSemiBold text-text'
        }`}>
        {value}
      </Text>
    </View>
  );
}
