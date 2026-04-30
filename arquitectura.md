# Arquitectura SSO: D1 como Identity Provider (IdP) Externo

Esta arquitectura permite que **D1** siga siendo la única fuente de verdad (donde residen usuarios, contraseñas y roles), mientras que **Keycloak** actúa como un orquestador o "Identity Broker". 

## 🏗️ Esquema de la Arquitectura
En este modelo, D1 funciona como un servidor OpenID Connect (OIDC) y Keycloak delega la autenticación en él.

┌─────────────────────────────────────────────────────────────┐
│                     docker-compose.yml                      │
│                                                             │
│  ┌─────────────────────────────────────────────────────┐   │
│  │                     MySQL                           │   │
│  │  - BD: keycloak_db                                  │   │
│  │  - BD: d1_db (Fuente de Verdad)                     │   │
│  │  - BD: d2_db                                        │   │
│  │  - BD: d3_db                                        │   │
│  └────────────────────────┬────────────────────────────┘   │
│                           │                                 │
│          ┌────────────────┼────────────────────────┐       │
│          │                │                        │       │
│          ▼                ▼                        ▼       │
│  ┌──────────────┐  ┌──────────────┐         ┌──────────────┐│
│  │   KEYCLOAK   │  │      D1      │         │    D2 / D3   ││
│  │   (Broker)   │  │ (OIDC Server)│         │ (OIDC Client)││
│  │              │  │              │         │              ││
│  │  Trusts D1 ◄─┼──┤ Auth Real    │◄────────┤ Trust KC     ││
│  │              │  │ Roles/Perms  │         │              ││
│  └──────────────┘  └──────────────┘         └──────────────┘│
│                                                             │
│   Red interna Docker: sso-network                          │
└─────────────────────────────────────────────────────────────┘

---

## 📁 Estructura de Archivos
Se mantiene la nomenclatura del MVP original pero se elimina la carpeta de Java SPI.

sso-mvp-idp/
│
├── docker-compose.yml
├── .env                          # Secrets y credenciales
│
├── keycloak/
│   └── realm-export.json         # Configuración del Identity Provider OIDC
│
├── d1/                           # SERVIDOR DE IDENTIDAD (IdP)
│   ├── Dockerfile
│   ├── requirements.txt          # Incluye django-oauth-toolkit
│   ├── config/
│   │   ├── settings.py           # Configurado como OAuth2 Provider
│   │   └── urls.py               # Endpoints de OIDC (/o/authorize, /o/token)
│   └── portal/                   # App para redirigir a D2 o D3 tras login
│
├── d2/ & d3/                     # CLIENTES (RP)
│   ├── Dockerfile
│   └── config/
│       └── settings.py           # mozilla-django-oidc apuntando a KEYCLOAK
│
└── mysql/
    └── init.sql                  # Creación de las 4 bases de datos

---

## 🐳 docker-compose.yml
Configuración optimizada para MySQL 8 y Keycloak 24+.

