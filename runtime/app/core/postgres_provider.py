from __future__ import annotations

from dataclasses import dataclass, field
from datetime import datetime, timezone
import json
import uuid
from typing import Any, Literal

try:
    import psycopg
    from psycopg import sql
    from psycopg.rows import dict_row
    from psycopg.types.json import Jsonb
except Exception:  # pragma: no cover - optional until POSTGRES_URL is configured.
    psycopg = None
    sql = None
    dict_row = None
    Jsonb = None


FilterOp = Literal["eq", "gte", "lte", "ilike", "in"]


@dataclass
class _Filter:
    column: str
    op: FilterOp
    value: Any


@dataclass
class _Result:
    data: list[dict]


@dataclass
class PostgresTableQuery:
    provider: "PostgresProvider"
    table_name: str
    action: Literal["select", "insert", "update", "upsert"] | None = None
    columns: str = "*"
    filters: list[_Filter] = field(default_factory=list)
    payload: dict | list[dict] | None = None
    order_column: str | None = None
    order_desc: bool = False
    limit_count: int | None = None
    conflict_column: str | None = None

    def select(self, columns: str = "*") -> "PostgresTableQuery":
        self.action = "select"
        self.columns = columns
        return self

    def insert(self, payload: dict | list[dict]) -> "PostgresTableQuery":
        self.action = "insert"
        self.payload = payload
        return self

    def update(self, payload: dict) -> "PostgresTableQuery":
        self.action = "update"
        self.payload = payload
        return self

    def upsert(self, payload: dict | list[dict], on_conflict: str) -> "PostgresTableQuery":
        self.action = "upsert"
        self.payload = payload
        self.conflict_column = on_conflict
        return self

    def eq(self, column: str, value: Any) -> "PostgresTableQuery":
        self.filters.append(_Filter(column, "eq", value))
        return self

    def gte(self, column: str, value: Any) -> "PostgresTableQuery":
        self.filters.append(_Filter(column, "gte", value))
        return self

    def lte(self, column: str, value: Any) -> "PostgresTableQuery":
        self.filters.append(_Filter(column, "lte", value))
        return self

    def ilike(self, column: str, value: Any) -> "PostgresTableQuery":
        self.filters.append(_Filter(column, "ilike", value))
        return self

    def in_(self, column: str, value: list[Any]) -> "PostgresTableQuery":
        self.filters.append(_Filter(column, "in", value))
        return self

    def order(self, column: str, desc: bool = False) -> "PostgresTableQuery":
        self.order_column = column
        self.order_desc = desc
        return self

    def limit(self, count: int) -> "PostgresTableQuery":
        self.limit_count = count
        return self

    def execute(self) -> _Result:
        if self.action == "select":
            return _Result(self.provider.select(self))
        if self.action == "insert":
            return _Result(self.provider.insert(self.table_name, self.payload))
        if self.action == "update":
            return _Result(self.provider.update(self))
        if self.action == "upsert":
            return _Result(self.provider.upsert(self.table_name, self.payload, self.conflict_column))
        raise RuntimeError("No query action selected")


