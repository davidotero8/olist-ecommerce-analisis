-- =====================================================================
-- 02 · Carga de los CSV limpios en las tablas
-- Los CSV de data/clean están montados dentro del contenedor en /data/clean.
-- El orden importa: primero las tablas a las que otras apuntan (claves foráneas).
-- Se puede ejecutar varias veces: vacía las tablas antes de cargar.
-- =====================================================================

TRUNCATE TABLE reviews, payments, items, orders, products, sellers,
               customers, geolocation, translation CASCADE;

COPY translation (product_category_name, product_category_name_english)
FROM '/data/clean/translation.csv' WITH (FORMAT csv, HEADER true);

COPY geolocation (geolocation_zip_code_prefix, geolocation_lat, geolocation_lng)
FROM '/data/clean/geolocation.csv' WITH (FORMAT csv, HEADER true);

COPY customers (customer_id, customer_unique_id, customer_zip_code_prefix, customer_city, customer_state)
FROM '/data/clean/customers.csv' WITH (FORMAT csv, HEADER true);

COPY sellers (seller_id, seller_zip_code_prefix, seller_city, seller_state)
FROM '/data/clean/sellers.csv' WITH (FORMAT csv, HEADER true);

COPY products (product_id, product_category_name, product_name_length, product_description_length,
               product_photos_qty, product_weight_g, product_length_cm, product_height_cm, product_width_cm)
FROM '/data/clean/products.csv' WITH (FORMAT csv, HEADER true);

COPY orders (order_id, customer_id, order_status, order_purchase_timestamp, order_approved_at,
             order_delivered_carrier_date, order_delivered_customer_date, order_estimated_delivery_date,
             fechas_incoherentes)
FROM '/data/clean/orders.csv' WITH (FORMAT csv, HEADER true);

COPY items (order_id, order_item_id, product_id, seller_id, shipping_limit_date, price, freight_value)
FROM '/data/clean/items.csv' WITH (FORMAT csv, HEADER true);

COPY payments (order_id, payment_sequential, payment_type, payment_installments, payment_value)
FROM '/data/clean/payments.csv' WITH (FORMAT csv, HEADER true);

-- OJO: en el CSV de reseñas review_id va ANTES que order_id (al revés que en la tabla),
-- por eso la lista de columnas sigue el orden del CSV, no el de la tabla.
COPY reviews (review_id, order_id, review_score, review_comment_title, review_comment_message,
              review_creation_date, review_answer_timestamp)
FROM '/data/clean/reviews.csv' WITH (FORMAT csv, HEADER true);
