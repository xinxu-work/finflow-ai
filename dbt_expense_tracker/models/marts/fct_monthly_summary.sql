-- Mart: Monthly summary by category
-- Key metrics for dashboard consumption

WITH transactions AS (
    SELECT * FROM {{ ref('stg_transactions') }}
),

categories AS (
    SELECT * FROM {{ ref('stg_categories') }}
),

monthly_agg AS (
    SELECT
        t.year_month,
        t.transaction_year,
        t.transaction_month,
        t.category_id,
        c.category_name,
        c.category_type,
        COUNT(*) AS transaction_count,
        SUM(t.amount) AS total_amount,
        AVG(t.amount) AS avg_amount,
        MIN(t.amount) AS min_amount,
        MAX(t.amount) AS max_amount
    FROM transactions t
    JOIN categories c ON t.category_id = c.category_id
    GROUP BY
        t.year_month,
        t.transaction_year,
        t.transaction_month,
        t.category_id,
        c.category_name,
        c.category_type
)

SELECT
    year_month,
    transaction_year,
    transaction_month,
    category_id,
    category_name,
    category_type,
    transaction_count,
    total_amount,
    avg_amount,
    min_amount,
    max_amount,
    -- Running total within the year
    SUM(total_amount) OVER (
        PARTITION BY transaction_year, category_type
        ORDER BY year_month
    ) AS ytd_amount
FROM monthly_agg
ORDER BY year_month DESC, category_type, total_amount DESC
