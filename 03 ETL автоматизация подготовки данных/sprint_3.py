import os
import time
import psycopg2
import requests
import json
import pandas as pd

from datetime import datetime, timedelta
from airflow import DAG
from airflow.operators.python_operator import PythonOperator, BranchPythonOperator
from airflow.providers.postgres.operators.postgres import PostgresOperator
from airflow.providers.postgres.hooks.postgres import PostgresHook
from airflow.hooks.base import BaseHook
from airflow.hooks.http_hook import HttpHook

http_conn_id = HttpHook.get_connection('http_conn_id')
api_key = http_conn_id.extra_dejson.get('api_key')
base_url = http_conn_id.host

postgres_conn_id = 'postgresql_de'

nickname = 'maksimzhv'
cohort = '39'
api_key = '5f55e6c0-e9e5-4a9c-b313-63c01fc31460'

headers = {
    'X-Nickname': nickname,
    'X-Cohort': cohort,
    'X-Project': 'True',
    'X-API-KEY': api_key,
    'Content-Type': 'application/x-www-form-urlencoded'
}

file_names = ['customer_research.csv', 'user_order_log.csv', 'user_activity_log.csv']
file_names_inc = ['customer_research_inc.csv', 'user_order_log_inc.csv', 'user_activity_log_inc.csv']
pg_tables = ['customer_research','user_order_log','user_activity_log']
storage = '/lessons/dags/storage_for_files'

def generate_report(ti):
    print('Making request generate_report')

    response = requests.post(f'{base_url}/generate_report', headers=headers)
    response.raise_for_status()
    task_id = json.loads(response.content)['task_id']
    ti.xcom_push(key='task_id', value=task_id)
    print(f'Response is {response.content}')


def get_report(ti):
    print('Making request get_report')
    task_id = ti.xcom_pull(key='task_id')
    print("GET_REPORT TASK_ID: " + task_id)

    report_id = None

    for i in range(20):
        response = requests.get(f'{base_url}/get_report?task_id={task_id}', headers=headers)
        response.raise_for_status()
        print(f'Response is {response.content}')
        status = json.loads(response.content)['status']
        if status == 'SUCCESS':
            report_id = json.loads(response.content)['data']['report_id']
            break
        else:
            time.sleep(10)

    if not report_id:
        raise TimeoutError()

    ti.xcom_push(key='report_id', value=report_id)
    print(f'Report_id={report_id}')
    

    for file_name in file_names:
        save_directory = f'{storage}'
        if not os.path.exists(save_directory):
            os.mkdir(save_directory)
        pd.read_csv(f'https://storage.yandexcloud.net/s3-sprint3/cohort_{cohort}/{nickname}/project/{report_id}/{file_name}').to_csv(f'{storage}/{file_name}')

def create_tables_in_pg_and_add_column_status(ti):
    pg_hook = BaseHook.get_connection(postgres_conn_id)
    pg_connect = psycopg2.connect(f"host={pg_hook.host} port={pg_hook.port} dbname={pg_hook.schema} user={pg_hook.login} password={pg_hook.password}")
    pg_cursor = pg_connect.cursor()
    
    #customer_research
    pg_cursor.execute("""
        CREATE TABLE IF NOT EXISTS staging.customer_research(
            id serial,
            date_id        TIMESTAMP,
            category_id    INTEGER,
            geo_id         INTEGER,
            sales_qty      INTEGER,
            sales_amt      NUMERIC(14,2),
            PRIMARY KEY (id)
        );
    """)
    pg_connect.commit()
    
    #user_order_log
    pg_cursor.execute("""
        CREATE TABLE IF NOT EXISTS staging.user_order_log(
            id serial,
            uniq_id         VARCHAR(100),
            date_time       TIMESTAMP,
            city_id         INTEGER,
            city_name       VARCHAR(100),
            customer_id     BIGINT,
            first_name      VARCHAR(100),
            last_name       VARCHAR(100),
            item_id         INTEGER,
            item_name       VARCHAR(100),
            quantity        BIGINT,
            payment_amount  NUMERIC(14,2),
            status          VARCHAR(100),
            PRIMARY KEY (id)
        );
    """)
    pg_cursor.execute("""
        ALTER TABLE staging.user_order_log
        ADD COLUMN IF NOT EXISTS status VARCHAR(100);
        """)
    pg_connect.commit()

    #user_activity_log
    pg_cursor.execute("""
        CREATE TABLE IF NOT EXISTS staging.user_activity_log(
            id serial,
            uniq_id         VARCHAR(100),
            date_time       TIMESTAMP ,
            action_id       BIGINT ,
            customer_id     BIGINT ,
            quantity        BIGINT ,
            PRIMARY KEY (id)
        );
    """)
    pg_connect.commit()
    
    pg_cursor.close()
    pg_connect.close()

def truncate_all_tables_in_staging(ti):
    pg_hook = BaseHook.get_connection(postgres_conn_id)
    pg_connect = psycopg2.connect(f"host={pg_hook.host} port={pg_hook.port} dbname={pg_hook.schema} user={pg_hook.login} password={pg_hook.password}")
    pg_cursor = pg_connect.cursor()
    pg_cursor.execute("""
    TRUNCATE staging.customer_research;
    """)
    pg_cursor.execute("""
    TRUNCATE staging.user_activity_log;
    """)
    pg_cursor.execute("""
    TRUNCATE staging.user_order_log;
    """)
    pg_connect.commit()
    
    pg_cursor.close()
    pg_connect.close()

