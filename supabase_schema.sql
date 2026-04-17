-- ============================================
-- Expense Tracker - Supabase Schema
-- Database: PostgreSQL (Supabase)
-- Timezone: Australia/Sydney (AEST/AEDT)
-- ============================================

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ============================================
-- 1. CATEGORIES (dimension table)
-- ============================================
CREATE TABLE categories (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(50) NOT NULL UNIQUE,
    type VARCHAR(10) NOT NULL CHECK (type IN ('expense', 'income', 'saving')),
    icon VARCHAR(10),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Seed default categories
INSERT INTO categories (name, type, icon) VALUES
    -- Expense categories
    ('Rent', 'expense', NULL),
    ('Groceries', 'expense', NULL),
    ('Dining Out', 'expense', NULL),
    ('Transport', 'expense', NULL),
    ('Utilities', 'expense', NULL),
    ('Phone & Internet', 'expense', NULL),
    ('Insurance', 'expense', NULL),
    ('Health', 'expense', NULL),
    ('Entertainment', 'expense', NULL),
    ('Shopping', 'expense', NULL),
    ('Education', 'expense', NULL),
    ('Subscriptions', 'expense', NULL),
    ('Personal Care', 'expense', NULL),
    ('Other Expense', 'expense', NULL),
    -- Income categories
    ('Salary', 'income', NULL),
    ('Freelance', 'income', NULL),
    ('Investment', 'income', NULL),
    ('Other Income', 'income', NULL),
    -- Saving categories
    ('Emergency Fund', 'saving', NULL),
    ('Investment Savings', 'saving', NULL),
    ('Travel Fund', 'saving', NULL),
    ('General Savings', 'saving', NULL);

-- ============================================
-- 2. TRANSACTIONS (fact table)
-- ============================================
CREATE TABLE transactions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    transaction_date DATE NOT NULL,
    category_id UUID NOT NULL REFERENCES categories(id),
    amount DECIMAL(10, 2) NOT NULL CHECK (amount > 0),
    description VARCHAR(255),
    payment_method VARCHAR(20) DEFAULT 'card' CHECK (payment_method IN ('card', 'cash', 'transfer', 'direct_debit')),
    is_recurring BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Index for common queries
CREATE INDEX idx_transactions_date ON transactions(transaction_date);
CREATE INDEX idx_transactions_category ON transactions(category_id);
CREATE INDEX idx_transactions_year_month ON transactions(
    EXTRACT(YEAR FROM transaction_date),
    EXTRACT(MONTH FROM transaction_date)
);

-- ============================================
-- 3. MONTHLY_BUDGETS (planning table)
-- ============================================
CREATE TABLE monthly_budgets (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    category_id UUID NOT NULL REFERENCES categories(id),
    year_month DATE NOT NULL, -- first day of month, e.g., '2026-04-01'
    budget_amount DECIMAL(10, 2) NOT NULL CHECK (budget_amount >= 0),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(category_id, year_month)
);

-- ============================================
-- 4. SAVINGS_GOALS (target tracking)
-- ============================================
CREATE TABLE savings_goals (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(100) NOT NULL,
    target_amount DECIMAL(10, 2) NOT NULL CHECK (target_amount > 0),
    current_amount DECIMAL(10, 2) DEFAULT 0 CHECK (current_amount >= 0),
    target_date DATE,
    status VARCHAR(20) DEFAULT 'active' CHECK (status IN ('active', 'completed', 'paused')),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================
-- 5. AUTO-UPDATE TRIGGER for updated_at
-- ============================================
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_transactions_updated
    BEFORE UPDATE ON transactions
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER trigger_savings_goals_updated
    BEFORE UPDATE ON savings_goals
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- ============================================
-- 6. ROW LEVEL SECURITY (Supabase auth)
-- ============================================
-- Enable RLS on all tables
ALTER TABLE categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE monthly_budgets ENABLE ROW LEVEL SECURITY;
ALTER TABLE savings_goals ENABLE ROW LEVEL SECURITY;

-- For now, allow all authenticated users (single-user app)
-- Update these policies when adding multi-tenant support
CREATE POLICY "Allow all for authenticated" ON categories
    FOR ALL USING (auth.role() = 'authenticated');

CREATE POLICY "Allow all for authenticated" ON transactions
    FOR ALL USING (auth.role() = 'authenticated');

CREATE POLICY "Allow all for authenticated" ON monthly_budgets
    FOR ALL USING (auth.role() = 'authenticated');

CREATE POLICY "Allow all for authenticated" ON savings_goals
    FOR ALL USING (auth.role() = 'authenticated');

-- ============================================
-- 7. VIEWS for common queries
-- ============================================

-- Monthly summary view
CREATE OR REPLACE VIEW v_monthly_summary AS
SELECT
    DATE_TRUNC('month', t.transaction_date)::DATE AS month,
    c.type,
    c.name AS category_name,
    COUNT(*) AS transaction_count,
    SUM(t.amount) AS total_amount,
    AVG(t.amount) AS avg_amount
FROM transactions t
JOIN categories c ON t.category_id = c.id
GROUP BY DATE_TRUNC('month', t.transaction_date), c.type, c.name
ORDER BY month DESC, c.type, total_amount DESC;

-- Budget vs actual view
CREATE OR REPLACE VIEW v_budget_vs_actual AS
SELECT
    b.year_month AS month,
    c.name AS category_name,
    b.budget_amount,
    COALESCE(SUM(t.amount), 0) AS actual_amount,
    b.budget_amount - COALESCE(SUM(t.amount), 0) AS remaining,
    CASE
        WHEN b.budget_amount > 0
        THEN ROUND((COALESCE(SUM(t.amount), 0) / b.budget_amount) * 100, 1)
        ELSE 0
    END AS utilisation_pct
FROM monthly_budgets b
JOIN categories c ON b.category_id = c.id
LEFT JOIN transactions t
    ON t.category_id = b.category_id
    AND DATE_TRUNC('month', t.transaction_date)::DATE = b.year_month
GROUP BY b.year_month, c.name, b.budget_amount
ORDER BY b.year_month DESC, c.name;
