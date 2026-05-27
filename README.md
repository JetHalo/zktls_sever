# VerifyTrade Verifier Server

`tlsn-verifier-server` (TLSNotary alpha.15), packaged for one-click Railway
deploy. This is the 2-party MPC counterpart that the in-browser TLSNotary
plugin talks to when notarizing a Binance Futures session.

## What changed vs the old notary-server

PSE removed `crates/notary/server` from the `tlsnotary/tlsn` workspace at
v0.1.0-alpha.13. The replacement is `tlsn-verifier-server` in the
`tlsnotary/tlsn-extension` repo under `servers/verifier/`. The wire protocol
is still MPC-TLS; the trust model shifted from "notary signs an attestation
that anyone can later verify offline" to "the verifier participates in the
MPC session and emits a presentation directly". The browser extension at
version `0.1.0.14xx` / `0.1.0.15xx` only talks to a verifier-server, not the
old notary-server.

## Deploy to Railway

1. Push this repo to GitHub.
2. Sign in to [Railway](https://railway.app).
3. `New Project → Deploy from GitHub repo → zktls_sever`.
4. Railway picks up `Dockerfile` + `railway.toml` automatically.
5. First build takes ~5-10 minutes (full Rust compile from source).
6. Once deployed, copy the public URL (looks like
   `verifytrade-verifier-production.up.railway.app`).

No env vars, no signing key, no secret material needed. The verifier model
does not use a long-lived ECDSA key.

## Connect from the browser plugin

Inside `veirfytrade/plugin/`:

```bash
VERIFIER_URL="https://<your-railway-url>"  \
PROXY_URL="wss://<your-railway-url>/proxy?token="  \
node esbuild.js
```

The plugin's `prove()` call will then open a WebSocket to
`<verifier-url>/session` to begin the MPC handshake.

## Local testing

```bash
docker build -t verifytrade-verifier .
docker run -p 7047:7047 verifytrade-verifier

# In another terminal:
curl http://localhost:7047/health
# expect HTTP 200
```

## Endpoints exposed

| Endpoint                       | Role                                                        |
| ------------------------------ | ----------------------------------------------------------- |
| `GET  /health`                 | Liveness check (Railway uses this).                         |
| `WS   /session`                | Create a new verification session, returns a session id.    |
| `WS   /verifier?sessionId=<id>` | Two-party MPC verification channel (the "other half").     |
| `WS   /proxy?token=<host>`     | TCP relay so the browser can reach the TLS target server.   |

`/proxy` is **not** a man-in-the-middle proxy; it just shuttles ciphertext
bytes between the browser and the target. The MPC keying material is split
across `/verifier` and the browser-side prover, so this server alone cannot
decrypt the user's traffic.

## Pinning the upstream release

The Dockerfile has `ARG TLSN_EXT_REF=0.1.0.1500`. To rebuild against a
different upstream tag (e.g. when alpha.16 ships), edit that line and trigger
a redeploy. The chrome extension version must match.

| Extension tag    | tlsn protocol      |
| ---------------- | ------------------ |
| `0.1.0.1500`     | `v0.1.0-alpha.15`  |
| `0.1.0.1409`     | `v0.1.0-alpha.15-pre` |
| `0.1.0.1402`     | `v0.1.0-alpha.14`  |

## Cost on Railway

Verifier idles at ~256 MB RAM, ~negligible CPU. Roughly the same as the old
notary-server -- expect ~$0.005-0.01/hour at idle.

## References

- [tlsnotary/tlsn-extension](https://github.com/tlsnotary/tlsn-extension)
- [Verifier README](https://github.com/tlsnotary/tlsn-extension/tree/main/servers/verifier)
- [Railway docs](https://docs.railway.app/)
