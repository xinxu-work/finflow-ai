-- Staging model: categories dimension

WITH source AS (
    SELECT
        id,
        name,
        type,
        icon,
        created_at
    FROM {{ source('expense_tracker', 'categories') }}
)

SELECT
    id AS category_id,
    name AS category_name,
    type AS category_type,
    icon,
    created_at
FROM source
