# Stage 1: Build
FROM node:22-alpine AS builder

WORKDIR /app

# Arguments for version tracking
ARG SHATARI_FRONT_VERSION=master

RUN apk add --no-cache git

# Clone and build
RUN git clone https://github.com/erorus/shatari-front.git . && \
    git checkout ${SHATARI_FRONT_VERSION} && \
    # Remove the hardcoded CSP meta tag that blocks resources on non-production domains
    sed -i '/Content-Security-Policy/d' index.html && \
    npm install && \
    npm run build


# Stage 2: Production
FROM nginx:alpine

# Copy built files
COPY --from=builder /app/dist /usr/share/nginx/html

# Copy static JSON files that are not part of the Vite build
COPY --from=builder /app/json /usr/share/nginx/html/json

# Create directories for mounting backend data
RUN mkdir -p /usr/share/nginx/html/data /usr/share/nginx/html/json/realms


# Note: Nginx config should be mounted externally at /etc/nginx/conf.d/default.conf


EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]

