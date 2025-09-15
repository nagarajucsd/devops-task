# Dockerfile (place in repo root)
### builder
FROM node:18-alpine AS builder
WORKDIR /app
COPY package*.json ./
RUN npm ci
COPY . .
# If project has build step: RUN npm run build

### production
FROM node:18-alpine
WORKDIR /app
# copy only what is needed from builder
COPY --from=builder /app . 
ENV NODE_ENV=production
EXPOSE 3000
# use non-root user (optional)
RUN addgroup -S appgrp && adduser -S appuser -G appgrp
USER appuser
CMD ["node", "index.js"]

