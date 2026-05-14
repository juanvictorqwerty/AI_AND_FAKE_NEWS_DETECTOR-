# Environment Variables Refactoring Guide

This guide provides a comprehensive, production-ready strategy to cleanly separate "Development" and "Production" environments across your multi-tech stack (Flutter/Android, NestJS, and FastAPI). It replaces the legacy `.env` file approaches and `SharedPreferences` syncing with modern, secure, and type-safe environment configurations.

## User Review Required

> [!WARNING]
> This refactoring will change how environment variables are passed to all three applications. 
> 1. You will need to start using specific build/run commands for Flutter.
> 2. The NestJS and FastAPI backends will require their respective system environment variables (`NODE_ENV` and `APP_ENV`) to be set to load the correct files.
> 
> Please review the Kotlin `build.gradle.kts` changes carefully to ensure the variable names align with your required native configurations. If you approve this plan, I will execute the changes on the Flutter and Kotlin side as requested.

---

## 1. FLUTTER & ANDROID/KOTLIN (Mobile App)

We will transition from using the `flutter_dotenv` package and `SharedPreferences` (via `ConfigManager.kt`) to using native compile-time variables injected via `--dart-define-from-file`.

### File Structure
```
ai_fake_news_detector/
├── env.dev.json      (NEW)
├── env.prod.json     (NEW)
└── lib/
    └── config/
        └── env_config.dart (NEW)
```

### JSON Environment Files
**`env.dev.json`**
```json
{
  "BASE_URL_NODE": "http://192.168.1.152:4000",
  "BASE_URL_FASTAPI": "http://192.168.1.152:8000",
  "NATIVE_FACT_CHECK_URL": "http://192.168.1.152:4000",
  "NATIVE_MEDIA_UPLOAD_URL": "http://192.168.1.152:8000"
}
```

### Dart Configuration Class
**`lib/config/env_config.dart`**
```dart
class EnvConfig {
  static const String baseUrlNode = String.fromEnvironment(
    'BASE_URL_NODE',
    defaultValue: 'http://192.168.1.152:4000',
  );

  static const String baseUrlFastApi = String.fromEnvironment(
    'BASE_URL_FASTAPI',
    defaultValue: 'http://192.168.1.152:8000',
  );
}
```

### Android/Kotlin Integration
To access these variables natively in Kotlin (e.g., in your background workers and services) without relying on Flutter syncing data to SharedPreferences, we extract the base64-encoded `dart-defines` directly in the Android build system.

**`android/app/build.gradle.kts`**
```kotlin
import java.util.Base64

// ... existing plugins ...

// Extract dart-defines injected by --dart-define-from-file
val dartEnvironmentVariables = mutableMapOf<String, String>()
if (project.hasProperty("dart-defines")) {
    val dartDefines = project.property("dart-defines") as String
    dartDefines.split(",").forEach {
        try {
            val decoded = String(Base64.getDecoder().decode(it))
            val split = decoded.split("=")
            if (split.size == 2) {
                dartEnvironmentVariables[split[0]] = split[1]
            }
        } catch (e: IllegalArgumentException) {
            // Ignore malformed base64
        }
    }
}

android {
    // ...
    
    // Enable BuildConfig generation
    buildFeatures {
        buildConfig = true
    }

    defaultConfig {
        // ...
        
        // Expose variables to Kotlin code via BuildConfig
        buildConfigField("String", "FACT_CHECK_URL", "\"${dartEnvironmentVariables["NATIVE_FACT_CHECK_URL"] ?: "http://192.168.1.152:4000"}\"")
        buildConfigField("String", "MEDIA_UPLOAD_URL", "\"${dartEnvironmentVariables["NATIVE_MEDIA_UPLOAD_URL"] ?: "http://192.168.1.152:8000"}\"")
        
        // Expose variables to AndroidManifest.xml
        manifestPlaceholders["customScheme"] = dartEnvironmentVariables["CUSTOM_SCHEME"] ?: "defaultScheme"
    }
}
```

*In Kotlin (`MainActivity.kt` or `ConfigManager.kt`), you can now access these directly via `BuildConfig.FACT_CHECK_URL`.*

### CLI Commands
- **Run Dev:** `flutter run --dart-define-from-file=env.dev.json`
- **Run Prod:** `flutter run --release --dart-define-from-file=env.prod.json`
- **Build APK:** `flutter build apk --release --dart-define-from-file=env.prod.json`

