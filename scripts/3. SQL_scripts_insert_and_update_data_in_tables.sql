MERGE INTO dwh.products_project_sprint_2 d
USING (SELECT DISTINCT product_name, product_description, product_type, product_price from external_source.all_data_tmp) t
ON d.product_name = t.product_name AND d.product_description = t.product_description AND d.product_price = t.product_price
WHEN MATCHED THEN
  UPDATE SET product_type= t.product_type, load_dttm = current_timestamp
WHEN NOT MATCHED THEN
  INSERT (product_name, product_description, product_type, product_price, load_dttm)
  VALUES (t.product_name, t.product_description, t.product_type, t.product_price, current_timestamp);

MERGE INTO dwh.craftsmans_project_sprint_2 d
USING (SELECT DISTINCT craftsman_name, craftsman_surname, craftsman_address_building, craftsman_address_street, craftsman_birthday, craftsman_email FROM external_source.all_data_tmp) t
ON d.craftsman_name = t.craftsman_name AND d.craftsman_surname = t.craftsman_surname and d.craftsman_email = t.craftsman_email
WHEN MATCHED THEN
  UPDATE SET craftsman_address_building = t.craftsman_address_building, craftsman_address_street = t.craftsman_address_street, craftsman_birthday = t.craftsman_birthday, load_dttm = current_timestamp
WHEN NOT MATCHED THEN
  INSERT (craftsman_name, craftsman_surname, craftsman_address_building, craftsman_address_street, craftsman_birthday, craftsman_email, load_dttm)
  VALUES (t.craftsman_name, t.craftsman_surname, t.craftsman_address_building, t.craftsman_address_street, t.craftsman_birthday, t.craftsman_email, current_timestamp);


MERGE INTO dwh.customers_project_sprint_2 d
USING (SELECT DISTINCT customer_name, customer_surname, customer_address_building, customer_address_street, customer_birthday, customer_email from external_source.all_data_tmp) t
ON d.customer_name = t.customer_name AND d.customer_surname = t.customer_surname and d.customer_email = t.customer_email
WHEN MATCHED THEN
  UPDATE SET customer_address_building = t.customer_address_building,  customer_address_street = t.customer_address_street, customer_birthday= t.customer_birthday, load_dttm = current_timestamp
WHEN NOT MATCHED THEN
  INSERT (customer_name, customer_surname, customer_address_building, customer_address_street, customer_birthday, customer_email, load_dttm)
  VALUES (t.customer_name, t.customer_surname, t.customer_address_building, t.customer_address_street, t.customer_birthday, t.customer_email, current_timestamp);