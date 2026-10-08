# Welcome to your Expo app 👋

This is an [Expo](https://expo.dev) project created with [`create-expo-app`](https://www.npmjs.com/package/create-expo-app).

## Get started

1. Install dependencies

   ```bash
   npm install
   ```

2. Start the app

   ```bash
   npx expo start
   ```

In the output, you'll find options to open the app in a

- [development build](https://docs.expo.dev/develop/development-builds/introduction/)
- [Android emulator](https://docs.expo.dev/workflow/android-studio-emulator/)
- [iOS simulator](https://docs.expo.dev/workflow/ios-simulator/)
- [Expo Go](https://expo.dev/go), a limited sandbox for trying out app development with Expo

You can start developing by editing the files inside the **app** directory. This project uses [file-based routing](https://docs.expo.dev/router/introduction).

## Get a fresh project

When you're ready, run:

```bash
npm run reset-project
```

This command will move the starter code to the **app-example** directory and create a blank **app** directory where you can start developing.

### Other setup steps

- To set up ESLint for linting, run `npx expo lint`, or follow our guide on ["Using ESLint and Prettier"](https://docs.expo.dev/guides/using-eslint/)
- If you'd like to set up unit testing, follow our guide on ["Unit Testing with Jest"](https://docs.expo.dev/develop/unit-testing/)
- Learn more about the TypeScript setup in this template in our guide on ["Using TypeScript"](https://docs.expo.dev/guides/typescript/)

## Supabase database types

`src/types/database.ts` exports the `Database` type the Supabase client at
`src/platform/supabase/client.ts` is parameterized with
(`createClient<Database>(...)`), so every `.from('...')` table/view name,
column, and `.rpc('...')` function name and argument is type-checked against
the real `public` schema — calling a table or RPC that doesn't exist is a
compile error.

**Regenerate it after every migration** lands in `supabase/migrations/`
(repo root):

```bash
npm run gen:types
```

This runs `supabase gen types typescript --project-id jzubookmbrtslocuzepe
--schema public`, which needs a `supabase login` session with network
access to the live project. If you only have the SQL locally (no CLI login,
offline, or a local Supabase stack via `supabase start`), generate from that
instead and review the diff before committing:

```bash
# Local Supabase stack (Docker) running against supabase/migrations/:
supabase gen types typescript --local --schema public > src/types/database.ts

# Or point the CLI at a schema dump / the running project's connection
# string directly — see `supabase gen types typescript --help`.
```

Commit the regenerated file. Do not hand-edit `database.ts` outside of a
regeneration — if the CLI genuinely can't reach any schema source, update it
by re-deriving it from `supabase/schema.sql` plus `supabase/migrations/` (in
timestamp order, since `schema.sql` alone is known to drift — see
`AGENTS.md` at the repo root) and leave a comment on exactly what changed and
why, the same way the current file documents its own provenance at the top.

## Learn more

To learn more about developing your project with Expo, look at the following resources:

- [Expo documentation](https://docs.expo.dev/): Learn fundamentals, or go into advanced topics with our [guides](https://docs.expo.dev/guides).
- [Learn Expo tutorial](https://docs.expo.dev/tutorial/introduction/): Follow a step-by-step tutorial where you'll create a project that runs on Android, iOS, and the web.

## Join the community

Join our community of developers creating universal apps.

- [Expo on GitHub](https://github.com/expo/expo): View our open source platform and contribute.
- [Discord community](https://chat.expo.dev): Chat with Expo users and ask questions.
