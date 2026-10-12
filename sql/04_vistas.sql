-- =====================================================================
-- 04 · Vistas para Power BI
-- Una vista es una consulta guardada con nombre que se usa como una tabla.
-- Aquí se dejan calculados los campos del análisis (retraso, ingresos por pedido...)
-- para que Power BI solo tenga que visualizar.
-- Se puede ejecutar varias veces (CREATE OR REPLACE).
-- =====================================================================

-- ---------------------------------------------------------------------
-- v_pedidos: UNA FILA POR PEDIDO (99.441 filas)
-- Los importes de items se agregan ANTES de unirlos, para no multiplicar filas.
-- ---------------------------------------------------------------------
CREATE OR REPLACE VIEW v_pedidos AS
WITH importes AS (
    SELECT order_id,
           SUM(price)         AS ingresos,
           SUM(freight_value) AS flete,
           COUNT(*)           AS articulos
    FROM items
    GROUP BY order_id
),
estados (codigo, nombre) AS (
    VALUES ('AC','Acre'), ('AL','Alagoas'), ('AP','Amapá'), ('AM','Amazonas'), ('BA','Bahia'),
           ('CE','Ceará'), ('DF','Distrito Federal'), ('ES','Espírito Santo'), ('GO','Goiás'),
           ('MA','Maranhão'), ('MT','Mato Grosso'), ('MS','Mato Grosso do Sul'), ('MG','Minas Gerais'),
           ('PA','Pará'), ('PB','Paraíba'), ('PR','Paraná'), ('PE','Pernambuco'), ('PI','Piauí'),
           ('RJ','Rio de Janeiro'), ('RN','Rio Grande do Norte'), ('RS','Rio Grande do Sul'),
           ('RO','Rondônia'), ('RR','Roraima'), ('SC','Santa Catarina'), ('SP','São Paulo'),
           ('SE','Sergipe'), ('TO','Tocantins')
),
base AS (
    SELECT o.order_id,
           c.customer_unique_id,
           c.customer_state                                        AS estado,
           e.nombre                                                AS estado_nombre,
           o.order_status                                          AS estado_pedido,
           o.order_purchase_timestamp::date                        AS fecha_compra,
           date_trunc('month', o.order_purchase_timestamp)::date   AS mes_compra,
           o.order_delivered_customer_date::date                   AS fecha_entrega,
           o.order_estimated_delivery_date::date                   AS fecha_estimada,
           o.fechas_incoherentes,
           COALESCE(i.ingresos, 0)                                 AS ingresos,
           COALESCE(i.flete, 0)                                    AS flete,
           COALESCE(i.articulos, 0)                                AS articulos,
           -- Retraso solo en pedidos entregados, con fecha de entrega y fechas coherentes
           CASE WHEN o.order_status = 'delivered'
                 AND o.order_delivered_customer_date IS NOT NULL
                 AND NOT o.fechas_incoherentes
                THEN o.order_delivered_customer_date::date - o.order_estimated_delivery_date::date
           END                                                     AS dias_retraso,
           r.review_score                                          AS nota
    FROM orders o
    JOIN customers c        ON c.customer_id = o.customer_id
    LEFT JOIN estados e     ON e.codigo = c.customer_state
    LEFT JOIN importes i    ON i.order_id = o.order_id
    LEFT JOIN reviews r     ON r.order_id = o.order_id
)
SELECT base.*,
       CASE WHEN dias_retraso IS NULL THEN NULL
            WHEN dias_retraso > 0 THEN 1 ELSE 0 END               AS entrega_tardia,
       CASE WHEN dias_retraso IS NULL THEN NULL
            WHEN dias_retraso <= 0 THEN '1. En plazo'
            WHEN dias_retraso <= 3 THEN '2. 1-3 días tarde'
            WHEN dias_retraso <= 7 THEN '3. 4-7 días tarde'
            ELSE '4. Más de 7 días tarde' END                     AS tramo_retraso
FROM base;


