FROM ubuntu:24.04 AS flutter-build

WORKDIR /workspace
ARG FLUTTER_VERSION=3.50.1

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        git \
        libglu1-mesa \
        unzip \
        xz-utils \
        zip \
    && rm -rf /var/lib/apt/lists/*

RUN git clone --depth 1 --branch "${FLUTTER_VERSION}" \
    https://github.com/flutter/flutter.git /opt/flutter
ENV PATH="/opt/flutter/bin:/opt/flutter/bin/cache/dart-sdk/bin:${PATH}" \
    TAR_OPTIONS="--no-same-owner"

RUN flutter config --no-analytics --enable-web \
    && flutter precache --web \
    && flutter --version \
    && dart --version

COPY pubspec.yaml pubspec.lock ./
RUN flutter pub get
COPY . .
RUN flutter build web --release \
    --base-href / \
    --dart-define=API_BASE_URL=same-origin

FROM node:22-bookworm-slim AS app

WORKDIR /app
ENV NODE_ENV=production
ENV WEB_ROOT=/app/web

COPY backend/package.json backend/package-lock.json ./
RUN npm ci --omit=dev
COPY backend/src ./src
COPY --from=flutter-build /workspace/build/web ./web

EXPOSE 3000
CMD ["npm", "start"]
