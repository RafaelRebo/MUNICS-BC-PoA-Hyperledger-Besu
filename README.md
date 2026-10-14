# MUNICS-BC-PoA-Hyperledger-Besu

# Hyperledger Besu QBFT - Blockchain Privada PoA

Este es un proyecto de una infraestructura blockchain desplegada sobre **Hyperledger Besu** utilizando el algoritmo de consenso **QBFT (Quorum Byzantine Fault Tolerance)**, basado en PoA.  Se complementa con con el explorador de bloques **Chainlens**, que nos proporciona una interfaz web para monitorizar el estado de la blockchain en todo momento.

---

## 📚 Documentación del proyecto

1. **[Guía de Despliegue Paso a Paso desde Cero](./docs/install.md)**  
   *Comandos para levantar la red en una máquina virtual Ubuntu Server recién instalada*

2. **[Configuración detallada del entorno](./docs/config.md)**  
   *Detalle de la configuración de Besu (`config.toml`, `.env`), mapeo de puertos, APIs JSON-RPC/WS expuestas y gestión de material criptográfico*

---

## ⚡ Ejecución de la aplicación

### Prerrequisitos del Sistema

Antes de desplegar la red, la máquina anfitriona (o máquina virtual en VirtualBox) debe cumplir con los siguientes requisitos:

* **Hardware mínimo recomendado:**
  * **RAM:** Sobre **8 GB** asignados.
  * **CPU:** Al menos **2 vCPUs**.
  * **Almacenamiento:** Mínimo **30 GB** de espacio libre en disco.
* **Software:**
  * **Git**
  * **Docker Engine** (v20.10 o superior) y **Docker Compose v2** (comando nativo `docker compose`).
* **Permisos de Docker (Sin `sudo`):**  
  El usuario actual debe pertenecer al grupo `docker` para permitir la comunicación con el socket de docker, si no ocurrirán errores de permisos:
  ```bash
  sudo usermod -aG docker $USER
  newgrp docker
  ```

### B. Reglas de Reenvío de Puertos 
Además, si estamos usando Docker a través de una máquina virtual, debemos en la configuración de VirtualBox acceder a **Configuración > Red > Adaptador 1 (conectado a NAT) > Avanzadas > Reenvío de puertos** y registrar las siguientes reglas:

| Nombre | Protocolo | IP Anfitrión | Puerto Anfitrión | IP Invitado | Puerto Invitado | Propósito |
| :--- | :---: | :---: | :---: | :---: | :---: | :--- |
| **SSH** | TCP | `127.0.0.1` | `2222` | *(vacío)* | `22` | Gestión remota de la consola Ubuntu |
| **Besu** | TCP | `127.0.0.1` | `8545` | *(vacío)* | `8545` | JSON-RPC HTTP (MetaMask, SDKs) |
| **Chainlens** | TCP | `127.0.0.1` | `8081` | *(vacío)* | `8081` | Interfaz web de Chainlens |
| **Blockscout** | TCP | `127.0.0.1` | `25000` | *(vacío)* | `25000` | Reservado para explorador auxiliar |

Si ya se dispone del entorno instalado en [la guía de instalación](./docs/install.md), podemos usar los scripts `start.sh`, `stop.sh` y `clean.sh` para iniciar, detener y restablecer la red al bloque 0. Los scripts se deberán ejecutar desde el directorio `quorum-test-network`:

```bash
# 1. Clonar el repositorio
git clone https://github.com/RafaelRebo/MUNICS-BC-PoA-Hyperledger-Besu.git
cd quorum-test-network

# 2. Dar permisos de ejecución a los ficheros
chmod u+x start.sh stop.sh clean.sh

# 3. Ejecutar el script deseado (debe hacerse desde el directorio quorum-test-network)
./start.sh

# 4. Comprobar que los 16 contenedores están en ejecución
docker compose ps
```

---

## 🌐 Endpoints y Servicios del Entorno

| Servicio | URL / Puerto | Descripción |
| :--- | :--- | :--- |
| **JSON-RPC HTTP** | `http://localhost:8545` | Endpoint usado por MetaMask, scripts Web3, etc. |
| **JSON-RPC WebSockets** | `ws://localhost:8546` | Endpoint para subscripciones en tiempo real |
| **Explorador Chainlens** | `http://localhost:8081` | Interfaz web de exploración de bloques y transacciones |

---

## 🦊 Guía de Interacción con MetaMask

Para ejecutar transacciones reales, es necesario conectar la extensión **MetaMask** del navegador anfitrión a la máquina virtual. En esta demostración, se usarán dos cuentas: una precargada con 90000 ETH (**"Magnate"**) y otra completamente vacía (**"Plebeyo"**).

