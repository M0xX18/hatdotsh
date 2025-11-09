FROM node:20-alpine AS builder

# Crear usuario no-root para build
RUN addgroup -g 1001 -S nodejs && \
    adduser -S nextjs -u 1001

WORKDIR /app

# Copiar solo archivos necesarios para npm install
COPY package*.json ./

# Instalar todas las dependencias (incluyendo devDependencies para el build)
RUN npm ci && \
    chown -R nextjs:nodejs /app

# Copiar código fuente
COPY --chown=nextjs:nodejs . ./

# Deshabilitar telemetría
ENV NEXT_TELEMETRY_DISABLED=1

# Build como usuario no-root
USER nextjs
RUN npm run build

# Stage de producción
FROM nginx:1.26-alpine

# Instalar actualizaciones de seguridad
RUN apk update && \
    apk upgrade && \
    apk add --no-cache tzdata wget && \
    rm -rf /var/cache/apk/*

# Copiar archivos estáticos
COPY --from=builder /app/out /usr/share/nginx/html

# Copiar configuración de servidor de Nginx (reemplaza default.conf)
COPY nginx-default.conf /etc/nginx/conf.d/default.conf

# Configurar permisos
RUN chown -R nginx:nginx /usr/share/nginx/html && \
    chmod -R 755 /usr/share/nginx/html

EXPOSE 80

# Healthcheck
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD wget --quiet --tries=1 --spider http://localhost/ || exit 1

ENTRYPOINT ["nginx", "-g", "daemon off;"]