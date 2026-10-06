# One service for the whole of Basirah: the API and the web app on one link.
# Build context: the repository root (so the shared core, the KB and the web
# build are visible).
#   docker build -t basirah .        (from the repository root)
# The web app in server/web is built by tool/build_web_for_deploy.ps1.
FROM dart:stable AS build
WORKDIR /app
COPY packages/basirah_core packages/basirah_core
COPY server/pubspec.yaml server/pubspec.lock* server/
WORKDIR /app/server
RUN dart pub get
COPY server/ /app/server/
RUN dart pub get --offline && dart compile exe bin/server.dart -o /app/bin/server
# The Quran text (QuranEnc + Quranpedia, the package's sources) and al-Muyassar.
RUN dart run tool/fetch_quran.dart /app/data/quran.json

FROM scratch
COPY --from=build /runtime/ /
# Root certificates for the HTTPS calls (the AI provider, Dorar, HadeethEnc,
# QuranEnc, mp3quran).
COPY --from=build /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/ca-certificates.crt
COPY --from=build /app/bin/server /app/bin/server
COPY --from=build /app/data/quran.json /app/data/quran.json
COPY assets/kb /app/assets/kb
COPY server/web /app/web
COPY server/seed /app/seed
WORKDIR /app
ENV KB_DIR=/app/assets/kb
ENV QURAN_FILE=/app/data/quran.json
ENV WEB_DIR=/app/web
ENV PORT=8080
EXPOSE 8080
CMD ["/app/bin/server"]
