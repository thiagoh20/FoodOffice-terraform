# FoodOffice Frontend

Frontend React para el sistema de gestión de pedidos de oficina.

## Requisitos

- Node.js 20.x
- pnpm 10.4.1+

## Instalación

```bash
pnpm install
```

## Configuración

Crea un archivo `.env` en la raíz del proyecto frontend con las siguientes variables:

```env
# URL del backend API
VITE_API_URL=http://localhost:3000

# OAuth (opcional)
VITE_OAUTH_PORTAL_URL=https://tu-servidor-oauth.com
VITE_APP_ID=tu-app-id

# Google Maps (opcional)
VITE_FRONTEND_FORGE_API_KEY=tu-api-key
VITE_FRONTEND_FORGE_API_URL=https://forge.butterfly-effect.dev
```

## Scripts

- `pnpm dev` - Inicia el servidor de desarrollo en `http://localhost:5173`
- `pnpm build` - Construye el proyecto para producción
- `pnpm preview` - Previsualiza la build de producción
- `pnpm check` - Verifica tipos TypeScript
- `pnpm format` - Formatea el código con Prettier

## Desarrollo

```bash
pnpm dev
```

El frontend se iniciará en `http://localhost:5173` y se conectará automáticamente al backend configurado en `VITE_API_URL`.

## Estructura

- `src/` - Código fuente de la aplicación
- `src/components/` - Componentes React
- `src/pages/` - Páginas de la aplicación
- `src/lib/` - Utilidades y configuraciones
- `shared/` - Código compartido con el backend

## Despliegue

### Build de producción

```bash
pnpm build
```

Los archivos estáticos se generarán en la carpeta `dist/`.

### Vercel / Netlify

El proyecto puede desplegarse directamente en Vercel o Netlify. Asegúrate de configurar las variables de entorno en la plataforma de despliegue.
