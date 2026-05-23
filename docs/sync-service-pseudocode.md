# Draft Pseudo-code: BE -> AI Sync Service

## 1) Core table mapping

| BE table | AI/Supabase table | Notes |
|---|---|---|
| `users` | `users` (shadow) + `profiles.id` | Keep `profiles.id` equal to BE `users.id` when syncing |
| `profiles` | `profiles` | Upsert full profile and macro targets |
| `subscription_plans` | `subscription_plans` | Upsert plan catalog |
| `subscriptions` | `subscriptions` | Map `plan_id`, `plan`, `status` |
| `ingredients` | `ingredients` | Prefer `name_vi`, keep legacy `name` |
| `foods` | `foods` | Prefer `name_vi`, keep legacy `name` |
| `recipes` | `recipes` | Map `title`, `instructions`, macros |
| `recipe_ingredients` | `recipe_ingredients` | Map `quantity` and `amount` |
| `meal_logs` | `meal_logs` | Map `food_label` and `food_name` |
| `fridge_items` | `fridge_items` | User fridge state |
| `meal_plans` | `meal_plans` | Planned meals |
| `ai_conversations` | `ai_conversations` | Optional sync |
| `ai_messages` | `ai_messages` | Optional sync |

---

## 2) Option A: Incremental polling (fast MVP)

### Cursor column mapping (important)

Not all BE tables have `updated_at`. Use per-table cursor column:

| Table | Cursor column |
|---|---|
| `profiles`, `subscription_plans`, `subscriptions`, `ingredients`, `foods`, `recipes`, `fridge_items` | `updated_at` |
| `recipe_ingredients`, `meal_logs`, `meal_plans`, `ai_conversations`, `ai_messages`, `notifications` | `created_at` |

### NestJS pseudo-code

```ts
@Module({
  providers: [SyncScheduler, BeReaderService, AiWriterService, SyncStateRepo],
})
export class SyncModule {}

@Injectable()
export class SyncScheduler {
  constructor(
    private readonly beReader: BeReaderService,
    private readonly aiWriter: AiWriterService,
    private readonly state: SyncStateRepo,
  ) {}

  @Cron('*/2 * * * *') // every 2 minutes
  async run() {
    const tables = [
      'profiles',
      'subscription_plans',
      'subscriptions',
      'ingredients',
      'foods',
      'recipes',
      'recipe_ingredients',
      'meal_logs',
      'fridge_items',
      'meal_plans',
    ];

    for (const table of tables) {
      const cursor = await this.state.getOffset(table); // last_synced_at
      const cursorCol = getCursorColumn(table);
      const rows = await this.beReader.fetchChangedRows(table, cursorCol, cursor);
      if (!rows.length) continue;

      try {
        await this.aiWriter.upsertBatch(table, rows);
        await this.state.saveOffset(table, maxTimestamp(rows, cursorCol));
      } catch (err) {
        await this.state.pushDeadLetter({
          source_table: table,
          payload: rows,
          error: String(err),
        });
      }
    }
  }
}

@Injectable()
export class BeReaderService {
  async fetchChangedRows(table: string, cursorCol: string, after?: string) {
    // SELECT * FROM <table>
    // WHERE <cursorCol> > :after
    // ORDER BY <cursorCol> ASC
    // LIMIT 2000;
  }
}

@Injectable()
export class AiWriterService {
  async upsertBatch(table: string, rows: any[]) {
    const payload = rows.map((r) => normalizeByTable(table, r));
    // Supabase upsert in chunks:
    // supabase.from(table).upsert(payload, { onConflict: '<pk_or_unique>' })
  }
}
```

### Normalize helper

```ts
function normalizeByTable(table: string, row: any) {
  switch (table) {
    case 'foods':
      return {
        id: row.id,
        slug: row.slug,
        name_vi: row.name_vi,
        name_en: row.name_en,
        name: row.name_vi ?? row.name_en, // legacy compat
        calories_kcal: row.calories_kcal,
        protein_g: row.protein_g,
        carbs_g: row.carbs_g,
        fat_g: row.fat_g,
        updated_at: row.updated_at,
      };
    case 'recipes':
      return {
        id: row.id,
        food_id: row.food_id,
        slug: row.slug,
        title: row.title,
        name: row.title, // legacy compat
        instructions: row.instructions,
        updated_at: row.updated_at,
      };
    case 'meal_logs':
      return {
        id: row.id,
        user_id: row.user_id,
        logged_at: row.logged_at,
        food_label: row.food_label,
        food_name: row.food_label, // legacy compat
        calories_kcal: row.calories_kcal,
        protein_g: row.protein_g,
        carbs_g: row.carbs_g,
        fat_g: row.fat_g,
        is_manual: row.is_manual,
        created_at: row.created_at,
      };
    default:
      return row;
  }
}
```

---

## 3) Option B: Event-driven (recommended production path)

- BE publishes events: `profile.updated`, `meal_log.created`, `recipe.updated`, etc.
- Sync service consumes queue (Kafka, RabbitMQ, SQS).
- Event payload should include `event_id`, `table`, `op`, `occurred_at`, `payload`.
- Use idempotency key as `event_id`.

```ts
async function handleEvent(evt: SyncEvent) {
  if (await alreadyProcessed(evt.event_id)) return;

  try {
    const row = normalizeByTable(evt.table, evt.payload);

    if (evt.op === 'delete') {
      await aiDb.softDelete(evt.table, row.id);
    } else {
      await aiDb.upsert(evt.table, row);
    }

    await markProcessed(evt.event_id);
  } catch (err) {
    await deadLetter(evt, err);
    throw err; // queue retry
  }
}
```

---

## 4) Python worker sketch

```python
def cursor_column(table: str) -> str:
    updated_tables = {
        "profiles", "subscription_plans", "subscriptions",
        "ingredients", "foods", "recipes", "fridge_items"
    }
    return "updated_at" if table in updated_tables else "created_at"


def sync_table(be_conn, sb_client, table, last_synced_at):
    col = cursor_column(table)
    rows = fetch_changed_rows(be_conn, table, col, last_synced_at)
    if not rows:
        return last_synced_at

    max_ts = last_synced_at
    for chunk in chunked(rows, 300):
        payload = [normalize_by_table(table, r) for r in chunk]
        sb_client.table(table).upsert(payload).execute()
        max_ts = max(max_ts, max(r[col] for r in chunk))
    return max_ts


def run_sync_loop():
    tables = [
        "profiles", "subscription_plans", "subscriptions",
        "ingredients", "foods", "recipes", "recipe_ingredients",
        "meal_logs", "fridge_items", "meal_plans",
    ]
    for t in tables:
        cursor = get_offset(t)
        try:
            new_cursor = sync_table(be_conn, supabase, t, cursor)
            save_offset(t, new_cursor)
        except Exception as e:
            save_dead_letter(t, str(e))
```

---

## 5) Quick implementation checklist

1. Add index on the real cursor column (`updated_at` or `created_at`) for each source table.
2. Start with polling, then move to event-driven.
3. Use batched upsert (200-500 rows/chunk) to reduce timeout risk.
4. Keep dead-letter logging for retry/audit.
5. Do not sync sensitive fields like `password_hash` into AI runtime reads unless required.