---

## 2. NESTJS (Main Backend)

### File Structure
```
news_auth_check/
├── .env.development
├── .env.production
└── src/
    ├── app.module.ts
    └── config/
        └── env.validation.ts
```

### Validation Schema
**`src/config/env.validation.ts`**
```typescript
import * as Joi from 'joi';

export const envValidationSchema = Joi.object({
  NODE_ENV: Joi.string().valid('development', 'production', 'test').default('development'),
  PORT: Joi.number().default(4000),
  DATABASE_URL: Joi.string().required(),
  JWT_SECRET: Joi.string().required(),
  // Add other critical variables here
});
```

### Dynamic Module Loading
**`src/app.module.ts`**
```typescript
import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { envValidationSchema } from './config/env.validation';
// ... other imports

@Module({
  imports: [
    ConfigModule.forRoot({
      isGlobal: true,
      envFilePath: process.env.NODE_ENV === 'production' ? '.env.production' : '.env.development',
      validationSchema: envValidationSchema,
      validationOptions: {
        abortEarly: true, // Crash immediately if vars are missing
      },
    }),
    DatabaseModule,
    // ...
  ],
  // ...
})
export class AppModule {}
```

---

## 3. FASTAPI (Secondary Backend)

### File Structure
```
analysis/
├── .env.development
├── .env.production
└── models/
    └── config.py
```

### Pydantic Settings implementation
**`models/config.py`**
```python
import os
from pydantic_settings import BaseSettings, SettingsConfigDict

class Settings(BaseSettings):
    app_env: str = "development"
    app_port: int = 8000
    app_host: str = "0.0.0.0"
    
    minio_endpoint: str
    minio_access_key: str
    minio_secret_key: str
    minio_bucket_name: str
    
    database_url: str
    ai_model_name: str = "Organika/sdxl-detector"

    # Dynamically select the env file based on the APP_ENV system variable
    model_config = SettingsConfigDict(
        env_file=".env.production" if os.getenv("APP_ENV") == "production" else ".env.development",
        env_file_encoding="utf-8",
        extra="ignore"
    )

settings = Settings()
```

*Replace `os.getenv(...)` calls in `main.py` and services with `settings.database_url`, etc.*

---

## 4. SECURITY & DEVOPS

### Strict `.gitignore` Rules
Add to all three projects:
```gitignore
# Environment variables
.env
.env.*
!.env.example
*.json
!env.dev.example.json
```

### Structure Templates
**`.env.example` / `env.example.json`**
Commit these to version control to provide clear structure without leaking secrets:
```json
{
  "BASE_URL_NODE": "http://your-dev-ip:4000",
  "BASE_URL_FASTAPI": "http://your-dev-ip:8000"
}
```

### Production Security Recommendations
1. **Never commit `.env.production` or `env.prod.json` to source control.**
2. **Docker / Containerization:** Inject environment variables via your container runtime (e.g., docker-compose `environment` mapping or Kubernetes `ConfigMaps`/`Secrets`) rather than baking physical `.env` files into your images.
3. **CI/CD Pipelines:** Store your production secrets securely in your CI/CD platform (e.g., GitHub Secrets, GitLab CI/CD variables) and generate the `.env.production` or `env.prod.json` file on the fly during the build step. 

---
## Proposed Changes to Execute

If approved, I will implement the following changes in the Flutter / Kotlin Android application:

### [MODIFY] android/app/build.gradle.kts
Update to decode `dart-defines`, enable `BuildConfig`, and expose variables native code.

### [MODIFY] android/app/src/main/kotlin/com/example/ai_fake_news_detector/ConfigManager.kt
Refactor this object to read from the injected `BuildConfig` variables instead of polling `FlutterSharedPreferences`.

### [NEW] env.dev.json & env.prod.json
Create the baseline configuration JSON files in the flutter root directory.

### [NEW] lib/config/env_config.dart
Create the type-safe Dart wrapper for `String.fromEnvironment`.

### [MODIFY] lib/services/*.dart
Refactor services to use the new `EnvConfig` instead of `flutter_dotenv`.

### [MODIFY] lib/main.dart
Remove `flutter_dotenv` initialization.
