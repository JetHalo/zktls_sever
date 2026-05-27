# VerifyTrade Notary Server
# Based on TLSNotary's official notary-server, configured for Railway deployment
#
# Build:   docker build -t verifytrade-notary .
# Run:     docker run -p 7047:7047 verifytrade-notary
# Railway: Railway auto-builds from this Dockerfile

# Pinned to v0.1.0-alpha.12 -- the latest pre-built image on ghcr.io.
# PSE stopped publishing notary-server images after alpha.12 (they narrowed
# project scope to core libraries / SDK; see PSE blog Feb 2026).
# If wire protocol drift breaks MPC, the fallback is to build from source.
FROM ghcr.io/tlsnotary/tlsn/notary-server:v0.1.0-alpha.12

WORKDIR /app

# Copy our config (overrides defaults)
COPY notary-config.yaml /app/config/config.yaml

# Railway dynamically assigns PORT; we listen on 7047 and let Railway proxy
ENV NOTARY_PORT=7047
EXPOSE 7047

# Health check (Railway uses this to verify the service is up)
HEALTHCHECK --interval=30s --timeout=10s --start-period=20s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://localhost:7047/info || exit 1

CMD ["/usr/local/bin/notary-server", "--config-file", "/app/config/config.yaml"]