```yaml
version: '3.8'

services:
  mysql:
    image: mysql:8.0
    container_name: sso-mysql
    environment:
      MYSQL_ROOT_PASSWORD: ${MYSQL_ROOT_PASSWORD}
      MYSQL_USER: ${MYSQL_USER}
      MYSQL_PASSWORD: ${MYSQL_PASSWORD}
    volumes:
      - mysql-data:/var/lib/mysql
      - ./mysql/init.sql:/docker-entrypoint-initdb.d/init.sql
    networks:
      - sso-network
    healthcheck:
      test: ["CMD", "mysqladmin", "ping", "-h", "localhost", "-u", "root", "-p${MYSQL_ROOT_PASSWORD}"]
      interval: 10s
      retries: 5

  keycloak:
    image: quay.io/keycloak/keycloak:24.0
    container_name: sso-keycloak
    command: start-dev --import-realm
    environment:
      KC_DB: mysql
      KC_DB_URL: jdbc:mysql://mysql:3306/keycloak_db
      KC_DB_USERNAME: ${MYSQL_USER}
      KC_DB_PASSWORD: ${MYSQL_PASSWORD}
      KEYCLOAK_ADMIN: ${KC_ADMIN_USER}
      KEYCLOAK_ADMIN_PASSWORD: ${KC_ADMIN_PASSWORD}
    volumes:
      - ./keycloak/realm-export.json:/opt/keycloak/data/import/realm-export.json
    ports:
      - "8080:8080"
    depends_on:
      mysql:
        condition: service_healthy
    networks:
      - sso-network

  d1:
    build: ./d1
    container_name: sso-d1
    environment:
      DB_NAME: d1_db
      OIDC_CLIENT_ID_FOR_KC: "keycloak-broker"
      OIDC_CLIENT_SECRET_FOR_KC: ${D1_SECRET_FOR_KC}
    ports:
      - "8001:8001"
    networks:
      - sso-network

  d2:
    build: ./d2
    container_name: sso-d2
    environment:
      DB_NAME: d2_db
      OIDC_RP_CLIENT_ID: "d2-client"
      OIDC_RP_CLIENT_SECRET: ${D2_CLIENT_SECRET}
      OIDC_OP_AUTHORIZATION_ENDPOINT: http://localhost:8080/realms/myrealm/protocol/openid-connect/auth
    ports:
      - "8002:8002"
    networks:
      - sso-network

  d3:
    build: ./d3
    container_name: sso-d3
    ports:
      - "8003:8003"
    networks:
      - sso-network

volumes:
  mysql-data:

networks:
  sso-network:
    driver: bridge
🔑 Configuración de D1 (Identity Provider)
D1 debe comportarse como un servidor de identidad. Se utiliza django-oauth-toolkit.

Instalación: pip install django-oauth-toolkit.

Settings: - Añadir 'oauth2_provider' a INSTALLED_APPS.

Configurar OAUTH2_PROVIDER para soportar scopes de OpenID.

Roles en el Token: Sobrescribir el método de generación de tokens para incluir los grupos o permisos del usuario en el campo id_token.

📋 Fases de Desarrollo
FASE 1: Infraestructura y DB
Levantar el contenedor de MySQL con las bases de datos keycloak_db, d1_db, d2_db y d3_db.

Verificar conectividad básica.

FASE 2: D1 como Servidor OIDC
Configurar D1 para que pueda emitir tokens.

Crear un "Application" en el admin de Django de D1:

Client ID: keycloak-broker.

Client Type: Confidential.

Authorization Grant Type: Authorization code.

FASE 3: Configuración de Keycloak (Broker)
Ir a Identity Providers en Keycloak.

Añadir un proveedor OpenID Connect 1.0.

Configurar:

Authorization URL: http://d1:8001/o/authorize/

Token URL: http://d1:8001/o/token/

User Info URL: http://d1:8001/o/userinfo/

Activar "First Broker Login Flow" para que Keycloak cree automáticamente una entrada de usuario local (shadow user) la primera vez que alguien se loguea desde D1.

FASE 4: Mapeo de Roles
Crear un Mapper en el Identity Provider de Keycloak.

Mapear el claim "roles" que envía D1 a roles internos de Keycloak o directamente pasarlos a los clientes D2/D3.

FASE 5: D2 y D3 como Clientes de Keycloak
Configurar D2 y D3 usando mozilla-django-oidc.

El OIDC_OP_AUTHORIZATION_ENDPOINT de D2/D3 debe apuntar a Keycloak, no a D1.

FASE 6: Portal de Selección (Dashboard)
Crear una vista simple en D1 (o una App "Portal").

Si el usuario está autenticado, mostrar botones: "Ir a App D2", "Ir a App D3".

Al hacer clic, el usuario va a D2, D2 lo manda a Keycloak, Keycloak ve que ya hay sesión iniciada en D1 y lo deja pasar automáticamente (SSO transparente).

✅ Resultados Esperados
Login Único: El usuario se loguea en la interfaz de D1.

Persistencia: Si el usuario cierra sesión en D1, Keycloak puede invalidar las sesiones en D2 y D3 (Backchannel Logout).

Control Total: Si desactivas a un usuario en D1, no podrá entrar a ninguna otra aplicación a través de Keycloak.