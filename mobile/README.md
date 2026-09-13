# Kelal Studio — Mobile

<!-- Badges Section Placeholder -->
[![Flutter](https://img.shields.io/badge/Flutter-3.44.4-02569B?logo=flutter&logoColor=white)](#)
[![Dart](https://img.shields.io/badge/Dart-3.12+-0175C2?logo=dart&logoColor=white)](#)
[![Platform](https://img.shields.io/badge/Platform-iOS%20%7C%20Android-lightgrey)](#)
[![Architecture](https://img.shields.io/badge/Architecture-Clean%20Architecture-teal)](#)
[![CI](https://img.shields.io/badge/CI-Passing-brightgreen)](#)

A bilingual (English / Amharic) social media caption, graphic, and video generation platform purpose-built for Ethiopian business owners.

---

## Overview

**Kelal Studio Mobile** is the primary, load-bearing client application for the Kelal Studio platform. It enables merchants, entrepreneurs, and content creators to go from an initial marketing concept to a production-ready, on-brand graphic or video with local Amharic copy—directly from iOS and Android devices.

---

## Screenshots Placeholder

| Idea Composer | Canvas Editor | Brand Kit & Preview |
|:---:|:---:|:---:|
| <img src="docs/screenshots/composer.png" width="240" alt="Idea Composer Placeholder"/> | <img src="docs/screenshots/editor.png" width="240" alt="Canvas Editor Placeholder"/> | <img src="docs/screenshots/brand_kit.png" width="240" alt="Brand Kit Preview Placeholder"/> |

| Post Reminders | Local Drafts | Bilingual Interface (EN/AM) |
|:---:|:---:|:---:|
| <img src="docs/screenshots/reminders.png" width="240" alt="Reminders Placeholder"/> | <img src="docs/screenshots/drafts.png" width="240" alt="Drafts Persistence Placeholder"/> | <img src="docs/screenshots/localization.png" width="240" alt="Bilingual Interface Placeholder"/> |

---

## Key Features

- **Idea Composer**: Streamlined prompt intake supporting both Latin and Fidel (Ge'ez) script inputs, aspect-ratio selection (1:1, 4:5), and AI marketing caption generation.
- **Canvas Editor**: High-performance interactive visual editor supporting layer transformations, custom typography, brand-aligned color palettes, and sticker/graphic overlays.
- **Export & Share Flow**: High-resolution rasterization pipeline with direct gallery save (`gal`) and platform sharing (`share_plus`).
- **Device-Local Drafts**: Robust offline-first draft persistence powered by an embedded SQLite database via **Drift**.
- **Post Reminders**: Scheduled local push notifications powered by **flutter_local_notifications** and managed via **permission_handler**.
- **Bilingual Interface (EN / AM)**: Seamless runtime locale switching between English and Amharic with zero system font dependencies (self-hosted Noto Sans Ethiopic).

---

## Tech Stack

| Technology / Package | Version | Purpose |
|---|---|---|
| **Flutter SDK** | `3.44.4` | Cross-platform UI toolkit (pinned via `.fvmrc`) |
| **Dart SDK** | `>=3.12.2 <4.0.0` | Client programming language |
| **Drift** (`drift_flutter`) | `2.31.0` (`0.2.8`) | Reactive local SQLite persistence for drafts |
| **flutter_local_notifications** | `22.0.0` | Cross-platform OS notification scheduling |
| **permission_handler** | `11.3.1` | Granular runtime permissions (notifications, gallery) |
| **flutter_bloc** (`hydrated_bloc`) | `9.1.1` (`10.1.1`) | Predictable state management and state persistence |
| **go_router** | `14.8.1` | Declarative routing and deep linking |
| **retrofit** & **dio** | `4.10.0` / `5.11.0` | Type-safe REST client & network interceptors |
| **freezed** | `3.2.5` | Immutable domain models, data classes, and unions |
| **injectable** & **get_it** | `2.7.1+4` / `8.3.0` | Compile-time dependency injection |
| **flutter_secure_storage** | `9.2.4` | Keychain/Keystore-backed secure token storage |
| **envied** | `1.3.8` | Compile-time environment configuration |

---

## Prerequisites

Ensure your development environment meets the following specifications:

- **Flutter SDK**: `3.44.4` (managed via [FVM](https://fvm.app/) recommended)
- **Dart SDK**: `3.12.2` or later
- **Xcode**: 15.0+ with CocoaPods installed (for iOS development)
- **Android Studio / Android SDK**: Platform SDK 34+, Build Tools, and JDK 17 (for Android development)
- **FVM**: `dart pub global activate fvm`

---

## Setup & Installation

### 1. Clone Repository & Navigate

```bash
git clone https://github.com/Bereke1t2/KELAL-STUDIO.git
cd KELAL-STUDIO/mobile
```

### 2. Install Pinned Flutter SDK via FVM

```bash
fvm install
fvm use 3.44.4
```

### 3. Fetch Dependencies & Run Code Generation

```bash
# Fetch package dependencies
fvm flutter pub get

# Generate freezed models, DI containers, retrofit clients, and drift tables
dart run build_runner build --delete-conflicting-outputs

# (Optional) Compile localization files if .arb files were modified
fvm flutter gen-l10n
```

### 4. Run the Application

#### Option A: Built-in Mock Mode (Default — No backend required)

Runs entirely against in-memory local fake repositories:

```bash
fvm flutter run
```

> **Demo Mock Credentials:**
> - Email: `demo@kelalstudio.app`
> - Password: `password123`

#### Option B: Real Backend Mode

Point the app to a running Kelal Studio Go API service:

```bash
fvm flutter run \
  --dart-define=USE_MOCK_API=false \
  --dart-define=API_BASE_URL=http://localhost:8080/v1
```

---

## Environment & Configuration

In accordance with platform security guidelines (PRD §7.8, §10.1), **the mobile client never holds secret credentials, private keys, or provider tokens**. Secrets live strictly server-side.

Runtime configuration is passed via compile-time `--dart-define` flags handled by `Envied` (`lib/core/env/env.dart`):

| Variable | Default | Description |
|---|---|---|
| `USE_MOCK_API` | `true` | When `true`, delegates to local mock services. When `false`, hits `API_BASE_URL`. |
| `API_BASE_URL` | `http://localhost:8080/v1` | Base REST endpoint for the Go backend (requires trailing `/v1`). |

> **Emulator Networking Note:**
> - **iOS Simulator**: `http://localhost:8080/v1`
> - **Android Emulator**: `http://10.0.2.2:8080/v1` (since `localhost` refers to the Android device itself)
> - **Physical Device**: `http://<YOUR-LOCAL-IP>:8080/v1`

---

## Project Structure

The mobile codebase follows **Feature-First Clean Architecture**, isolating business logic from UI and data layers:

```
lib/
├── app.dart                   # Root MaterialApp (theme, routing, localization setup)
├── bootstrap.dart             # Application initialization (DI, SQLite, HydratedBloc, logging)
├── main.dart                  # Entry point
├── core/                      # Shared platform infrastructure & services
│   ├── database/              # Drift SQLite database (app_database.dart) & tables
│   ├── di/                    # Dependency injection bindings (injection.dart)
│   ├── env/                   # Envied compile-time configuration
│   ├── error/                 # Domain failures & Result<Failure, T> types
│   ├── l10n/                  # ARB localization definitions & LocaleCubit
│   ├── network/               # Dio HTTP client, auth interceptor, and OpenAPI contracts
│   ├── notifications/         # flutter_local_notifications scheduling service
│   ├── render_engine/         # Canvas rendering engine shared by editor & export
│   ├── router/                # GoRouter route declarations & navigation keys
│   ├── storage/               # Secure key-value storage for access/refresh tokens
│   ├── theme/                 # Figma design tokens, typography, and ThemeCubit
│   └── widgets/               # Reusable UI components & design system primitives
└── features/                  # Independent domain slices
    ├── auth/                  # Authentication, email verification, login, session restore
    ├── brand_kit/             # Brand identity configuration & live preview
    ├── canvas_editor/         # Interactive multi-layer graphic editor
    ├── composer/              # Idea prompt composer & ratio selection
    ├── drafts/                # Device-local draft post persistence via Drift
    ├── export/                # Canvas rendering, gallery saving, and social share
    ├── generation/            # AI caption/image generation and polling
    ├── quota/                 # Daily generation quota tracking UI
    ├── reminders/             # Scheduled post reminder notifications
    ├── settings/              # Language toggle (EN/AM), theme mode, account actions
    └── video_teaser/          # Async video job status polling & playback
```

Each feature slice contains:
- `data/`: Data transfer objects (DTOs), remote datasources, and repository implementations.
- `domain/`: Business entities, value objects, and repository contracts.
- `presentation/`: BLoCs/Cubits, pages, and feature-specific widgets.

---

## Testing & Quality Gates

Run all automated test suites using the pinned SDK:

```bash
# 1. Run static analysis (must be zero errors/warnings before committing)
fvm flutter analyze

# 2. Check code formatting
dart format --set-exit-if-changed .

# 3. Run unit, widget, and golden tests with coverage
fvm flutter test --coverage

# 4. Update golden test baselines (run only when visual UI changes are intentional)
fvm flutter test --tags golden --update-goldens
```

---

## Branching & Contribution Notes

- **Commit Format**: Commits adhere strictly to the [Conventional Commits](https://www.conventionalcommits.org/) specification (`feat:`, `fix:`, `refactor:`, `test:`, `docs:`).
- **Commit Guard**: Changes made under `mobile/**` must pass through the automated commit workflow (`.claude/commands/commit.md`), which validates code formatting and static analysis before allowing the commit.
- **Stacked Pull Requests**: Multi-part features are stacked via `gh stack` (`/pr`) rather than large monolithic pull requests.
- **Feature Ownership**: Backend and cross-stack feature slice status is managed via [`../backend/docs/FEATURE_OWNERSHIP.md`](../backend/docs/FEATURE_OWNERSHIP.md).
