import { TableSyncConfig } from "./sync.types";

export const TABLE_CONFIGS: Record<string, TableSyncConfig> = {
  profiles: {
    table: "profiles",
    mode: "incremental",
    cursorColumn: "updated_at",
    onConflict: "user_id",
  },
  health_profiles: {
    table: "health_profiles",
    mode: "incremental",
    cursorColumn: "updated_at",
    onConflict: "user_id",
  },
  subscription_plans: {
    table: "subscription_plans",
    mode: "incremental",
    cursorColumn: "created_at",
    onConflict: "id",
  },
  subscriptions: {
    table: "subscriptions",
    mode: "incremental",
    cursorColumn: "created_at",
    onConflict: "id",
  },
  ingredients: {
    table: "ingredients",
    mode: "incremental",
    cursorColumn: "updated_at",
    onConflict: "id",
  },
  foods: {
    table: "foods",
    mode: "incremental",
    cursorColumn: "updated_at",
    onConflict: "id",
  },
  recipes: {
    table: "recipes",
    mode: "incremental",
    cursorColumn: "updated_at",
    onConflict: "id",
  },
  recipe_ingredients: {
    table: "recipe_ingredients",
    mode: "full",
    onConflict: "id",
  },
  meal_logs: {
    table: "meal_logs",
    mode: "incremental",
    cursorColumn: "logged_at",
    onConflict: "id",
  },
  fridge_items: {
    table: "fridge_items",
    mode: "incremental",
    cursorColumn: "updated_at",
    onConflict: "id",
  },
  meal_plan_headers: {
    table: "meal_plan_headers",
    mode: "incremental",
    cursorColumn: "created_at",
    onConflict: "id",
  },
  meal_plan_items: {
    table: "meal_plan_items",
    mode: "incremental",
    cursorColumn: "created_at",
    onConflict: "id",
  },
  notifications: {
    table: "notifications",
    mode: "incremental",
    cursorColumn: "created_at",
    onConflict: "id",
  },
};

export const DEFAULT_TABLE_ORDER: string[] = [
  "profiles",
  "health_profiles",
  "subscription_plans",
  "subscriptions",
  "ingredients",
  "foods",
  "recipes",
  "recipe_ingredients",
  "meal_logs",
  "fridge_items",
  "meal_plan_headers",
  "meal_plan_items",
  "notifications",
];
