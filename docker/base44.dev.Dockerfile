# Dev-only runtime image for the Base44 sandbox preview.
#
# Base image plus the native-module build toolchain only — no application source
# is copied in. The repository is bind-mounted at run time and dependencies are
# installed by the compose start command, so source edits are picked up without
# rebuilding this image. (The project's own Dockerfile bakes `src`/`public` and a
# production `npm ci`, which would freeze the code for the edit loop.)
#
# Base image and system packages mirror the project's Dockerfile, so
# better-sqlite3 and ffmpeg-static resolve the same way they do in production.
FROM node:24-alpine

RUN apk add --no-cache python3 make g++

WORKDIR /app

# Mount points for the compose volumes (dependencies, runtime data).
RUN mkdir -p /app/node_modules /data
