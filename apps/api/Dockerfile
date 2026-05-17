FROM node:22-alpine

WORKDIR /app

RUN corepack enable && corepack prepare pnpm@10.22.0 --activate

COPY package.json pnpm-lock.yaml ./
RUN pnpm install --frozen-lockfile --prod

COPY index.js ./

ENV APP_VERSION=0.1.0
EXPOSE 4000

CMD ["node", "index.js"]
