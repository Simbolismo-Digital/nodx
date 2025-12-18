# --- Build stage ---
FROM elixir:1.19.4-otp-28-alpine AS build

# Install build dependencies + Node.js + WireGuard
RUN apk add --no-cache \
    git \
    build-base \
    bash \
    curl \
    gnupg \
    linux-headers \
    iproute2 \
    wireguard-tools \
    openrc \
    procps \
    libc-dev \
    pkgconfig

# Install Node.js 25.2.1
RUN curl -fsSL https://unofficial-builds.nodejs.org/download/release/v25.2.1/node-v25.2.1-linux-x64-musl.tar.xz | tar -xJ -C /usr/local --strip-components=1

# Set working directory
WORKDIR /app

# Copy mix files and install deps
COPY mix.exs mix.lock ./
RUN mix do deps.get deps.compile

# Copy source code
COPY config config
COPY assets assets
COPY lib lib

# Compile assets
# RUN cd assets && npm install
RUN mix assets.deploy

# Build release
RUN MIX_ENV=prod mix release

# --- Runtime stage ---
FROM alpine:latest

# Install runtime dependencies
RUN apk add --no-cache \
    bash \
    ncurses-libs \
    openssl \
    wireguard-tools \
    iproute2 \
    procps \
    libc6-compat \
    libgcc \
    libstdc++

WORKDIR /app

# Copy release from build stage
COPY --from=build /app/_build/prod/rel/nodx ./

# Set default command
CMD ["bin/nodx", "start"]