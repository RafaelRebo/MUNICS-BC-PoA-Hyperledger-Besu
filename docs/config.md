# Detalles de Configuración y Arquitectura

Este documento describe la arquitectura y configuración de la red basada en **Hyperledger Besu**, con el algoritmo de consenso **QBFT (Quorum Byzantine Fault Tolerance)**. También se detalla la gestión de claves criptográficas y las diferentes interfaces expuestas.

---

## 1. Estructura Completa del Repositorio

El repositorio organiza el material desacoplando el código de orquestación, las configuraciones del motor Besu y las identidades criptográficas de los nodos:

```text
.
├── docker-compose.yml              # Definición y orquestación de contenedores (Besu, Chainlens...)
├── README.md                       # Resumen del proyecto, endpoints y configuración de MetaMask
├── start.sh                        # Script de inicialización de servicios
├── stop.sh                         # Script de detención preservando el estado de la red
├── clean.sh                        # Script de reinicio total al bloque 0
├── docs/
│   ├── config.md                   # Arquitectura, parámetros Besu, claves...
│   └── install.md                  # Guía de instalación en Ubuntu Server
├── config/
│   ├── besu/
│   │   ├── config.toml             # Configuración declarativa de Besu (P2P, RPC/WS)
│   │   ├── .env                    # Variables de entorno Besu
│   │   ├── genesis.json            # Bloque génesis activo en la red
│   │   └── QBFTgenesis.json        # Plantilla base para el bloque génesis
│   ├── nodes/
│   │   ├── validator{1..4}/        # Material criptográfico de los 4 nodos validadores
│   │   │   ├── nodekey / .pub      # Par de claves P2P
│   │   │   ├── accountPrivateKey   # Clave privada Ethereum para la firma de bloques
│   │   │   ├── accountKeystore     # Clave de consenso cifrada en formato estándar Ethereum
│   │   │   ├── accountPassword     # Contraseña en texto plano para descifrar el keystore
│   │   │   └── address             # Dirección pública autorizada en extraData del génesis
│   │   └── rpcnode/                # Nodo de consulta y entrada a la red (no tiene rol de validador)
│   │       └── ...                 # Par de claves P2P (nodekey / .pub) y credenciales de nodo
│   ├── ethsigner/                  # Proxy de firma de transacciones
│   │   ├── key                     # Clave privada
│   │   └── password                # Contraseña de desbloqueo
├── chainlens/                      # Configuración de proxy inverso (Nginx) para Chainlens
└── loki/ / promtail/               # Agente y recolector centralizado de logs de contenedores
```

---

## 2. Configuración del Motor Besu y Peering

### A. Parámetros de Hyperledger Besu (`config/besu/config.toml`)

La instancia de Hyperledger Besu inicia su ejecución cargando de forma estandarizada los parámetros definidos en este archivo:

```toml
genesis-file="/config/genesis.json"
node-private-key-file="/opt/besu/keys/nodekey"
logging="INFO"
data-path="/opt/besu/data"
host-allowlist=["*"]
min-gas-price=0

# rpc
rpc-http-enabled=true
rpc-http-host="0.0.0.0"
rpc-http-port=8545
rpc-http-cors-origins=["*"]

# ws
rpc-ws-enabled=true
rpc-ws-host="0.0.0.0"
rpc-ws-port=8546

# graphql
graphql-http-enabled=true
graphql-http-host="0.0.0.0"
graphql-http-port=8547
graphql-http-cors-origins=["*"]

# metrics
metrics-enabled=true
metrics-host="0.0.0.0"
metrics-port=9545

# permissions
permissions-nodes-config-file-enabled=true
permissions-nodes-config-file="/config/permissions_config.toml"

# bootnodes
bootnodes=["enode://8208a3f344695d44e9cf2c023683cbea7b9343e2f70a5e804bd2c93858e945f8f91439eef96a4ab6c47ff06637d6fbe6472f96de1655a1bee57ea896654f3a22@172.16.239.11:30303"]


# Discovery at boot is set to a list of static files, but will also discover new nodes should they be added
# static nodes
static-nodes-file="/config/static-nodes.json"
discovery-enabled=true
```

### B. Variables de Entorno (`config/besu/.env`)

Centraliza las versiones de imagen y directivas globales:

```env
LOG4J_CONFIGURATION_FILE=/config/log-config.xml
```

### C. Topología de Red

1. **Aislamiento en una subred `quorum-dev-quickstart`:** Los nodos conviven en la red virtual `quorum-dev-quickstart` (`172.16.239.0/24`). Dentro de ella, se asignan IPs estáticas a cada uno de los nodos. Entre ellos, se destacan los validadores (`172.16.239.11` a `.14`) y el nodo RPC (`172.16.239.15`). Podemos emplear el siguiente comando para verificar la asignación de IPs a los nodos:

