# Clients Service - Microservice for Client Management
# Port: 3001
# Database: PostgreSQL (clients_db on port 5433)

## Responsibilities

This microservice handles:
- **UC-01**: Inscription et Vérification du Client
- **UC-02**: Authentification Multi-Facteurs (MFA)

## API Endpoints

### Registration & Verification (UC-01)
- `POST /api/v1/clients` - Register new client
- `POST /api/v1/clients/:id/verify_email` - Verify email with token
- `POST /api/v1/clients/:id/resend_verification` - Resend verification email
- `GET /api/v1/clients/:id` - Get client profile

### Authentication (UC-02)
- `POST /api/v1/auth/login` - Login (sends MFA code)
- `POST /api/v1/auth/verify_mfa` - Verify MFA code
- `POST /api/v1/auth/logout` - Logout
- `POST /api/v1/auth/refresh_token` - Refresh JWT token
- `GET /api/v1/me` - Get current user

### Health & Metrics
- `GET /health` - Health check
- `GET /metrics` - Prometheus metrics

## Database Tables

- `clients` - Client accounts
- `verification_tokens` - Email verification tokens
- `mfa_codes` - MFA codes
- `sessions` - User sessions
- `outbox_events` - Event outbox for inter-service communication

## Running Locally

```bash
cd services/clients-service

# Install dependencies
bundle install

# Setup database
rails db:create db:migrate db:seed

# Start server
rails server -p 3001
```

## Running with Docker

```bash
docker-compose -f docker-compose.microservices.yml up clients-service
```

## Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| DATABASE_HOST | PostgreSQL host | localhost |
| DATABASE_PORT | PostgreSQL port | 5433 |
| DATABASE_USERNAME | DB username | postgres |
| DATABASE_PASSWORD | DB password | postgres |
| REDIS_URL | Redis URL | redis://localhost:6379/0 |
| JWT_SECRET_KEY | Secret for JWT tokens | (generated) |
| SMTP_HOST | SMTP server host | localhost |
| SMTP_PORT | SMTP server port | 1025 |
| APP_URL | Base URL for emails | http://localhost:3001 |

## Events Published

| Event | Description |
|-------|-------------|
| `client.registered` | New client registered |
| `client.email_verified` | Email verified |
| `client.logged_in` | Client logged in |
