# Application Execution & Deployment Guide

This guide contains the essential commands for running your application in **Development** and deploying it to **Production** platforms (Hugging Face, Vercel, Neon, and Mobile).

---

## 📱 Mobile App (Flutter & Android)

### Development
Run the app on a connected device or emulator with development configurations:
```bash
flutter run --dart-define-from-file=env.dev.json
```

### Production Build (APK)
Generate a release-ready APK with production environment variables:
```bash
flutter build apk --release --dart-define-from-file=env.prod.json
```
*The APK will be located at: `build/app/outputs/flutter-apk/app-release.apk`*

---

## 🟢 NestJS Backend (News Auth Check)
**Platform:** Vercel

### Development
Run locally with hot-reload:
```bash
# Ensure dependencies are installed first
pnpm install

# Run with development environment
NODE_ENV=development pnpm start:dev
```

### Deployment to Vercel
1. **Set Environment Variables**: In your Vercel Dashboard, add the variables defined in `.env.example`.
2. **Deploy**:
   ```bash
   vercel --prod
   ```

---

## 🚀 FastAPI Backend (Analysis Service)
**Platform:** Hugging Face Spaces

### Development
Run locally using uvicorn:
```bash
# Ensure you are in the /analysis directory
cd analysis

# Run with development environment
APP_ENV=development uvicorn main:app --reload --port 7860
```

### Deployment to Hugging Face
1. **Secrets**: Go to **Settings > Variables and Secrets** in your Space.
2. **Add Variables**: Add all keys from `analysis/.env.example` as "Secrets".
3. **Trigger Build**: Push your code to the Hugging Face Space repository.
   ```bash
   git push hf main
   ```

---

## 🐘 Database (Neon)
**Platform:** Neon Serverless Postgres

### Connection String
Both backends require the `DATABASE_URL` from your Neon dashboard.
- **NestJS**: Add to Vercel Environment Variables.
- **FastAPI**: Add to Hugging Face Secrets.

---

## 🛠 Useful Maintenance Commands

### Clean Project (Fixes Build Issues)
```bash
# Flutter
flutter clean
flutter pub get

# NestJS
rm -rf dist node_modules
pnpm install

# FastAPI
# (Optional) Reinstall requirements
pip install -r requirements.txt
```

### Checking Logs (Production)
- **Vercel**: `vercel logs`
- **Hugging Face**: View the "Logs" tab in your Space dashboard.
