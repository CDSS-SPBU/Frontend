
ARG NODE_VERSION=23.11.0-alpine
ARG NGINX_VERSION=alpine3.22
################################################################################
# Use node image for base image for all stages.
FROM node:${NODE_VERSION} AS builder

# Set working directory for all build stages.
WORKDIR /app

################################################################################
COPY package.json package-lock.json ./

RUN --mount=type=cache,target=/root/.npm npm ci

# Copy the rest of the source files into the image.
COPY . .
# Run the build script.
RUN npm run build

################################################################################
# Create a new stage to run the application with minimal runtime dependencies
# where the necessary files are copied from the build stage.
FROM nginxinc/nginx-unprivileged:${NGINX_VERSION} AS runner

# Run the application as a non-root user.
USER nginx

# Copy custom Nginx config.
COPY nginx.conf /etc/nginx/nginx.conf

# Copy the static build output from the build stage to Nginx's default HTML serving directory
COPY --chown=nginx:nginx --from=builder /app/dist /usr/share/nginx/html

# Expose the port that the application listens on.
EXPOSE 8080

ENTRYPOINT ["nginx", "-c", "/etc/nginx/nginx.conf"]
CMD ["-g", "daemon off;"]
