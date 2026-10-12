-- =====================================================================
-- 01 · Esquema de la base de datos Olist (PostgreSQL 16)
-- Crea las 9 tablas con sus tipos, claves primarias y claves foráneas.
-- Se puede ejecutar varias veces: borra y recrea todo desde cero.
-- =====================================================================

-- Borrado de todas las tablas (no falla si no existen)
DROP TABLE IF EXISTS reviews, payments, items, orders, products, sellers,
                     customers, geolocation, translation CASCADE;

-- ---------------------------------------------------------------------
-- Tablas de referencia (no dependen de ninguna otra)
-- ---------------------------------------------------------------------

CREATE TABLE translation (
    product_category_name         varchar PRIMARY KEY,
    product_category_name_english varchar NOT NULL
);

CREATE TABLE geolocation (
    geolocation_zip_code_prefix integer PRIMARY KEY,
    geolocation_lat             double precision NOT NULL,
    geolocation_lng             double precision NOT NULL
);

-- customer_id cambia en cada pedido; customer_unique_id identifica a la persona real.
-- El código postal no es clave foránea: 279 clientes no tienen coordenadas.
CREATE TABLE customers (
    customer_id              varchar PRIMARY KEY,
    customer_unique_id       varchar NOT NULL,
    customer_zip_code_prefix integer,
    customer_city            varchar,
    customer_state           char(2)
);

CREATE TABLE sellers (
    seller_id              varchar PRIMARY KEY,
    seller_zip_code_prefix integer,
    seller_city            varchar,
    seller_state           char(2)
);

-- ---------------------------------------------------------------------
-- Productos y pedidos
-- ---------------------------------------------------------------------

-- Longitudes y medidas en numeric: en el CSV aparecen como 40.0 (pandas las guardó
-- como decimales al tener nulos) y un integer rechazaría ese formato.
CREATE TABLE products (
    product_id                 varchar PRIMARY KEY,
    product_category_name      varchar,
    product_name_length        numeric,
    product_description_length numeric,
    product_photos_qty         numeric,
    product_weight_g           numeric,
    product_length_cm          numeric,
    product_height_cm          numeric,
    product_width_cm           numeric,
    FOREIGN KEY (product_category_name) REFERENCES translation (product_category_name)
);

CREATE TABLE orders (
    order_id                      varchar PRIMARY KEY,
    customer_id                   varchar NOT NULL,
    order_status                  varchar NOT NULL,
    order_purchase_timestamp      timestamp NOT NULL,
    order_approved_at             timestamp,
    order_delivered_carrier_date  timestamp,
    order_delivered_customer_date timestamp,
    order_estimated_delivery_date timestamp NOT NULL,
    fechas_incoherentes           boolean NOT NULL,   -- marca puesta en la limpieza
    FOREIGN KEY (customer_id) REFERENCES customers (customer_id)
);

-- ---------------------------------------------------------------------
-- Detalle de pedidos
-- ---------------------------------------------------------------------

-- Una fila por artículo dentro de un pedido: clave compuesta
CREATE TABLE items (
    order_id            varchar NOT NULL,
    order_item_id       integer NOT NULL,
    product_id          varchar NOT NULL,
    seller_id           varchar NOT NULL,
    shipping_limit_date timestamp,
    price               numeric(10, 2) NOT NULL,
    freight_value       numeric(10, 2) NOT NULL,
    PRIMARY KEY (order_id, order_item_id),
    FOREIGN KEY (order_id)   REFERENCES orders (order_id),
    FOREIGN KEY (product_id) REFERENCES products (product_id),
    FOREIGN KEY (seller_id)  REFERENCES sellers (seller_id)
);

-- Un pedido puede pagarse con varios métodos: clave compuesta
CREATE TABLE payments (
    order_id             varchar NOT NULL,
    payment_sequential   integer NOT NULL,
    payment_type         varchar NOT NULL,
    payment_installments integer NOT NULL,
    payment_value        numeric(10, 2) NOT NULL,
    PRIMARY KEY (order_id, payment_sequential),
    FOREIGN KEY (order_id) REFERENCES orders (order_id)
);

-- Una reseña por pedido tras la limpieza (order_id es la clave).
-- review_id NO es único: una misma reseña puede estar asociada a varios pedidos.
CREATE TABLE reviews (
    order_id                varchar PRIMARY KEY,
    review_id               varchar NOT NULL,
    review_score            smallint NOT NULL CHECK (review_score BETWEEN 1 AND 5),
    review_comment_title    varchar,
    review_comment_message  varchar,
    review_creation_date    timestamp,
    review_answer_timestamp timestamp,
    FOREIGN KEY (order_id) REFERENCES orders (order_id)
);
