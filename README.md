# 🕵️ AI and Fake News Detector

A comprehensive mobile and web application powered by AI that detects fake news, analyzes images, and verifies media authenticity. Built with Flutter, NestJS, FastAPI, and Next.js.

## 📋 Table of Contents

- [Overview](#overview)
- [Features](#features)
- [System Architecture](#system-architecture)
- [Prerequisites](#prerequisites)
- [Installation & Setup](#installation--setup)
- [Running the App](#running-the-app)
- [Project Structure](#project-structure)
- [API Documentation](#api-documentation)
- [Deployment](#deployment)
- [Contributing](#contributing)
- [Support](#support)

## 🎯 Overview

AI and Fake News Detector is a multi-platform application designed to combat misinformation by:
- Analyzing images for authenticity and AI-generated content
- Fact-checking news articles and claims
- Providing real-time verification through a persistent notification interface
- Supporting multiple input methods (text, image, video)

The system uses advanced machine learning models for accurate detection and analysis.

## ✨ Features

### Mobile App (Flutter)
- **Quick Fact Check**: Rapid text-based fact checking
- **Image Analysis**: Upload and analyze images for authenticity
- **Video Upload**: Support for video media analysis
- **Persistent Notification**: Background fact-checking service with quick access
- **Media Picker**: Built-in image and video selection from device
- **Real-time Results**: Get analysis results instantly
- **Multi-platform**: iOS, Android, and Web support

### Backend Services
- **Authentication**: Secure user authentication and authorization
- **API Gateway**: RESTful APIs for all operations
- **AI Analysis**: Machine learning model inference
- **Storage**: Integrated file storage with MinIO
- **Logging & Monitoring**: Comprehensive system monitoring

## 🏗️ System Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Client Layer                              │
├─────────────────────────────────────────────────────────────┤
│  Flutter Mobile App (iOS/Android/Web)                        │
│  - UI Components                                             │
│  - Media Picker                                              │
│  - Notification Service                                      │
└──────────────────────┬──────────────────────────────────────┘
                       │ HTTP/REST
┌──────────────────────▼──────────────────────────────────────┐
│                   API Layer                                  │
├─────────────────────────────────────────────────────────────┤
│  NestJS Backend (news_auth_check)                            │
│  - Authentication                                            │
│  - Request Routing                                           │
│  - Database Management                                       │
└──────────────────────┬──────────────────────────────────────┘
                       │
       ┌───────────────┴───────────────┐
       │                               │
┌──────▼──────────┐         ┌──────────▼─────────┐
│ Analysis Service│         │  Next.js Website   │
│  (Python)       │         │  (Public Interface)│
│  - Image Analysis         │  - Dashboard       │
│  - Fact Checking          │  - Analytics       │
│  - MinIO Storage          │  - User Portal     │
└─────────────────┘         └────────────────────┘
```

### Components

| Component | Technology | Purpose |
|-----------|-----------|---------|
| Mobile App | Flutter + Dart | iOS/Android client |
| Backend API | NestJS + TypeScript | Business logic & authentication |
| Analysis Engine | Python + FastAPI | AI model inference |
| Database | PostgreSQL (Drizzle ORM) | Data persistence |
| Storage | MinIO | File storage |
| Website | Next.js + React | Web interface |

## 📦 Prerequisites

### Required
- **Flutter SDK**: 3.11.0 or higher
- **Node.js**: 18.0.0 or higher
- **Python**: 3.9 or higher
- **Docker**: For containerized services
- **Git**: Version control

### Optional
- **Android Studio**: For Android development
- **Xcode**: For iOS development
- **PostgreSQL**: For local database (or use containerized version)

## ⚙️ Installation & Setup

### 1. Clone the Repository
```bash
git clone <repository-url>
cd AI_AND_FAKE_NEWS_DETECTOR
```

### 2. Flutter App Setup
```bash
cd ai_fake_news_detector

# Get Flutter dependencies
flutter pub get

# Configure environment
cp env.example.json env.dev.json
# Edit env.dev.json with your backend URL and API keys
```

### 3. NestJS Backend Setup
```bash
cd news_auth_check

# Install dependencies
pnpm install

# Configure environment
cp .env.example .env.local
# Edit .env.local with database credentials
```

### 4. Python Analysis Service Setup
```bash
cd analysis

# Create Python virtual environment
python -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate

# Install dependencies
pip install -r requirements.txt

# Configure environment
cp .env.example .env
# Edit .env with MinIO and model credentials
```

### 5. Next.js Website Setup
```bash
cd website

# Install dependencies
pnpm install

# Configure environment
cp .env.example .env.local
# Edit .env.local with API endpoints
```

## 🚀 Running the App

### Option 1: Docker Compose (Recommended for Development)
```bash
# From root directory
docker-compose up -d

# This starts:
# - PostgreSQL database
# - MinIO storage
# - Python analysis service
# - NestJS backend
# - Next.js website (optional)
```

### Option 2: Manual Development Setup

#### Terminal 1: Backend API
```bash
cd news_auth_check
pnpm run start:dev
# API runs on http://localhost:3000
```

#### Terminal 2: Python Analysis Service
```bash
cd analysis
source venv/bin/activate
python main.py
# Service runs on http://localhost:7860
```

#### Terminal 3: Flutter App
```bash
cd ai_fake_news_detector

# Android
flutter run -d android

# iOS
flutter run -d ios

# Web
flutter run -d web
```

#### Terminal 4: Next.js Website (Optional)
```bash
cd website
pnpm run dev
# Website runs on http://localhost:3001
```

## 📁 Project Structure

```
AI_AND_FAKE_NEWS_DETECTOR/
├── ai_fake_news_detector/          # Flutter mobile app
│   ├── lib/                        # Dart source code
│   ├── android/                    # Android configuration
│   ├── ios/                        # iOS configuration
│   ├── web/                        # Web build
│   ├── test/                       # Unit & widget tests
│   ├── pubspec.yaml               # Flutter dependencies
│   └── env/                        # Environment configs
│
├── news_auth_check/                # NestJS backend
│   ├── src/                        # TypeScript source
│   ├── test/                       # Test files
│   ├── drizzle/                    # Database migrations
│   ├── package.json               # Node dependencies
│   └── tsconfig.json              # TypeScript config
│
├── analysis/                       # Python analysis service
│   ├── main.py                    # FastAPI app
│   ├── service/                   # Service layer
│   ├── controller/                # API controllers
│   ├── models/                    # Data models
│   ├── requirements.txt           # Python dependencies
│   └── logs/                      # Application logs
│
├── website/                        # Next.js web interface
│   ├── src/                       # React components
│   ├── public/                    # Static assets
│   ├── package.json              # Node dependencies
│   └── tsconfig.json            # TypeScript config
│
└── _docs/                          # Documentation
    ├── implementation_plan.md
    ├── BUILD_INSTRUCTIONS.md
    └── flutter/                   # Flutter-specific docs
```

## 📡 API Documentation

### Backend Endpoints (NestJS)

See [NestJS README](./news_auth_check/README.md) for full API documentation.

**Key Endpoints:**
- `POST /auth/register` - User registration
- `POST /auth/login` - User authentication
- `POST /analysis/images` - Analyze image
- `POST /analysis/text` - Fact check text
- `GET /health` - Health check

### Analysis Service Endpoints (Python)

See [Analysis README](./analysis/README.md) for full API documentation.

**Key Endpoints:**
- `POST /analyze/image` - Image analysis
- `POST /analyze/video` - Video analysis
- `GET /health` - Service health check

## 🐳 Deployment

### Docker Deployment
```bash
# Build all services
docker-compose build

# Start production environment
docker-compose -f docker-compose.yml up -d

# View logs
docker-compose logs -f
```

### Cloud Deployment
See [Deployment Guide](./deployment_commands.md) for cloud platform-specific instructions.

## 🤝 Contributing

1. **Create a feature branch**: `git checkout -b feature/amazing-feature`
2. **Commit changes**: `git commit -m 'Add amazing feature'`
3. **Push to branch**: `git push origin feature/amazing-feature`
4. **Open a Pull Request**: Describe your changes and improvements

### Code Style
- **Flutter/Dart**: Follow [Dart style guide](https://dart.dev/guides/language/effective-dart/style)
- **TypeScript**: Follow ESLint configuration in each project
- **Python**: Follow PEP 8 style guide

## 📚 Documentation

Detailed documentation is available in the `_docs/` directory:
- [Implementation Checklist](./deployment_commands.md)
- [Flutter Build Instructions](./_docs/flutter/BUILD_INSTRUCTIONS.md)
- [Media Upload Implementation](./_docs/flutter/MEDIA_UPLOAD_IMPLEMENTATION_SUMMARY.md)
- [Notification System](./_docs/flutter/NATIVE_NOTIFICATION_SYSTEM.md)
- [Troubleshooting Guide](./_docs/flutter/TROUBLESHOOTING.md)

## 🐛 Troubleshooting

### Common Issues

**Flutter app not connecting to backend:**
- Check `env.dev.json` has correct backend URL
- Ensure NestJS backend is running on correct port
- Check firewall/network permissions

**Database connection errors:**
- Verify PostgreSQL is running
- Check database credentials in `.env`
- Run migrations: `pnpm run migrate`

**Python service not responding:**
- Check Python environment is activated
- Verify MinIO is accessible
- Check service logs for errors

See [Troubleshooting Guide](./_docs/flutter/TROUBLESHOOTING.md) for more solutions.

## 📞 Support

- **Documentation**: Check `_docs/` folder for detailed guides
- **Issues**: Report bugs via GitHub Issues
- **Discussions**: Ask questions in GitHub Discussions
- **Email**: Contact development team

## 📄 License

This project is provided as-is for educational and commercial use.

## 👥 Team

Developed by the AI and Fake News Detector team.

---

**Last Updated**: May 2026

For the latest information, check our [IMPLEMENTATION_CHECKLIST.md](./_docs/IMPLEMENTATION_CHECKLIST.md)
