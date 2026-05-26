CREATE TABLE geolocations (
    geolocation_id BIGSERIAL PRIMARY KEY,
    zip_code VARCHAR(20) NOT NULL,
    city VARCHAR(100) NOT NULL,
    state VARCHAR(100) NOT NULL,
    latitude NUMERIC(10,6),
    longitude NUMERIC(10,6)
);
