-- Inicialización de bases de datos para el sistema SSO
-- Bases de datos: keycloak_db, d1_db, d2_db, d3_db

-- Crear las bases de datos
CREATE DATABASE IF NOT EXISTS keycloak_db CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE DATABASE IF NOT EXISTS d1_db CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE DATABASE IF NOT EXISTS d2_db CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE DATABASE IF NOT EXISTS d3_db CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- El usuario sso_user ya se crea automáticamente por las variables de entorno
-- Asignar permisos completos al usuario para todas las bases de datos
GRANT ALL PRIVILEGES ON keycloak_db.* TO 'sso_user'@'%';
GRANT ALL PRIVILEGES ON d1_db.* TO 'sso_user'@'%';
GRANT ALL PRIVILEGES ON d2_db.* TO 'sso_user'@'%';
GRANT ALL PRIVILEGES ON d3_db.* TO 'sso_user'@'%';

-- Refrescar privilegios
FLUSH PRIVILEGES;

-- Log de confirmación
SELECT 'Bases de datos SSO creadas exitosamente' as MESSAGE;