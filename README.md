# Eatzy

Monorepo for Zivo, a modular super app (food, grocery and pharmacy delivery).

```
eatzy/
├── flutter_app/        Flutter app (canonical, shipping client)
├── react_native_app/   Expo + TypeScript app
├── supabase/           Shared backend: schema, migrations, seed
├── docs/  vault/       Shared docs and project vault
└── .github/            CI for both apps
```

- Flutter app: see [flutter_app/README.md](flutter_app/README.md). Run all
  `flutter`/`dart` commands from inside `flutter_app/`.
- React Native app: see [react_native_app/README.md](react_native_app/README.md).
  Run all `npm`/`npx expo` commands from inside `react_native_app/`.
- Backend: see [supabase/README.md](supabase/README.md).
- Agent conventions: [AGENTS.md](AGENTS.md).
