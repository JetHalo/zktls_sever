# VerifyTrade Verifier Server
#
# Builds `tlsn-verifier-server` from source on every Railway deploy.
# Replaces the older notary-server (which PSE removed from the tlsn workspace
# at alpha.13). The verifier-server lives in tlsnotary/tlsn-extension under
# servers/verifier/ and is the active 2-party MPC counterpart for browser
# extension versions 0.1.0.14xx and 0.1.0.15xx.
#
# Build:   docker build -t verifytrade-verifier .
# Run:     docker run -p 7047:7047 verifytrade-verifier
# Railway: auto-builds from this Dockerfile (~5-10 min Rust compile)
#
# To bump the pinned upstream release, change TLSN_EXT_REF below and make sure
# the browser extension installed by the user is on the same tag.
#   0.1.0.1500  -> tlsn v0.1.0-alpha.15  (current)
#   0.1.0.1409  -> tlsn v0.1.0-alpha.15-pre
#   0.1.0.1402  -> tlsn v0.1.0-alpha.14

# ---- Build stage ---------------------------------------------------------
FROM rust:latest AS builder

WORKDIR /build

RUN apt-get update && apt-get install -y --no-install-recommends \
      pkg-config \
      libssl-dev \
      git \
      ca-certificates && \
    rm -rf /var/lib/apt/lists/*

ARG TLSN_EXT_REF=0.1.0.1500
RUN git clone --depth=1 --branch ${TLSN_EXT_REF} \
      https://github.com/tlsnotary/tlsn-extension.git /build/tlsn-extension

WORKDIR /build/tlsn-extension/servers

# Build only the verifier binary. The workspace also contains a `swissbank`
# demo crate which we don't need.
RUN cargo build --release --bin tlsn-verifier-server

# ---- Runtime stage -------------------------------------------------------
FROM debian:bookworm-slim

WORKDIR /app

RUN apt-get update && apt-get install -y --no-install-recommends \
      ca-certificates \
      libssl3 \
      wget && \
    rm -rf /var/lib/apt/lists/*

COPY --from=builder /build/tlsn-extension/servers/target/release/tlsn-verifier-server /app/tlsn-verifier-server
COPY config.yaml /app/config.yaml

# Crank up tracing inside the tlsn library so we can see exactly which step of
# the MPC handshake (Verifier::accept -> deps.setup -> ...) hangs.
# Default crates stay at warn to keep volume manageable.
ENV RUST_LOG=warn,tlsn=trace,tlsn_core=trace,mpc_tls=trace,mpz=debug,tlsn_verifier_server=debug

# tlsn-verifier-server hardcodes its bind address to 0.0.0.0:7047
# (upstream README: "configuration is currently hardcoded in main.rs").
# Railway terminates TLS at its edge proxy, so we serve plain HTTP/WS here.
EXPOSE 7047

HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://localhost:7047/health || exit 1

CMD ["/app/tlsn-verifier-server"]
