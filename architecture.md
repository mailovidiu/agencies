# Architecture decisions — Government Departments & Agencies App

## Purpose
This document records the key architectural decisions for the app. It describes the layered architecture, folder responsibilities, state management choices, data flow, testing strategy, and practical notes for integration in the Dreamflow environment.

## High-level architecture
We use a layered, modular architecture to keep UI, business logic, and data handling separate. Layers:

- Presentation (UI): screens, widgets, theming and routing. Should contain no business logic beyond view-specific transformation.
- Domain (State & business logic): providers implementing ChangeNotifier (Provider package). Providers orchestrate repositories/services and expose UI-friendly state (loading/error/data).
- Data (Repositories & Services): abstraction over data sources (remote APIs, local cache). Repositories expose simple methods to the domain layer and hide details of data source switching, caching, and retries.
- Models: immutable data classes used across the app.

Note: For small apps the repository and service can be merged, but keep abstraction boundaries to make the codebase easier to grow and test.

## Folder responsibilities (lib/)

- lib/models/
  - Plain data models (Department, Agency, etc.). Keep them immutable where possible.

- lib/providers/
  - ChangeNotifier-based providers. Each provider is focused (e.g., DepartmentProvider) and exposes typed states: loading, success, error.

- lib/screens/
  - Full-screen widgets (pages). They consume providers and present UI. Keep logic minimal; call provider methods for actions.

- lib/widgets/
  - Reusable components (cards, lists, dialogs). Widgets should accept data via constructor parameters; avoid pulling data directly.

- lib/ads/
  - Ad helper utilities and wrappers for AdMob flow (native, interstitial, app-open). Provide platform-aware fallbacks for web.

- lib/services/ (recommended)
  - Low-level network or platform APIs (HTTP clients, Firebase wrappers). Services should be easily mockable.

- lib/repositories/ (recommended)
  - High-level data access interfaces and implementations that depend on services.

- lib/utils/ or lib/helpers/ (recommended)
  - Small pure helpers and extensions, date formatting, validators.

- lib/theme.dart
  - Central theme, typography, and color tokens. Avoid scattering colors across widgets.

## State management (Provider)

- Providers should extend ChangeNotifier and expose a minimal public API.
- Use typed state (e.g., enum or sealed-like class with Loading/Success/Error) instead of multiple booleans to represent UI state.
- Keep async operations inside providers and call notifyListeners() once state changes.
- Register providers at app entry (lib/main.dart) using MultiProvider. For lazy creation use ChangeNotifierProvider(create: ...).

Optional: For larger projects consider using get_it for DI alongside Provider for better separation of construction and consumption.

## Data flow and repository pattern

1. UI (Screen or Widget) calls a provider method (e.g., departmentProvider.loadAll()).
2. Provider calls repository (e.g., departmentRepository.fetchDepartments()).
3. Repository uses a service (e.g., DepartmentApiService / LocalCacheService) to get raw data.
4. Repository converts raw responses to model objects and returns them to the provider.
5. Provider updates state and notifies UI.

Benefits: easier to mock repositories/services in unit tests and swap remote/local sources transparently.

## Offline & caching

- Use a local cache (Hive or shared_preferences) for small datasets. Abstract caching behind a repository.
- Implement simple cache invalidation policies: time-based TTL or manual refresh action from the UI.

## Error handling & logging

- Use a small error/failure model that providers return so UI can react (messages, retry actions).
- Wrap network calls with try/catch and map exceptions to user-friendly errors.
- Include a logger (e.g., logger package) for debug builds; keep sensitive info out of logs.

## Ads integration (lib/ads)

- Keep ad logic separate from app business logic.
- Provide a clear interface for showing/hiding ads and for lifecycle events (app open, resume).
- Provide fallbacks for web builds (AdMob is mobile-first) and respect ad policy.

## Backend and third-party integration notes

- This project currently has no backend connected. To enable Firebase or Supabase, open the corresponding panel in the Dreamflow IDE and complete the guided setup. After binding the project, add the required service wrappers and repositories.
- Avoid direct use of dart:io; use cross-platform packages (http, file_picker) so the app works on web as well.

## Testing strategy

- Unit tests: providers (mock repositories/services), pure utilities, and model conversions.
- Widget tests: key screens and components with fake providers to verify UI states (loading/error/data).
- Integration tests: flows that exercise the app end-to-end in a test environment (optional).

Mocks
- Keep small, focused interfaces for services and repositories to make mocking straightforward in tests.

## Code style & conventions

- Use descriptive file, class and method names (DepartmentRepository, DepartmentProvider).
- One public class or widget per file where possible.
- Use relative imports for app files.
- Avoid `dynamic` and prefer concrete types.
- Use English for identifiers and comments.

## Security & privacy

- Never hardcode API keys in source. If using Firebase or similar, use Dreamflow's backend integration and environment-specific config.
- For production, follow platform-specific guidelines for securing keys and user data.

## Next steps / TODOs

- Add the following folders/files (suggested):
  - lib/services/department_api_service.dart
  - lib/repositories/department_repository.dart
  - lib/providers/department_provider.dart (already present)
  - lib/screens/department_list_screen.dart
  - lib/widgets/department_card.dart (already present)

- Wire providers in lib/main.dart with MultiProvider.
- Add unit tests for providers and repository mapping.

---

If you'd like, I can also create the recommended services and repository files now and wire the providers into main.dart. If you plan to use Firebase or Supabase, open the Dreamflow Firebase or Supabase panel and connect before I add concrete backend code.