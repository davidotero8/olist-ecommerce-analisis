
/*1. ¿cuántos pedidos hay en cada estado de
 pedido (order_status), de más a menos?*/

select order_status, count(*) as pedidos
from orders
group by order_status
order by pedidos desc;


/*2. Para cada región de Brasil (SP, RJ, MG...) donde 
  viven los clientes, ¿cuántos pedidos han llegado
  a su destino? Muéstralo de más a menos.*/

--paso 1: pegamos las dos tablas

select o.order_id, o.order_status, c.customer_state
from orders o
join customers c on c.customer_id = o.customer_id
limit 10;

--paso 2: quedarnos con los entregados

select o.order_id, o.order_status, c.customer_state
from orders o
join customers c on c.customer_id = o.customer_id
where o.order_status = 'delivered'
limit 10;

--paso 3: agrupar y contar

select c.customer_state, count(*) as pedidos
from orders o
join customers c on c.customer_id = o.customer_id
where o.order_status = 'delivered'
group by c.customer_state
order by pedidos desc;
 

/*3. Para cada región de Brasil, ¿cuántos pedidos
 entregados y cuánto dinero (en precio de los artículos)
 han generado? De más a menos dinero.*/

select c.customer_state, count(distinct o.order_id) as pedidos,
		round(sum(i.price),2) as ingresos
from orders o
join customers c on c.customer_id = o.customer_id
join items i on i.order_id = o.order_id
where o.order_status = 'delivered'
group by c.customer_state
order by ingresos desc;



/*4. ¿Qué porcentaje del total de ingresos 
 aporta cada región?*/

with ingresos_estado as (
	select c.customer_state,
		sum(i.price) as ingresos
	from orders o
	join customers c on c.customer_id = o.customer_id
	join items i on i.order_id = o.order_id
	where o.order_status = 'delivered'
	group by c.customer_state
)
select customer_state,
       round(ingresos, 2) as ingresos,
       round(100.0 * ingresos / sum(ingresos) over (), 1) as pct
from ingresos_estado
order by ingresos desc



/*5. Mes a mes, de enero de 2017 a agosto de 2018: 
 ¿cuántos pedidos entregados y cuántos ingresos hubo?*/

--Paso 1: solo el mes de cada pedido

select o.order_id,
	date_trunc('month', o.order_purchase_timestamp)::date as mes
from orders o;

--Paso 2: contar pedidos por mes

select date_trunc('month', o.order_purchase_timestamp)::date as mes,
	count(*) as pedidos
from orders o
group by 1     --aqui 1 quiere decir la 1ª columna del select=mes
order by mes;

--Paso 3: añadir dinero, filtros y la union con items

select date_trunc('month', o.order_purchase_timestamp)::date as mes,
       count(distinct o.order_id)  as pedidos,
       round(sum(i.price), 2)      as ingresos
from orders o
join items i on i.order_id = o.order_id
where o.order_status = 'delivered'
  and o.order_purchase_timestamp >= '2017-01-01'
  and o.order_purchase_timestamp <  '2018-09-01'
group by 1
order by 1;



/*5b. Día a día, del 15 al 30 de noviembre de 2017: 
 * ¿cuántos pedidos entregados y cuántos 
ingresos hubo? (Para ver el pico de Black Friday)*/

select o.order_purchase_timestamp::date as dia,
       count(distinct o.order_id)       as pedidos,
       round(sum(i.price), 2)           as ingresos
from orders o
join items i on i.order_id = o.order_id
where o.order_status = 'delivered'
  and o.order_purchase_timestamp >= '2017-11-15'
  and o.order_purchase_timestamp <  '2017-12-01'
group by 1
order by 1;



/*6. ¿Qué 10 categorías de producto generan más
 ingresos, y cuántos artículos se venden en cada 
 una? (Solo pedidos entregados, con el nombre de 
 la categoría en inglés.)*/

select t.product_category_name_english as categoria,
       count(*)               as articulos,
       round(sum(i.price), 2) as ingresos
from orders o
join items i        on i.order_id = o.order_id
join products p     on p.product_id = i.product_id
join translation t  on t.product_category_name = p.product_category_name
where o.order_status = 'delivered'
group by 1
order by ingresos desc
limit 10;



/*7. Para cada región, de los pedidos que han
 llegado, ¿qué porcentaje llegó después de
 la fecha estimada? Solo regiones con al menos
 500 pedidos, de más a menos tardías.*/

-- Criterio de "tarde": el día de entrega es posterior al día estimado (se compara solo el día,
-- porque la fecha estimada no tiene hora; entregar el día prometido es llegar en plazo).
select c.customer_state,
       count(*) as pedidos,
       count(*) filter (where o.order_delivered_customer_date::date > o.order_estimated_delivery_date::date) as tardios,
       round(100.0 * count(*) filter (where o.order_delivered_customer_date::date > o.order_estimated_delivery_date::date)
             / count(*), 1) as pct_tarde
from orders o
join customers c on c.customer_id = o.customer_id
where o.order_status = 'delivered'
  and o.order_delivered_customer_date is not null
  and not o.fechas_incoherentes
group by c.customer_state
having count(*) >= 500
order by pct_tarde desc;



/*8. Según los días de retraso en la entrega, ¿cuánto baja la nota media de la reseña?*/

