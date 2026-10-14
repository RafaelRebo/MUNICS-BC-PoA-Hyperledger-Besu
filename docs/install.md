# Guía de Despliegue de Red Hyperledger Besu (QBFT)

En este documento se detalla el procedimiento de despliegue de una red blockchain privada mediante Hyperledger Besu y algoritmo QBFT (variante de PoA) en un sistema **Ubuntu Server 24.04 / 22.04 LTS**.

## 0. Configuración del Entorno en Oracle VirtualBox

En esta sección se explica cómo configurar una máquina virtual Oracle VirtualBox para alojar los contenedores necesarios, usando reenvío de puertos para que las aplicaciones puedan exponer sus interfaces en nuestra máquina local.

### A. Recursos Asignados a la Máquina Virtual
* **Procesadores (vCPU):** 4 cores
* **Memoria Base (RAM):** 6 GB (6144 MB)
* **Almacenamiento Virtual:** 30 GB (disco dinámico)

### B. Reglas de Reenvío de Puertos (Port Forwarding)
En VirtualBox, acceder a **Configuración > Red > Adaptador 1 (conectado a NAT) > Avanzadas > Reenvío de puertos** y registrar las siguientes reglas:

| Nombre | Protocolo | IP Anfitrión | Puerto Anfitrión | IP Invitado | Puerto Invitado | Propósito |
| :--- | :---: | :---: | :---: | :---: | :---: | :--- |
| **SSH** | TCP | `127.0.0.1` | `2222` | *(vacío)* | `22` | Gestión remota de la consola Ubuntu |
| **Besu** | TCP | `127.0.0.1` | `8545` | *(vacío)* | `8545` | JSON-RPC HTTP (MetaMask, SDKs) |
| **Chainlens** | TCP | `127.0.0.1` | `8081` | *(vacío)* | `8081` | Interfaz web de Chainlens |
| **Blockscout** | TCP | `127.0.0.1` | `25000` | *(vacío)* | `25000` | Reservado para explorador auxiliar |

### C. Conexión SSH desde el sistema anfitrión:
Una vez iniciada la máquina virtual, nos conectamos desde el anfitrión usando:

```bash
ssh -p 2222 user@127.0.0.1
```

### Nota. Servidor SSH:
Es posible que el sistema operativo instalado en la máquina no tenga un servidor OpenSSH activo por defecto. Si ese es el caso, no podremos conectarnos, debemos instalar OpenSSH y/o activarlo antes:

```bash
# 1. Comprobar si está instalado y ejecutándose
sudo systemctl status ssh

# 2. Si no lo está, lo instalamos y arrancamos:
sudo apt update && sudo apt install -y openssh-server
sudo systemctl enable --now ssh
```

---

## 1. Preparación del Sistema Operativo

Partiendo de una sesión SSH en el servidor recién instalado:

```bash
# 1. Actualizar los paquetes del sistema
sudo apt update

# 2. Instalar Docker, Docker Compose, Node.js y npm, necesarios para ejecutar el entorno
sudo apt install -y docker.io docker-compose-v2 nodejs npm

# 3. Añadir usuario local a grupo docker para que no sea necesario el uso de sudo
sudo usermod -aG docker $USER

# 4. Aplicar el nuevo grupo a la sesión actual
newgrp docker

# 5. Comprobar que docker responde correctamente
docker ps
```

### Nota. Sobre los privilegios de usuario
El comando `docker ps` anterior debe funcionar correctamente ejecutado desde el usuario sin privilegios que estemos usando. Es **muy importante** ejecutar todos los comandos a partir de aquí desde un usuario sin privilegios, y no desde `root`, de lo contrario, los directorios de Besu se crearán con privilegios de `root` y luego `Chainlens` no podrá funcionar. Esto nos olbigaría a cambiar los permisos de dichos ficheros manualmente tras la instalación.

---

## 2. Generación del entorno inicial con Quorum Dev Quickstart

Se utiliza Quorum Dev Quickstart para generar los archivos de configuración plantilla de Hyperledger Besu y los contenedores Docker:

```bash
npx quorum-dev-quickstart
```

### Respuestas seleccionadas en el asistente:
1. **Which Ethereum client would you like to run?:** `1` *(Hyperledger Besu)*
2. **Do you wish to enable support for private transactions?:** `n` *(No requeridas)*
3. **Do you wish to enable support for logging with Loki, Splunk or ELK?:** `1` *(Loki)*
4. **Do you wish to enable support for monitoring your network with Chainlens?:** `y` *(Sí)*
5. **Do you wish to enable support for monitoring your network with Blockscout?:** `n` *(No)*
6. **Where should we create the config files for this network?:** Presionar `Enter` *(Ruta por defecto: `./quorum-test-network`)*

Acceder al directorio creado:

```bash
cd quorum-test-network
```

---

## 3. Corrección de dependencias en `docker-compose.yml`

El fichero `docker-compose.yml` por defecto presenta incompatibilidades que impiden la correcta ejecución de los contenedores y de `chainlens`:
1. La imagen `consensys/quorum-explorer` provoca un error de descarga, porque ya no está disponible.
2. El servicio `chainlensapi` requiere obligatoramente una instancia **Redis**, pero por defecto se omite la creación de dicha instancia, provocando excepciones al intentar acceder a la interfaz web de `chainlens`.

Se edita el fichero `docker-compose.yml` de la siguiente forma:

*(El archivo `docker-compose.yml` de este repositorio ya incorpora estas correcciones. Por ello, se recomienda usar directamente el fichero presente en este repositorio).*

```bash
nano docker-compose.yml
```
---

### Paso 3.1. Eliminar el bloque `explorer`

Localizar en la sección `services:` el siguiente fragmento y **eliminarlo por completo**:

```yaml
  # ❌ ELIMINAR ESTE FRAGMENTO:
  explorer:
    image: consensys/quorum-explorer:${QUORUM_EXPLORER_VERSION:-latest}
    volumes:
      - ./quorum-explorer/config.json:/app/config.json
      - ./quorum-explorer/env:/app/.env.production
    depends_on:
      - rpcnode
    ports:
      - 25000:25000/tcp
    networks:
      quorum-dev-quickstart:
        ipv4_address: 172.16.239.31
```

---

### Paso 3.2. Configurar el host Redis en `x-chainlensapi-ref`

Localizar el bloque  `x-chainlensapi-ref` e incorporar las variables no presentes `SPRING_REDIS_HOST` y `REDIS_HOST` en el entorno:

#### Bloque original:
```yaml
x-chainlensapi-ref:
  &chainlensapi-def
  image: web3labs/epirus-free-api:latest
  container_name: chainlensapi
  environment:
    - NODE_ENDPOINT=http://rpcnode:8545
    - MONGO_CLIENT_URI=mongodb://chainlensmongodb:27017
    - REINDEX_ENDPOINT=http://chainlensingestion/reindex/
    - MONGO_DB_NAME=epirus
    - MONGO_CREATE_INDICES=true
  depends_on:
    - chainlensmongodb
```

#### Bloque modificado (dos últimas variables en `environment`):
```yaml
x-chainlensapi-ref:
  &chainlensapi-def
  image: web3labs/epirus-free-api:latest
  container_name: chainlensapi
  environment:
    - NODE_ENDPOINT=http://rpcnode:8545
    - MONGO_CLIENT_URI=mongodb://chainlensmongodb:27017
    - REINDEX_ENDPOINT=http://chainlensingestion/reindex/
    - MONGO_DB_NAME=epirus
    - MONGO_CREATE_INDICES=true
    - SPRING_REDIS_HOST=chainlensredis
    - REDIS_HOST=chainlensredis
  depends_on:
    - chainlensmongodb
```

---

### Paso 3.3. Crear el servicio `chainlensredis`

Dentro de la sección `services:`, encima de `chainlensapi:`, **insertar el nuevo servicio de Redis**:

```yaml
  chainlensredis:
    image: redis:alpine
    container_name: chainlensredis
    networks:
      quorum-dev-quickstart:
        ipv4_address: 172.16.239.58
```

---

### Paso 3.4. Configurar WebSockets y vista en `chainlensweb`

Localizar el servicio `chainlensweb` dentro de `services:` y modificarlo para incluir las variables de entorno adecuadas:

#### Bloque original por defecto:
```yaml
  chainlensweb:
    <<: *chainlensweb-def
    networks:
      quorum-dev-quickstart:
        ipv4_address: 172.16.239.56
```

#### Bloque modificado:
```yaml
  chainlensweb:
    <<: *chainlensweb-def
    environment:
      - API_URL=/api
      - WS_API_URL=ws://localhost:8081/api
      - DISPLAY_NETWORK_TAB=disabled
    networks:
      quorum-dev-quickstart:
        ipv4_address: 172.16.239.56
```

---

### Paso 3.5. Validar la sintaxis YAML resultante

Guardar los cambios en el archivo y lo validamos con el siguiente comando:

```bash
docker compose config > /dev/null && echo "Sintaxis CORRECTA"
```

*(El archivo `docker-compose.yml` de este repositorio ya incorpora estas correcciones. Por ello, se recomienda usar directamente el fichero presente en este repositorio).*

---

## 4. Inicialización y Despliegue de la Red

Levantar toda la infraestructura (validadores Besu QBFT, nodo RPC, Chainlens y telemetría):

```bash
docker compose up -d
```

### Comprobación de servicios activos:

```bash
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
```

Los 16 contenedores deben figurar en estado activo (`Up` / `healthy`):
* `quorum-test-network-validator1-1` a `validator4-1` (Validadores del protocolo QBFT)
* `rpcnode` (Punto de entrada JSON-RPC HTTP/WS en puertos `8545` y `8546`)
* `chainlensredis`, `chainlensmongodb`, `chainlensapi`, `chainlensingestion`, `chainlensweb`, `chainlensnginx` (Explorador Chainlens y dependencias)
* `prometheus`, `grafana`, `loki`, `promtail` (Métricas y logs)
* `quorum-test-network-ethsignerProxy-1`

---

## 5. Verificación de Funcionamiento

### A. Comprobar la creación de bloques en Chainlens
Inspeccionar logs de Chainlens para verificar que la cadena genera bloques cada 5 segundos:

```bash
docker logs --tail 15 chainlensingestion
```
*(Salida esperada: `Import reached block X (...)` incrementando secuencialmente).*

### B. Comprobar el arranque de Chainlens
Verificar que Spring Boot ha arrancado sin excepciones:

```bash
docker logs --tail 20 chainlensapi
```
*(Salida esperada: `Started ApiApplicationKt in ... seconds` y `Tomcat started on port(s): 8090`).*

---
