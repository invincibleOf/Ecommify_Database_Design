INSERT INTO order_payments (
    order_id,
    payment_type,
    payment_installments,
    payment_value,
    transaction_metadata
)
SELECT
    o.order_id,
    'credit_card',
    12,
    o.total_amount,
    '{
        "gateway": "Stripe",
        "authorization_code": "AUTH-1001",
        "provider_response": "approved"
    }'::jsonb
FROM orders o
LIMIT 1;

INSERT INTO order_payments (
    order_id,
    payment_type,
    payment_installments,
    payment_value,
    transaction_metadata
)
SELECT
    o.order_id,
    'debit_card',
    1,
    o.total_amount,
    '{
        "gateway": "PayPal",
        "authorization_code": "AUTH-2001",
        "provider_response": "approved"
    }'::jsonb
FROM orders o
OFFSET 1 LIMIT 1;
