DROP TABLE IF EXISTS dwh.orders_project_sprint_2;
CREATE TABLE dwh.orders_project_sprint_2 (
order_id bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
product_id bigint not null,
craftsman_id bigint not null,
customer_id bigint not null,
order_created_date date not null,
order_completion_date date default null,
order_status TEXT not null,
load_dttm timestamp not null,
CONSTRAINT order_pk PRIMARY KEY (order_id),
CONSTRAINT order_craftsman_fk FOREIGN KEY (craftsman_id) REFERENCES dwh.craftsmans_project_sprint_2(craftsman_id) ON DELETE restrict,
CONSTRAINT order_customer_fk FOREIGN KEY (customer_id) REFERENCES dwh.customers_project_sprint_2(customer_id) ON DELETE restrict,
CONSTRAINT order_product_fk FOREIGN KEY (product_id) REFERENCES dwh.products_project_sprint_2(product_id) ON DELETE restrict
);


DROP TABLE IF EXISTS dwh.products_project_sprint_2;
CREATE TABLE dwh.products_project_sprint_2 (
    product_id bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
    product_name text not null,
    product_description text not null,
    product_type text not null,
    product_price int8 not null,
    load_dttm timestamp not null,
    CONSTRAINT product_ps2_pk PRIMARY KEY (product_id)
);


DROP TABLE IF EXISTS dwh.craftsmans_project_sprint_2;
CREATE TABLE dwh.craftsmans_project_sprint_2 (
    craftsman_id bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
    craftsman_name TEXT NOT NULL,
    craftsman_surname TEXT NOT NULL,
    craftsman_address_building INT NOT NULL,
    craftsman_address_street TEXT NOT NULL,
    craftsman_birthday DATE NOT NULL,
    craftsman_email TEXT NOT null,
    load_dttm timestamp not null,
    CONSTRAINT craftsman_ps2_pk PRIMARY KEY (craftsman_id)
);

DROP TABLE IF EXISTS dwh.customers_project_sprint_2;
CREATE TABLE dwh.customers_project_sprint_2 (
    customer_id bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
    customer_name TEXT NOT NULL,
    customer_surname TEXT NOT NULL,
    customer_address_building INT NOT NULL,
    customer_address_street TEXT NOT NULL,
    customer_birthday DATE NOT NULL,
    customer_email TEXT NOT null,
    load_dttm timestamp not null,
    CONSTRAINT customer_ps2_pk PRIMARY KEY (customer_id)
);