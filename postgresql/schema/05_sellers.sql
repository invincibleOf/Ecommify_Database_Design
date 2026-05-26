CREATE TABLE sellers (
    seller_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    seller_name VARCHAR(150) NOT NULL,
    seller_email VARCHAR(150) UNIQUE,
    geolocation_id BIGINT,
    created_at TIMESTAMP DEFAULT NOW(),

    CONSTRAINT fk_seller_geolocation
        FOREIGN KEY (geolocation_id)
        REFERENCES geolocations(geolocation_id)
);
