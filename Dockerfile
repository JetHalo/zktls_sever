# VerifyTrade Notary Server
# Based on TLSNotary's official notary-server, configured for Railway deployment
#
# Build:   docker build -t verifytrade-notary .
# Run:     docker run -p 7047:7047 verifytrade-notary
# Railway: Railway auto-builds from this Dockerfile

# Pinned to v0.1.0-alpha.14 to match prover/Cargo.toml's tlsn crate tag.
# If you change either, update both in lockstep — wire protocol must match.
FROM ghcr.io/tlsnotary/tlsn/notary-server:v0.1.0-alpha.14

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
