ALTER TABLE products
ADD CONSTRAINT chk_product_price
CHECK (base_price > 0);

ALTER TABLE products
ADD CONSTRAINT chk_product_stock
CHECK (stock_quantity >= 0);

ALTER TABLE order_items
ADD CONSTRAINT chk_item_quantity
CHECK (quantity > 0);

ALTER TABLE order_payments
ADD CONSTRAINT chk_payment_installments
CHECK (payment_installments >= 1);

ALTER TABLE orders
ADD CONSTRAINT chk_total_amount
CHECK (total_amount > 0);
