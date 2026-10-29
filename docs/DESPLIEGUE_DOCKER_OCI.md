# Despliegue de Atipax con Docker, GitHub Actions y OCI

Esta guía cubre exactamente las cuatro evidencias solicitadas: Docker Desktop, publicación automática en Docker Hub, creación de una VM en Oracle Cloud Infrastructure (OCI) y ejecución pública del contenedor.

## 1. Probar la imagen en Docker Desktop

Desde PowerShell, en la raíz del proyecto:

```powershell
docker compose up --build -d
docker compose ps
docker inspect --format='{{json .State.Health}}' atipax-cafeteria
```

Abrir `http://localhost:8080`. Para detenerlo:

```powershell
docker compose down
```

Si la aplicación debe conectarse a Supabase, mantener las variables en `.env.local`. Docker Compose las usa como argumentos de compilación; el archivo está excluido de Git y del contexto Docker. Las variables `VITE_*` quedan incorporadas en el JavaScript del frontend, por lo que solo debe usarse la clave pública `anon`, nunca una clave `service_role`.

**Capturas requeridas:**

1. Docker Desktop > Containers mostrando `atipax-cafeteria` en ejecución y el puerto `8080:80`.
2. Navegador mostrando Atipax en `http://localhost:8080`.
3. Terminal con `docker compose ps` y estado `healthy`.

## 2. Subir el proyecto a GitHub

El proyecto debe estar en un repositorio GitHub cuya rama principal sea `main`. Antes del primer push, configurar en GitHub: **Settings > Secrets and variables > Actions > New repository secret**.

| Secret | Valor |
|---|---|
| `DOCKERHUB_USERNAME` | usuario de Docker Hub |
| `DOCKERHUB_TOKEN` | access token creado en Docker Hub (no la contraseña) |
| `VITE_SUPABASE_URL` | URL pública del proyecto Supabase |
| `VITE_SUPABASE_ANON_KEY` | clave pública `anon` de Supabase |

Si se desea publicar la interfaz sin conexión a Supabase, crear los dos últimos secretos con valor vacío o adaptar el workflow para omitir esos argumentos.

Comandos iniciales, reemplazando la URL por la del repositorio real:

```powershell
git init
git branch -M main
git add .
git commit -m "Configurar despliegue con Docker y GitHub Actions"
git remote add origin https://github.com/USUARIO/REPOSITORIO.git
git push -u origin main
```

Cada push a `main` ejecutará `.github/workflows/docker-publish.yml` y publicará:

- `DOCKERHUB_USERNAME/atipax-cafeteria:latest`
- `DOCKERHUB_USERNAME/atipax-cafeteria:sha-<commit>`

**Capturas requeridas:**

1. GitHub > Actions > workflow **Publicar imagen en Docker Hub**, ejecución verde y pasos desplegados.
2. Docker Hub > repositorio `atipax-cafeteria`, pestaña Tags mostrando `latest` y la etiqueta `sha-*`.

## 3. Crear manualmente la VM en OCI

En OCI: **Compute > Instances > Create instance**.

- Nombre: `atipax-docker-vm`
- Imagen: Ubuntu 22.04 o 24.04
- Shape: una opción Always Free elegible, por ejemplo `VM.Standard.E2.1.Micro` si está disponible en la región, o Ampere A1 con recursos dentro del nivel gratuito.
- Red: crear o seleccionar VCN/subnet pública.
- Activar asignación de IPv4 pública.
- Agregar la clave SSH pública del equipo y conservar la clave privada.

En la Subnet o Network Security Group, agregar una regla de ingreso:

| Source CIDR | Protocolo | Puerto destino | Uso |
|---|---|---:|---|
| `0.0.0.0/0` | TCP | 80 | sitio público |
| `TU_IP_PUBLICA/32` | TCP | 22 | SSH restringido |

No dejar el puerto 22 abierto a todo Internet si puede restringirse a la IP del administrador.

Conectarse desde PowerShell (ajustar ruta e IP):

```powershell
ssh -i .\clave-oci.key ubuntu@IP_PUBLICA_OCI
```

**Capturas requeridas:**

1. OCI mostrando la instancia en estado `Running`, nombre, shape e IP pública.
2. Reglas de ingreso mostrando TCP 80 y TCP 22 restringido.
3. Terminal local mostrando una conexión SSH exitosa (ocultar rutas personales si corresponde).

## 4. Instalar Docker y desplegar manualmente en la VM

Ejecutar dentro de la VM Ubuntu:

```bash
sudo apt-get update
sudo apt-get install -y ca-certificates curl
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
sudo systemctl enable --now docker
sudo docker --version
```

Descargar y ejecutar la imagen (reemplazar `USUARIO_DOCKERHUB`):

```bash
sudo docker pull USUARIO_DOCKERHUB/atipax-cafeteria:latest
sudo docker run -d --name atipax-cafeteria --restart unless-stopped -p 80:80 USUARIO_DOCKERHUB/atipax-cafeteria:latest
sudo docker ps
sudo docker logs --tail 30 atipax-cafeteria
curl -I http://localhost
```

Si Ubuntu usa UFW y está activo:

```bash
sudo ufw allow 80/tcp
sudo ufw status
```

Abrir en el navegador: `http://IP_PUBLICA_OCI`.

Para actualizar luego de otro push a `main`:

```bash
sudo docker pull USUARIO_DOCKERHUB/atipax-cafeteria:latest
sudo docker rm -f atipax-cafeteria
sudo docker run -d --name atipax-cafeteria --restart unless-stopped -p 80:80 USUARIO_DOCKERHUB/atipax-cafeteria:latest
```

**Capturas requeridas:**

1. Terminal de la VM con `docker pull` completado.
2. Terminal con `docker ps`, mapeo `0.0.0.0:80->80/tcp` y contenedor `Up`.
3. Terminal con `curl -I http://localhost` respondiendo `HTTP/1.1 200 OK`.
4. Navegador mostrando Atipax mediante `http://IP_PUBLICA_OCI` con la barra de dirección visible.

## 5. Orden sugerido para el informe

1. Portada y objetivo.
2. Arquitectura: GitHub `main` → GitHub Actions → Docker Hub → `docker pull` en OCI → Nginx/React por IP pública.
3. Archivos creados: `Dockerfile`, `.dockerignore`, `nginx.conf`, `compose.yaml` y workflow.
4. Evidencia Docker Desktop.
5. Evidencia GitHub Actions y Docker Hub.
6. Evidencia de la VM y reglas de red.
7. Evidencia de comandos Docker y acceso por IP pública.
8. Conclusión.

Antes de entregar, ocultar tokens, claves privadas, cookies y cualquier secreto. La IP pública sí debe quedar visible porque forma parte de la evaluación.

