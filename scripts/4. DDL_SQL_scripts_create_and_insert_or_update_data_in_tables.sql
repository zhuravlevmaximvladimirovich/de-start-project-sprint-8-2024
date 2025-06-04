DROP TABLE IF EXISTS external_source.all_data_fact_tmp;
CREATE TABLE external_source.all_data_fact_tmp AS 
SELECT  dp.product_id,
        dc.craftsman_id,
        dcust.customer_id,
        src.order_created_date,
        src.order_completion_date,
        src.order_status,
        current_timestamp 
FROM external_source.all_data_tmp src
JOIN dwh.craftsmans_project_sprint_2 dc ON dc.craftsman_name = src.craftsman_name and dc.craftsman_surname = src.craftsman_surname and dc.craftsman_email = src.craftsman_email 
JOIN dwh.customers_project_sprint_2 dcust ON dcust.customer_name = src.customer_name and dcust.customer_surname = src.customer_surname and dcust.customer_email = src.customer_email 
JOIN dwh.products_project_sprint_2 dp ON dp.product_name = src.product_name and dp.product_description = src.product_description and dp.product_price = src.product_price;


MERGE INTO dwh.orders_project_sprint_2 f
USING external_source.all_data_fact_tmp t
ON f.product_id = t.product_id AND f.craftsman_id = t.craftsman_id AND f.customer_id = t.customer_id AND f.order_created_date = t.order_created_date 
WHEN MATCHED THEN
  UPDATE SET order_completion_date = t.order_completion_date, order_status = t.order_status, load_dttm = current_timestamp
WHEN NOT MATCHED THEN
  INSERT (product_id, craftsman_id, customer_id, order_created_date, order_completion_date, order_status, load_dttm)
  VALUES (t.product_id, t.craftsman_id, t.customer_id, t.order_created_date, t.order_completion_date, t.order_status, current_timestamp);