## Dockerfile multi-étages (proche production)

# --- Image de base avec dépendances système
FROM ruby:3.2.2-slim-bookworm AS base

ENV BUNDLE_WITHOUT=development:test \
    BUNDLE_JOBS=4 \
    BUNDLE_RETRY=3

RUN apt-get update -qq && \
    apt-get install -y --no-install-recommends \
        build-essential \
        pkg-config \
        libpq-dev \
        nodejs \
        npm \
        git \
        curl \
    && rm -rf /var/lib/apt/lists/*

RUN npm install -g yarn

WORKDIR /app

# --- Étape builder : installation des gems et préparation de l'application
FROM base AS builder

COPY Gemfile Gemfile.lock ./
RUN bundle config set force_ruby_platform true && \
    bundle install && \
    bundle clean

COPY . .

# --- Étape exécution : image allégée (dépendances runtime + application + gems)
FROM ruby:3.2.2-slim-bookworm AS runtime

RUN apt-get update -qq && \
    apt-get install -y --no-install-recommends \
        libpq-dev \
        curl \
    && rm -rf /var/lib/apt/lists/*

ENV RAILS_ENV=production \
    RACK_ENV=production \
    RAILS_LOG_TO_STDOUT=true

WORKDIR /app

# Copier les gems Ruby depuis l'étape builder
COPY --from=builder /usr/local/bundle /usr/local/bundle

# Copier le code de l'application
COPY --from=builder /app /app

# Créer les répertoires temporaires utilisés par Rails/Puma
RUN mkdir -p tmp/pids tmp/cache tmp/sockets

EXPOSE 3000

CMD ["bash", "-lc", "bundle exec rails server -b 0.0.0.0 -p 3000"]