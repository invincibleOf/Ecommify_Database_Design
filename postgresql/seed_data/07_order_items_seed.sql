INSERT INTO order_items (
    order_id,
    product_id,
    seller_id,
    quantity,
    unit_price,
    freight_value
)
SELECT
    o.order_id,
    p.product_id,
    p.seller_id,
    1,
    p.base_price,
    25.00
FROM orders o
JOIN products p
ON p.product_name = 'Gaming Laptop RTX'
LIMIT 1;

INSERT INTO order_items (
    order_id,
    product_id,
    seller_id,
    quantity,
    unit_price,
    freight_value
)
SELECT
    o.order_id,
    p.product_id,
    p.seller_id,
    1,
    p.base_price,
    15.00
FROM orders o
JOIN products p
ON p.product_name = 'Modern Sofa'
OFFSET 1 LIMIT 1;
