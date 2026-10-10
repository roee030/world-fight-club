# Online relay for World Fight Club (see docs/online-relay.md).
FROM debian:bookworm-slim
RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates curl unzip && rm -rf /var/lib/apt/lists/*
RUN curl -L --fail -o /tmp/godot.zip https://github.com/godotengine/godot/releases/download/4.7.2-stable/Godot_v4.7.2-stable_linux.x86_64.zip \
 && unzip -q /tmp/godot.zip -d /opt/godot && rm /tmp/godot.zip \
 && mv /opt/godot/Godot_v4.7.2-stable_linux.x86_64 /usr/local/bin/godot
WORKDIR /app
COPY project.godot ./
COPY server ./server
ENV PORT=9080
EXPOSE 9080
CMD ["godot", "--headless", "--path", "/app", "--script", "res://server/relay_main.gd"]
