# Kelal Studio — Mobile Client

[![Flutter](https://img.shields.io/badge/Flutter-3.44.4-02569B?style=flat-square&logo=flutter&logoColor=white)](#tech-stack)
[![Dart](https://img.shields.io/badge/Dart-3.12.2+-0175C2?style=flat-square&logo=dart&logoColor=white)](#tech-stack)
[![Architecture](https://img.shields.io/badge/Architecture-Clean%20%2F%20Feature--First-blueviolet?style=flat-square)](#architecture)
[![Coverage](https://img.shields.io/badge/Tests-Unit%20%7C%20Widget%20%7C%20Goldens-success?style=flat-square)](#testing)

The primary, load-bearing client surface for **Kelal Studio** (iOS & Android).

Kelal Studio empowers Ethiopian small businesses and content creators with localized, AI-powered digital marketing directly from their phones. Users can compose concepts, generate Amharic and English captions alongside on-brand graphics, customize layouts in a real-time canvas editor, and export marketing collateral ready for social platforms.

> [!NOTE]
> This README covers mobile-specific setup and workflows. For end-to-end multi-service orchestration (running the Go backend, PostgreSQL, and web admin portal simultaneously), refer to the [Root README.md](../README.md).

---

## Tech Stack

All dependencies are strictly pinned to exact versions in [`pubspec.yaml`](pubspec.yaml) to ensure deterministic builds and pixel-stable golden tests:

| Component / Library | Version | Purpose |
|---|---|---|
| **Flutter SDK** | `3.44.4` | Pinned cross-platform framework (enforced via `.fvmrc`) |
| **Dart SDK** | `>=3.12.2 <4.0.0` | Target Dart language runtime |
| **`freezed` / `freezed_annotation`** | `3.2.5` / `3.1.0` | Immutable data modeling, union types, and pattern matching |
| **`injectable` / `get_it`** | `2.7.1+4` / `8.3.0` | Compile-time dependency injection and service locator |
| **`retrofit` / `dio`** | `4.10.0` / `5.11.0` | Type-safe REST client generating OpenAPI contract bindings |
| **`drift` / `drift_flutter`** | `2.31.0` / `0.2.8` | Reactive SQLite abstraction for device-local draft storage |
| **`envied` / `envied_generator`** | `1.3.8` / `1.3.8` | Compile-time environment configuration (`--dart-define`) |
| **`flutter_bloc` / `bloc_concurrency`** | `9.1.1` / `0.3.0` | Predictable state management with explicit event transformers |
| **`hydrated_bloc`** | `10.1.1` | Local persistence for user preferences (theme and locale cubits) |
| **`go_router`** | `14.8.1` | Declarative routing with deep linking support |
| **`flutter_secure_storage`** | `9.2.4` | Keychain/Keystore encrypted storage for JWT session tokens |
| **`alchemist`** | `0.14.0` | Multi-theme golden screenshot testing engine |
| **`mocktail`** | `1.0.5` | Null-safe test mocking without code generation |
| **`very_good_analysis`** | `7.0.0` | Strict opinionated linting rules |

---

## Quickstart

### 1. Prerequisites & Tooling
Always execute Flutter commands via [FVM](https://fvm.app/) to match the exact pinned Flutter SDK (`3.44.4`):

```bash
# Install dependencies
fvm flutter pub get

# Generate immutable classes, DI bindings, and database schemas
dart run build_runner build --delete-conflicting-outputs

# (Optional) Rebuild localization bindings if ARB files change
fvm flutter gen-l10n
```

### 2. Standalone Run (Mock API Mode)
By default, the mobile app launches in mock mode (`Env.useMockApi = true`), requiring **no running backend**:

```bash
fvm flutter run
```

- **Demo Account**: `demo@kelalstudio.app`
- **Demo Password**: `password123`

---

### 3. Running Against a Real Backend

To connect the mobile app to your local Go API:

```bash
fvm flutter run \
  --dart-define=USE_MOCK_API=false \
  --dart-define=API_BASE_URL=http://localhost:8080/v1
```

> [!IMPORTANT]
> **The trailing `/v1` is required**: The Go backend mounts its API routes under `/v1`, but mobile endpoint paths (e.g., `/auth/login`) do not include this prefix. `API_BASE_URL` must supply it.

#### Target-Specific Emulator & Device Networking

- **iOS Simulator**: `http://localhost:8080/v1` connects directly to the host machine.
- **Android Emulator**: `localhost` resolves to the Android emulator itself. You must use **`http://10.0.2.2:8080/v1`**.
- **Physical Device**: Use your workstation's LAN address (e.g., `http://192.168.1.100:8080/v1`) and ensure both devices share the same Wi-Fi network.

---

## Project Structure

The codebase is organized under `mobile/lib/` using feature-first Clean Architecture:

```
lib/
├── app.dart                   # Root MaterialApp with router, theme, and locale wiring
├── bootstrap.dart             # App initialization (DI, SQLite, HydratedBloc, logging)
├── main.dart                  # Application entry point
├── core/                      # Foundational services and cross-cutting infrastructure
│   ├── database/              # Drift SQLite database (app_database.dart) for local drafts
│   ├── di/                    # Dependency injection modules and GetIt registration
│   ├── env/                   # Envied compile-time configuration and environment flags
│   ├── error/                 # Domain failures and functional Result<Failure, T> types
│   ├── l10n/                  # Amharic & English ARB files, gen bindings, and LocaleCubit
│   ├── network/               # Dio HTTP client, auth interceptor, and OpenAPI contracts
│   ├── notifications/         # Scheduled notifications (flutter_local_notifications)
│   ├── render_engine/         # Canvas rendering engine shared between editor & export
│   ├── router/                # GoRouter route definitions, redirects, and navigation keys
│   ├── storage/               # Secure key-value storage for access/refresh tokens
│   ├── theme/                 # Figma design tokens, colors, typography, and ThemeCubit
│   └── widgets/               # Reusable atomic UI components (buttons, text fields, badges)
└── features/                  # Independent domain slices (data, domain, presentation)
    ├── auth/                  # Register, verify email, login, session restore, password reset
    ├── brand_kit/             # Brand color palettes, typography, tone of voice, logo preview
    ├── canvas_editor/         # Interactive visual editor with layer manipulation and gestures
    ├── composer/              # Idea input, generation options, and aspect ratio selectors
    ├── drafts/                # Device-local draft persistence, listing, and resumption
    ├── export/                # High-res rendering, device gallery saving (gal), social share
    ├── generation/            # AI caption/image generation requests, polling, and parsing
    ├── quota/                 # Daily generation limits, usage tracking, and allowance UI
    ├── reminders/             # Scheduled post reminder setup via local notifications
    ├── settings/              # Language switching (EN/AM), dark mode toggle, account actions
    └── video_teaser/          # Async video job polling, status display, and video playback
```

---

## Architecture

The mobile app strictly enforces **Clean Architecture** organized **feature-first**:
- **Domain Layer (`domain/`)**: Pure Dart with zero Flutter or third-party framework dependencies. Houses entity models and single-responsibility Use Case classes (`call()`).
- **Data Layer (`data/`)**: Implements domain repository interfaces, coordinating remote data sources (`retrofit`/`dio`) and local cache/database (`drift`). Switches between `Fake*` and `Real*` implementations via `@module` based on `Env.useMockApi`.
- **Presentation Layer (`presentation/`)**: BLoC/Cubit state management using explicit `bloc_concurrency` event transformers. UI consumes design tokens from `context.colors`, `AppTypography`, and `AppSpacing` rather than ad-hoc literals.
- **Unified Render Engine (`core/render_engine`)**: A single paint routine serves both the real-time interactive canvas editor and final raster export. This eliminates visual parity bugs between what the user previews and what is exported.
- **Client Security Boundary**: No AI provider keys or database secrets ever ship within the mobile binary. All authentication flows through the backend Go API.

> For the comprehensive architectural standard, state management patterns, and security constraints, see [`CLAUDE.md`](CLAUDE.md) and domain skills in [`.claude/skills/`](.claude/skills/).

---

## Testing

The testing suite covers domain unit logic, BLoC state transitions, widget interactions, and pixel-level golden tests.

### Everyday Testing Commands

```bash
# Run all unit and widget tests with code coverage
fvm flutter test --coverage

# Run golden tests across light and dark themes
fvm flutter test --tags golden

# Update golden baselines (only when visual UI changes are deliberate)
fvm flutter test --tags golden --update-goldens

# Verify static analysis and code formatting
fvm flutter analyze
dart format --set-exit-if-changed .
```

### Golden Test Rigor & Ethiopic Typography
Golden tests use [Alchemist](https://pub.dev/packages/alchemist) via `goldenThemeTest` (`test/goldens/golden_helpers.dart`), rendering each component across both light and dark themes. In `test/flutter_test_config.dart`, `CiGoldensConfig.obscureText` is deliberately disabled (`false`) so goldens validate actual Ethiopic glyphs ([Noto Sans Ethiopic](assets/fonts/NotoSansEthiopic-Regular.ttf)) rather than black boxes, guarding against font-rendering regressions.

---

## Contributing & Commit Guidelines

- **Pre-commit Gate**: All changes touching `mobile/` must be committed using the `/commit` command (`mobile/.claude/commands/commit.md`), which automatically verifies `flutter analyze`, test passes, and runs the Flutter code reviewer. A root git hook blocks raw `git commit` calls that bypass this flow.
- **Stacked Pull Requests**: Multi-part features are stacked using `gh stack`.
- **Commit Format**: Follow [Conventional Commits](https://www.conventionalcommits.org/) (`feat:`, `fix:`, `refactor:`, `test:`, `chore:`). Never append AI attribution trailers (`Co-Authored-By`).

For full repository pull-request and branching guidelines, see the root [CONTRIBUTING.md](../CONTRIBUTING.md).