def get_increment(date, ti):
    print('Making request get_increment')
    report_id = ti.xcom_pull(key='report_id')

    print(f"<<<DATE:{date}>>>")

    response = requests.get(
        f'{base_url}/get_increment?report_id={report_id}&date={str(date)}T00:00:00',
        headers=headers)
    response.raise_for_status()
    print(f'Response is {response.content}')

    increment_id = json.loads(response.content)['data']['increment_id']
    if not increment_id:
        raise ValueError(f'Increment is empty. Most probably due to error in API call.')
    
    ti.xcom_push(key='increment_id', value=increment_id)
    print(f'increment_id={increment_id}')

    for file_name in file_names_inc:
        save_directory = f'{storage}/{increment_id}'
        if not os.path.exists(save_directory):
            os.mkdir(save_directory)
        pd.read_csv(f'https://storage.yandexcloud.net/s3-sprint3/cohort_{cohort}/{nickname}/project/{increment_id}/{file_name}').to_csv(f'{save_directory}/{file_name}')



def upload_data_to_staging(filename, date, pg_table, pg_schema, ti):
    
    report_id = ti.xcom_pull(key='report_id')

    for count_operation in range(0,3):
        file_name = file_names[count_operation]
        file_name_inc = file_names_inc[count_operation]
        pg_table = pg_tables[count_operation]

        s3_filename = f'https://storage.yandexcloud.net/s3-sprint3/cohort_{cohort}/{nickname}/project/{report_id}/{file_name}'
        print(s3_filename)
        local_filename = date.replace('-', '') + '_' + file_name
        print(local_filename)
        response = requests.get(s3_filename)
        response.raise_for_status()
        open(f"{local_filename}", "wb").write(response.content)
        print(response.content)
        df = pd.read_csv(local_filename)
        
        if 'id' in df.columns:        
            df=df.drop('id', axis=1)
        if 'uniq_id' in df.columns:
            df=df.drop_duplicates(subset=['uniq_id'])
        
        if file_name in 'user_order_log' and 'status' not in df.columns:
            df['status'] = 'shipped'

        increment_id = ti.xcom_pull(key='increment_id')
        s3_filename_inc = f'https://storage.yandexcloud.net/s3-sprint3/cohort_{cohort}/{nickname}/project/{increment_id}/{file_name_inc}'
        print(s3_filename_inc)
        local_filename_inc = date.replace('-', '') + '_' + file_name_inc
        print(local_filename_inc)
        response = requests.get(s3_filename_inc)
        response.raise_for_status()
        open(f"{local_filename_inc}", "wb").write(response.content)
        print(response.content)

        df_inc = pd.read_csv(local_filename_inc)
        
        if 'id' in df_inc.columns:        
            df_inc=df_inc.drop('id', axis=1)

        df_inc = df_inc.append(df)
        if 'uniq_id' in df_inc.columns:
            df_inc=df_inc.drop_duplicates(subset=['uniq_id'])
        
        if file_name in 'user_order_log' and 'status' not in df_inc.columns:
            df_inc['status'] = 'shipped'
        
        postgres_hook = PostgresHook(postgres_conn_id)
        engine = postgres_hook.get_sqlalchemy_engine()
        row_count = df_inc.to_sql(pg_table, engine, schema=pg_schema, if_exists='append', index=False)
        print(f'{row_count} rows was inserted')

args = {
    "owner": "student",
    'email': ['student@example.com'],
    'email_on_failure': False,
    'email_on_retry': False,
    'retries': 0
}

business_dt = '{{ ds }}'

with DAG(
        'sales_mart',
        default_args=args,
        description='Provide default dag for sprint3',
        catchup=True,
        start_date=datetime.today() - timedelta(days=7),
        end_date=datetime.today() - timedelta(days=1),
) as dag:
    generate_report = PythonOperator(
        task_id='generate_report',
        python_callable=generate_report)

    get_report = PythonOperator(
        task_id='get_report',
        python_callable=get_report)

    create_tables_in_pg_and_add_column_status = PythonOperator(
        task_id='create_tables_in_pg_and_add_column_status',
        python_callable=create_tables_in_pg_and_add_column_status)
    
    truncate_all_tables_in_staging = PythonOperator(
        task_id='truncate_all_tables_in_staging',
        python_callable=truncate_all_tables_in_staging)

    get_increment = PythonOperator(
        task_id='get_increment',
        python_callable=get_increment,
        op_kwargs={'date': business_dt})

    upload_user_order_inc = PythonOperator(
        task_id='upload_user_order_inc',
        python_callable=upload_data_to_staging,
        op_kwargs={'date': business_dt,
                   'filename': 'user_order_log_inc.csv',
                   'pg_table': 'user_order_log',
                   'pg_schema': 'staging'})

    update_d_item_table = PostgresOperator(
        task_id='update_d_item',
        postgres_conn_id=postgres_conn_id,
        sql="sql/mart.d_item.sql")

    update_d_customer_table = PostgresOperator(
        task_id='update_d_customer',
        postgres_conn_id=postgres_conn_id,
        sql="sql/mart.d_customer.sql")

    update_d_city_table = PostgresOperator(
        task_id='update_d_city',
        postgres_conn_id=postgres_conn_id,
        sql="sql/mart.d_city.sql")

    update_f_sales = PostgresOperator(
        task_id='update_f_sales',
        postgres_conn_id=postgres_conn_id,
        sql="sql/mart.f_sales.sql",
        parameters={"date": {business_dt}}
    )

    update_f_customer_retention = PostgresOperator(
        task_id='update_f_customer_retention',
        postgres_conn_id=postgres_conn_id,
        sql="sql/mart.f_customer_retention.sql",
        parameters={"date": {business_dt}}
    )

    (
            generate_report
            >> get_report
            >> create_tables_in_pg_and_add_column_status
            >> truncate_all_tables_in_staging
            >> get_increment
            >> upload_user_order_inc
            >> [update_d_item_table, update_d_city_table, update_d_customer_table]
            >> update_f_sales
            >> update_f_customer_retention
    )
