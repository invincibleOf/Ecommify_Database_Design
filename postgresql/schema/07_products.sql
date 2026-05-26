CREATE TABLE products (
    product_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    seller_id UUID NOT NULL,
    category_id INTEGER NOT NULL,
    product_name VARCHAR(200) NOT NULL,
    base_price NUMERIC(12,2) NOT NULL CHECK (base_price > 0),
    stock_quantity INTEGER NOT NULL CHECK (stock_quantity >= 0),
    sku VARCHAR(100) UNIQUE,
    dimensions JSONB,
    tags TEXT[],
    created_at TIMESTAMP DEFAULT NOW(),

    CONSTRAINT fk_product_seller
        FOREIGN KEY (seller_id)
        REFERENCES sellers(seller_id),

    CONSTRAINT fk_product_category
        FOREIGN KEY (category_id)
        REFERENCES categories(category_id)
);