with pedidos as (
    select o.order_id,
           o.order_delivered_customer_date::date - o.order_estimated_delivery_date::date as dias_retraso,
           r.review_score
    from orders o
    left join reviews r on r.order_id = o.order_id
    where o.order_status = 'delivered'
      and o.order_delivered_customer_date is not null
      and not o.fechas_incoherentes
)
select case when dias_retraso <= 0 then '1. En plazo'
            when dias_retraso <= 3 then '2. 1-3 días tarde'
            when dias_retraso <= 7 then '3. 4-7 días tarde'
            else '4. Más de 7 días tarde' end as grupo,
       count(*)                    as pedidos,
       count(review_score)         as con_resena,
       round(avg(review_score), 2) as nota_media
from pedidos
group by 1
order by 1;


/*9a. Pregunta 5. ¿Cuántos pedidos entregados ha hecho cada persona real (customer_unique_id)?
¿Qué porcentaje de personas repite?*/

with por_persona as (
    select c.customer_unique_id,
           count(distinct o.order_id) as pedidos
    from orders o
    join customers c on c.customer_id = o.customer_id
    where o.order_status = 'delivered'
    group by 1
)
select pedidos,
       count(*) as personas,
       round(100.0 * count(*) / sum(count(*)) over (), 2) as pct
from por_persona
group by 1
order by 1;


/*9b. ¿Vuelven menos los clientes cuyo primer pedido llegó tarde?
Se compara el porcentaje de recompra según si el PRIMER pedido llegó a tiempo o con retraso.*/

with entregados as (
    select c.customer_unique_id,
           o.order_id,
           o.order_purchase_timestamp,
           o.order_delivered_customer_date::date > o.order_estimated_delivery_date::date as tardio
    from orders o
    join customers c on c.customer_id = o.customer_id
    where o.order_status = 'delivered'
      and o.order_delivered_customer_date is not null
      and not o.fechas_incoherentes
),
ordenados as (
    select customer_unique_id, tardio,
           row_number() over (partition by customer_unique_id order by order_purchase_timestamp) as n_pedido,
           count(*)     over (partition by customer_unique_id) as total_pedidos
    from entregados
)
select case when tardio then 'Primer pedido con retraso' else 'Primer pedido a tiempo' end as primer_pedido,
       count(*) as personas,
       count(*) filter (where total_pedidos > 1) as repiten,
       round(100.0 * count(*) filter (where total_pedidos > 1) / count(*), 2) as pct_repiten
from ordenados
where n_pedido = 1
group by 1
order by 1;


/*10a. Pregunta 6. ¿Los 10 vendedores que más ingresan, y qué parte del total acumulan?*/

with ingresos_vendedor as (
    select i.seller_id,
           sum(i.price) as ingresos
    from items i
    join orders o on o.order_id = i.order_id
    where o.order_status = 'delivered'
    group by 1
)
select row_number() over (order by ingresos desc)                   as ranking,
       left(seller_id, 8)                                           as vendedor,
       round(ingresos, 2)                                           as ingresos,
       round(100.0 * ingresos / sum(ingresos) over (), 2)           as pct,
       round(100.0 * sum(ingresos) over (order by ingresos desc
             rows between unbounded preceding and current row)
             / sum(ingresos) over (), 2)                            as pct_acumulado
from ingresos_vendedor
order by ingresos desc
limit 10;


/*10b. Regla 80/20: ¿cuántos vendedores hacen falta para llegar al 80% de los ingresos,
y qué porcentaje del total de vendedores son?*/

with ingresos_vendedor as (
    select i.seller_id,
           sum(i.price) as ingresos
    from items i
    join orders o on o.order_id = i.order_id
    where o.order_status = 'delivered'
    group by 1
),
acumulado as (
    select seller_id,
           row_number() over (order by ingresos desc) as ranking,
           sum(ingresos) over (order by ingresos desc
               rows between unbounded preceding and current row) / sum(ingresos) over () as pct_acumulado
    from ingresos_vendedor
)
select min(ranking) filter (where pct_acumulado >= 0.8)                       as vendedores_para_80pct,
       count(*)                                                               as vendedores_totales,
       round(100.0 * min(ranking) filter (where pct_acumulado >= 0.8) / count(*), 1) as pct_de_vendedores
from acumulado;


/*10c. ¿Qué vendedores dan peor servicio? Vendedores con al menos 100 pedidos entregados:
% de pedidos tardíos y nota media, de peor a mejor nota.*/

with pedido_vendedor as (
    select distinct i.seller_id, o.order_id
    from items i
    join orders o on o.order_id = i.order_id
    where o.order_status = 'delivered'
      and o.order_delivered_customer_date is not null
      and not o.fechas_incoherentes
)
select left(pv.seller_id, 8) as vendedor,
       count(*) as pedidos,
       round(100.0 * count(*) filter (where o.order_delivered_customer_date::date > o.order_estimated_delivery_date::date)
             / count(*), 1) as pct_tarde,
       round(avg(r.review_score), 2) as nota_media
from pedido_vendedor pv
join orders o on o.order_id = pv.order_id
left join reviews r on r.order_id = pv.order_id
group by pv.seller_id
having count(*) >= 100
order by nota_media asc
limit 10;
 

