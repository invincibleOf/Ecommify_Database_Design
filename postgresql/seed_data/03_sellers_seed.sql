INSERT INTO sellers (
    seller_id,
    seller_name,
    seller_email,
    geolocation_id
)
VALUES
(
    gen_random_uuid(),
    'carlos Store',
    'carlos@hotmail.com',
    1
),
(
    gen_random_uuid(),
    'oscar Center',
    'socarr@egmail.com',
    2
),
(
    gen_random_uuid(),
    'Fashion Shop',
    'fashion@eyahoo.com',
    3
);
