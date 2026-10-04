# Build context: the repository root (so the shared core and the KB are visible).
#   docker build -f server/Dockerfile -t basirah-api .
FROM dart:stable AS build
WORKDIR /app
COPY packages/basirah_core packages/basirah_core
COPY server/pubspec.yaml server/pubspec.lock* server/
WORKDIR /app/server
RUN dart pub get
COPY server/ /app/server/
RUN dart pub get --offline && dart compile exe bin/server.dart -o /app/bin/server
# Quran text + al-Muyassar (≈5 MB, ~15 s from api.quran.com).
RUN dart run tool/fetch_quran.dart /app/data/quran.json

FROM scratch
COPY --from=build /runtime/ /
# Root certificates for HTTPS calls to api.anthropic.com and api.quran.com.
COPY --from=build /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/ca-certificates.crt
COPY --from=build /app/bin/server /app/bin/server
COPY --from=build /app/data/quran.json /app/data/quran.json
COPY assets/kb /app/assets/kb
WORKDIR /app
ENV KB_DIR=/app/assets/kb
ENV QURAN_FILE=/app/data/quran.json
ENV PORT=8080
EXPOSE 8080
CMD ["/app/bin/server"]
