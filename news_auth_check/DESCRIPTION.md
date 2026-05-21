# News Auth Check - Backend API

## Overview

The central backend API service for the AI and Fake News Detector system. This NestJS application orchestrates all business logic, user authentication, data management, and communication between the Flutter mobile app and the Python analysis service.

## Purpose

This service provides:
- **User Authentication & Authorization**: Secure registration, login, and token management
- **API Gateway**: Central hub for all client requests
- **Fact-Checking Logic**: Orchestration of text analysis and verification
- **Image Analysis Routing**: Request forwarding to Python analysis service
- **Data Persistence**: Database operations with Drizzle ORM
- **Error Handling**: Centralized error management and logging
- **Rate Limiting**: Protection against abuse and DDoS attacks

## Key Responsibilities

### Authentication Service
- User registration with validation
- Secure password handling (hashing)
- JWT token generation and validation
- Session management
- Role-based access control (RBAC)

### Analysis Orchestration
- Receive analysis requests from Flutter app
- Forward requests to Python FastAPI service
- Process and transform analysis results
- Cache results for performance
- Manage request queue and prioritization

### Data Management
- User profile management
- Analysis history storage
- Result caching
- Search and filter capabilities
- Analytics data collection

### External Service Integration
- Python analysis service communication
- MinIO file storage integration
- Third-party API integrations
- Webhook support for notifications

## Technology Stack

| Technology | Purpose |
|-----------|---------|
| **NestJS 10+** | Progressive Node.js framework |
| **TypeScript** | Type-safe language |
| **PostgreSQL** | Primary database |
| **Drizzle ORM** | Database abstraction |
| **JWT** | Authentication tokens |
| **Passport.js** | Authentication middleware |
| **Axios** | HTTP client for external services |
| **Pnpm** | Package manager |
| **Docker** | Containerization |

## Project Structure

```
news_auth_check/
├── src/
│   ├── main.ts                   # Application entry point
│   │
│   ├── auth/
│   │   ├── auth.controller.ts    # Auth endpoints
│   │   ├── auth.service.ts       # Auth logic
│   │   ├── auth.module.ts        # Auth module
│   │   ├── jwt.strategy.ts       # JWT authentication
│   │   └── roles.guard.ts        # Role-based access
│   │
│   ├── analysis/
│   │   ├── analysis.controller.ts
│   │   ├── analysis.service.ts
│   │   └── analysis.module.ts
│   │
│   ├── users/
│   │   ├── users.controller.ts
│   │   ├── users.service.ts
│   │   └── users.module.ts
│   │
│   ├── common/
│   │   ├── filters/             # Exception filters
│   │   ├── guards/              # Authentication guards
│   │   ├── interceptors/        # Request/response interceptors
│   │   ├── pipes/               # Data validation pipes
│   │   └── decorators/          # Custom decorators
│   │
│   ├── config/
│   │   ├── database.config.ts
│   │   ├── env.validation.ts
│   │   └── app.config.ts
│   │
│   └── app.module.ts            # Root module
│
├── drizzle/
│   ├── migrations/              # Database migrations
│   └── schema.ts                # Database schema
│
├── test/                        # Test files
├── package.json                 # Dependencies
├── tsconfig.json               # TypeScript config
├── .env.example                # Environment template
└── nest-cli.json              # NestJS CLI config
```

## Core Modules

### Auth Module
**Handles**: User authentication and authorization
- Registration validation
- Login with credentials
- JWT token generation
- Token refresh mechanism
- Password reset flow
- Email verification (optional)

### Analysis Module
**Handles**: Analysis request orchestration
- Receive fact-check requests
- Route to Python service
- Transform analysis results
- Store results in database
- Provide result retrieval endpoints

### Users Module
**Handles**: User data management
- Profile retrieval and updates
- User preferences
- Subscription management
- Activity history
- Account deletion

### Common Module
**Handles**: Shared utilities
- Exception filters for error handling
- JWT authentication strategy
- Role-based access guards
- Input validation pipes
- Request/response logging interceptors

## Key Endpoints

### Authentication
```
POST   /auth/register              Register new user
POST   /auth/login                 Login user
POST   /auth/refresh               Refresh JWT token
POST   /auth/logout                Logout user
POST   /auth/forgot-password       Request password reset
POST   /auth/reset-password        Reset password
```

### Analysis
```
POST   /analysis/text              Fact-check text
POST   /analysis/image             Analyze image
POST   /analysis/video             Analyze video
GET    /analysis/results/:id       Get analysis result
GET    /analysis/history           Get user's analysis history
DELETE /analysis/results/:id       Delete analysis result
```

### Users
```
GET    /users/profile              Get user profile
PUT    /users/profile              Update user profile
GET    /users/preferences          Get user preferences
PUT    /users/preferences          Update preferences
DELETE /users/account              Delete account
```

