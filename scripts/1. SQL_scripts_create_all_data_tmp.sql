drop table if exists external_source.all_data_tmp;
create table external_source.all_data_tmp as
select
	t1.id
	,t1.craftsman_id
    ,t1.craftsman_name as craftsman_name_all
	,(regexp_split_to_array(t1.craftsman_name, '\s+'))[1] as craftsman_name
	,(regexp_split_to_array(t1.craftsman_name, '\s+'))[2] as craftsman_surname
	,t1.craftsman_address
	,(regexp_match(t1.craftsman_address, '\d+'))[1]::int  as craftsman_address_building
	,(regexp_match(t1.craftsman_address, '[a-zA-Z]+[a-zA-Z\s]+'))[1] as craftsman_address_street
	,t1.craftsman_birthday
	,t1.craftsman_email
	,t1.product_id
    ,t1.product_name
	,t1.product_description
	,t1.product_type
	,t1.product_price
	,t1.order_id
    ,t1.order_created_date
	,t1.order_completion_date
	,t1.order_status
	,t2.customer_id
    ,t2.customer_name as customer_name_all
	,(regexp_split_to_array(t2.customer_name, '\s+'))[1] as customer_name
	,(regexp_split_to_array(t2.customer_name, '\s+'))[2] as customer_surname
	,t2.customer_address
	,(regexp_match(t2.customer_address, '\d+'))[1]::int  as customer_address_building
	,(regexp_match(t2.customer_address, '[a-zA-Z]+[a-zA-Z\s]+'))[1] as customer_address_street
	,t2.customer_birthday
	,t2.customer_email
from external_source.craft_products_orders t1
inner join external_source.customers t2
on t1.customer_id = t2.customer_id
;
