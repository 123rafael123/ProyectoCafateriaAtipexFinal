# Atipax Cafetería · plataforma web

Primera versión del front-end en React para convertir la aplicación de escritorio en una experiencia web con tres espacios: comprador, vendedor y propietario.

## Requisitos
Node.js 20.19+ o 22.12+.

## Iniciar
```bash
npm install
npm run dev
```

## Docker

```bash
docker compose up --build -d
```

La aplicación queda disponible en `http://localhost:8080`. La guía completa para Docker Hub, GitHub Actions y una VM en OCI está en [`docs/DESPLIEGUE_DOCKER_OCI.md`](docs/DESPLIEGUE_DOCKER_OCI.md).

## Recorrido del prototipo
- **Comprador:** tienda pública, hero de marca con el logo principal, catálogo con búsqueda y filtros, productos, carrito de muestra e historia del local.
- **Vendedor:** panel de turno, pedidos recibidos desde web/móvil, caja, nueva venta, inventario y alertas de stock.
- **Propietario:** resumen de negocio, ventas, inventario, clientes, personal/roles y reportes como mapa inicial de navegación.
- Cambia de rol con el selector **VISTA** en la barra superior. El diálogo de inicio de sesión representa el acceso privado; aún no autentica usuarios.

## Identidad
El logo principal de mariposa azul inspira la paleta noche, azul tinta, azul eléctrico, celeste hielo, plata y nube. Se conservan los PNG originales en `public/assets/` y se usa la foto de ambiente existente en la sección de marca.

## Alcance de esta etapa
Datos, pedidos y caja son de demostración en el navegador. No se configuraron credenciales de Supabase ni pagos reales. La conexión a la base existente, autorización de permisos, persistencia, pedidos compartidos con móvil e integración de pagos se deben desarrollar como etapa backend antes de operar con clientes.
