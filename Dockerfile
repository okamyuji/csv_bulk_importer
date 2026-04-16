# syntax=docker/dockerfile:1
# check=error=true
#
# Multi-stage production Dockerfile for csv_bulk_importer.
# Targets: "web" (default) and "worker" (Solid Queue).
#
# Build:
#   docker build -t csv-bulk-importer:latest .
#   docker build -t csv-bulk-importer:worker --target worker .
#
# Run:
#   docker run -p 80:80 -e RAILS_MASTER_KEY=<key> csv-bulk-importer:latest
#   docker run -e RAILS_MASTER_KEY=<key> csv-bulk-importer:worker

# ---------------------------------------------------------------------------
# Stage 0: base — shared runtime packages (production only)
# ---------------------------------------------------------------------------
ARG RUBY_VERSION=3.4.8
FROM docker.io/library/ruby:${RUBY_VERSION}-slim AS base

WORKDIR /rails

RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y \
      curl \
      default-mysql-client \
      libjemalloc2 && \
    ln -s /usr/lib/$(uname -m)-linux-gnu/libjemalloc.so.2 /usr/local/lib/libjemalloc.so && \
    apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false && \
    rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/*

ENV RAILS_ENV="production" \
    BUNDLE_DEPLOYMENT="1" \
    BUNDLE_PATH="/usr/local/bundle" \
    BUNDLE_WITHOUT="development:test" \
    LD_PRELOAD="/usr/local/lib/libjemalloc.so" \
    RAILS_LOG_TO_STDOUT="1" \
    RAILS_SERVE_STATIC_FILES="1" \
    MALLOC_ARENA_MAX="2"

# ---------------------------------------------------------------------------
# Stage 1: gems — install gems in a throwaway layer
# ---------------------------------------------------------------------------
FROM base AS gems

RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y \
      build-essential \
      default-libmysqlclient-dev \
      git \
      libyaml-dev \
      pkg-config && \
    rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/*

COPY Gemfile Gemfile.lock ./

RUN --mount=type=cache,target=/usr/local/bundle/cache \
    bundle install --jobs=$(nproc) --retry=3 && \
    rm -rf "${BUNDLE_PATH}"/ruby/*/cache \
           "${BUNDLE_PATH}"/ruby/*/bundler/gems/*/.git \
           "${BUNDLE_PATH}"/ruby/*/gems/*/spec \
           "${BUNDLE_PATH}"/ruby/*/gems/*/test

# ---------------------------------------------------------------------------
# Stage 2: frontend — build Vite SPA
# ---------------------------------------------------------------------------
FROM node:22-slim AS frontend

WORKDIR /app/frontend

COPY frontend/package.json frontend/pnpm-lock.yaml ./

RUN corepack enable pnpm && \
    pnpm install --frozen-lockfile --ignore-scripts --prod=false

COPY frontend/ ./

RUN pnpm run build && \
    rm -rf node_modules

# ---------------------------------------------------------------------------
# Stage 3: build — combine gems + app code, precompile
# ---------------------------------------------------------------------------
FROM gems AS build

COPY . .

# Copy frontend dist into public/ so Rails serves it.
COPY --from=frontend /app/frontend/dist /rails/public/

RUN bundle exec bootsnap precompile --gemfile app/ lib/ && \
    SECRET_KEY_BASE_DUMMY=1 ./bin/rails assets:precompile && \
    rm -rf tmp/cache tmp/pids log/*.log

# ---------------------------------------------------------------------------
# Stage 4: web — final production image (default target)
# ---------------------------------------------------------------------------
FROM base AS web

RUN groupadd --system --gid 1000 rails && \
    useradd rails --uid 1000 --gid 1000 --create-home --shell /bin/bash && \
    mkdir -p /rails/tmp/pids /rails/tmp/cache /rails/log && \
    chown -R rails:rails /rails

USER 1000:1000

COPY --chown=rails:rails --from=build "${BUNDLE_PATH}" "${BUNDLE_PATH}"
COPY --chown=rails:rails --from=build /rails /rails

ENTRYPOINT ["/rails/bin/docker-entrypoint"]
EXPOSE 80
HEALTHCHECK --interval=15s --timeout=3s --start-period=30s \
  CMD curl -fs http://localhost:80/up || exit 1

CMD ["./bin/thrust", "./bin/rails", "server"]

# ---------------------------------------------------------------------------
# Stage 5: worker — Solid Queue (same image, different CMD)
# ---------------------------------------------------------------------------
FROM web AS worker

EXPOSE 0
HEALTHCHECK --interval=30s --timeout=5s --start-period=15s \
  CMD pgrep -f solid_queue || exit 1

CMD ["./bin/jobs"]
