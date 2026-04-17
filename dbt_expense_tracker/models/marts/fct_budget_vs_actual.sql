-- Mart: Budget vs Actual comparison
-- Shows how actual spending compares to budgeted amounts

WITH budgets AS (
    SELECT
        id,
        category_id,
        year_month,
        budget_amount
    FROM {{ source('expense_tracker', 'monthly_budgets') }}
),

transactions AS (
    SELECT * FROM {{ ref('stg_transactions') }}
),

categories AS (
    SELECT * FROM {{ ref('stg_categories') }}
),

actual_spend AS (
    SELECT
        category_id,
        year_month,
        SUM(amount) AS actual_amount,
        COUNT(*) AS transaction_count
    FROM transactions
    GROUP BY category_id, year_month
)

SELECT
    b.year_month,
    c.category_name,
    c.category_type,
    b.budget_amount,
    COALESCE(a.actual_amount, 0) AS actual_amount,
    b.budget_amount - COALESCE(a.actual_amount, 0) AS variance,
    CASE
        WHEN b.budget_amount > 0
        THEN ROUND((COALESCE(a.actual_amount, 0) / b.budget_amount) * 100, 1)
        ELSE 0
    END AS utilisation_pct,
    COALESCE(a.transaction_count, 0) AS transaction_count,
    CASE
        WHEN COALESCE(a.actual_amount, 0) > b.budget_amount THEN 'over_budget'
        WHEN COALESCE(a.actual_amount, 0) > b.budget_amount * 0.9 THEN 'near_budget'
        ELSE 'within_budget'
    END AS budget_status
FROM budgets b
JOIN categories c ON b.category_id = c.category_id
LEFT JOIN actual_spend a
    ON b.category_id = a.category_id
    AND TO_CHAR(b.year_month, 'YYYY-MM') = a.year_month
ORDER BY b.year_month DESC, c.category_name