```bash
$ docker inspect -f '{{printf "%-35s" .Name}} {{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' $(docker ps -q)
/chainlensnginx                     172.16.239.57
/chainlensweb                       172.16.239.56
/quorum-test-network-ethsignerProxy-1 172.16.239.40
/chainlensingestion                 172.16.239.55
/chainlensapi                       172.16.239.53
/rpcnode                            172.16.239.15
/quorum-test-network-validator4-1   172.16.239.14
/quorum-test-network-validator3-1   172.16.239.13
/quorum-test-network-validator2-1   172.16.239.12
/chainlensredis                     172.16.239.58
/quorum-test-network-prometheus-1   172.16.239.32
/chainlensmongodb                   172.16.239.54
/quorum-test-network-grafana-1      172.16.239.33
/quorum-test-network-loki-1         172.16.239.34
/quorum-test-network-promtail-1     172.16.239.35
/quorum-test-network-validator1-1   172.16.239.11
```

2. **Conexión entre nodos y descubrimiento P2P:**
   * **Comunicación de IPs entre los nodos:** Al arrancar cada contenedor de la red, Besu obtiene su IP interna mediante el comando `/opt/besu/bin/besu --config-file=/config/config.toml --p2p-host=$$(hostname -i)` (presente en `docker-compose.yml`) para publicarla al resto de participantes.
   * **Nodo de arranque (*Bootnode*):** En `config.toml`, la directiva `bootnodes` apunta al nodo `validator1` (`172.16.239.11:30303`). Gracias a esto y a la directiva `depends_on: - validator1` en `docker-compose.yml`, el resto de validadores y el nodo RPC acuden a él como punto de contacto inicial al encenderse.
   * **Convergencia de la red:** Al estar activo `discovery-enabled=true` en `config.toml`, `validator1` intercambia la información de los pares entrantes por el puerto `30303` (puerto por defecto de comunicación P2P), creando de forma dinámica la topología de red completa a partir de `validator1`.

### D. APIs Expuestas y Propósito

En `docker-compose.yml`, los nodos exponen las siguientes interfaces mediante los parámetros `--rpc-http-api` y `--rpc-ws-api`:

`EEA,WEB3,ETH,NET,TRACE,DEBUG,ADMIN,TXPOOL,PERM,QBFT`

* **`ETH`, `WEB3`, `NET`:** Métodos estándar Ethereum (`eth_blockNumber`, `eth_getBalance`, `eth_sendRawTransaction`) requeridos por MetaMask y librerías Web3 de frontend.
* **`QBFT`:** Métodos del algoritmo de consenso QBFT (`qbft_getValidatorsByBlockNumber`, `qbft_proposeValidatorVote`).
* **`TXPOOL`:** Inspección en tiempo real de transacciones (`txpool_besuStatistics`).
* **`ADMIN`:** Administración de la conectividad P2P (`admin_peers`, `admin_nodeInfo`).
* **`TRACE`, `DEBUG`:** Trazabilidad profunda de ejecución de transacciones..
* **`PERM`:** Consultas sobre listas de control de acceso.

---

## 3. Gestión de claves criptográficas

### A. Almacenamiento y separación de claves
Cada nodo validador monta su material criptográfico (un par de claves de curva elíptica **secp256k1**) de forma aislada en `/opt/besu/keys:ro`, manteniendo dos identidades desacopladas:
1. **Identidad en la red P2P (`nodekey` y `nodekey.pub`):** Cifra el tráfico entre las máquinas de la red interna y autentica al nodo frente al *bootnode*.
2. **Identidad de Consenso QBFT (`accountPrivateKey` / `accountKeystore` y `address`):** Firma los bloques emitidos. Las 4 direcciones `address` están incrustadas en el campo `extraData` del bloque 0 (`genesis.json`).

El siguiente fragmento de `docker-compose.yml` ilustra la creación de un volumen aislado para el material criptográfico de un nodo.

```yaml
volumes:
  - ./config/nodes/validator1:/opt/besu/keys:ro
```

El modificador `:ro` asegura que el contenedor únicamente lea la clave, impidiendo cualquier tipo de modificaciones.

### B. Política de Claves

Las claves presentes en el repositorio fueron generadas automáticamente por la utilidad `quorum-dev-quickstart`. Por tanto, ninguna de ellas está asociada a activos reales potencialmente sensibles y se publican para simplificar el proceso de despliegue.

Sin embargo, la política adecuada en un entorno de producción real sería:

* Las claves privadas (`nodekey`) de cada uno de los nodos Docker y las claves privadas de consenso (`accountPrivateKey`) deben estar declaradas en `.gitignore` y **nunca** subirse al sistema de control de versiones.
