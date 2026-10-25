# PandaPewPew server: Bun lobby backend + Godot headless dedicated servers.
# Built for linux/arm64 (the k3s nodes are Raspberry Pis). The backend spawns
# `godot --headless --path . -- --server --port=<7800-7999>` with its working
# directory at the Godot project root, so the image must contain both the
# backend (server/) and the full game project, with `godot` on PATH.
FROM oven/bun:1

ARG GODOT_VERSION=4.3-stable

USER root

# Godot's editor binary still links X11/GL/audio libs even for --headless runs.
RUN apt-get update && apt-get install -y --no-install-recommends \
      ca-certificates curl unzip \
      libx11-6 libxext6 libxcursor1 libxrandr2 libxinerama1 libxi6 libgl1 libasound2 \
    && rm -rf /var/lib/apt/lists/* \
    && curl -fsSL -o /tmp/godot.zip \
      "https://github.com/godotengine/godot-builds/releases/download/${GODOT_VERSION}/Godot_v${GODOT_VERSION}_linux.arm64.zip" \
    && unzip -q /tmp/godot.zip -d /tmp \
    && mv "/tmp/Godot_v${GODOT_VERSION}_linux.arm64" /usr/local/bin/godot \
    && chmod +x /usr/local/bin/godot \
    && rm /tmp/godot.zip \
    && godot --version

WORKDIR /app

COPY project.godot ./
COPY scripts ./scripts
COPY scenes ./scenes
COPY server ./server

RUN cd server && bun install

ENV PORT=3000
EXPOSE 3000

CMD ["bun", "run", "server/src/server.ts"]
