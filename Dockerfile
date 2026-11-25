FROM ghcr.io/cirruslabs/flutter:stable AS flutter-build

WORKDIR /workspace
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
