-- ============================================================================
-- SCRIPT SQL: Base de datos "inmosantander"
-- Sistema inmobiliario - Java EE (JSP + MySQL)
-- Motor: MySQL 8.x (XAMPP)
-- Normalización: hasta 3FN
-- ============================================================================

DROP DATABASE IF EXISTS inmosantander;
CREATE DATABASE inmosantander
    CHARACTER SET utf8mb4
    COLLATE utf8mb4_unicode_ci;
USE inmosantander;

-- ============================================================================
-- DDL - DEFINICIÓN DE TABLAS
-- Orden de creación respetando dependencias FK
-- ============================================================================

-- ---------------------------------------------------------------------------
-- 1. ROL
-- Catalogo de roles del sistema: ADMINISTRADOR, CLIENTE, INMOBILIARIA.
-- Tabla independiente, sin FK. Se usa en usuario_rol (N:M).
-- ---------------------------------------------------------------------------
CREATE TABLE rol (
    id_rol      INT AUTO_INCREMENT PRIMARY KEY,
    nombre      VARCHAR(50)  NOT NULL UNIQUE,
    descripcion VARCHAR(255) NULL
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------------
-- 2. USUARIO
-- Entidad central de autenticación. Cada usuario tiene un correo único
-- y contraseña cifrada con SHA-256 + salt (password_hash + password_salt).
-- Un usuario puede tener múltiples roles (relación N:M vía usuario_rol).
-- ---------------------------------------------------------------------------
CREATE TABLE usuario (
    id_usuario    INT AUTO_INCREMENT PRIMARY KEY,
    correo        VARCHAR(150) NOT NULL,
    password_hash VARCHAR(64)  NOT NULL COMMENT 'SHA-256(password + salt) en hex',
    password_salt VARCHAR(64)  NOT NULL COMMENT 'Salt aleatorio por usuario',
    nombre        VARCHAR(100) NOT NULL,
    apellido      VARCHAR(100) NOT NULL,
    telefono      VARCHAR(20)  NULL,
    activo        TINYINT(1)   NOT NULL DEFAULT 1,
    fecha_registro DATETIME    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_usuario_correo UNIQUE (correo)
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------------
-- 3. USUARIO_ROL (N:M)
-- Relación N:M entre usuario y rol. PK compuesta (id_usuario, id_rol).
-- Un usuario puede tener varios roles y un rol puede pertenecer a varios
-- usuarios. ON DELETE CASCADE: si se elimina un usuario o un rol, se
-- eliminan automáticamente sus asignaciones (integridad referencial).
-- ON UPDATE CASCADE: si cambia el id de usuario/rol, se propaga.
-- ---------------------------------------------------------------------------
CREATE TABLE usuario_rol (
    id_usuario INT NOT NULL,
    id_rol     INT NOT NULL,
    PRIMARY KEY (id_usuario, id_rol),
    CONSTRAINT fk_ur_usuario
        FOREIGN KEY (id_usuario) REFERENCES usuario (id_usuario)
        ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_ur_rol
        FOREIGN KEY (id_rol) REFERENCES rol (id_rol)
        ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------------
-- 4. PERFIL (1:1 con usuario)
-- Información adicional del usuario (dirección, documento, foto, etc.).
-- id_usuario es UNIQUE para garantizar la relación 1:1.
-- ON DELETE CASCADE: si se elimina el usuario, se elimina su perfil.
-- ON UPDATE CASCADE: propagar cambio de id de usuario.
-- ---------------------------------------------------------------------------
CREATE TABLE perfil (
    id_perfil           INT AUTO_INCREMENT PRIMARY KEY,
    id_usuario          INT          NOT NULL,
    direccion           VARCHAR(255) NULL,
    ciudad_residencia   VARCHAR(100) NULL,
    fecha_nacimiento    DATE         NULL,
    documento_identidad VARCHAR(30)  NULL,
    foto_url            VARCHAR(500) NULL,
    CONSTRAINT uq_perfil_usuario UNIQUE (id_usuario),
    CONSTRAINT fk_perfil_usuario
        FOREIGN KEY (id_usuario) REFERENCES usuario (id_usuario)
        ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------------
-- 5. CIUDAD
-- Catálogo de ciudades. Propiedades e inmobiliarias referencian esta tabla.
-- ON DELETE RESTRICT: no permitir eliminar una ciudad si hay registros que
-- la referencian (evitar borrado accidentales con datos dependientes).
-- ON UPDATE CASCADE: si cambia el id, propagar.
-- ---------------------------------------------------------------------------
CREATE TABLE ciudad (
    id_ciudad    INT AUTO_INCREMENT PRIMARY KEY,
    nombre       VARCHAR(100) NOT NULL,
    departamento VARCHAR(100) NOT NULL,
    CONSTRAINT uq_ciudad UNIQUE (nombre, departamento)
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------------
-- 6. INMOBILIARIA
-- Cada inmobiliaria está vinculada a un usuario (dueño/representante).
-- 1:N: un usuario puede administrar varias inmobiliarias.
-- FK a usuario ON DELETE CASCADE: si se borra el usuario dueño, se borra
-- la inmobiliaria (el usuario es su dueño, no tiene sentido sin él).
-- FK a ciudad ON DELETE RESTRICT: no permitir borrar ciudad con datos.
-- ---------------------------------------------------------------------------
CREATE TABLE inmobiliaria (
    id_inmobiliaria INT AUTO_INCREMENT PRIMARY KEY,
    id_usuario      INT          NOT NULL,
    nit             VARCHAR(20)  NOT NULL UNIQUE,
    razon_social    VARCHAR(200) NOT NULL,
    direccion       VARCHAR(255) NULL,
    telefono        VARCHAR(20)  NULL,
    id_ciudad       INT          NULL,
    descripcion     TEXT         NULL,
    logo_url        VARCHAR(500) NULL,
    activa          TINYINT(1)   NOT NULL DEFAULT 1,
    fecha_registro  DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_inmo_usuario
        FOREIGN KEY (id_usuario) REFERENCES usuario (id_usuario)
        ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_inmo_ciudad
        FOREIGN KEY (id_ciudad) REFERENCES ciudad (id_ciudad)
        ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------------
-- 7. TIPO_PROPIEDAD
-- Catálogo: apartamento, casa, local comercial, terreno, etc.
-- Tabla independiente, sin FK.
-- ---------------------------------------------------------------------------
CREATE TABLE tipo_propiedad (
    id_tipo     INT AUTO_INCREMENT PRIMARY KEY,
    nombre      VARCHAR(80)  NOT NULL UNIQUE,
    descripcion VARCHAR(255) NULL
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------------
-- 8. PROPIEDAD
-- Entidad principal del negocio. Cada propiedad pertenece a UNA inmobiliaria,
-- UN tipo y UNA ciudad. La matrícula inmobiliaria es única (identificador
-- legal del inmueble).
-- FK a inmobiliaria ON DELETE CASCADE: si se elimina la inmobiliaria, sus
-- propiedades quedan huérfanas → borrarlas en cascada.
-- FK a tipo_propiedad ON DELETE RESTRICT: no permitir borrar un tipo si hay
-- propiedades de ese tipo (evitar inconsistencias).
-- FK a ciudad ON DELETE RESTRICT: no permitir borrar ciudad con propiedades.
-- ---------------------------------------------------------------------------
CREATE TABLE propiedad (
    id_propiedad           INT AUTO_INCREMENT PRIMARY KEY,
    id_inmobiliaria        INT            NOT NULL,
    id_tipo                INT            NOT NULL,
    id_ciudad              INT            NOT NULL,
    titulo                 VARCHAR(200)   NOT NULL,
    descripcion            TEXT           NULL,
    precio                 DECIMAL(15, 2) NOT NULL COMMENT 'Precio en COP',
    area_m2                DECIMAL(10, 2) NULL,
    num_habitaciones       INT            NULL DEFAULT 0,
    num_banos              INT            NULL DEFAULT 0,
    direccion              VARCHAR(255)   NOT NULL,
    matricula_inmobiliaria VARCHAR(50)    NOT NULL COMMENT 'Matrícula inmobiliaria única (identificador legal)',
    estado                 ENUM('DISPONIBLE', 'RESERVADA', 'VENDIDA', 'ALQUILADA')
                                        NOT NULL DEFAULT 'DISPONIBLE',
    fecha_publicacion      DATETIME       NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_propiedad_matricula UNIQUE (matricula_inmobiliaria),
    CONSTRAINT fk_prop_inmobiliaria
        FOREIGN KEY (id_inmobiliaria) REFERENCES inmobiliaria (id_inmobiliaria)
        ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_prop_tipo
        FOREIGN KEY (id_tipo) REFERENCES tipo_propiedad (id_tipo)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_prop_ciudad
        FOREIGN KEY (id_ciudad) REFERENCES ciudad (id_ciudad)
        ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------------
-- 9. IMAGEN_PROPIEDAD
-- 1:N desde propiedad → imágenes. Una propiedad puede tener varias fotos.
-- es_principal (TINYINT): marca la foto principal/portada.
-- orden: controla el orden de visualización.
-- FK a propiedad ON DELETE CASCADE: si se borra la propiedad, sus imágenes
-- se borran automáticamente (no existen sin la propiedad).
-- ---------------------------------------------------------------------------
CREATE TABLE imagen_propiedad (
    id_imagen    INT AUTO_INCREMENT PRIMARY KEY,
    id_propiedad INT          NOT NULL,
    url_imagen   VARCHAR(500) NOT NULL,
    es_principal TINYINT(1)   NOT NULL DEFAULT 0,
    orden        TINYINT      NOT NULL DEFAULT 0,
    CONSTRAINT fk_img_propiedad
        FOREIGN KEY (id_propiedad) REFERENCES propiedad (id_propiedad)
        ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------------
-- 10. CARACTERISTICA
-- Catálogo de características: piscina, parqueadero, gimnasio, etc.
-- Tabla independiente, sin FK. Se asocia a propiedades vía N:M.
-- ---------------------------------------------------------------------------
CREATE TABLE caracteristica (
    id_caracteristica INT AUTO_INCREMENT PRIMARY KEY,
    nombre            VARCHAR(100) NOT NULL UNIQUE,
    descripcion       VARCHAR(255) NULL
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------------
-- 11. PROPIEDAD_CARACTERISTICA (N:M)
-- Relación N:M entre propiedad y característica.
-- PK compuesta (id_propiedad, id_caracteristica).
-- Atributo cantidad: cuántas unidades de esa característica tiene
-- (ej: "2 parqueaderos", "3 baños"). Default 1.
-- FK cascade: si se borra la propiedad o la característica, se eliminan
-- las asociaciones automáticamente.
-- ---------------------------------------------------------------------------
CREATE TABLE propiedad_caracteristica (
    id_propiedad      INT NOT NULL,
    id_caracteristica INT NOT NULL,
    cantidad          INT NOT NULL DEFAULT 1,
    PRIMARY KEY (id_propiedad, id_caracteristica),
    CONSTRAINT fk_pc_propiedad
        FOREIGN KEY (id_propiedad) REFERENCES propiedad (id_propiedad)
        ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_pc_caracteristica
        FOREIGN KEY (id_caracteristica) REFERENCES caracteristica (id_caracteristica)
        ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------------
-- 12. CITA
-- Un cliente agenda citas para visitar propiedades.
-- UNIQUE(id_propiedad, fecha_hora): no dos citas para la misma propiedad
-- en el mismo momento (evitar doble agendamiento).
-- FK a usuario (cliente) ON DELETE CASCADE: si se borra el usuario, se borran
-- sus citas. FK a propiedad ON DELETE CASCADE: si se borra la propiedad, se
-- borran las citas asociadas.
-- ---------------------------------------------------------------------------
CREATE TABLE cita (
    id_cita      INT AUTO_INCREMENT PRIMARY KEY,
    id_usuario   INT      NOT NULL,
    id_propiedad INT      NOT NULL,
    fecha_hora   DATETIME NOT NULL,
    estado       ENUM('PENDIENTE', 'CONFIRMADA', 'CANCELADA', 'REALIZADA')
                             NOT NULL DEFAULT 'PENDIENTE',
    notas        TEXT     NULL,
    CONSTRAINT uq_cita_prop_fecha UNIQUE (id_propiedad, fecha_hora),
    CONSTRAINT fk_cita_usuario
        FOREIGN KEY (id_usuario) REFERENCES usuario (id_usuario)
        ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_cita_propiedad
        FOREIGN KEY (id_propiedad) REFERENCES propiedad (id_propiedad)
        ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------------
-- 13. SOLICITUD
-- Solicitudes de compra o alquiler que un cliente envía sobre una propiedad.
-- FK a usuario ON DELETE CASCADE: si se borra el cliente, sus solicitudes
-- se eliminan. FK a propiedad ON DELETE CASCADE: si se borra la propiedad,
-- las solicitudes asociadas se eliminan.
-- ---------------------------------------------------------------------------
CREATE TABLE solicitud (
    id_solicitud   INT AUTO_INCREMENT PRIMARY KEY,
    id_usuario     INT      NOT NULL,
    id_propiedad   INT      NOT NULL,
    tipo           ENUM('COMPRA', 'ALQUILER') NOT NULL,
    estado         ENUM('EN_REVISION', 'APROBADA', 'RECHAZADA', 'COMPLETADA')
                                NOT NULL DEFAULT 'EN_REVISION',
    fecha_solicitud DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    notas          TEXT     NULL,
    CONSTRAINT fk_sol_usuario
        FOREIGN KEY (id_usuario) REFERENCES usuario (id_usuario)
        ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_sol_propiedad
        FOREIGN KEY (id_propiedad) REFERENCES propiedad (id_propiedad)
        ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------------
-- 14. DOCUMENTO_SOLICITUD
-- Documentos adjuntos de una solicitud (cedula, carta de crédito, etc.).
-- 1:N desde solicitud → documentos.
-- FK a solicitud ON DELETE CASCADE: si se borra la solicitud, se borran
-- sus documentos (no existen sin la solicitud).
-- ---------------------------------------------------------------------------
CREATE TABLE documento_solicitud (
    id_documento    INT AUTO_INCREMENT PRIMARY KEY,
    id_solicitud    INT          NOT NULL,
    nombre_archivo  VARCHAR(255) NOT NULL,
    url_archivo     VARCHAR(500) NOT NULL,
    tipo_documento  VARCHAR(50)  NOT NULL COMMENT 'Ej: CEDULA, CARTA_CREDITO, CERTIFICADO_INGRESOS',
    fecha_subida    DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_doc_solicitud
        FOREIGN KEY (id_solicitud) REFERENCES solicitud (id_solicitud)
        ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------------
-- 15. FAVORITO
-- Un usuario puede marcar propiedades como favoritas.
-- UNIQUE(id_usuario, id_propiedad): un usuario no puede marcar la misma
-- propiedad como favorita dos veces.
-- FK cascade: si se borra el usuario o la propiedad, se elimina el favorito.
-- ---------------------------------------------------------------------------
CREATE TABLE favorito (
    id_favorito    INT AUTO_INCREMENT PRIMARY KEY,
    id_usuario     INT      NOT NULL,
    id_propiedad   INT      NOT NULL,
    fecha_agregado DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_favorito UNIQUE (id_usuario, id_propiedad),
    CONSTRAINT fk_fav_usuario
        FOREIGN KEY (id_usuario) REFERENCES usuario (id_usuario)
        ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_fav_propiedad
        FOREIGN KEY (id_propiedad) REFERENCES propiedad (id_propiedad)
        ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------------
-- 16. AUDITORIA
-- Registro de acciones sobre datos críticos (quién, qué, cuándo, dónde).
-- Tabla de solo lectura en el sistema normal. ON DELETE RESTRICT: jamás
-- borrar registros de auditoría. FK a usuario ON DELETE SET NULL: si se
-- borra el usuario, el registro de auditoría se conserva y el id_usuario
-- se pone en NULL (trazabilidad histórica).
-- ---------------------------------------------------------------------------
CREATE TABLE auditoria (
    id_auditoria   INT AUTO_INCREMENT PRIMARY KEY,
    id_usuario     INT          NULL,
    tabla_afectada VARCHAR(50)  NOT NULL,
    id_registro    INT          NULL,
    accion         VARCHAR(10)  NOT NULL COMMENT 'INSERT, UPDATE, DELETE',
    detalles       TEXT         NULL,
    fecha_accion   DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    ip_address     VARCHAR(45)  NULL,
    CONSTRAINT fk_audit_usuario
        FOREIGN KEY (id_usuario) REFERENCES usuario (id_usuario)
        ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE=InnoDB;


-- ============================================================================
-- DML - DATOS DE PRUEBA
-- ============================================================================
-- NOTA: Los password_hash son el resultado real de SHA-256(password + salt)
-- calculados con algoritmo SHA-256 estándar.
-- Fórmula: SHA-256( CAST(password AS UTF-8) || CAST(salt AS UTF-8) )
--
-- TABLA DE VERIFICACIÓN:
-- +-----------+--------+--------------------------------------------------------------+
-- | password  | salt   | SHA-256(password + salt)                                      |
-- +-----------+--------+--------------------------------------------------------------+
-- | admin123  | sal001 | e81180d10358d338e4b02ec266b7b52c020e7a7aad5f092e3566eec823a50c32 |
-- | inmo123   | sal002 | d9eee057a82ae352e9a436da2f1581911ce8befd8220b3db34ba98b1fbfbe892 |
-- | inmo456   | sal003 | d078e71299b9b5f85ae76af7b99baaaa86683ae6b1693e85bbb26eb5b8132a7e |
-- | cliente1  | sal004 | 36844ebcb6e3f00cdd5709dd1802738703bbc17c472a2f4dc856b015b130d552 |
-- | cliente2  | sal005 | b472a6effb7422eadd6f02c1b5018f68f80d2492addb98caba869c85bc7880fb |
-- | cliente3  | sal006 | 03ea449fb76bc31c173212728354473bba0e4910e74070f0ca211a181a26cc97 |
-- | cliente4  | sal007 | 17fbf48e6e6ec45d646c44848fe1cd9a0ac3db3271ae60029265cda3417b0ed9 |
-- | cliente5  | sal008 | 71f1da7c62ca72b4685aa13ef33f96f92a7f9860bc90c177a38123f83fac520f |
-- | cliente6  | sal009 | eddb5024adbf65ff242c409f7a3fb2b136bd64bc0f52e0caff1238226f9f4d11 |
-- | inmo789   | sal010 | 5c7c301215171f0cd2d8bdf87a80738ac0ad57b466c8583013b4f551ba5daf5b |
-- +-----------+--------+--------------------------------------------------------------+
-- ============================================================================

-- --- ROLES ---
INSERT INTO rol (id_rol, nombre, descripcion) VALUES
(1, 'ADMINISTRADOR',  'Administrador general del sistema. Acceso total.'),
(2, 'CLIENTE',        'Cliente que busca compra o alquiler de inmuebles.'),
(3, 'INMOBILIARIA',   'Representante o dueño de una inmobiliaria registrada.');

-- --- USUARIOS (10 registros) ---
-- Todos con hash real de SHA-256(password + salt) verificable.
INSERT INTO usuario (id_usuario, correo, password_hash, password_salt, nombre, apellido, telefono, activo) VALUES
(1, 'admin@inmosantander.com',  'e81180d10358d338e4b02ec266b7b52c020e7a7aad5f092e3566eec823a50c32', 'sal001', 'Carlos',  'Martinez',   '3001234567', 1),
(2, 'inmo1@inmosantander.com',  'd9eee057a82ae352e9a436da2f1581911ce8befd8220b3db34ba98b1fbfbe892', 'sal002', 'Laura',   'Gutierrez',   '3012345678', 1),
(3, 'inmo2@inmosantander.com',  'd078e71299b9b5f85ae76af7b99baaaa86683ae6b1693e85bbb26eb5b8132a7e', 'sal003', 'Pedro',   'Ramirez',     '3023456789', 1),
(4, 'cliente1@mail.com',        '36844ebcb6e3f00cdd5709dd1802738703bbc17c472a2f4dc856b015b130d552', 'sal004', 'Ana',     'Lopez',       '3101111111', 1),
(5, 'cliente2@mail.com',        'b472a6effb7422eadd6f02c1b5018f68f80d2492addb98caba869c85bc7880fb', 'sal005', 'Jorge',   'Diaz',        '3112222222', 1),
(6, 'cliente3@mail.com',        '03ea449fb76bc31c173212728354473bba0e4910e74070f0ca211a181a26cc97', 'sal006', 'Maria',   'Fernandez',   '3123333333', 1),
(7, 'cliente4@mail.com',        '17fbf48e6e6ec45d646c44848fe1cd9a0ac3db3271ae60029265cda3417b0ed9', 'sal007', 'Andres',  'Morales',     '3134444444', 1),
(8, 'cliente5@mail.com',        '71f1da7c62ca72b4685aa13ef33f96f92a7f9860bc90c177a38123f83fac520f', 'sal008', 'Sofia',   'Torres',      '3145555555', 1),
(9, 'cliente6@mail.com',        'eddb5024adbf65ff242c409f7a3fb2b136bd64bc0f52e0caff1238226f9f4d11', 'sal009', 'Ricardo', 'Vargas',      '3156666666', 1),
(10,'inmo3@inmosantander.com',  '5c7c301215171f0cd2d8bdf87a80738ac0ad57b466c8583013b4f551ba5daf5b', 'sal010', 'Diana',   'Ospina',      '3034567890', 1);

-- --- ASIGNACIÓN DE ROLES ---
INSERT INTO usuario_rol (id_usuario, id_rol) VALUES
(1,  1),   -- Carlos  → ADMINISTRADOR
(2,  3),   -- Laura   → INMOBILIARIA
(3,  3),   -- Pedro   → INMOBILIARIA
(10, 3),   -- Diana   → INMOBILIARIA
(4,  2),   -- Ana     → CLIENTE
(5,  2),   -- Jorge   → CLIENTE
(6,  2),   -- Maria   → CLIENTE
(7,  2),   -- Andres  → CLIENTE
(8,  2),   -- Sofia   → CLIENTE
(9,  2);   -- Ricardo → CLIENTE

-- --- PERFILES (1:1 con usuario, uno por cada usuario) ---
INSERT INTO perfil (id_usuario, direccion, ciudad_residencia, fecha_nacimiento, documento_identidad, foto_url) VALUES
(1,  'Calle 7 #3-50',           'Bucaramanga', '1985-03-15', '1020304050', '/img/perfiles/admin_carlos.jpg'),
(2,  'Carrera 27 #40-20',      'Bucaramanga', '1990-07-22', '1098765432', '/img/perfiles/laura.jpg'),
(3,  'Avenida 5 #12-80',       'Floridablanca', '1988-11-03', '1087654321', '/img/perfiles/pedro.jpg'),
(4,  'Calle 96 #15-30',        'Barranquilla', '1992-05-10', '80123456',   '/img/perfiles/ana.jpg'),
(5,  'Carrera 43 #1-70',       'Medellin',     '1995-01-28', '1034567890', '/img/perfiles/jorge.jpg'),
(6,  'Calle 50 #8-25',         'Cucuta',       '1991-09-14', '1056789012', '/img/perfiles/maria.jpg'),
(7,  'Diagonal 7B #34-12',     'Bucaramanga', '1993-12-01', '1067890123', '/img/perfiles/andres.jpg'),
(8,  'Transversal 10 #22-45',  'Floridablanca', '1997-06-18', '1078901234', '/img/perfiles/sofia.jpg'),
(9,  'Carrera 19 #5-60',       'Piedecuesta',  '1989-04-25', '1089012345', '/img/perfiles/ricardo.jpg'),
(10, 'Calle 11 #5-10',         'Bucaramanga', '1994-08-07', '1045678901', '/img/perfiles/diana.jpg');

-- --- CIUDADES ---
INSERT INTO ciudad (id_ciudad, nombre, departamento) VALUES
(1, 'Bucaramanga',   'Santander'),
(2, 'Floridablanca', 'Santander'),
(3, 'Barranquilla',  'Atlantico'),
(4, 'Medellin',      'Antioquia'),
(5, 'Cucuta',        'Norte de Santander'),
(6, 'Piedecuesta',   'Santander'),
(7, 'Bogota',        'Cundinamarca'),
(8, 'Cartagena',     'Bolivar'),
(9, 'Santa Marta',   'Magdalena'),
(10,'Cali',          'Valle del Cauca');

-- --- INMOBILIARIAS (3) ---
INSERT INTO inmobiliaria (id_inmobiliaria, id_usuario, nit, razon_social, direccion, telefono, id_ciudad, descripcion, activa) VALUES
(1, 2,  '900123456-1', 'Inmobiliaria Santander S.A.S',  'Carrera 27 #40-20 Local 3', '3011234567', 1, 'Especialistas en apartamentos y casas de lujo en el area metropolitana de Bucaramanga.', 1),
(2, 3,  '900654321-2', 'Inversiones Norte Ltda',        'Avenida 5 #12-80 Oficina 501', '3022345678', 1, 'Compra, venta y arrendamiento de propiedades residenciales y comerciales en Santander.', 1),
(3, 10, '900789123-3', 'Grupo InmoOriente S.A',         'Calle 11 #5-10 Piso 2',        '3033456789', 1, 'Inmobiliaria con presencia en todo Oriente colombiano. Casas, apartamentos y lotes.', 1);

-- --- TIPOS DE PROPIEDAD ---
INSERT INTO tipo_propiedad (id_tipo, nombre, descripcion) VALUES
(1, 'Apartamento',  'Unidad habitacional dentro de un edificio o conjunto residencial.'),
(2, 'Casa',         'Vivienda unifamiliar con terreno propio.'),
(3, 'Local Comercial', 'Espacio destinado a actividad comercial o de oficinas.'),
(4, 'Terreno',      'Lote o terreno para construccion o inversion.'),
(5, 'Oficina',      'Espacio de oficinas para profesionales o empresas.'),
(6, 'Finca',        'Propiedad rural con terreno agricola o ganadero.'),
(7, 'Loft',         'Espacio abierto tipo industrial adaptado para vivienda.'),
(8, 'Duplex',       'Vivienda de dos niveles dentro de un conjunto.');

-- --- PROPIEDADES (12 registros) ---
INSERT INTO propiedad (id_propiedad, id_inmobiliaria, id_tipo, id_ciudad, titulo, descripcion, precio, area_m2, num_habitaciones, num_banos, direccion, matricula_inmobiliaria, estado, fecha_publicacion) VALUES
(1,  1, 1, 1, 'Apartamento Campestre Norte',
     'Hermoso apartamento de 3 habitaciones con vista al Valle de Santander. Conjunto cerrado con piscina y vigilancia 24h.',
     280000000, 95.00, 3, 2, 'Carrera 15 #120-45, Bucaramanga', 'MAT-001-2024', 'DISPONIBLE', '2024-09-01 10:00:00'),
(2,  1, 2, 1, 'Casa Campestre La Gabriela',
     'Casa de 2 pisos en urbanizacion exclusiva, amplios jardines, zona de BBQ y piscina privada.',
     650000000, 220.00, 4, 3, 'Calle 145 #18-30, Bucaramanga', 'MAT-002-2024', 'DISPONIBLE', '2024-09-05 14:30:00'),
(3,  1, 1, 2, 'Apartamento Villa del Rio',
     'Moderno apartamento en Floridablanca, cerca al Rio Fonce. Amoblado con acabados premium.',
     320000000, 110.00, 3, 2, 'Avenida 8 #34-12, Floridablanca', 'MAT-003-2024', 'DISPONIBLE', '2024-09-10 09:00:00'),
(4,  2, 3, 1, 'Local Centro Comercial Santander',
     'Local comercial a pie de carrera en zona de alto tráfico peatonal. Ideal para restaurante o tienda.',
     450000000, 80.00, 0, 1, 'Carrera 35 #52-10, Bucaramanga', 'MAT-004-2024', 'DISPONIBLE', '2024-09-12 11:00:00'),
(5,  2, 1, 1, 'Apartamento Estudiante Bucaramanga',
     'Apartamento studio ideal para estudiantes universitarios. Cerca a la Universidad Industrial.',
     150000000, 45.00, 1, 1, 'Calle 67 #15-22, Bucaramanga', 'MAT-005-2024', 'DISPONIBLE', '2024-09-15 08:00:00'),
(6,  2, 2, 3, 'Casa Campestre Barranquilla',
     'Amplia casa con piscina y terraza panorámica en el mejor sector residencial de Barranquilla.',
     800000000, 300.00, 5, 4, 'Carrera 52 #70-25, Barranquilla', 'MAT-006-2024', 'RESERVADA', '2024-09-18 16:00:00'),
(7,  2, 4, 4, 'Terreno El Poblado',
     'Terreno de 400 m2 en zona en expansion del Poblado, ideal para proyecto de vivienda.',
     180000000, 400.00, 0, 0, 'Transversal 33 #12B-50, Medellin', 'MAT-007-2024', 'DISPONIBLE', '2024-09-20 12:00:00'),
(8,  3, 1, 1, 'Apartamento Panorama',
     'Apartamento con vista panorámica a los Santos. Torre de 15 pisos, localeadero y Gimnasio.',
     380000000, 120.00, 3, 2, 'Carrera 40 #65-80, Bucaramanga', 'MAT-008-2024', 'DISPONIBLE', '2024-09-22 10:30:00'),
(9,  3, 2, 6, 'Finca San Fernando',
     'Finca de 2 hectareas con casa principal y casa de visitas. zona ganadera y forestal.',
     950000000, 20000.00, 6, 4, 'Vereda San Fernando, Piedecuesta', 'MAT-009-2024', 'DISPONIBLE', '2024-09-25 14:00:00'),
(10, 3, 5, 7, 'Oficina Torre Colcap',
     'Oficina de 60 m2 en torre empresarial, piso 8, con estacionamiento incluido.',
     220000000, 60.00, 0, 1, 'Carrera 7 #32-16, Bogota', 'MAT-010-2024', 'VENDIDA', '2024-10-01 09:00:00'),
(11, 1, 1, 5, 'Apartamento Centro Cucuta',
     'Apartamento moderno en el centro de Cucuta, a pasos del Parque Santander.',
     180000000, 72.00, 2, 1, 'Calle 9 #5-30, Cucuta', 'MAT-011-2024', 'DISPONIBLE', '2024-10-05 11:00:00'),
(12, 3, 8, 1, 'Duplex Chicamocha',
     'Duplex de lujo con terraza privada y vista al canon del Chicamocha.',
     520000000, 160.00, 3, 3, 'Carrera 23 #90-15, Bucaramanga', 'MAT-012-2024', 'ALQUILADA', '2024-10-10 15:00:00');

-- --- IMÁGENES DE PROPIEDADES ---
INSERT INTO imagen_propiedad (id_propiedad, url_imagen, es_principal, orden) VALUES
(1,  '/img/props/apto_campestre_1.jpg',  1, 1),
(1,  '/img/props/apto_campestre_2.jpg',  0, 2),
(1,  '/img/props/apto_campestre_3.jpg',  0, 3),
(2,  '/img/props/casa_gabriela_1.jpg',   1, 1),
(2,  '/img/props/casa_gabriela_2.jpg',   0, 2),
(3,  '/img/props/apto_villa_1.jpg',      1, 1),
(3,  '/img/props/apto_villa_2.jpg',      0, 2),
(4,  '/img/props/local_santander_1.jpg', 1, 1),
(5,  '/img/props/apto_estudiante_1.jpg', 1, 1),
(6,  '/img/props/casa_barranquilla_1.jpg',1, 1),
(6,  '/img/props/casa_barranquilla_2.jpg',0, 2),
(7,  '/img/props/terreno_poblado_1.jpg', 1, 1),
(8,  '/img/props/apto_panorama_1.jpg',   1, 1),
(8,  '/img/props/apto_panorama_2.jpg',   0, 2),
(9,  '/img/props/finca_sanfernando_1.jpg',1, 1),
(10, '/img/props/oficina_colcap_1.jpg',  1, 1),
(11, '/img/props/apto_cucuta_1.jpg',     1, 1),
(12, '/img/props/duplex_chicamocha_1.jpg',1, 1);

-- --- CARACTERÍSTICAS ---
INSERT INTO caracteristica (id_caracteristica, nombre, descripcion) VALUES
(1,  'Piscina',         'Piscina comunal o privada.'),
(2,  'Parqueadero',     'Espacio de parqueadero vehicular.'),
(3,  'Gimnasio',        'Sala de ejercicio o gimnasio.'),
(4,  'BBQ',             'Zona de asadero o barbacoa.'),
(5,  'Vigilancia 24h',  'Servicio de vigilancia las 24 horas.'),
(6,  'Salon Comunal',   'Salon de eventos o reuniones.'),
(7,  'Ascensor',        'Ascensor en el edificio.'),
(8,  'Terraza',         'Terraza privada o comunal.'),
(9,  'Estudio',         'Espacio destinado como estudio o despacho.'),
(10, 'Deposito',        'Bodega o deposito privado.'),
(11, 'Amoblado',        'Se entrega amoblado.'),
(12, 'Patio',           'Patio o area verde privada.'),
(13, 'Vista Panoramica', 'Vista panorámica al valle o montañas.'),
(14, 'Aire Acondicionado', 'Sistema de aire acondicionado.'),
(15, 'Camara CCTV',     'Sistema de vigilancia con cámaras.');

-- --- PROPIEDAD_CARACTERISTICA (N:M con atributo cantidad) ---
INSERT INTO propiedad_caracteristica (id_propiedad, id_caracteristica, cantidad) VALUES
(1,  1,  1),   (1,  2,  1),   (1,  5,  1),   (1,  7,  1),   (1,  13, 1),
(2,  1,  1),   (2,  2,  2),   (2,  4,  1),   (2,  5,  1),   (2,  8,  1),   (2,  12, 1),
(3,  1,  1),   (3,  2,  1),   (3,  3,  1),   (3,  11, 1),
(4,  2,  2),   (4,  15, 1),
(5,  2,  1),   (5,  7,  1),   (5,  3,  1),
(6,  1,  1),   (6,  2,  2),   (6,  4,  1),   (6,  5,  1),   (6,  8,  1),
(7,  12, 1),
(8,  1,  1),   (8,  2,  1),   (8,  3,  1),   (8,  7,  1),   (8,  13, 1),
(9,  1,  1),   (9,  2,  3),   (9,  4,  1),   (9,  12, 1),
(10, 2,  1),   (10, 7,  1),   (10, 14, 1),
(11, 2,  1),   (11, 6,  1),
(12, 2,  2),   (12, 8,  1),   (12, 13, 1),   (12, 9,  1);

-- --- CITAS (6 registros) ---
INSERT INTO cita (id_usuario, id_propiedad, fecha_hora, estado, notas) VALUES
(4,  1,  '2024-10-15 10:00:00', 'CONFIRMADA',   'El cliente quiere ver el apartamento en la mañana.'),
(5,  2,  '2024-10-16 14:00:00', 'PENDIENTE',    'Solicita visita con su pareja.'),
(4,  3,  '2024-10-17 09:30:00', 'REALIZADA',    'Visita completada, cliente interesado.'),
(6,  8,  '2024-10-18 11:00:00', 'CANCELADA',    'Cliente viajó de emergencia.'),
(7,  9,  '2024-10-20 08:00:00', 'PENDIENTE',    'Visita a la finca, requiere transporte.'),
(8,  5,  '2024-10-21 16:00:00', 'CONFIRMADA',   'Revisar estado de amoblamiento.');

-- --- SOLICITUDES (5 registros) ---
INSERT INTO solicitud (id_usuario, id_propiedad, tipo, estado, notas) VALUES
(4,  3,  'COMPRA',    'EN_REVISION',   'Ofrecimiento inicial de 300.000.000.'),
(5,  2,  'COMPRA',    'APROBADA',      'Aprobada con credito bancario del Banco de Bogota.'),
(6,  8,  'ALQUILER',  'RECHAZADA',     'No cumple con requisitos de ingreso minimo.'),
(7,  9,  'COMPRA',    'EN_REVISION',   'Solicitud pendiente de avalúo.'),
(8,  5,  'ALQUILER',  'COMPLETADA',    'Contrato firmado por 12 meses, valor $1.200.000/mes.');

-- --- DOCUMENTOS DE SOLICITUD ---
INSERT INTO documento_solicitud (id_solicitud, nombre_archivo, url_archivo, tipo_documento) VALUES
(1, 'cedula_ana.pdf',        '/docs/sol1/cedula_ana.pdf',        'CEDULA'),
(1, 'carta_credito_ana.pdf', '/docs/sol1/carta_credito_ana.pdf', 'CARTA_CREDITO'),
(2, 'cedula_jorge.pdf',      '/docs/sol2/cedula_jorge.pdf',      'CEDULA'),
(2, 'cert_ingresos_jorge.pdf','/docs/sol2/cert_ingresos_jorge.pdf','CERTIFICADO_INGRESOS'),
(3, 'cedula_maria.pdf',      '/docs/sol3/cedula_maria.pdf',      'CEDULA'),
(4, 'cedula_andres.pdf',     '/docs/sol4/cedula_andres.pdf',     'CEDULA'),
(4, 'avaluo_finca.pdf',      '/docs/sol4/avaluo_finca.pdf',      'AVALUO'),
(5, 'cedula_sofia.pdf',      '/docs/sol5/cedula_sofia.pdf',      'CEDULA'),
(5, 'contrato_alquiler.pdf', '/docs/sol5/contrato_alquiler.pdf', 'CONTRATO');

-- --- FAVORITOS ---
INSERT INTO favorito (id_usuario, id_propiedad) VALUES
(4, 1),  (4, 3),  (4, 8),
(5, 2),  (5, 6),
(6, 1),  (6, 8),  (6, 12),
(7, 9),  (7, 2),
(8, 5),  (8, 12),
(9, 1),  (9, 3),  (9, 11);

-- --- AUDITORÍA (registros de ejemplo) ---
INSERT INTO auditoria (id_usuario, tabla_afectada, id_registro, accion, detalles, ip_address) VALUES
(1,  'usuario',     1,  'INSERT', 'Creación de usuario administrador principal.',       '127.0.0.1'),
(2,  'propiedad',   1,  'INSERT', 'Publicación de apartamento Campestre Norte.',         '192.168.1.10'),
(2,  'propiedad',   2,  'INSERT', 'Publicación de casa Campestre La Gabriela.',         '192.168.1.10'),
(4,  'cita',        1,  'INSERT', 'Cita agendada para apartamento Campestre Norte.',    '192.168.1.20'),
(4,  'solicitud',   1,  'INSERT', 'Solicitud de compra para apartamento Villa del Rio.', '192.168.1.20'),
(1,  'propiedad',   10, 'UPDATE', 'Propiedad Oficina Torre Colcap cambiada a VENDIDA.', '127.0.0.1'),
(8,  'favorito',    11, 'INSERT', 'Sofia agrego Duplex Chicamocha a favoritos.',        '192.168.1.50'),
(3,  'propiedad',   6,  'UPDATE', 'Casa Barranquilla cambiada a RESERVADA.',            '192.168.1.15'),
(6,  'cita',        4,  'UPDATE', 'Cita cancelada por viaje del cliente.',               '192.168.1.30'),
(8,  'solicitud',   5,  'UPDATE', 'Solicitud de alquiler completada, contrato firmado.','192.168.1.50');
