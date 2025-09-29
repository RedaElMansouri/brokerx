# Dockerfile
FROM ruby:3.2.2-slim-bookworm

# Installer les dépendances système
RUN apt-get update -qq && \
    apt-get install -y \
    build-essential \
    pkg-config \
    libpq-dev \
    nodejs \
    npm \
    git \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Installer Yarn
RUN npm install -g yarn

# Créer le répertoire de l'application
WORKDIR /app

# Copier les fichiers de dépendances
COPY Gemfile Gemfile.lock ./

# Installer les gems
RUN bundle config set force_ruby_platform true && \
    bundle config set without 'development test' && \
    bundle install --jobs=4 --retry=3

# Copier le reste de l'application
COPY . .

# Créer le dossier pour les PID files
RUN mkdir -p tmp/pids

# Exposer le port
EXPOSE 3000

# Commande de démarrage
CMD ["rails", "server", "-b", "0.0.0.0", "-p", "3000"]