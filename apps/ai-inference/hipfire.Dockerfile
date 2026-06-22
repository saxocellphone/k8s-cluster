FROM rocm/dev-ubuntu-24.04:7.2.4-complete AS builder

ARG HIPFIRE_REF=master
ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    ca-certificates \
    curl \
    git \
    pkg-config \
    unzip \
    && rm -rf /var/lib/apt/lists/*

RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
ENV PATH=/root/.cargo/bin:/root/.bun/bin:/opt/rocm/bin:$PATH
RUN curl -fsSL https://bun.sh/install | bash

WORKDIR /src
RUN git clone --depth 1 --branch ${HIPFIRE_REF} https://github.com/Kaden-Schutt/hipfire.git .
RUN cargo build --release --features deltanet --example daemon --example infer --example infer_hfq --example triattn_validate -p hipfire-runtime
RUN cargo build --release -p hipfire-tui || true

FROM rocm/dev-ubuntu-24.04:7.2.4-complete

ENV DEBIAN_FRONTEND=noninteractive \
    HIPFIRE_HOME=/models/hipfire-home \
    HOME=/models/hipfire-home \
    PATH=/models/hipfire-home/.hipfire/bin:/models/hipfire-home/.bun/bin:/opt/rocm/bin:$PATH

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    git \
    unzip \
    && rm -rf /var/lib/apt/lists/*

RUN curl -fsSL https://bun.sh/install | bash

COPY --from=builder /src/target/release/examples/daemon /opt/hipfire/bin/daemon
COPY --from=builder /src/target/release/examples/infer /opt/hipfire/bin/infer
COPY --from=builder /src/target/release/examples/infer_hfq /opt/hipfire/bin/infer_hfq
COPY --from=builder /src/target/release/examples/triattn_validate /opt/hipfire/bin/triattn_validate
COPY --from=builder /src/target/release/hipfire-tui /opt/hipfire/bin/hipfire-tui
COPY --from=builder /src/cli /opt/hipfire/cli
COPY --from=builder /src/registry /opt/hipfire/registry
COPY --from=builder /src/kernels /opt/hipfire/kernels

RUN rm -rf /opt/hipfire/cli/node_modules \
    /opt/hipfire/cli/.gitignore \
    /opt/hipfire/cli/tsconfig.json \
    /opt/hipfire/cli/README.md \
    /opt/hipfire/cli/bun.lock \
    && find /opt/hipfire/cli -maxdepth 1 -type f \( -name '*.test.ts' -o -name 'test_*.ts' -o -name 'bench_*.ts' \) -delete

RUN cat >/usr/local/bin/hipfire <<'EOF'
#!/bin/bash
set -euo pipefail
export HOME="${HIPFIRE_HOME:-/models/hipfire-home}"
export HIPFIRE_HOME="$HOME"
mkdir -p "$HOME/.hipfire/bin" "$HOME/.hipfire/models" "$HOME/.hipfire/cli"
for binary in daemon infer infer_hfq triattn_validate hipfire-tui; do
  if [[ -x "/opt/hipfire/bin/$binary" && ! -e "$HOME/.hipfire/bin/$binary" ]]; then
    ln -s "/opt/hipfire/bin/$binary" "$HOME/.hipfire/bin/$binary"
  fi
done
if [[ ! -e "$HOME/.hipfire/cli/index.ts" ]]; then
  cp -R /opt/hipfire/cli/. "$HOME/.hipfire/cli/"
fi
exec /root/.bun/bin/bun run "$HOME/.hipfire/cli/index.ts" "$@"
EOF
RUN chmod +x /usr/local/bin/hipfire

COPY apps/ai-inference/hipfire-serve.sh /usr/local/bin/hipfire-serve.sh
RUN chmod +x /usr/local/bin/hipfire-serve.sh

EXPOSE 11435
CMD ["/usr/local/bin/hipfire-serve.sh"]
