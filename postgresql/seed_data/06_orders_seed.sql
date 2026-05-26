INSERT INTO orders (
    order_id,
    customer_id,
    order_status,
    purchase_timestamp,
    approved_timestamp,
    delivered_timestamp,
    freight_value,
    total_amount
)
SELECT
    gen_random_uuid(),
    c.customer_id,
    'DELIVERED',
    NOW(),
    NOW(),
    NOW(),
    25.00,
    4525.00
FROM customers c
LIMIT 1;

INSERT INTO orders (
    order_id,
    customer_id,
    order_status,
    purchase_timestamp,
    freight_value,
    total_amount
)
SELECT
    gen_random_uuid(),
    c.customer_id,
    'PROCESSING',
    NOW(),
    15.00,
    1815.00
FROM customers c
OFFSET 1 LIMIT 1;
