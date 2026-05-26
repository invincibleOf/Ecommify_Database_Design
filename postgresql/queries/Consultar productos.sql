SELECT
    p.product_name,
    p.base_price,
    c.category_name_en AS category,
    s.seller_name
FROM products p
JOIN categories c
    ON p.category_id = c.category_id
JOIN sellers s
    ON p.seller_id = s.seller_id;
