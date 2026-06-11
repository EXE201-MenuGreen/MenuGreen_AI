import { TableSyncConfig } from "./sync.types";

export const TABLE_CONFIGS: Record<string, TableSyncConfig> = {
  roles: {
    table: "roles",
    mode: "incremental",
    cursorColumn: "UpdatedAt",
    onConflict: "Id",
  },
  users: {
    table: "users",
    mode: "incremental",
    cursorColumn: "UpdatedAt",
    onConflict: "Id",
  },
  profiles: {
    table: "profiles",
    mode: "incremental",
    cursorColumn: "UpdatedAt",
    onConflict: "UserId",
  },
  user_ai_profile: {
    table: "user_ai_profile",
    mode: "incremental",
    cursorColumn: "UpdatedAt",
    onConflict: "UserId",
  },
  health_profiles: {
    table: "health_profiles",
    mode: "incremental",
    cursorColumn: "UpdatedAt",
    onConflict: "UserId",
  },
  subscription_plans: {
    table: "subscription_plans",
    mode: "full",
    onConflict: "Id",
  },
  subscriptions: {
    table: "subscriptions",
    mode: "full",
    onConflict: "Id",
  },
  ingredients: {
    table: "ingredients",
    mode: "full",
    onConflict: "Id",
  },
  foods: {
    table: "foods",
    mode: "full",
    onConflict: "Id",
  },
  recipes: {
    table: "recipes",
    mode: "full",
    onConflict: "Id",
  },
  recipe_ingredients: {
    table: "recipe_ingredients",
    mode: "full",
    onConflict: "Id",
  },
  meal_logs: {
    table: "meal_logs",
    mode: "incremental",
    cursorColumn: "LoggedAt",
    onConflict: "Id",
  },
  meal_plan_headers: {
    table: "meal_plan_headers",
    mode: "incremental",
    cursorColumn: "UpdatedAt",
    onConflict: "Id",
  },
  meal_plan_items: {
    table: "meal_plan_items",
    mode: "incremental",
    cursorColumn: "CreatedAt",
    onConflict: "Id",
  },
  ai_conversations: {
    table: "ai_conversations",
    mode: "incremental",
    cursorColumn: "CreatedAt",
    onConflict: "Id",
  },
  ai_messages: {
    table: "ai_messages",
    mode: "incremental",
    cursorColumn: "CreatedAt",
    onConflict: "Id",
  },
  notifications: {
    table: "notifications",
    mode: "incremental",
    cursorColumn: "CreatedAt",
    onConflict: "Id",
  },
  activity_logs: {
    table: "activity_logs",
    mode: "incremental",
    cursorColumn: "CreatedAt",
    onConflict: "Id",
  },
};

export const DEFAULT_TABLE_ORDER: string[] = [
  "roles",
  "users",
  "profiles",
  "user_ai_profile",
  "health_profiles",
  "subscription_plans",
  "subscriptions",
  "ingredients",
  "foods",
  "recipes",
  "recipe_ingredients",
  "meal_plan_headers",
  "meal_plan_items",
  "meal_logs",
  "ai_conversations",
  "ai_messages",
  "notifications",
  "activity_logs",
];
