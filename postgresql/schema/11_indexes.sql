CREATE INDEX idx_products_tags
ON products USING GIN(tags);

CREATE INDEX idx_products_dimensions
ON products USING GIN(dimensions);

CREATE INDEX idx_orders_customer
ON orders(customer_id);

CREATE INDEX idx_orders_status
ON orders(order_status);

CREATE INDEX idx_payment_metadata
ON order_payments USING GIN(transaction_metadata);

CREATE INDEX idx_product_name_trgm
ON products USING GIN(product_name gin_trgm_ops);
