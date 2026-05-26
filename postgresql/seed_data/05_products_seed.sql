INSERT INTO products (
    product_id,
    seller_id,
    category_id,
    product_name,
    base_price,
    stock_quantity,
    sku,
    dimensions,
    tags
)
SELECT
    gen_random_uuid(),
    s.seller_id,
    1,
    'Gaming Laptop RTX',
    4500.00,
    15,
    'SKU-LAPTOP-001',
    '{
        "height_cm": 3,
        "width_cm": 36,
        "depth_cm": 25,
        "weight_kg": 2.5
    }'::jsonb,
    ARRAY['gaming','laptop','premium']
FROM sellers s
LIMIT 1;

INSERT INTO products (
    product_id,
    seller_id,
    category_id,
    product_name,
    base_price,
    stock_quantity,
    sku,
    dimensions,
    tags
)
SELECT
    gen_random_uuid(),
    s.seller_id,
    3,
    'Modern Sofa',
    1800.00,
    8,
    'SKU-SOFA-001',
    '{
        "height_cm": 90,
        "width_cm": 220,
        "depth_cm": 85,
        "weight_kg": 35
    }'::jsonb,
    ARRAY['furniture','living-room']
FROM sellers s
OFFSET 1 LIMIT 1;
