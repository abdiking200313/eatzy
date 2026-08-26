# Zivo - Modern Food Delivery App

A beautiful, feature-rich Flutter food delivery application built with modern design principles and best practices.

## 🎯 About

Zivo is a super-app-in-progress: food delivery today, with grocery, pharmacy, and home-cleaning-booking verticals also under active development. It's backed by a real Supabase project (auth, catalog data, order placement via `SECURITY DEFINER` RPCs, RLS-protected tables) — not a UI-only prototype.

## ✨ Features

### Working today
- Modern Material Design 3 interface, custom theme system (`lib/config/theme.dart`, `lib/config/tailwind.dart`)
- Supabase-backed auth (`lib/features/auth/`)
- Home/restaurant browsing, cart, and checkout for food (`lib/features/home/`, `lib/features/restaurant/`, `lib/features/cart/`, `lib/features/checkout/`)
- Grocery and pharmacy verticals with their own cart/checkout controllers (`lib/services/grocery/`, `lib/services/pharmacy/`)
- Real order placement via Supabase RPCs with server-side price recomputation and RLS

### Known gaps (tracked as GitHub issues on this repo)
Several screens currently show polished UI backed by hardcoded/fake data rather than real integration — wallet, rewards, settings, saved addresses, and payment methods are the main ones. See the repo's open issues for the current list; don't assume a screen is fully wired up just because it renders correctly.

## 🚀 Quick Start

### Prerequisites
- Flutter SDK 3.41.9+ (bundles Dart SDK 3.11.5+, per `pubspec.yaml`'s `environment:` constraint; see `.fvmrc`/`.tool-versions` for the pinned version)
- Git

### Installation

```bash
# Clone the repository
git clone <repository-url>
cd eatzy

# Install dependencies
flutter pub get

# Run the app
flutter run
```

Requires a Supabase project — see `supabase/` for schema/migrations. Note: the linked docs below live one directory above this repo's root and are **not tracked in this git repository** (a plain clone of this repo won't include them) — treat them as historical local notes, not guaranteed-available references. This README and the code/tests are the current source of truth; see `AGENTS.md` and `vault/` in this repo for up-to-date architecture and conventions.

## 📱 Supported Platforms

- ✅ iOS
- ✅ Android
- ✅ Web
- ✅ Windows
- ✅ macOS
- ✅ Linux

## 📁 Project Structure

Domain-based, not layer-based — see `vault/Architecture.md` in this repo for the full breakdown. Summary:

```
lib/
├── main.dart              # App entry point, Supabase init
├── app/                   # Routing (go_router), app-level wiring
├── config/                # Theme, design tokens (theme.dart, tailwind.dart)
├── features/              # auth, cart, checkout, home, onboarding, orders,
│                          #   profile, restaurant, rewards, settings,
│                          #   super_app, support, wallet — each with its own
│                          #   data/models/presentation subfolders
├── services/              # food, grocery, pharmacy verticals (same layout)
├── platform/              # Cross-cutting: activity feed, localization,
│                          #   session, system UI
├── screens/                # A handful of legacy screens not yet moved into
│                          #   features/ (addresses, cart, categories,
│                          #   explore, payment_methods)
└── widgets/                # Shared, reused across features
```

## 🎨 Design System

The app uses a centralized theme system with:
- **Colors**: Primary gradient (Fire-Sun), surface, error, success
- **Typography**: Epilogue (headlines), Plus Jakarta Sans (body)
- **Spacing**: 4px, 8px, 12px, 16px, 24px scales
- **Radii**: 4px, 8px, 16px, 50px (rounded)

## 📦 Dependencies

- `flutter`: Core framework
- `supabase_flutter`: Backend — auth, database, RPC calls
- `go_router`: Navigation/routing
- `google_fonts`: Typography
- `cached_network_image`: Image optimization
- `intl`: Formatting (dates, currency)
- `shared_preferences`: Local persistence (cart storage)

See `pubspec.yaml` for the complete, authoritative list.

## 🔧 Development

### Code Style
- Follow Dart style guide
- Use meaningful names
- Keep widgets focused
- Use `const` constructors

### Adding Features
1. Create a feature branch
2. Implement with tests
3. Run `dart format --output=none --set-exit-if-changed lib test`, `flutter analyze`, and `flutter test` (see `AGENTS.md` for the full definition of done)
4. Submit pull request

## 📚 Documentation

- `AGENTS.md` (this repo's root) — architecture, conventions, agent delegation rules
- `vault/` (this repo) — architecture notes, decisions log, open tasks, status log

## 🧪 Testing

```bash
# Run all tests
flutter test

# Run specific test file
flutter test test/categories_screen_test.dart
```

## 🏗️ Building

### Development
```bash
flutter run --debug
```

### Release
```bash
# Android
flutter build apk
flutter build appbundle

# iOS
flutter build ios

# Web
flutter build web
```

## 📋 Roadmap

See this repo's GitHub Issues (`todo` label) for the current, maintained list of planned work — it supersedes any static roadmap in this file, which will otherwise inevitably drift.

## 🐛 Known Issues

See this repo's GitHub Issues for the current list — as of the last update there are multiple open issues, including a release-blocking one that's since been fixed (missing Android `INTERNET` permission) and several screens with UI that isn't backed by real data yet (wallet, rewards, settings, saved addresses, payment methods). Don't rely on this README to know what's currently broken — check the issue tracker.

## 🤝 Contributing

1. Fork the repository
2. Create feature branch (`git checkout -b feature/amazing-feature`)
3. Commit changes (`git commit -m 'Add amazing feature'`)
4. Push to branch (`git push origin feature/amazing-feature`)
5. Open Pull Request

## 📄 License

This project is licensed under the MIT License.

## 👥 Authors

- Zivo Development Team

## 📞 Support

For issues and questions, create a GitHub issue on this repo.

## 🎓 Learning Resources

- [Flutter Documentation](https://flutter.dev/docs)
- [Material Design 3](https://m3.material.io)
- [Dart Language](https://dart.dev)

---

Made with ❤️ using Flutter

