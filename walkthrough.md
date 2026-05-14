# Environment Variable Refactoring Walkthrough

The Flutter and Android (Kotlin) layers have been fully refactored to use compile-time `--dart-define-from-file` environment variables, replacing the legacy `flutter_dotenv` package. This allows secure, type-safe switching between Dev and Prod without modifying source files.

## What was Accomplished

### 1. Flutter Environment JSONs
We created environment definition files:
- `env.dev.json`: For local development parameters.
- `env.prod.json`: For production parameters.
- `env.example.json`: Added as a safe template.

### 2. Dart Refactoring
- **`EnvConfig` Class (`lib/config/env_config.dart`)**: Created a centralized configuration file utilizing `String.fromEnvironment()` to securely access compile-time injected variables.
- Removed the `flutter_dotenv` dependency from `pubspec.yaml` and initialized setup in `main.dart`.
- Refactored `AuthService`, `FactCheckService`, and `HistoryService` to pull base URLs from the new `EnvConfig` instead of the legacy `dotenv` instance.

### 3. Native Android / Kotlin Integration
A critical piece of this refactoring was ensuring background workers and native services (like notifications) had access to the environment without polling Flutter.
- **Gradle (`android/app/build.gradle.kts`)**: Modified to parse the `dart-defines` injected during compile time.
- Exposed these native definitions directly to Android's `BuildConfig` and `AndroidManifest.xml` via `manifestPlaceholders`.
- **`ConfigManager.kt`**: Refactored to read default configurations from the dynamically generated `BuildConfig` instead of hard-coded constants or Flutter sync. 

### 4. Security Improvements
- Updated the root `.gitignore` to track `!env.example.json` but securely ignore any other `.env` or `env*.json` files to prevent credentials from entering version control.

## Validation & Next Steps

You can now use these specific commands to run the application targeting different environments:

> [!TIP]
> **To run the application in Development mode:**
> `flutter run --dart-define-from-file=env.dev.json`
>
> **To build the Production APK:**
> `flutter build apk --release --dart-define-from-file=env.prod.json`

The backend configurations for NestJS and FastAPI have also been fully refactored to use robust, schema-validated environment management.

### 5. NestJS Backend Refactoring
- **Dependencies**: Installed `@nestjs/config` and `joi` for validation.
- **Environment Files**: Created `.env.development` and `.env.production` (template).
- **Validation**: Implemented `src/config/env.validation.ts` using Joi to ensure all required variables are present at startup.
- **Dynamic Loading**: Updated `AppModule` to dynamically load the correct `.env` file based on `NODE_ENV`.
- **Security**: Updated `.gitignore` to exclude sensitive env files while allowing `.env.example`.

### 6. FastAPI Backend Refactoring
- **Dependencies**: Added `pydantic-settings` to `requirements.txt`.
- **Environment Files**: Created `.env.development` and `.env.production` (template) in the `analysis/` directory.
- **Settings Model**: Implemented `models/config.py` using Pydantic's `BaseSettings` for type-safe configuration and automatic environment file loading based on `APP_ENV`.
- **Refactoring**: Replaced legacy `os.getenv` calls across `main.py` and services with the centralized `settings` object.
- **Security**: Fixed `.gitignore` to protect environment files and properly unignore the `models/` directory for version control.

## Validation & Next Steps

You can now use these specific commands to run the applications targeting different environments:

> [!TIP]
> **To run Flutter in Development:**
> `flutter run --dart-define-from-file=env.dev.json`
>
> **To run NestJS in Development:**
> `NODE_ENV=development pnpm start:dev`
>
> **To run FastAPI in Development:**
> `APP_ENV=development uvicorn main:app --reload`

The entire multi-stack environment management system is now production-ready, secure, and type-safe!
