# AGENTS.md

## Project
This is a Flutter/Dart project. Follow the existing architecture, folder structure, and local style before changing code.

## Main folders
- `lib/`: production Flutter code.
- `test/` and `integration_test/`: tests, when present.
- `assets/`: images, fonts, translations, and static resources.
- Do not edit generated files directly, including `*.g.dart`, `*.freezed.dart`, `*.mocks.dart`, generated Firebase options, or generated localization files.

## Working rules
- Keep diffs small and focused; avoid broad refactors.
- Use the repo's configured Flutter/Dart version, including FVM config if present.
- Do not introduce new state management, routing, localization, theme, analytics, Firebase, or dependency-injection patterns unless requested.
- Do not add dependencies to `pubspec.yaml` unless necessary; explain why first.
- Preserve existing screens, tabs, and navigation flows, including Digest, Weekly Digest, and watchlist digest sections where present.
- Keep business logic out of widgets unless nearby code already follows that pattern.
- Do not create fake APIs, placeholder classes, or hardcoded production data unless requested.
- Do not commit secrets, API keys, signing files, service account files, or local env files.

## Verification
After Dart or Flutter changes, run the commands that fit the repo:
- `dart format .`
- `dart analyze`
- `flutter test`

If code generation is used, run the repo's existing build_runner command before analysis.

## Done
A task is complete when the behavior is implemented, formatting is applied, analyzer issues are addressed, and relevant tests pass or any failures are clearly explained.
