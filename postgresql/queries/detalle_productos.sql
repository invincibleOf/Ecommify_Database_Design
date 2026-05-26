SELECT
    o.order_id,
    p.product_name,
    oi.quantity,
    oi.unit_price
FROM order_items oi
JOIN orders o
    ON oi.order_id = o.order_id
JOIN products p
    ON oi.product_id = p.product_id;
