# Kelal Studio — Web (Admin & Brand Kit Portal)

<!-- Badges Section Placeholder -->
[![React](https://img.shields.io/badge/React-19.2.8-61DAFB?logo=react&logoColor=black)](#)
[![TypeScript](https://img.shields.io/badge/TypeScript-7.0.2-3178C6?logo=typescript&logoColor=white)](#)
[![Vite](https://img.shields.io/badge/Vite-8.2.2-646CFF?logo=vite&logoColor=white)](#)
[![Tailwind CSS](https://img.shields.io/badge/Tailwind_CSS-4.3.3-38B2AC?logo=tailwind-css&logoColor=white)](#)
[![React Router](https://img.shields.io/badge/React_Router-8.3.0-CA4245?logo=react-router&logoColor=white)](#)
[![Vitest](https://img.shields.io/badge/Vitest-4.1.11-6E9F18?logo=vitest&logoColor=white)](#)
[![CI](https://img.shields.io/badge/CI-Passing-brightgreen)](#)

A web dashboard for Kelal Studio businesses to manage brand kits and content settings, paired with administrative oversight tools for platform moderation and usage governance.

---

## Table of Contents

- [Overview & Scope](#overview--scope)
- [Key Features](#key-features)
- [Tech Stack](#tech-stack)
- [Prerequisites](#prerequisites)
- [Setup & Installation](#setup--installation)
  - [1. Install Dependencies](#1-install-dependencies)
  - [2. Environment Configuration](#2-environment-configuration)
  - [3. Start Development Server](#3-start-development-server)
  - [4. Running Alongside Backend](#4-running-alongside-backend)
- [Project Structure](#project-structure)
- [Testing & Quality Gates](#testing--quality-gates)
- [Build & Deployment](#build--deployment)
- [Conventions](#conventions)

---

## Overview & Scope

The web portal is purpose-built as a **single-page application (SPA)** operating entirely behind authenticated views (PRD §4).

> **Scope Boundary Note:**
> Content generation surfaces (idea composer, interactive canvas editor, draft post storage, and video export) are strictly mobile-first (PRD §5.6). The web management portal is intentionally focused on **Brand Kit configuration** and **Admin platform governance**; it never generates content.

---

## Key Features

### 1. Brand Kit Setup & Live Preview
- **Visual Identity Management**: Upload brand logos with client-side dimension validation, specify brand colors (primary, secondary, accent), and configure brand typography.
- **Tone of Voice**: Select preset brand voice guidelines (e.g., formal, conversational, festive) applied to AI caption outputs.
- **Live Brand Preview**: Real-time rendering card reflecting configured logos, colors, and typography before saving.

### 2. Admin Oversight Dashboard
- **Usage Metrics**: Aggregated counts of platform activity, total users, generations, and asset counts.
- **Moderation Flag Queue**: Administrative review surface for posts flagged by the moderation engine, with approve/reject workflows.
- **User Limits & Quota Governance**: Per-user quota adjustments and manual tier overrides.

### 3. Authentication & Session Flow
- **Self-Serve Auth**: Account registration, email verification token handling, login, and forgot/reset password flows.
- **Session Management**: Transparent single-flight access token refresh with sliding refresh token rotation.
- **Role-Based Routing**: Protected routes distinguishing standard business merchant accounts from administrator accounts (`role: 'admin'`).

### 4. Bilingual Localization (EN / AM)
- Seamless UI toggling between English and Amharic with self-hosted Noto Sans Ethiopic fonts (see [`FONTS.md`](./FONTS.md)).

---

## Tech Stack

All package versions are pinned exactly in [`package.json`](package.json) for deterministic builds:

| Technology | Exact Version | Purpose |
|---|---|---|
| **React** | `19.2.8` | Declarative component UI library (`react` & `react-dom`) |
| **TypeScript** | `7.0.2` | Application type safety and strict checking |
| **Vite** | `8.2.2` | Fast bundler and development server (`@vitejs/plugin-react: 6.1.0`) |
| **Tailwind CSS** | `4.3.3` | Utility styling (`@tailwindcss/vite: 4.3.3`) bridging CSS design tokens |
| **React Router** | `8.3.0` | Client-side routing and layout hierarchies |
| **Vitest** | `4.1.11` | Unit and component test runner (`jsdom: 30.0.1`) |
| **Testing Library** | `16.3.3` | DOM test utilities (`@testing-library/react`, `jest-dom: 7.0.1`) |
| **oxlint** | `1.80.0` | High-performance linter |

---

## Prerequisites

- **Node.js**: `20.x` or later (LTS recommended)
- **npm**: `10.x` or later
- **Backend Service**: Running instance of the Go API (or local mock server) listening on port `8080`.

---

## Setup & Installation

### 1. Install Dependencies

```bash
cd web
npm ci
```

### 2. Environment Configuration

The web application contains **no `.env` file and stores no secret API keys** (PRD §7.8). In production, the client communicates same-origin with the backend.

For local development, `vite.config.ts` automatically proxies `/v1` requests to `http://localhost:8080`. You can optionally customize the target using `VITE_API_TARGET`:

```bash
# Optional override if your backend runs on a different port:
export VITE_API_TARGET=http://localhost:8080
```

### 3. Start Development Server

```bash
npm run dev
```

The portal runs locally at: **`http://localhost:5173`**.

### 4. Running Alongside Backend

Start the Go API in mock mode in a separate terminal:

```bash
cd ../backend
USE_MOCK_DATA=true make run   # :8080, in-memory data, permissive moderation
```

> **Admin Access Note:**
> Mock backend mode contains no default admin user. Accessing `/admin/*` views requires a real PostgreSQL database with an explicit role grant:
> ```sql
> UPDATE users SET role='admin' WHERE email='owner@example.com';
> ```

---

## Project Structure

```
web/
├── public/                    # Static assets & subsetted self-hosted fonts (Noto Sans Ethiopic)
├── src/
│   ├── main.tsx               # Application entry point & root DOM mount
│   ├── App.tsx                # Top-level routing & layout composition
│   ├── api/                   # Typed API client, error taxonomy, and OpenAPI models
│   │   ├── client.ts          # Axios/fetch wrapper with single-flight token refresh
│   │   └── types.ts           # Transcribed shapes matching backend/api/openapi.yaml
│   ├── app/                   # Shell layout, navigation header, and app frame
│   ├── auth/                  # AuthContext, session restore, and route guards
│   ├── features/              # Feature modules
│   │   ├── admin/             # Platform usage statistics, moderation queue, user quotas
│   │   ├── auth/              # Login, register, email verification, password reset screens
│   │   └── brandKit/          # Brand kit editor form, color picker, live brand card preview
│   ├── i18n/                  # Bilingual localization engine (EN/AM translation dictionaries)
│   ├── lib/                   # Utility helpers and formatters
│   ├── styles/                # tokens.css design system variables (synced from Figma)
│   ├── theme/                 # ThemeContext & dark/light mode controller (data-theme)
│   └── ui/                    # Reusable UI kit components (buttons, inputs, cards, dialogs)
├── index.html                 # Single page application HTML template
├── vite.config.ts             # Vite build & proxy configuration
└── vitest.config.ts           # Vitest testing environment configuration
```

---

## Testing & Quality Gates

Run all automated checks before committing:

```bash
# 1. Typecheck TypeScript contracts (must pass cleanly)
npm run typecheck

# 2. Run fast linter (oxlint)
npm run lint

# 3. Execute unit and component tests via Vitest
npm run test

# 4. Run tests in interactive watch mode
npm run test:watch
```

---

## Build & Deployment

### 1. Production Compilation

```bash
npm run build
```

This invokes `tsc -b && vite build`, creating an optimized static bundle in `web/dist/`.

### 2. Deployment Architecture (Same-Origin Reverse Proxy)

Because the portal is an SPA with all operations authenticated via the API:
- The static files in `web/dist/` are designed to be served **same-origin** alongside the Go backend process behind a reverse proxy (such as Nginx, Caddy, or Cloudflare).
- The reverse proxy serves `index.html` for client-side routing and proxies `/v1/*` requests directly to the Go backend API.
- This eliminates CORS configuration overhead and prevents embedding backend URLs into the client-side bundle.

### 3. Local Production Preview

To test the built production bundle locally:

```bash
npm run preview
```

---

## Conventions

- **Exact Dependency Pinning**: Dependency versions are strictly pinned (no `^`), mirroring `mobile/pubspec.yaml`'s policy. Upgrades require deliberate review.
- **Design Tokens**: Colors, spacing, and typography reference CSS variables in `src/styles/tokens.css` (synced with the mobile theme from Figma `0dIrGk2LyVEseP6Tz1KxMa`). Direct hex values in components are avoided.
- **Bilingual Interface**: Strings are localized in English and Amharic. A unit test verifies key parity between language bundles.
