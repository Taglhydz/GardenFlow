# Image of the API, started by deploy/docker-compose.yml (guide : deploy/README.md)
FROM node:22-bookworm-slim

ENV NODE_ENV=production
WORKDIR /app

# production dependencies only (bcrypt uses a prebuilt binary : no compiler needed)
COPY package.json package-lock.json ./
RUN npm ci --omit=dev && npm cache clean --force

COPY src ./src
COPY scripts ./scripts

# photos sent by the users : a volume is mounted here, it keeps the owner of the folder
ENV UPLOADS_DIR=/data/uploads
RUN mkdir -p /data/uploads && chown -R node:node /data
USER node

EXPOSE 3000

# the pending migrations are applied first : in production the server refuses to start without them
CMD ["sh", "-c", "node scripts/migrate.js up && exec node src/server.js"]
