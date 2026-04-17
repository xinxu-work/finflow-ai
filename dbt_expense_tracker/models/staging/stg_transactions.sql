-- Staging model: clean and type-cast raw transactions
-- Converts UTC timestamps to AEST (Australia/Sydney)

WITH source AS (
    SELECT
        id,
        transaction_date,
        category_id,
        amount,
        description,
        payment_method,
        is_recurring,
        created_at,
        updated_at
    FROM {{ source('expense_tracker', 'transactions') }}
)

SELECT
    id,
    transaction_date,
    -- Convert to AEST for reporting
    (transaction_date AT TIME ZONE 'UTC' AT TIME ZONE 'Australia/Sydney')::DATE AS transaction_date_aest,
    category_id,
    amount,
    COALESCE(description, 'No description') AS description,
    payment_method,
    is_recurring,
    EXTRACT(YEAR FROM transaction_date) AS transaction_year,
    EXTRACT(MONTH FROM transaction_date) AS transaction_month,
    TO_CHAR(transaction_date, 'YYYY-MM') AS year_month,
    EXTRACT(DOW FROM transaction_date) AS day_of_week,
    created_at,
    updated_at
FROM source
