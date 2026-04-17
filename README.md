# Expense Tracker - Full Data Pipeline

Personal expense & savings tracker with a modern data stack:
**Supabase (PostgreSQL) -> dbt (Transform) -> FastAPI (Backend) -> Power BI (Dashboard)**

---

## Architecture

```
Data Entry (API / Supabase UI)
        |
   Supabase (PostgreSQL)
        |
   dbt Core (transform)
        |
   Mart Tables (fct_monthly_summary, fct_savings_rate, fct_budget_vs_actual)
        |
   Power BI (dashboard)
```

---

## 1. Supabase Setup

### Create Project
1. Go to https://supabase.com and create a free account
2. Create a new project (pick a region close to Australia)
3. Note your **Project URL** and **anon key** from Settings > API

### Run Schema
1. Go to **SQL Editor** in the Supabase dashboard
2. Paste the contents of `supabase_schema.sql`
3. Click **Run** — this creates all tables, indexes, views, and seed data

### Get Connection Details (for dbt & Power BI)
- Go to **Settings > Database**
- Note: Host, Port (5432), Database (postgres), User (postgres), Password

---

## 2. FastAPI Setup

```bash
cd api

# Create virtual environment
python -m venv venv
source venv/bin/activate  # Windows: venv\Scripts\activate

# Install dependencies
pip install -r requirements.txt

# Configure environment
cp .env.example .env
# Edit .env with your Supabase URL and anon key

# Run the API
python main.py
```

API runs at http://localhost:8000

- Interactive docs: http://localhost:8000/docs
- Endpoints: `/transactions`, `/categories`, `/budgets`, `/savings-goals`, `/summary/monthly`

---

## 3. dbt Setup

### Install dbt
```bash
pip install dbt-postgres
```

### Configure Connection
Copy `dbt_expense_tracker/profiles.yml` to `~/.dbt/profiles.yml` and update with your Supabase credentials.

### Run dbt
```bash
cd dbt_expense_tracker

# Test connection
dbt debug

# Run all models
dbt run

# Run tests
dbt test

# Generate docs
dbt docs generate
dbt docs serve
```

### dbt Model Lineage
```
sources (raw tables)
    |
staging (stg_transactions, stg_categories)
    |-- AEST date conversion
    |-- Type casting & cleaning
    |
marts
    |-- fct_monthly_summary     (spending by category per month, YTD)
    |-- fct_savings_rate        (income vs expenses, savings %, 3-month rolling avg)
    |-- fct_budget_vs_actual    (budget utilisation, over/under flags)
```

---

## 4. Power BI Connection

### Connect to Supabase PostgreSQL

1. Open Power BI Desktop
2. **Get Data** > **PostgreSQL database**
3. Enter connection details:
   - Server: `db.YOUR_PROJECT_ID.supabase.co`
   - Database: `postgres`
   - Data Connectivity mode: **DirectQuery** (for live data) or **Import**
4. Enter credentials: User `postgres`, Password from Supabase dashboard
5. Select the mart tables:
   - `fct_monthly_summary`
   - `fct_savings_rate`
   - `fct_budget_vs_actual`

### Suggested Dashboard Pages

**Page 1: Monthly Overview**
- Card visuals: Total Income, Total Expenses, Net Savings, Savings Rate %
- Bar chart: Spending by category (current month)
- Line chart: Monthly spending trend (last 12 months)

**Page 2: Budget Tracker**
- Gauge visuals: Budget utilisation per category
- Table: Budget vs Actual with conditional formatting (red = over budget)
- Slicer: Month/Year selector

**Page 3: Savings Progress**
- KPI visual: Savings rate % vs target
- Line chart: 3-month rolling average income vs expenses
- Progress bars: Savings goals completion

### Power BI Tips
- Use **DirectQuery** if you want real-time data from Supabase
- Use **Import** mode if you want faster performance (schedule refresh)
- Date columns are already AEST-converted in the dbt models

---

## 5. Future Enhancements (Phase 2+)

- [ ] AI-powered transaction categorisation (Claude API)
- [ ] Auto-import from bank CSV/OFX files
- [ ] Multi-tenant support for customer deployments
- [ ] Airflow orchestration for scheduled dbt runs
- [ ] Industry templates (restaurant, retail)

---

## Project Structure

```
expense_tracker/
|-- supabase_schema.sql          # Database schema (run in Supabase SQL Editor)
|-- api/
|   |-- main.py                  # FastAPI backend
|   |-- requirements.txt         # Python dependencies
|   |-- .env.example             # Environment template
|-- dbt_expense_tracker/
|   |-- dbt_project.yml          # dbt config
|   |-- profiles.yml             # DB connection (copy to ~/.dbt/)
|   |-- models/
|       |-- staging/
|       |   |-- stg_transactions.sql
|       |   |-- stg_categories.sql
|       |   |-- schema.yml
|       |-- marts/
|           |-- fct_monthly_summary.sql
|           |-- fct_savings_rate.sql
|           |-- fct_budget_vs_actual.sql
|           |-- schema.yml
```
