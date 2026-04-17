"""
Expense Tracker API
FastAPI backend connecting to Supabase PostgreSQL
"""

from datetime import date, datetime
from typing import Optional
from uuid import UUID

from fastapi import FastAPI, HTTPException, Query
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field
from supabase import create_client, Client
from dotenv import load_dotenv
import os

load_dotenv()

# --- Supabase client ---
SUPABASE_URL = os.getenv("SUPABASE_URL")
SUPABASE_KEY = os.getenv("SUPABASE_KEY")

if not SUPABASE_URL or not SUPABASE_KEY:
    raise RuntimeError("Set SUPABASE_URL and SUPABASE_KEY in .env")

supabase: Client = create_client(SUPABASE_URL, SUPABASE_KEY)

# --- App ---
app = FastAPI(
    title="Expense Tracker API",
    description="Personal expense & savings tracker",
    version="1.0.0",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


# --- Pydantic models ---
class TransactionCreate(BaseModel):
    transaction_date: date
    category_id: UUID
    amount: float = Field(gt=0)
    description: Optional[str] = None
    payment_method: str = "card"
    is_recurring: bool = False


class TransactionUpdate(BaseModel):
    transaction_date: Optional[date] = None
    category_id: Optional[UUID] = None
    amount: Optional[float] = Field(default=None, gt=0)
    description: Optional[str] = None
    payment_method: Optional[str] = None
    is_recurring: Optional[bool] = None


class BudgetCreate(BaseModel):
    category_id: UUID
    year_month: date  # first day of month, e.g., 2026-04-01
    budget_amount: float = Field(ge=0)


class SavingsGoalCreate(BaseModel):
    name: str
    target_amount: float = Field(gt=0)
    current_amount: float = 0
    target_date: Optional[date] = None


# --- Category endpoints ---
@app.get("/categories")
def list_categories(type: Optional[str] = None):
    query = supabase.table("categories").select("*")
    if type:
        query = query.eq("type", type)
    result = query.order("name").execute()
    return result.data


# --- Transaction endpoints ---
@app.post("/transactions")
def create_transaction(txn: TransactionCreate):
    data = txn.model_dump(mode="json")
    data["category_id"] = str(data["category_id"])
    result = supabase.table("transactions").insert(data).execute()
    return result.data[0]


@app.get("/transactions")
def list_transactions(
    year: Optional[int] = None,
    month: Optional[int] = None,
    category_id: Optional[str] = None,
    limit: int = Query(default=100, le=1000),
    offset: int = 0,
):
    query = supabase.table("transactions").select(
        "*, categories(name, type)"
    )

    if year and month:
        start = date(year, month, 1)
        if month == 12:
            end = date(year + 1, 1, 1)
        else:
            end = date(year, month + 1, 1)
        query = query.gte("transaction_date", start.isoformat())
        query = query.lt("transaction_date", end.isoformat())

    if category_id:
        query = query.eq("category_id", category_id)

    result = (
        query.order("transaction_date", desc=True)
        .range(offset, offset + limit - 1)
        .execute()
    )
    return result.data


@app.get("/transactions/{txn_id}")
def get_transaction(txn_id: UUID):
    result = (
        supabase.table("transactions")
        .select("*, categories(name, type)")
        .eq("id", str(txn_id))
        .execute()
    )
    if not result.data:
        raise HTTPException(status_code=404, detail="Transaction not found")
    return result.data[0]


@app.put("/transactions/{txn_id}")
def update_transaction(txn_id: UUID, txn: TransactionUpdate):
    data = txn.model_dump(mode="json", exclude_none=True)
    if "category_id" in data:
        data["category_id"] = str(data["category_id"])
    result = (
        supabase.table("transactions")
        .update(data)
        .eq("id", str(txn_id))
        .execute()
    )
    if not result.data:
        raise HTTPException(status_code=404, detail="Transaction not found")
    return result.data[0]


@app.delete("/transactions/{txn_id}")
def delete_transaction(txn_id: UUID):
    result = (
        supabase.table("transactions")
        .delete()
        .eq("id", str(txn_id))
        .execute()
    )
    if not result.data:
        raise HTTPException(status_code=404, detail="Transaction not found")
    return {"status": "deleted"}


# --- Summary endpoints ---
@app.get("/summary/monthly")
def monthly_summary(year: int, month: int):
    result = (
        supabase.table("v_monthly_summary")
        .select("*")
        .eq("month", date(year, month, 1).isoformat())
        .execute()
    )
    return result.data


@app.get("/summary/savings-rate")
def savings_rate(year: Optional[int] = None):
    query = supabase.table("v_monthly_summary").select("*")
    # Return raw data for the savings rate view
    result = (
        supabase.rpc(
            "get_savings_rate",
            {"p_year": year} if year else {},
        ).execute()
        if year
        else supabase.table("v_monthly_summary").select("*").execute()
    )
    return result.data


# --- Budget endpoints ---
@app.post("/budgets")
def create_budget(budget: BudgetCreate):
    data = budget.model_dump(mode="json")
    data["category_id"] = str(data["category_id"])
    result = supabase.table("monthly_budgets").upsert(data).execute()
    return result.data[0]


@app.get("/budgets/{year}/{month}")
def get_budgets(year: int, month: int):
    result = (
        supabase.table("v_budget_vs_actual")
        .select("*")
        .eq("month", date(year, month, 1).isoformat())
        .execute()
    )
    return result.data


# --- Savings goals endpoints ---
@app.post("/savings-goals")
def create_savings_goal(goal: SavingsGoalCreate):
    data = goal.model_dump(mode="json")
    result = supabase.table("savings_goals").insert(data).execute()
    return result.data[0]


@app.get("/savings-goals")
def list_savings_goals(status: str = "active"):
    result = (
        supabase.table("savings_goals")
        .select("*")
        .eq("status", status)
        .execute()
    )
    return result.data


@app.put("/savings-goals/{goal_id}")
def update_savings_goal(goal_id: UUID, current_amount: float):
    result = (
        supabase.table("savings_goals")
        .update({"current_amount": current_amount})
        .eq("id", str(goal_id))
        .execute()
    )
    if not result.data:
        raise HTTPException(status_code=404, detail="Goal not found")
    return result.data[0]


# --- Health check ---
@app.get("/health")
def health():
    return {"status": "ok", "timestamp": datetime.utcnow().isoformat()}


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
