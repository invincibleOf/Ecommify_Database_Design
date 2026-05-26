CREATE TABLE order_payments (
    payment_id BIGSERIAL PRIMARY KEY,
    order_id UUID NOT NULL,
    payment_type VARCHAR(50) NOT NULL,
    payment_installments INTEGER CHECK (payment_installments >= 1),
    payment_value NUMERIC(12,2) NOT NULL CHECK (payment_value > 0),
    transaction_metadata JSONB,

    CONSTRAINT fk_payment_order
        FOREIGN KEY (order_id)
        REFERENCES orders(order_id)
);