### Health
```
GET    /health                     Health check
GET    /health/deep                Deep health check with dependencies
```

## Database Schema

### Users Table
- `id`: UUID primary key
- `email`: Unique email address
- `password`: Hashed password
- `firstName`: User first name
- `lastName`: User last name
- `role`: User role (admin, user)
- `isEmailVerified`: Email verification status
- `createdAt`: Registration timestamp
- `updatedAt`: Last update timestamp

### Analysis Results Table
- `id`: UUID primary key
- `userId`: Foreign key to users
- `type`: Analysis type (text, image, video)
- `inputContent`: Stored input data
- `result`: Analysis results JSON
- `confidence`: Confidence score
- `createdAt`: Analysis timestamp

### Authentication Tokens Table
- `id`: UUID primary key
- `userId`: Foreign key to users
- `token`: JWT token
- `refreshToken`: Refresh token
- `expiresAt`: Token expiration
- `isRevoked`: Token revocation status

## Environment Configuration

Create `.env.local`:
```env
# Application
NODE_ENV=development
PORT=3000

# Database
DATABASE_URL=postgresql://user:password@localhost:5432/ai_fake_news_db

# JWT
JWT_SECRET=your-secret-key
JWT_EXPIRATION=24h

# Analysis Service
ANALYSIS_SERVICE_URL=http://localhost:7860

# MinIO
MINIO_ENDPOINT=localhost
MINIO_PORT=9000
MINIO_ACCESS_KEY=minioadmin
MINIO_SECRET_KEY=minioadmin

# CORS
CORS_ORIGIN=http://localhost:3001
```

## Development Workflow

### Setup
```bash
pnpm install
pnpm run migrate:dev
pnpm run seed  # Optional: seed database
```

### Running
```bash
# Development with hot reload
pnpm run start:dev

# Production build
pnpm run build
pnpm run start:prod

# Watch mode
pnpm run watch
```

### Database Management
```bash
# Run migrations
pnpm run migrate:dev

# Generate migration
pnpm run migrate:generate

# Reset database
pnpm run migrate:reset
```

### Testing
```bash
# Unit tests
pnpm run test

# E2E tests
pnpm run test:e2e

# Test coverage
pnpm run test:cov
```

## API Communication Flow

1. **Client Request** → Flutter app sends HTTP request with JWT token
2. **Authentication** → Passport JWT strategy validates token
3. **Authorization** → Roles guard checks user permissions
4. **Validation** → Input validation pipe validates request data
5. **Processing** → Controller routes to appropriate service
6. **Business Logic** → Service processes request
7. **Database** → Drizzle ORM handles data persistence
8. **External Call** → May call Python analysis service
9. **Response** → Controller returns formatted response
10. **Interception** → Response interceptor adds metadata
11. **Client Receives** → Flutter app processes response

## Error Handling

- **400 Bad Request**: Invalid input data
- **401 Unauthorized**: Missing or invalid JWT token
- **403 Forbidden**: Insufficient permissions
- **404 Not Found**: Resource not found
- **429 Too Many Requests**: Rate limit exceeded
- **500 Internal Server Error**: Server error
- **503 Service Unavailable**: External service failure

## Security Features

- JWT token-based authentication
- Password hashing with bcrypt
- CORS protection
- Rate limiting on API endpoints
- Input validation and sanitization
- SQL injection prevention via ORM
- HTTPS/TLS support in production
- Environment variable protection
- Request/response logging for audit trail

## Deployment

### Docker
```bash
docker build -t news-auth-check .
docker run -p 3000:3000 \
  -e DATABASE_URL=... \
  -e JWT_SECRET=... \
  news-auth-check
```

### Environment Variables
All sensitive data must use environment variables. Never commit `.env.local`.

## Performance Optimization

- Database query optimization with indexes
- Response caching strategies
- Request batching support
- Async/await for non-blocking operations
- Connection pooling for database
- Load balancing with multiple instances

## Monitoring & Logging

- Structured JSON logging
- Request/response logging with correlation IDs
- Performance metrics collection
- Error tracking and alerting
- Health check endpoints for monitoring

## Integration Points

- **Flutter App**: REST API communication
- **Python Analysis Service**: HTTP requests for analysis
- **PostgreSQL**: Primary data store
- **MinIO**: File storage
- **Authentication**: Third-party OAuth (optional)

## Related Documentation

- [NestJS Documentation](https://docs.nestjs.com/)
- [Drizzle ORM Documentation](https://orm.drizzle.team/)
- [JWT Authentication Best Practices](https://tools.ietf.org/html/rfc7519)

---

**Last Updated**: May 2026
**Version**: 1.0.0
**Framework**: NestJS 10+