-- ---------------------------------------------------------------------
-- v_items: UNA FILA POR ARTÍCULO VENDIDO (112.650 filas)
-- Con la categoría en inglés y el vendedor. Se relaciona con v_pedidos por order_id.
-- ---------------------------------------------------------------------
CREATE OR REPLACE VIEW v_items AS
SELECT i.order_id,
       i.order_item_id,
       i.seller_id,
       left(i.seller_id, 8)                                      AS vendedor,
       i.product_id,
       t.product_category_name_english                           AS categoria,
       i.price                                                   AS precio,
       i.freight_value                                           AS flete
FROM items i
JOIN products p     ON p.product_id = i.product_id
JOIN translation t  ON t.product_category_name = p.product_category_name;


-- ---------------------------------------------------------------------
-- v_clientes: UNA FILA POR PERSONA REAL (customer_unique_id)
-- Misma población que la consulta 9b: pedidos entregados, con fecha de entrega
-- y sin fechas incoherentes. "Tarde" = el día de entrega es posterior al estimado.
-- ---------------------------------------------------------------------
CREATE OR REPLACE VIEW v_clientes AS
WITH entregados AS (
    SELECT c.customer_unique_id,
           o.order_id,
           o.order_purchase_timestamp,
           (o.order_delivered_customer_date::date > o.order_estimated_delivery_date::date) AS tardio
    FROM orders o
    JOIN customers c ON c.customer_id = o.customer_id
    WHERE o.order_status = 'delivered'
      AND o.order_delivered_customer_date IS NOT NULL
      AND NOT o.fechas_incoherentes
),
ordenados AS (
    SELECT customer_unique_id, tardio,
           row_number() OVER (PARTITION BY customer_unique_id ORDER BY order_purchase_timestamp) AS n_pedido,
           count(*)     OVER (PARTITION BY customer_unique_id)                                   AS total_pedidos
    FROM entregados
)
SELECT customer_unique_id,
       total_pedidos                                             AS pedidos,
       CASE WHEN total_pedidos > 1 THEN 1 ELSE 0 END             AS repite,
       CASE WHEN tardio THEN 'Primer pedido con retraso'
            ELSE 'Primer pedido a tiempo' END                    AS primer_pedido
FROM ordenados
WHERE n_pedido = 1;


-- ---------------------------------------------------------------------
-- v_vendedores: UNA FILA POR VENDEDOR
-- Ingresos de pedidos entregados, ranking, % acumulado (regla 80/20)
-- y calidad del servicio (porcentaje de pedidos tardíos y nota media).
-- ---------------------------------------------------------------------
CREATE OR REPLACE VIEW v_vendedores AS
WITH ingresos AS (
    SELECT i.seller_id,
           SUM(i.price)                AS ingresos,
           COUNT(DISTINCT i.order_id)  AS pedidos
    FROM items i
    JOIN orders o ON o.order_id = i.order_id
    WHERE o.order_status = 'delivered'
    GROUP BY i.seller_id
),
pedido_vendedor AS (
    SELECT DISTINCT i.seller_id, o.order_id
    FROM items i
    JOIN orders o ON o.order_id = i.order_id
    WHERE o.order_status = 'delivered'
      AND o.order_delivered_customer_date IS NOT NULL
      AND NOT o.fechas_incoherentes
),
servicio AS (
    SELECT pv.seller_id,
           COUNT(*) AS pedidos_servicio,
           AVG(CASE WHEN o.order_delivered_customer_date::date > o.order_estimated_delivery_date::date
                    THEN 1.0 ELSE 0.0 END)  AS frac_tarde,
           AVG(r.review_score)              AS nota_media
    FROM pedido_vendedor pv
    JOIN orders o ON o.order_id = pv.order_id
    LEFT JOIN reviews r ON r.order_id = pv.order_id
    GROUP BY pv.seller_id
)
SELECT left(ing.seller_id, 8)                                        AS vendedor,
       ing.ingresos,
       ing.pedidos,
       row_number() OVER (ORDER BY ing.ingresos DESC)                AS ranking,
       round(100.0 * SUM(ing.ingresos) OVER (ORDER BY ing.ingresos DESC
             ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW)
             / SUM(ing.ingresos) OVER (), 2)                         AS pct_acumulado,
       s.pedidos_servicio,
       round(100.0 * s.frac_tarde, 1)                                AS pct_tarde,
       round(s.nota_media, 2)                                        AS nota_media
FROM ingresos ing
LEFT JOIN servicio s ON s.seller_id = ing.seller_id;