### 0. Instalación de MetaMask

Primero, instalaremos la extensión de **MetaMask** disponible para nuestro navegador de preferencia (FireFox, Edge, Opera...) y creamos una nueva billetera, usando alguna de las opciones de autenticación que se nos presentan. Creamos también una contraseña que luego servirá para abrir nuestra billetera de **MetaMask**.

* **Nota**: Durante los siguientes pasos se hará referencia al fichero `genesis.json`. Este se puede encontrar dentro de nuestra instancia de `Hyperledger Besu`, por defecto, en la ruta `/home/$USER/quorum-test-network/config/besu`.

### 1. Parámetros de Red de `genesis.json`

Luego, debemos seleccionar, justo debajo de las opciones de `Comprar`, `Canjear` y siguientes:
* **Todas las redes** > **Administrar redes** > **Agregar red personalizada**

Daremos de alta una nueva red personalizada en Metamask con estos parámetros (presentes en `genesis.json`):

* **Nombre de la red:** `Hyperledger Besu QBFT` *(identificador libre)*
* **Dirección RPC:** `http://127.0.0.1:8545` *(puerto 8545 del contenedor `rpcnode`)*
* **Identificador de cadena (Chain ID):** `1337` *(definido textualmente en `genesis.json` en `"config": { "chainId": 1337 }`)*
* **Símbolo de moneda:** `ETH`
* **Dirección del explorador de bloques:** `http://localhost:8081` *(interfaz web de `chainlens`)*

### 2. Vincular la cuenta de MetaMask a la red recién creada

Después, debemos vincular nuestra cuenta recién creada a la red `Hyperledger Besu QBFT`, para ello:

* **Todas las redes** > **Administrar redes** y habilitamos la opción **Mostrar redes de prueba**.
* Hecho esto, aparecerá la red `Hyperledger Besu QBFT`.
* Volvemos a la pantalla principal, seleccionamos **Todas las redes** y más abajo seleccionaremos la opción `Hyperledger Besu QBFT`.

---

### 3. Configuración de la Cuenta "Plebeyo" (0 ETH iniciales)

Usaremos esta cuenta como receptor de ETH para comprobar que las transacciones funcionan con normalidad. Como ya hemos creado una cuenta durante la instalación de **MetaMask**, la usaremos con este propósito. Por ello, simplemente la renombramos a "Plebeyo" y dejamos el resto como está.

---

### 4. Configuración de la Cuenta "Magnate"

En las blockchains públicas, las monedas se obtienen por minado o PoS. En una red privada, podemos usar las cuentas del apartado **`"alloc"`** del `genesis.json`, que tienen un balance elevado a propósito para probar el correcto funcionamiento de la blockchain.

Al revisar el archivo `genesis.json` del repositorio:

```json
"alloc" : {
....
    "0x627306090abaB3A6e1400e9345bC60c78a8BEf57" : {
      "privateKey" : "0xc87509a1c067bbde78beb793e6fa76530b6382a4c0241e5e4a9ec0a0f44dc0d3",
      "comment" : "private key and this comment are ignored.  In a real chain, the private key should NOT be stored",
      "balance" : "0x130EE8E7179044400000"
    },
....
}
```

* **Dirección de la billetera con 90000 ETH de balance:** `0x627306090abaB3A6e1400e9345bC60c78a8BEf57`
* **Clave privada de la cuenta:** `0xc87509a1c067bbde78beb793e6fa76530b6382a4c0241e5e4a9ec0a0f44dc0d3`

* **Nota**: Las claves privadas mostradas en este fragmento pueden variar en cada instalación. Debemos asegurarnos de copiar la clave privada que aparezca en nuestro fichero `genesis.json`. En este repositorio, mostramos dichas claves privadas ya que se tratan de cuentas de prueba y sus datos no son sensibles.
  
#### Pasos para incorporarla en MetaMask:
1. Abrir **MetaMask** y hacer clic en el desplegable superior de cuentas.
2. Pulsar en **Añadir nueva billetera** y seleccionar **Importar cuenta mediante clave privada**.
4. Pegar la clave privada indicada arriba y pulsar **Importar**.
5. Renombrar la cuenta a **"Magnate"**. Al importarse, el balance de la cuenta se situará directamente en **90000 ETH**.

---

## 🛠️ Scripts de gestión de la red

* **Iniciar red:** `./start.sh` (Levanta contenedores y red Hyperledger Besu).
* **Pausar:** `./stop.sh` (Detiene los contenedores manteniendo el estado de la red).
* **Resetear:** `./clean.sh` (Elimina los datos, reiniciando la cadena al bloque 0).
