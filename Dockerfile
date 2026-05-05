# =========================
# 1️⃣ BUILD STAGE
# =========================
FROM node:22-slim AS build

WORKDIR /app

# Install required packages
RUN apt-get update && apt-get install -y \
    git \
    openssh-client \
    && rm -rf /var/lib/apt/lists/*

# Setup SSH properly
RUN mkdir -p /root/.ssh

# Copy SSH keys FIRST
COPY ssh_keys/ /root/.ssh

# Fix permissions (important)
RUN chmod 700 /root/.ssh && \
    chmod 600 /root/.ssh/id_rsa

# Add GitHub to known_hosts
RUN ssh-keyscan github.com >> /root/.ssh/known_hosts

# Copy project
COPY . .

# Init submodules
RUN git submodule update --init --recursive

# Checkout branch
RUN git -C ./bifi_app_be checkout nodev22

# Install dependencies
RUN npm --prefix ./bifi_app_be install

# Build project
ENV NODE_OPTIONS=--max_old_space_size=4096
RUN npm --prefix ./bifi_app_be run build


# =========================
# 2️⃣ RUNTIME STAGE
# =========================
FROM node:22-slim

WORKDIR /app

ENV NODE_ENV=production

# Puppeteer dependencies
RUN apt-get update && apt-get install -y \
    ca-certificates \
    fonts-liberation \
    libasound2 \
    libatk-bridge2.0-0 \
    libatk1.0-0 \
    libcups2 \
    libdbus-1-3 \
    libdrm2 \
    libgbm1 \
    libgtk-3-0 \
    libnspr4 \
    libnss3 \
    libx11-xcb1 \
    libxcomposite1 \
    libxdamage1 \
    libxfixes3 \
    libxrandr2 \
    xdg-utils \
    wget \
    openssh-client \
    --no-install-recommends \
    && rm -rf /var/lib/apt/lists/*

# Copy package.json first (better cache)
COPY --from=build /app/bifi_app_be/package*.json ./

# Install only production deps
RUN npm install --omit=dev

# Copy built app
COPY --from=build /app/bifi_app_be/dist ./dist

# Expose port
EXPOSE 8081

# Run app
CMD ["node", "dist/index.js"]
