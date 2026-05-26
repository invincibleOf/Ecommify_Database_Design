SELECT
    product_name,
    dimensions ->> 'weight_kg' AS weight
FROM products;
