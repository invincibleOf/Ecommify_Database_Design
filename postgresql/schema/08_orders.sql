CREATE TABLE orders (
    order_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    customer_id UUID NOT NULL,
    order_status VARCHAR(30) NOT NULL,
    purchase_timestamp TIMESTAMP NOT NULL,
    approved_timestamp TIMESTAMP,
    delivered_timestamp TIMESTAMP,
    freight_value NUMERIC(12,2) CHECK (freight_value >= 0),
    total_amount NUMERIC(12,2) NOT NULL CHECK (total_amount > 0),

    CONSTRAINT fk_order_customer
        FOREIGN KEY (customer_id)
        REFERENCES customers(customer_id)
)
PARTITION BY RANGE (purchase_timestamp);
