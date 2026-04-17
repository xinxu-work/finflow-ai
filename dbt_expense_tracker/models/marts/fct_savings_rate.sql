-- Mart: Monthly savings rate calculation
-- Shows income vs expenses vs savings per month

WITH transactions AS (
    SELECT * FROM {{ ref('stg_transactions') }}
),

categories AS (
    SELECT * FROM {{ ref('stg_categories') }}
),

monthly_totals AS (
    SELECT
        t.year_month,
        t.transaction_year,
        t.transaction_month,
        SUM(CASE WHEN c.category_type = 'income' THEN t.amount ELSE 0 END) AS total_income,
        SUM(CASE WHEN c.category_type = 'expense' THEN t.amount ELSE 0 END) AS total_expenses,
        SUM(CASE WHEN c.category_type = 'saving' THEN t.amount ELSE 0 END) AS total_savings
    FROM transactions t
    JOIN categories c ON t.category_id = c.category_id
    GROUP BY t.year_month, t.transaction_year, t.transaction_month
)

SELECT
    year_month,
    transaction_year,
    transaction_month,
    total_income,
    total_expenses,
    total_savings,
    total_income - total_expenses AS net_income,
    total_income - total_expenses - total_savings AS remaining_after_savings,
    CASE
        WHEN total_income > 0
        THEN ROUND(((total_income - total_expenses) / total_income) * 100, 1)
        ELSE 0
    END AS net_savings_rate_pct,
    CASE
        WHEN total_income > 0
        THEN ROUND((total_savings / total_income) * 100, 1)
        ELSE 0
    END AS explicit_savings_rate_pct,
    -- Rolling 3-month average
    AVG(total_expenses) OVER (ORDER BY year_month ROWS BETWEEN 2 PRECEDING AND CURRENT ROW) AS avg_expenses_3m,
    AVG(total_income) OVER (ORDER BY year_month ROWS BETWEEN 2 PRECEDING AND CURRENT ROW) AS avg_income_3m
FROM monthly_totals
ORDER BY year_month DESC
