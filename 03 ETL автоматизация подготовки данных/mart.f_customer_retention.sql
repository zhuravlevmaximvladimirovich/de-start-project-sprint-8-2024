create table if not exists mart.f_customer_retention(
    id serial, 
    new_customers_count INTEGER,-- кол-во новых клиентов (тех, которые сделали только один заказ за рассматриваемый промежуток времени).
    returning_customers_count INTEGER,-- кол-во вернувшихся клиентов (тех,которые сделали только несколько заказов за рассматриваемый промежуток времени).
    refunded_customer_count INTEGER,-- кол-во клиентов, оформивших возврат за рассматриваемый промежуток времени.
    period_name varchar(25),-- weekly.
    period_id INTEGER,-- идентификатор периода (номер недели или номер месяца).
    item_id INTEGER,-- идентификатор категории товара.
    new_customers_revenue numeric(10,2),-- доход с новых клиентов.
    returning_customers_revenue numeric(10,2),-- доход с вернувшихся клиентов.
    customers_refunded INTEGER,-- количество возвратов клиентов.
    PRIMARY KEY (id)
);

truncate mart.f_customer_retention;

insert into mart.f_customer_retention (
    new_customers_count, returning_customers_count, refunded_customer_count, period_name,
    period_id, item_id, new_customers_revenue, returning_customers_revenue, customers_refunded)
WITH f_sales_calendar AS (
select t2.year_actual, t2.week_of_year, t2.date_id, t1.uniq_id, t1.city_name, t1.city_id, t1.customer_id, t1.item_id, t1.quantity, t1.payment_amount, t1.status
from staging.user_order_log as t1
left join mart.d_calendar as t2
on t1.date_time::Date = t2.date_actual
), new_customers as (
select t4.year_actual, t4.week_of_year, count(t4.new_counts) as new_customers_count, sum(t4.new_revenue) as new_customers_revenue
from (
    SELECT t3.year_actual, t3.week_of_year, t3.customer_id, COUNT(*) AS new_counts, SUM(case when t3.status = 'refunded' then t3.payment_amount*-1 else t3.payment_amount end) as new_revenue
    from f_sales_calendar AS t3 
    GROUP by t3.year_actual, t3.week_of_year, customer_id
    having COUNT(t3.customer_id) = 1
) as t4
group by t4.year_actual, t4.week_of_year
), returning_customers as (
select t4.year_actual, t4.week_of_year, count(t4.returning_counts) as returning_customers_count, sum(t4.returning_revenue) as returning_customers_revenue
from (
    SELECT t3.year_actual, t3.week_of_year, t3.customer_id, COUNT(*) AS returning_counts, SUM(case when t3.status = 'refunded' then t3.payment_amount*-1 else t3.payment_amount end) as returning_revenue
    from f_sales_calendar AS t3 
    GROUP by t3.year_actual, t3.week_of_year, customer_id
    having COUNT(t3.customer_id) > 1
) as t4
group by t4.year_actual, t4.week_of_year
), refunded_customers as (
SELECT t5.year_actual, t5.week_of_year, COUNT(t5.customer_id) AS refunded_customer_count, COUNT(t5.item_id) as customers_refunded
from f_sales_calendar AS t5
where t5.status = 'refunded'
GROUP by t5.year_actual, t5.week_of_year
), popular_item_id as (
select t8.year_actual, t8.week_of_year, t8.item_id
from (
    select t7.year_actual, t7.week_of_year, t7.item_id, row_number() over(partition by t7.year_actual, t7.week_of_year order by t7.item_id_counts desc) as popular_item_id
    from (
        SELECT t3.year_actual, t3.week_of_year, t3.item_id, COUNT(t3.item_id) AS item_id_counts
        from f_sales_calendar AS t3 
        GROUP by t3.year_actual, t3.week_of_year, t3.item_id
    ) as t7
) as t8
where t8.popular_item_id = 1
)
select
    coalesce(t11.new_customers_count, 0) as new_customers_count
    ,coalesce(t22.returning_customers_count, 0) as returning_customers_count
    ,coalesce(t33.refunded_customer_count, 0) as refunded_customer_count
    ,concat(t11.year_actual::text,'Y', t11.week_of_year::text, 'W') as period_name, t11.week_of_year as period_id
    ,coalesce(t44.item_id, 0) as item_id
    ,coalesce(t11.new_customers_revenue, 0) as new_customers_revenue
    ,coalesce(t22.returning_customers_revenue, 0) as returning_customers_revenue
    ,coalesce(t33.customers_refunded, 0) as customers_refunded 
from new_customers as t11
full join returning_customers as t22
on t11.year_actual = t22.year_actual and t11.week_of_year = t22.week_of_year
full join refunded_customers as t33
on t11.year_actual = t33.year_actual and t11.week_of_year  = t33.week_of_year
full join popular_item_id as t44
on t11.year_actual = t44.year_actual and t11.week_of_year  = t44.week_of_year
;