class PostgresProvider:
    def __init__(self, connection_string: str) -> None:
        if psycopg is None:
            raise RuntimeError("psycopg is not installed. Run pip install -r runtime/requirements-runtime.txt")
        self.connection_string = connection_string

    def table(self, table_name: str) -> PostgresTableQuery:
        return PostgresTableQuery(provider=self, table_name=table_name)

    def select(self, query: PostgresTableQuery) -> list[dict]:
        where_sql, params = self._where(query.filters)
        columns_sql = sql.SQL("*") if query.columns == "*" else sql.SQL(", ").join(
            sql.Identifier(c.strip()) for c in query.columns.split(",") if c.strip() != "*"
        )
        parts = [
            sql.SQL("SELECT "),
            columns_sql,
            sql.SQL(" FROM "),
            sql.Identifier(query.table_name),
            where_sql,
        ]
        if query.order_column:
            parts.extend(
                [
                    sql.SQL(" ORDER BY "),
                    sql.Identifier(query.order_column),
                    sql.SQL(" DESC" if query.order_desc else " ASC"),
                ]
            )
        if query.limit_count is not None:
            parts.append(sql.SQL(" LIMIT %s"))
            params.append(query.limit_count)
        return self._fetch(sql.Composed(parts), params)

    def insert(self, table_name: str, payload: dict | list[dict] | None) -> list[dict]:
        rows = self._prepare_rows(table_name, payload)
        if not rows:
            return []
        return self._insert_rows(table_name, rows)

    def update(self, query: PostgresTableQuery) -> list[dict]:
        if not isinstance(query.payload, dict) or not query.payload:
            return []
        payload = self._prepare_row(query.table_name, query.payload, is_insert=False)
        assignments = sql.SQL(", ").join(
            sql.Composed([sql.Identifier(k), sql.SQL(" = %s")]) for k in payload
        )
        params = [self._adapt(v) for v in payload.values()]
        where_sql, where_params = self._where(query.filters)
        params.extend(where_params)
        statement = sql.SQL("UPDATE {table} SET {assignments}{where} RETURNING *").format(
            table=sql.Identifier(query.table_name),
            assignments=assignments,
            where=where_sql,
        )
        return self._fetch(statement, params)

    def upsert(self, table_name: str, payload: dict | list[dict] | None, conflict_column: str | None) -> list[dict]:
        if not conflict_column:
            raise RuntimeError("upsert requires on_conflict")
        rows = self._prepare_rows(table_name, payload)
        if not rows:
            return []
        columns = list(rows[0].keys())
        values = [[self._adapt(row.get(col)) for col in columns] for row in rows]
        placeholders = sql.SQL(", ").join(
            sql.SQL("(") + sql.SQL(", ").join(sql.Placeholder() for _ in columns) + sql.SQL(")")
            for _ in rows
        )
        updates = sql.SQL(", ").join(
            sql.Composed([sql.Identifier(col), sql.SQL(" = EXCLUDED."), sql.Identifier(col)])
            for col in columns
            if col != conflict_column
        )
        params = [value for row_values in values for value in row_values]
        statement = sql.SQL(
            "INSERT INTO {table} ({columns}) VALUES {values} "
            "ON CONFLICT ({conflict}) DO UPDATE SET {updates} RETURNING *"
        ).format(
            table=sql.Identifier(table_name),
            columns=sql.SQL(", ").join(sql.Identifier(c) for c in columns),
            values=placeholders,
            conflict=sql.Identifier(conflict_column),
            updates=updates or sql.SQL("{conflict} = EXCLUDED.{conflict}").format(
                conflict=sql.Identifier(conflict_column)
            ),
        )
        return self._fetch(statement, params)

    def _insert_rows(self, table_name: str, rows: list[dict]) -> list[dict]:
        columns = list(rows[0].keys())
        values = [[self._adapt(row.get(col)) for col in columns] for row in rows]
        placeholders = sql.SQL(", ").join(
            sql.SQL("(") + sql.SQL(", ").join(sql.Placeholder() for _ in columns) + sql.SQL(")")
            for _ in rows
        )
        params = [value for row_values in values for value in row_values]
        statement = sql.SQL("INSERT INTO {table} ({columns}) VALUES {values} RETURNING *").format(
            table=sql.Identifier(table_name),
            columns=sql.SQL(", ").join(sql.Identifier(c) for c in columns),
            values=placeholders,
        )
        return self._fetch(statement, params)

    def _where(self, filters: list[_Filter]) -> tuple[Any, list[Any]]:
        if not filters:
            return sql.SQL(""), []
        clauses = []
        params: list[Any] = []
        for item in filters:
            if item.op == "eq":
                clauses.append(sql.Composed([sql.Identifier(item.column), sql.SQL(" = %s")]))
                params.append(item.value)
            elif item.op == "gte":
                clauses.append(sql.Composed([sql.Identifier(item.column), sql.SQL(" >= %s")]))
                params.append(item.value)
            elif item.op == "lte":
                clauses.append(sql.Composed([sql.Identifier(item.column), sql.SQL(" <= %s")]))
                params.append(item.value)
            elif item.op == "ilike":
                clauses.append(sql.Composed([sql.Identifier(item.column), sql.SQL(" ILIKE %s")]))
                params.append(item.value)
            elif item.op == "in":
                values = list(item.value or [])
                if not values:
                    clauses.append(sql.SQL("FALSE"))
                else:
                    clauses.append(sql.Composed([sql.Identifier(item.column), sql.SQL(" = ANY(%s)")]))
                    params.append(values)
        return sql.SQL(" WHERE ") + sql.SQL(" AND ").join(clauses), params

    def _fetch(self, statement: Any, params: list[Any]) -> list[dict]:
        with psycopg.connect(self.connection_string, row_factory=dict_row) as conn:
            with conn.cursor() as cur:
                cur.execute(statement, params)
                rows = cur.fetchall() if cur.description else []
            conn.commit()
        return [dict(row) for row in rows]

    def _prepare_rows(self, table_name: str, payload: dict | list[dict] | None) -> list[dict]:
        raw_rows = payload if isinstance(payload, list) else ([payload] if isinstance(payload, dict) else [])
        return [self._prepare_row(table_name, row, is_insert=True) for row in raw_rows]

    def _prepare_row(self, table_name: str, row: dict, is_insert: bool) -> dict:
        prepared = dict(row)
        now = datetime.now(timezone.utc)
        id_tables = {
            "roles",
            "users",
            "sessions",
            "email_verifications",
            "password_reset_tokens",
            "allergies",
            "ingredients",
            "foods",
            "recipes",
            "recipe_ingredients",
            "meal_logs",
            "water_logs",
            "weight_logs",
            "nutrition_snapshots",
            "fridge_items",
            "meal_plan_headers",
            "meal_plan_items",
            "ai_conversations",
            "ai_messages",
            "recommendation_history",
            "recommendation_feedbacks",
            "notifications",
            "subscription_plans",
            "subscriptions",
            "payments",
            "sepay_transactions",
            "activity_logs",
            "budget_requests",
        }
        if is_insert and table_name in id_tables:
            prepared.setdefault("id", str(uuid.uuid4()))
        created_at_tables = {
            "roles",
            "users",
            "sessions",
            "email_verifications",
            "password_reset_tokens",
            "profiles",
            "health_profiles",
            "allergies",
            "user_allergies",
            "ingredients",
            "foods",
            "recipes",
            "favorite_foods",
            "nutrition_snapshots",
            "meal_plan_headers",
            "meal_plan_items",
            "ai_conversations",
            "ai_messages",
            "recommendation_history",
            "recommendation_feedbacks",
            "user_ai_profiles",
            "notifications",
            "subscription_plans",
            "subscriptions",
            "payments",
            "sepay_transactions",
            "activity_logs",
            "budget_requests",
        }
        if is_insert and table_name in created_at_tables:
            prepared.setdefault("created_at", now)
        if table_name in {
            "roles",
            "users",
            "profiles",
            "health_profiles",
            "ingredients",
            "foods",
            "recipes",
            "fridge_items",
            "meal_plan_headers",
            "user_ai_profiles",
        }:
            prepared.setdefault("updated_at", now)
        return prepared

    @staticmethod
    def _adapt(value: Any) -> Any:
        if Jsonb is not None and isinstance(value, (dict, list)):
            return Jsonb(value)
        if isinstance(value, (dict, list)):
            return json.dumps(value, ensure_ascii=False)
        return value
