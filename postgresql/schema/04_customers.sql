CREATE TABLE customers (
    customer_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    first_name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100) NOT NULL,
    email VARCHAR(150) UNIQUE NOT NULL,
    phone VARCHAR(20),
    created_at TIMESTAMP DEFAULT NOW(),
    geolocation_id BIGINT,

    CONSTRAINT fk_customer_geolocation
        FOREIGN KEY (geolocation_id)
        REFERENCES geolocations(geolocation_id)
);
