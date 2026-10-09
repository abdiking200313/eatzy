import { Text } from 'react-native';

export type SectionTitleProps = {
  title: string;
  color?: string;
  fontSize?: number;
};

/**
 * Ports flutter_app/lib/widgets/app_scaffold.dart's `SectionTitle`: a small
 * heading used to introduce a new section of content.
 */
export function SectionTitle({ title, color, fontSize }: SectionTitleProps) {
  return (
    <Text
      style={{ color, fontSize }}
      className={color ? 'text-sectionTitle font-outfitSemiBold' : 'text-sectionTitle font-outfitSemiBold text-text'}>
      {title}
    </Text>
  );
}
