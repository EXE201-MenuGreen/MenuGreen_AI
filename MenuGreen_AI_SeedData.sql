-- =============================================================================
-- MenuGreen - PostgreSQL Rich AI seed data (DYNAMICALLY GENERATED)
-- =============================================================================
-- Self-contained PostgreSQL script: creates tables for all current entities and
-- inserts sample data. Safe to re-run with ON CONFLICT DO NOTHING.
-- =============================================================================

BEGIN;

DROP TABLE IF EXISTS activity_logs CASCADE;
DROP TABLE IF EXISTS notifications CASCADE;
DROP TABLE IF EXISTS notification_settings CASCADE;
DROP TABLE IF EXISTS budget_requests CASCADE;
DROP TABLE IF EXISTS recommendation_feedbacks CASCADE;
DROP TABLE IF EXISTS recommendation_history CASCADE;
DROP TABLE IF EXISTS ai_messages CASCADE;
DROP TABLE IF EXISTS ai_conversations CASCADE;
DROP TABLE IF EXISTS nutrition_snapshots CASCADE;
DROP TABLE IF EXISTS weight_logs CASCADE;
DROP TABLE IF EXISTS meal_logs CASCADE;
DROP TABLE IF EXISTS meal_plan_items CASCADE;
DROP TABLE IF EXISTS meal_plan_headers CASCADE;
DROP TABLE IF EXISTS food_allergen_tags CASCADE;
DROP TABLE IF EXISTS food_allergies CASCADE;
DROP TABLE IF EXISTS user_allergies CASCADE;
DROP TABLE IF EXISTS favorite_foods CASCADE;
DROP TABLE IF EXISTS allergies CASCADE;
DROP TABLE IF EXISTS recipe_ingredients CASCADE;
DROP TABLE IF EXISTS recipes CASCADE;
DROP TABLE IF EXISTS ingredients CASCADE;
DROP TABLE IF EXISTS foods CASCADE;
DROP TABLE IF EXISTS password_reset_tokens CASCADE;
DROP TABLE IF EXISTS email_verifications CASCADE;
DROP TABLE IF EXISTS sessions CASCADE;
DROP TABLE IF EXISTS sepay_transactions CASCADE;
DROP TABLE IF EXISTS payments CASCADE;
DROP TABLE IF EXISTS subscription_transactions CASCADE;
DROP TABLE IF EXISTS subscriptions CASCADE;
DROP TABLE IF EXISTS user_subscriptions CASCADE;
DROP TABLE IF EXISTS subscription_plans CASCADE;
DROP TABLE IF EXISTS health_profiles CASCADE;
DROP TABLE IF EXISTS user_ai_profile CASCADE;
DROP TABLE IF EXISTS profiles CASCADE;
DROP TABLE IF EXISTS users CASCADE;
DROP TABLE IF EXISTS roles CASCADE;

CREATE TABLE roles (
    "Id" uuid NOT NULL,
    "Name" character varying(50) NOT NULL,
    "Description" text NULL,
    "CreatedAt" timestamp with time zone NOT NULL,
    "UpdatedAt" timestamp with time zone NOT NULL,
    CONSTRAINT "PK_roles" PRIMARY KEY ("Id")
);

CREATE TABLE users (
    "Id" uuid NOT NULL,
    "RoleId" uuid NOT NULL,
    "Email" text NOT NULL,
    "PasswordHash" text NOT NULL,
    "EmailConfirmed" boolean NOT NULL DEFAULT false,
    "IsActive" boolean NOT NULL DEFAULT true,
    "LastSignInAt" timestamp with time zone NULL,
    "CreatedAt" timestamp with time zone NOT NULL,
    "UpdatedAt" timestamp with time zone NOT NULL,
    "DeletedAt" timestamp with time zone NULL,
    CONSTRAINT "PK_users" PRIMARY KEY ("Id"),
    CONSTRAINT "FK_users_roles_RoleId" FOREIGN KEY ("RoleId") REFERENCES roles ("Id") ON DELETE RESTRICT
);

CREATE TABLE profiles (
    "UserId" uuid NOT NULL,
    "FullName" character varying(255) NULL,
    "AvatarUrl" text NULL,
    "DateOfBirth" date NULL,
    "Gender" character varying(20) NULL,
    "PreferredCuisine" character varying(100) NULL,
    "CreatedAt" timestamp with time zone NOT NULL,
    "UpdatedAt" timestamp with time zone NOT NULL,
    CONSTRAINT "PK_profiles" PRIMARY KEY ("UserId"),
    CONSTRAINT "FK_profiles_users_UserId" FOREIGN KEY ("UserId") REFERENCES users ("Id") ON DELETE CASCADE
);

CREATE TABLE user_ai_profile (
    "UserId" uuid NOT NULL,
    "Preferences" jsonb NULL,
    "DislikedFoods" jsonb NULL,
    "EatingPattern" jsonb NULL,
    "UpdatedAt" timestamp with time zone NULL,
    CONSTRAINT "PK_user_ai_profile" PRIMARY KEY ("UserId"),
    CONSTRAINT "FK_user_ai_profile_users_UserId" FOREIGN KEY ("UserId") REFERENCES users ("Id") ON DELETE CASCADE
);

CREATE TABLE health_profiles (
    "UserId" uuid NOT NULL,
    "HeightCm" numeric(5,2) NULL,
    "WeightKg" numeric(5,2) NULL,
    "BodyFatPercent" numeric(5,2) NULL,
    "ActivityLevel" character varying(50) NULL,
    "Goal" character varying(50) NULL,
    "Bmi" numeric(5,2) NULL,
    "BmrKcal" integer NULL,
    "TdeeKcal" integer NULL,
    "TargetCalories" integer NULL,
    "TargetProteinG" integer NULL,
    "TargetCarbsG" integer NULL,
    "TargetFatG" integer NULL,
    "CreatedAt" timestamp with time zone NOT NULL,
    "UpdatedAt" timestamp with time zone NOT NULL,
    CONSTRAINT "PK_health_profiles" PRIMARY KEY ("UserId"),
    CONSTRAINT "FK_health_profiles_users_UserId" FOREIGN KEY ("UserId") REFERENCES users ("Id") ON DELETE CASCADE
);

CREATE TABLE subscription_plans (
    "Id" uuid NOT NULL,
    "Name" text NULL,
    "Description" text NULL,
    "DurationDays" integer NULL,
    "PriceVnd" integer NULL,
    "FeatureGroup" text NULL,
    "IsActive" boolean NULL,
    CONSTRAINT "PK_subscription_plans" PRIMARY KEY ("Id")
);

CREATE TABLE subscriptions (
    "Id" uuid NOT NULL,
    "UserId" uuid NOT NULL,
    "PlanId" uuid NOT NULL,
    "Status" text NULL,
    "AutoRenew" boolean NULL,
    "StartedAt" timestamp with time zone NULL,
    "ExpiresAt" timestamp with time zone NULL,
    CONSTRAINT "PK_subscriptions" PRIMARY KEY ("Id"),
    CONSTRAINT "FK_subscriptions_subscription_plans_PlanId" FOREIGN KEY ("PlanId") REFERENCES subscription_plans ("Id") ON DELETE CASCADE,
    CONSTRAINT "FK_subscriptions_users_UserId" FOREIGN KEY ("UserId") REFERENCES users ("Id") ON DELETE CASCADE
);

CREATE TABLE user_subscriptions (
    "Id" uuid NOT NULL,
    "UserId" uuid NOT NULL,
    "SubscriptionPlanId" uuid NOT NULL,
    "Status" character varying(50) NOT NULL,
    "StartDate" timestamp with time zone NOT NULL,
    "EndDate" timestamp with time zone NOT NULL,
    "CancelledAt" timestamp with time zone NULL,
    "RenewedAt" timestamp with time zone NULL,
    "CreatedAt" timestamp with time zone NOT NULL,
    "UpdatedAt" timestamp with time zone NOT NULL,
    CONSTRAINT "PK_user_subscriptions" PRIMARY KEY ("Id"),
    CONSTRAINT "FK_user_subscriptions_subscription_plans_SubscriptionPlanId" FOREIGN KEY ("SubscriptionPlanId") REFERENCES subscription_plans ("Id") ON DELETE RESTRICT,
    CONSTRAINT "FK_user_subscriptions_users_UserId" FOREIGN KEY ("UserId") REFERENCES users ("Id") ON DELETE CASCADE
);

CREATE TABLE payments (
    "Id" uuid NOT NULL,
    "UserId" uuid NOT NULL,
    "UserSubscriptionId" uuid NULL,
    "AmountVnd" integer NOT NULL,
    "Status" character varying(32) NOT NULL,
    "PaymentMethod" character varying(32) NOT NULL,
    "Provider" character varying(32) NOT NULL,
    "ProviderOrderCode" character varying(128) NOT NULL,
    "CreatedAt" timestamp with time zone NOT NULL,
    "UpdatedAt" timestamp with time zone NULL,
    "ExpiredAt" timestamp with time zone NULL,
    "PaidAt" timestamp with time zone NULL,
    CONSTRAINT "PK_payments" PRIMARY KEY ("Id"),
    CONSTRAINT "CK_payments_status" CHECK ("Status" IN ('PENDING','PAID','FAILED','EXPIRED','REFUNDED')),
    CONSTRAINT "FK_payments_user_subscriptions_UserSubscriptionId" FOREIGN KEY ("UserSubscriptionId") REFERENCES user_subscriptions ("Id") ON DELETE SET NULL,
    CONSTRAINT "FK_payments_users_UserId" FOREIGN KEY ("UserId") REFERENCES users ("Id") ON DELETE CASCADE
);

CREATE TABLE sepay_transactions (
    "Id" uuid NOT NULL,
    "PaymentId" uuid NOT NULL,
    "TransactionCode" character varying(128) NOT NULL,
    "BankAccount" character varying(64) NULL,
    "TransferAmount" integer NOT NULL,
    "TransferContent" character varying(256) NOT NULL,
    "TransactionTime" timestamp with time zone NOT NULL,
    "Status" character varying(32) NOT NULL,
    "RawPayloadJson" text NULL,
    "CreatedAt" timestamp with time zone NOT NULL,
    CONSTRAINT "PK_sepay_transactions" PRIMARY KEY ("Id"),
    CONSTRAINT "FK_sepay_transactions_payments_PaymentId" FOREIGN KEY ("PaymentId") REFERENCES payments ("Id") ON DELETE CASCADE
);

CREATE TABLE subscription_transactions (
    "Id" uuid NOT NULL,
    "UserId" uuid NOT NULL,
    "UserSubscriptionId" uuid NOT NULL,
    "TransactionType" character varying(50) NOT NULL,
    "Amount" integer NOT NULL,
    "Status" character varying(50) NOT NULL,
    "Note" text NULL,
    "TransactionDate" timestamp with time zone NOT NULL,
    "CreatedAt" timestamp with time zone NOT NULL,
    CONSTRAINT "PK_subscription_transactions" PRIMARY KEY ("Id"),
    CONSTRAINT "FK_sub_txn_user_sub" FOREIGN KEY ("UserSubscriptionId") REFERENCES user_subscriptions ("Id") ON DELETE CASCADE,
    CONSTRAINT "FK_subscription_transactions_users_UserId" FOREIGN KEY ("UserId") REFERENCES users ("Id") ON DELETE CASCADE
);

CREATE TABLE sessions (
    "Id" uuid NOT NULL,
    "UserId" uuid NOT NULL,
    "RefreshToken" text NOT NULL,
    "UserAgent" text NULL,
    "IpAddress" inet NULL,
    "ExpiresAt" timestamp with time zone NOT NULL,
    "CreatedAt" timestamp with time zone NOT NULL,
    CONSTRAINT "PK_sessions" PRIMARY KEY ("Id"),
    CONSTRAINT "FK_sessions_users_UserId" FOREIGN KEY ("UserId") REFERENCES users ("Id") ON DELETE CASCADE
);

CREATE TABLE email_verifications (
    "Id" uuid NOT NULL,
    "UserId" uuid NOT NULL,
    "OtpCode" character varying(20) NOT NULL,
    "ExpiresAt" timestamp with time zone NOT NULL,
    "VerifiedAt" timestamp with time zone NULL,
    "CreatedAt" timestamp with time zone NOT NULL,
    CONSTRAINT "PK_email_verifications" PRIMARY KEY ("Id"),
    CONSTRAINT "FK_email_verifications_users_UserId" FOREIGN KEY ("UserId") REFERENCES users ("Id") ON DELETE CASCADE
);

CREATE TABLE password_reset_tokens (
    "Id" uuid NOT NULL,
    "UserId" uuid NOT NULL,
    "Token" text NOT NULL,
    "ExpiresAt" timestamp with time zone NOT NULL,
    "UsedAt" timestamp with time zone NULL,
    "CreatedAt" timestamp with time zone NOT NULL,
    CONSTRAINT "PK_password_reset_tokens" PRIMARY KEY ("Id"),
    CONSTRAINT "FK_password_reset_tokens_users_UserId" FOREIGN KEY ("UserId") REFERENCES users ("Id") ON DELETE CASCADE
);

CREATE TABLE ingredients (
    "Id" uuid NOT NULL,
    "NameVi" text NOT NULL,
    "NameEn" text NULL,
    "Category" text NULL,
    "CaloriesKcal" numeric NULL,
    "ProteinG" numeric NULL,
    "CarbsG" numeric NULL,
    "FatG" numeric NULL,
    "EstimatedPriceVnd" integer NULL,
    "UnitDefault" text NULL,
    "ImageUrl" text NULL,
    "IsActive" boolean NULL,
    "CreatedAt" timestamp with time zone NULL,
    CONSTRAINT "PK_ingredients" PRIMARY KEY ("Id")
);

CREATE TABLE foods (
    "Id" uuid NOT NULL,
    "NameVi" text NOT NULL,
    "NameEn" text NULL,
    "Category" text NULL,
    "Description" text NULL,
    "CaloriesKcal" numeric NULL,
    "ProteinG" numeric NULL,
    "CarbsG" numeric NULL,
    "FatG" numeric NULL,
    "FiberG" numeric NULL,
    "EstimatedPriceVnd" integer NULL,
    "DefaultServingG" integer NULL,
    "ImageUrl" text NULL,
    "IsActive" boolean NULL,
    "CreatedAt" timestamp with time zone NULL,
    CONSTRAINT "PK_foods" PRIMARY KEY ("Id")
);

CREATE TABLE recipes (
    "Id" uuid NOT NULL,
    "FoodId" uuid NULL,
    "Title" text NOT NULL,
    "Description" text NULL,
    "PrepTimeMin" integer NULL,
    "CookTimeMin" integer NULL,
    "TotalTimeMin" integer NULL,
    "Servings" integer NULL,
    "Difficulty" text NULL,
    "MealType" text NULL,
    "EstimatedPriceVnd" integer NULL,
    "Instructions" json NULL,
    "ImageUrl" text NULL,
    "VideoUrl" text NULL,
    "IsActive" boolean NULL,
    "CreatedAt" timestamp with time zone NULL,
    CONSTRAINT "PK_recipes" PRIMARY KEY ("Id"),
    CONSTRAINT "FK_recipes_foods_FoodId" FOREIGN KEY ("FoodId") REFERENCES foods ("Id") ON DELETE CASCADE
);

CREATE TABLE recipe_ingredients (
    "Id" uuid NOT NULL,
    "RecipeId" uuid NOT NULL,
    "IngredientId" uuid NOT NULL,
    "Quantity" numeric NULL,
    "Unit" text NULL,
    "Notes" text NULL,
    CONSTRAINT "PK_recipe_ingredients" PRIMARY KEY ("Id"),
    CONSTRAINT "FK_recipe_ingredients_ingredients_IngredientId" FOREIGN KEY ("IngredientId") REFERENCES ingredients ("Id") ON DELETE CASCADE,
    CONSTRAINT "FK_recipe_ingredients_recipes_RecipeId" FOREIGN KEY ("RecipeId") REFERENCES recipes ("Id") ON DELETE CASCADE
);

CREATE TABLE allergies (
    "Id" uuid NOT NULL,
    "UserId" uuid NOT NULL,
    "Name" text NOT NULL,
    "Notes" text NULL,
    "IsActive" boolean NOT NULL,
    "CreatedAt" timestamp with time zone NOT NULL,
    "UpdatedAt" timestamp with time zone NOT NULL,
    CONSTRAINT "PK_allergies" PRIMARY KEY ("Id"),
    CONSTRAINT "FK_allergies_users_UserId" FOREIGN KEY ("UserId") REFERENCES users ("Id") ON DELETE CASCADE
);

CREATE TABLE favorite_foods (
    "UserId" uuid NOT NULL,
    "FoodId" uuid NOT NULL,
    "CreatedAt" timestamp with time zone NOT NULL,
    CONSTRAINT "PK_favorite_foods" PRIMARY KEY ("UserId", "FoodId"),
    CONSTRAINT "FK_favorite_foods_foods_FoodId" FOREIGN KEY ("FoodId") REFERENCES foods ("Id") ON DELETE CASCADE,
    CONSTRAINT "FK_favorite_foods_users_UserId" FOREIGN KEY ("UserId") REFERENCES users ("Id") ON DELETE CASCADE
);

CREATE TABLE user_allergies (
    "UserId" uuid NOT NULL,
    "AllergyId" uuid NOT NULL,
    "CreatedAt" timestamp with time zone NOT NULL,
    CONSTRAINT "PK_user_allergies" PRIMARY KEY ("UserId", "AllergyId"),
    CONSTRAINT "FK_user_allergies_allergies_AllergyId" FOREIGN KEY ("AllergyId") REFERENCES allergies ("Id") ON DELETE CASCADE,
    CONSTRAINT "FK_user_allergies_users_UserId" FOREIGN KEY ("UserId") REFERENCES users ("Id") ON DELETE CASCADE
);

CREATE TABLE food_allergies (
    "FoodId" uuid NOT NULL,
    "AllergyId" uuid NOT NULL,
    CONSTRAINT "PK_food_allergies" PRIMARY KEY ("FoodId", "AllergyId"),
    CONSTRAINT "FK_food_allergies_allergies_AllergyId" FOREIGN KEY ("AllergyId") REFERENCES allergies ("Id") ON DELETE CASCADE,
    CONSTRAINT "FK_food_allergies_foods_FoodId" FOREIGN KEY ("FoodId") REFERENCES foods ("Id") ON DELETE CASCADE
);

CREATE TABLE food_allergen_tags (
    "FoodId" uuid NOT NULL,
    "AllergenKey" character varying(64) NOT NULL,
    CONSTRAINT "PK_food_allergen_tags" PRIMARY KEY ("FoodId", "AllergenKey"),
    CONSTRAINT "FK_food_allergen_tags_foods_FoodId" FOREIGN KEY ("FoodId") REFERENCES foods ("Id") ON DELETE CASCADE
);

CREATE TABLE meal_plan_headers (
    "Id" uuid NOT NULL,
    "UserId" uuid NOT NULL,
    "Title" character varying(255) NULL,
    "PlanType" character varying(50) NULL,
    "StartDate" date NULL,
    "EndDate" date NULL,
    "TargetCalories" integer NULL,
    "GeneratedBy" character varying(50) NULL,
    "IsActive" boolean NOT NULL DEFAULT true,
    "CreatedAt" timestamp with time zone NULL,
    "UpdatedAt" timestamp with time zone NULL,
    CONSTRAINT "PK_meal_plan_headers" PRIMARY KEY ("Id"),
    CONSTRAINT "FK_meal_plan_headers_users_UserId" FOREIGN KEY ("UserId") REFERENCES users ("Id") ON DELETE CASCADE
);

CREATE TABLE meal_plan_items (
    "Id" uuid NOT NULL,
    "MealPlanId" uuid NOT NULL,
    "MealType" character varying(50) NULL,
    "FoodId" uuid NULL,
    "RecipeId" uuid NULL,
    "PlannedDate" date NULL,
    "ScheduledTime" time without time zone NULL,
    "TargetCalories" integer NULL,
    "IsCompleted" boolean NOT NULL DEFAULT false,
    "CreatedAt" timestamp with time zone NULL,
    CONSTRAINT "PK_meal_plan_items" PRIMARY KEY ("Id"),
    CONSTRAINT "FK_meal_plan_items_foods_FoodId" FOREIGN KEY ("FoodId") REFERENCES foods ("Id") ON DELETE SET NULL,
    CONSTRAINT "FK_meal_plan_items_meal_plan_headers_MealPlanId" FOREIGN KEY ("MealPlanId") REFERENCES meal_plan_headers ("Id") ON DELETE CASCADE,
    CONSTRAINT "FK_meal_plan_items_recipes_RecipeId" FOREIGN KEY ("RecipeId") REFERENCES recipes ("Id") ON DELETE SET NULL
);

CREATE TABLE meal_logs (
    "Id" uuid NOT NULL,
    "UserId" uuid NOT NULL,
    "FoodId" uuid NULL,
    "RecipeId" uuid NULL,
    "MealType" text NULL,
    "QuantityG" numeric NULL,
    "CaloriesKcal" numeric NULL,
    "ProteinG" numeric NULL,
    "CarbsG" numeric NULL,
    "FatG" numeric NULL,
    "SourceType" text NULL,
    "Notes" text NULL,
    "LoggedAt" timestamp with time zone NULL,
    "MealPlanItemId" uuid NULL,
    "IsFromMealPlan" boolean NOT NULL,
    CONSTRAINT "PK_meal_logs" PRIMARY KEY ("Id"),
    CONSTRAINT "FK_meal_logs_foods_FoodId" FOREIGN KEY ("FoodId") REFERENCES foods ("Id") ON DELETE SET NULL,
    CONSTRAINT "FK_meal_logs_meal_plan_items_MealPlanItemId" FOREIGN KEY ("MealPlanItemId") REFERENCES meal_plan_items ("Id") ON DELETE SET NULL,
    CONSTRAINT "FK_meal_logs_recipes_RecipeId" FOREIGN KEY ("RecipeId") REFERENCES recipes ("Id") ON DELETE SET NULL,
    CONSTRAINT "FK_meal_logs_users_UserId" FOREIGN KEY ("UserId") REFERENCES users ("Id") ON DELETE CASCADE
);

CREATE TABLE weight_logs (
    "Id" uuid NOT NULL,
    "UserId" uuid NOT NULL,
    "WeightKg" numeric NULL,
    "BodyFatPercent" numeric NULL,
    "RecordedAt" timestamp with time zone NULL,
    CONSTRAINT "PK_weight_logs" PRIMARY KEY ("Id"),
    CONSTRAINT "FK_weight_logs_users_UserId" FOREIGN KEY ("UserId") REFERENCES users ("Id") ON DELETE CASCADE
);

CREATE TABLE nutrition_snapshots (
    "Id" uuid NOT NULL,
    "UserId" uuid NOT NULL,
    "SnapshotDate" date NULL,
    "TotalCalories" numeric NULL,
    "TotalProteinG" numeric NULL,
    "TotalCarbsG" numeric NULL,
    "TotalFatG" numeric NULL,
    "GoalCompletionPercent" numeric NULL,
    CONSTRAINT "PK_nutrition_snapshots" PRIMARY KEY ("Id"),
    CONSTRAINT "FK_nutrition_snapshots_users_UserId" FOREIGN KEY ("UserId") REFERENCES users ("Id") ON DELETE CASCADE
);

CREATE TABLE ai_conversations (
    "Id" uuid NOT NULL,
    "UserId" uuid NOT NULL,
    "Title" text NULL,
    "CreatedAt" timestamp with time zone NULL,
    CONSTRAINT "PK_ai_conversations" PRIMARY KEY ("Id"),
    CONSTRAINT "FK_ai_conversations_users_UserId" FOREIGN KEY ("UserId") REFERENCES users ("Id") ON DELETE CASCADE
);

CREATE TABLE ai_messages (
    "Id" uuid NOT NULL,
    "ConversationId" uuid NOT NULL,
    "Role" text NULL,
    "Content" text NULL,
    "TokensUsed" integer NULL,
    "CreatedAt" timestamp with time zone NULL,
    CONSTRAINT "PK_ai_messages" PRIMARY KEY ("Id"),
    CONSTRAINT "FK_ai_messages_ai_conversations_ConversationId" FOREIGN KEY ("ConversationId") REFERENCES ai_conversations ("Id") ON DELETE CASCADE
);

CREATE TABLE recommendation_history (
    "Id" uuid NOT NULL,
    "UserId" uuid NOT NULL,
    "Type" text NULL,
    "Input" json NULL,
    "Output" json NULL,
    "Confidence" numeric NULL,
    "CreatedAt" timestamp with time zone NULL,
    CONSTRAINT "PK_recommendation_history" PRIMARY KEY ("Id"),
    CONSTRAINT "FK_recommendation_history_users_UserId" FOREIGN KEY ("UserId") REFERENCES users ("Id") ON DELETE CASCADE
);

CREATE TABLE recommendation_feedbacks (
    "Id" uuid NOT NULL,
    "RecommendationId" uuid NOT NULL,
    "Rating" integer NULL,
    "Feedback" text NULL,
    "CreatedAt" timestamp with time zone NULL,
    CONSTRAINT "PK_recommendation_feedbacks" PRIMARY KEY ("Id"),
    CONSTRAINT "FK_recommendation_feedbacks_recommendation_history_RecommendationId" FOREIGN KEY ("RecommendationId") REFERENCES recommendation_history ("Id") ON DELETE CASCADE
);

CREATE TABLE budget_requests (
    "Id" uuid NOT NULL,
    "UserId" uuid NOT NULL,
    "BudgetVnd" integer NULL,
    "TimeLimitMin" integer NULL,
    "Result" json NULL,
    "CreatedAt" timestamp with time zone NULL,
    CONSTRAINT "PK_budget_requests" PRIMARY KEY ("Id"),
    CONSTRAINT "FK_budget_requests_users_UserId" FOREIGN KEY ("UserId") REFERENCES users ("Id") ON DELETE CASCADE
);

CREATE TABLE notification_settings (
    "Id" uuid NOT NULL,
    "UserId" uuid NOT NULL,
    "MealReminderEnabled" boolean NOT NULL DEFAULT true,
    "MealReminderOffsetMinutes" integer NOT NULL DEFAULT 30,
    "PrepReminderEnabled" boolean NOT NULL DEFAULT true,
    "PrepReminderOffsetMinutes" integer NOT NULL DEFAULT 20,
    "InAppEnabled" boolean NOT NULL DEFAULT true,
    "PushEnabled" boolean NOT NULL DEFAULT false,
    "CreatedAt" timestamp with time zone NOT NULL,
    "UpdatedAt" timestamp with time zone NOT NULL,
    CONSTRAINT "PK_notification_settings" PRIMARY KEY ("Id"),
    CONSTRAINT "FK_notification_settings_users_UserId" FOREIGN KEY ("UserId") REFERENCES users ("Id") ON DELETE CASCADE
);

CREATE TABLE notifications (
    "Id" uuid NOT NULL,
    "UserId" uuid NOT NULL,
    "Title" character varying(200) NULL,
    "Body" character varying(1000) NULL,
    "Type" character varying(100) NULL,
    "IsRead" boolean NOT NULL DEFAULT false,
    "CreatedAt" timestamp with time zone NOT NULL,
    "ScheduledAt" timestamp with time zone NULL,
    "SentAt" timestamp with time zone NULL,
    "ReadAt" timestamp with time zone NULL,
    CONSTRAINT "PK_notifications" PRIMARY KEY ("Id"),
    CONSTRAINT "FK_notifications_users_UserId" FOREIGN KEY ("UserId") REFERENCES users ("Id") ON DELETE CASCADE
);

CREATE TABLE activity_logs (
    "Id" uuid NOT NULL,
    "UserId" uuid NOT NULL,
    "Action" text NULL,
    "EntityType" text NULL,
    "EntityId" uuid NULL,
    "Metadata" json NULL,
    "CreatedAt" timestamp with time zone NULL,
    CONSTRAINT "PK_activity_logs" PRIMARY KEY ("Id"),
    CONSTRAINT "FK_activity_logs_users_UserId" FOREIGN KEY ("UserId") REFERENCES users ("Id") ON DELETE CASCADE
);

INSERT INTO roles ("Id", "Name", "Description", "CreatedAt", "UpdatedAt")
VALUES
('00000000-0000-0000-0000-000000000001', 'Free', 'Gói người dùng miễn phí', now(), now()),
('00000000-0000-0000-0000-000000000002', 'Pro', 'Gói Pro / Premium quyền lợi cao nhất', now(), now()),
('00000000-0000-0000-0000-000000000003', 'User', 'Standard system user role', now(), now()),
('00000000-0000-0000-0000-000000000004', 'Admin', 'Quản trị viên hệ thống', now(), now())
ON CONFLICT DO NOTHING;

INSERT INTO subscription_plans ("Id", "Name", "Description", "DurationDays", "PriceVnd", "FeatureGroup", "IsActive")
VALUES
('10000000-0000-0000-0000-000000000001', 'Cơ bản', 'Quản lý thực đơn cơ bản, tính calo theo chuẩn', NULL, 0, 'basic', true),
('10000000-0000-0000-0000-000000000002', 'Pro Tháng/GYM', 'Thực đơn nâng cao, phân tích dinh dưỡng, hỗ trợ AI 24/7', 30, 99000, 'pro', true),
('10000000-0000-0000-0000-000000000003', 'Pro Năm', 'Tất cả tính năng Pro, tiết kiệm 20%, hỗ trợ offline và xuất báo cáo PDF', 365, 790000, 'pro', true)
ON CONFLICT DO NOTHING;

INSERT INTO users ("Id", "RoleId", "Email", "PasswordHash", "EmailConfirmed", "IsActive", "LastSignInAt", "CreatedAt", "UpdatedAt", "DeletedAt")
VALUES
('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '00000000-0000-0000-0000-000000000004', 'admin@menugreen.app', '$2b$12$zcokeEBiEkl4iukyN0j6nev0lINFlC8ol8dje1O/JfY2yOHM0arey', true, true, now(), now() - interval '30 days', now() - interval '30 days', NULL),
('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', '00000000-0000-0000-0000-000000000001', 'demo@menugreen.app', '$2b$12$zcokeEBiEkl4iukyN0j6nev0lINFlC8ol8dje1O/JfY2yOHM0arey', true, true, now() - interval '1 day', now() - interval '30 days', now() - interval '30 days', NULL),
('cccccccc-cccc-cccc-cccc-cccccccccccc', '00000000-0000-0000-0000-000000000001', 'free@menugreen.app', '$2b$12$zcokeEBiEkl4iukyN0j6nev0lINFlC8ol8dje1O/JfY2yOHM0arey', true, true, now() - interval '1 day', now() - interval '30 days', now() - interval '30 days', NULL),
('dddddddd-dddd-dddd-dddd-dddddddddddd', '00000000-0000-0000-0000-000000000003', 'user@menugreen.app', '$2b$12$zcokeEBiEkl4iukyN0j6nev0lINFlC8ol8dje1O/JfY2yOHM0arey', true, true, now() - interval '1 day', now() - interval '30 days', now() - interval '30 days', NULL),
('eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee', '00000000-0000-0000-0000-000000000002', 'pro@menugreen.app', '$2b$12$zcokeEBiEkl4iukyN0j6nev0lINFlC8ol8dje1O/JfY2yOHM0arey', true, true, now() - interval '1 day', now() - interval '30 days', now() - interval '30 days', NULL),
('ffffffff-ffff-ffff-ffff-ffffffffffff', '00000000-0000-0000-0000-000000000002', 'premium@menugreen.app', '$2b$12$zcokeEBiEkl4iukyN0j6nev0lINFlC8ol8dje1O/JfY2yOHM0arey', true, true, now() - interval '1 day', now() - interval '30 days', now() - interval '30 days', NULL),
('885810e8-168f-4608-a72e-e23a20dfd258', '00000000-0000-0000-0000-000000000003', 'nguyễnvănbình@gmail.com', '$2b$12$zcokeEBiEkl4iukyN0j6nev0lINFlC8ol8dje1O/JfY2yOHM0arey', true, true, now() - interval '1 day', now() - interval '30 days', now() - interval '30 days', NULL),
('48069bd5-f29a-417d-bdeb-c00797968aca', '00000000-0000-0000-0000-000000000001', 'trầnthịhoa@gmail.com', '$2b$12$zcokeEBiEkl4iukyN0j6nev0lINFlC8ol8dje1O/JfY2yOHM0arey', true, true, now() - interval '1 day', now() - interval '30 days', now() - interval '30 days', NULL),
('9afb13a5-e5a1-4342-9ce1-33bf7cc1de70', '00000000-0000-0000-0000-000000000001', 'phạmminhtuấn@gmail.com', '$2b$12$zcokeEBiEkl4iukyN0j6nev0lINFlC8ol8dje1O/JfY2yOHM0arey', true, true, now() - interval '1 day', now() - interval '30 days', now() - interval '30 days', NULL),
('081b4669-b97f-4e75-b089-4c8de0151653', '00000000-0000-0000-0000-000000000003', 'lêthịmai@gmail.com', '$2b$12$zcokeEBiEkl4iukyN0j6nev0lINFlC8ol8dje1O/JfY2yOHM0arey', true, true, now() - interval '1 day', now() - interval '30 days', now() - interval '30 days', NULL),
('586209d0-d3c4-43a4-bba7-5d4c73b37bc1', '00000000-0000-0000-0000-000000000002', 'hoànganhdũng@gmail.com', '$2b$12$zcokeEBiEkl4iukyN0j6nev0lINFlC8ol8dje1O/JfY2yOHM0arey', true, true, now() - interval '1 day', now() - interval '30 days', now() - interval '30 days', NULL),
('b022ccde-0aa6-4b11-bd7b-f76aaf2c2b17', '00000000-0000-0000-0000-000000000001', 'vũthuhà@gmail.com', '$2b$12$zcokeEBiEkl4iukyN0j6nev0lINFlC8ol8dje1O/JfY2yOHM0arey', true, true, now() - interval '1 day', now() - interval '30 days', now() - interval '30 days', NULL),
('453681f7-f489-47ed-842c-bc3ffd220423', '00000000-0000-0000-0000-000000000001', 'phanhuyhoàng@gmail.com', '$2b$12$zcokeEBiEkl4iukyN0j6nev0lINFlC8ol8dje1O/JfY2yOHM0arey', true, true, now() - interval '1 day', now() - interval '30 days', now() - interval '30 days', NULL),
('396f9dff-6c2a-422f-b0cc-8eb451168ed3', '00000000-0000-0000-0000-000000000001', 'đỗmỹlinh@gmail.com', '$2b$12$zcokeEBiEkl4iukyN0j6nev0lINFlC8ol8dje1O/JfY2yOHM0arey', true, true, now() - interval '1 day', now() - interval '30 days', now() - interval '30 days', NULL),
('5dc50160-db9e-447a-ba33-9026d8800ab5', '00000000-0000-0000-0000-000000000003', 'bùiquốcanh@gmail.com', '$2b$12$zcokeEBiEkl4iukyN0j6nev0lINFlC8ol8dje1O/JfY2yOHM0arey', true, true, now() - interval '1 day', now() - interval '30 days', now() - interval '30 days', NULL),
('212ea8ea-749e-44a1-92d2-636bd617cbc8', '00000000-0000-0000-0000-000000000001', 'ngôkhánhvy@gmail.com', '$2b$12$zcokeEBiEkl4iukyN0j6nev0lINFlC8ol8dje1O/JfY2yOHM0arey', true, true, now() - interval '1 day', now() - interval '30 days', now() - interval '30 days', NULL)
ON CONFLICT DO NOTHING;

INSERT INTO profiles ("UserId", "FullName", "AvatarUrl", "DateOfBirth", "Gender", "PreferredCuisine", "CreatedAt", "UpdatedAt")
VALUES
('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'Admin MenuGreen', 'https://i.pravatar.cc/150?u=aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '1995-04-12', 'Male', 'Việt Nam', now() - interval '30 days', now() - interval '30 days'),
('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'Nguyễn Văn Demo', 'https://i.pravatar.cc/150?u=bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', '1995-04-12', 'Male', 'Việt Nam', now() - interval '30 days', now() - interval '30 days'),
('cccccccc-cccc-cccc-cccc-cccccccccccc', 'Trần Thị Free', 'https://i.pravatar.cc/150?u=cccccccc-cccc-cccc-cccc-cccccccccccc', '1997-09-22', 'Female', 'Việt Nam', now() - interval '30 days', now() - interval '30 days'),
('dddddddd-dddd-dddd-dddd-dddddddddddd', 'Lê Văn User', 'https://i.pravatar.cc/150?u=dddddddd-dddd-dddd-dddd-dddddddddddd', '1995-04-12', 'Male', 'Việt Nam', now() - interval '30 days', now() - interval '30 days'),
('eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee', 'Phạm Hoàng Pro', 'https://i.pravatar.cc/150?u=eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee', '1995-04-12', 'Male', 'Tây Âu', now() - interval '30 days', now() - interval '30 days'),
('ffffffff-ffff-ffff-ffff-ffffffffffff', 'Hoàng Thị Premium', 'https://i.pravatar.cc/150?u=ffffffff-ffff-ffff-ffff-ffffffffffff', '1997-09-22', 'Female', 'Nhật Bản', now() - interval '30 days', now() - interval '30 days'),
('885810e8-168f-4608-a72e-e23a20dfd258', 'Nguyễn Văn Bình', 'https://i.pravatar.cc/150?u=885810e8-168f-4608-a72e-e23a20dfd258', '1995-04-12', 'Male', 'Việt Nam', now() - interval '30 days', now() - interval '30 days'),
('48069bd5-f29a-417d-bdeb-c00797968aca', 'Trần Thị Hoa', 'https://i.pravatar.cc/150?u=48069bd5-f29a-417d-bdeb-c00797968aca', '1997-09-22', 'Female', 'Việt Nam', now() - interval '30 days', now() - interval '30 days'),
('9afb13a5-e5a1-4342-9ce1-33bf7cc1de70', 'Phạm Minh Tuấn', 'https://i.pravatar.cc/150?u=9afb13a5-e5a1-4342-9ce1-33bf7cc1de70', '1995-04-12', 'Male', 'Việt Nam', now() - interval '30 days', now() - interval '30 days'),
('081b4669-b97f-4e75-b089-4c8de0151653', 'Lê Thị Mai', 'https://i.pravatar.cc/150?u=081b4669-b97f-4e75-b089-4c8de0151653', '1997-09-22', 'Female', 'Việt Nam', now() - interval '30 days', now() - interval '30 days'),
('586209d0-d3c4-43a4-bba7-5d4c73b37bc1', 'Hoàng Anh Dũng', 'https://i.pravatar.cc/150?u=586209d0-d3c4-43a4-bba7-5d4c73b37bc1', '1995-04-12', 'Male', 'Việt Nam', now() - interval '30 days', now() - interval '30 days'),
('b022ccde-0aa6-4b11-bd7b-f76aaf2c2b17', 'Vũ Thu Hà', 'https://i.pravatar.cc/150?u=b022ccde-0aa6-4b11-bd7b-f76aaf2c2b17', '1997-09-22', 'Female', 'Việt Nam', now() - interval '30 days', now() - interval '30 days'),
('453681f7-f489-47ed-842c-bc3ffd220423', 'Phan Huy Hoàng', 'https://i.pravatar.cc/150?u=453681f7-f489-47ed-842c-bc3ffd220423', '1995-04-12', 'Male', 'Việt Nam', now() - interval '30 days', now() - interval '30 days'),
('396f9dff-6c2a-422f-b0cc-8eb451168ed3', 'Đỗ Mỹ Linh', 'https://i.pravatar.cc/150?u=396f9dff-6c2a-422f-b0cc-8eb451168ed3', '1997-09-22', 'Female', 'Việt Nam', now() - interval '30 days', now() - interval '30 days'),
('5dc50160-db9e-447a-ba33-9026d8800ab5', 'Bùi Quốc Anh', 'https://i.pravatar.cc/150?u=5dc50160-db9e-447a-ba33-9026d8800ab5', '1995-04-12', 'Male', 'Việt Nam', now() - interval '30 days', now() - interval '30 days'),
('212ea8ea-749e-44a1-92d2-636bd617cbc8', 'Ngô Khánh Vy', 'https://i.pravatar.cc/150?u=212ea8ea-749e-44a1-92d2-636bd617cbc8', '1997-09-22', 'Female', 'Việt Nam', now() - interval '30 days', now() - interval '30 days')
ON CONFLICT DO NOTHING;

INSERT INTO user_ai_profile ("UserId", "Preferences", "DislikedFoods", "EatingPattern", "UpdatedAt")
VALUES
('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', '{"likes": ["salad", "smoothie", "ức gà"], "goals": ["lose weight"]}', '["fried foods", "fast food", "mỡ động vật"]', '{"meals_per_day": 3, "eating_speed": "moderate"}', now()),
('cccccccc-cccc-cccc-cccc-cccccccccccc', '{"likes": ["salad", "smoothie", "ức gà"], "goals": ["lose weight"]}', '["fried foods", "fast food", "mỡ động vật"]', '{"meals_per_day": 3, "eating_speed": "moderate"}', now()),
('dddddddd-dddd-dddd-dddd-dddddddddddd', '{"likes": ["salad", "smoothie", "ức gà"], "goals": ["lose weight"]}', '["fried foods", "fast food", "mỡ động vật"]', '{"meals_per_day": 3, "eating_speed": "moderate"}', now()),
('eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee', '{"likes": ["salad", "smoothie", "ức gà"], "goals": ["lose weight"]}', '["fried foods", "fast food", "mỡ động vật"]', '{"meals_per_day": 3, "eating_speed": "moderate"}', now()),
('ffffffff-ffff-ffff-ffff-ffffffffffff', '{"likes": ["salad", "smoothie", "ức gà"], "goals": ["lose weight"]}', '["fried foods", "fast food", "mỡ động vật"]', '{"meals_per_day": 3, "eating_speed": "moderate"}', now()),
('885810e8-168f-4608-a72e-e23a20dfd258', '{"likes": ["salad", "smoothie", "ức gà"], "goals": ["lose weight"]}', '["fried foods", "fast food", "mỡ động vật"]', '{"meals_per_day": 3, "eating_speed": "moderate"}', now()),
('48069bd5-f29a-417d-bdeb-c00797968aca', '{"likes": ["salad", "smoothie", "ức gà"], "goals": ["lose weight"]}', '["fried foods", "fast food", "mỡ động vật"]', '{"meals_per_day": 3, "eating_speed": "moderate"}', now()),
('9afb13a5-e5a1-4342-9ce1-33bf7cc1de70', '{"likes": ["salad", "smoothie", "ức gà"], "goals": ["lose weight"]}', '["fried foods", "fast food", "mỡ động vật"]', '{"meals_per_day": 3, "eating_speed": "moderate"}', now()),
('081b4669-b97f-4e75-b089-4c8de0151653', '{"likes": ["salad", "smoothie", "ức gà"], "goals": ["lose weight"]}', '["fried foods", "fast food", "mỡ động vật"]', '{"meals_per_day": 3, "eating_speed": "moderate"}', now()),
('586209d0-d3c4-43a4-bba7-5d4c73b37bc1', '{"likes": ["salad", "smoothie", "ức gà"], "goals": ["lose weight"]}', '["fried foods", "fast food", "mỡ động vật"]', '{"meals_per_day": 3, "eating_speed": "moderate"}', now()),
('b022ccde-0aa6-4b11-bd7b-f76aaf2c2b17', '{"likes": ["salad", "smoothie", "ức gà"], "goals": ["lose weight"]}', '["fried foods", "fast food", "mỡ động vật"]', '{"meals_per_day": 3, "eating_speed": "moderate"}', now()),
('453681f7-f489-47ed-842c-bc3ffd220423', '{"likes": ["salad", "smoothie", "ức gà"], "goals": ["lose weight"]}', '["fried foods", "fast food", "mỡ động vật"]', '{"meals_per_day": 3, "eating_speed": "moderate"}', now()),
('396f9dff-6c2a-422f-b0cc-8eb451168ed3', '{"likes": ["salad", "smoothie", "ức gà"], "goals": ["lose weight"]}', '["fried foods", "fast food", "mỡ động vật"]', '{"meals_per_day": 3, "eating_speed": "moderate"}', now()),
('5dc50160-db9e-447a-ba33-9026d8800ab5', '{"likes": ["salad", "smoothie", "ức gà"], "goals": ["lose weight"]}', '["fried foods", "fast food", "mỡ động vật"]', '{"meals_per_day": 3, "eating_speed": "moderate"}', now()),
('212ea8ea-749e-44a1-92d2-636bd617cbc8', '{"likes": ["salad", "smoothie", "ức gà"], "goals": ["lose weight"]}', '["fried foods", "fast food", "mỡ động vật"]', '{"meals_per_day": 3, "eating_speed": "moderate"}', now())
ON CONFLICT DO NOTHING;

INSERT INTO health_profiles ("UserId", "HeightCm", "WeightKg", "BodyFatPercent", "ActivityLevel", "Goal", "Bmi", "BmrKcal", "TdeeKcal", "TargetCalories", "TargetProteinG", "TargetCarbsG", "TargetFatG", "CreatedAt", "UpdatedAt")
VALUES
('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 175.00, 71.50, 18.50, 'moderately active', 'gain muscle', 23.35, 1673, 2301, 2601, 195, 292, 72, now() - interval '30 days', now() - interval '30 days'),
('cccccccc-cccc-cccc-cccc-cccccccccccc', 160.00, 54.60, 24.50, 'moderately active', 'lose weight', 21.33, 1255, 1725, 1325, 99, 149, 36, now() - interval '30 days', now() - interval '30 days'),
('dddddddd-dddd-dddd-dddd-dddddddddddd', 175.00, 70.50, 18.50, 'moderately active', 'gain muscle', 23.02, 1663, 2287, 2587, 194, 291, 71, now() - interval '30 days', now() - interval '30 days'),
('eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee', 175.00, 70.00, 18.50, 'moderately active', 'lose weight', 22.86, 1658, 2280, 1880, 141, 211, 52, now() - interval '30 days', now() - interval '30 days'),
('ffffffff-ffff-ffff-ffff-ffffffffffff', 160.00, 55.50, 24.50, 'moderately active', 'gain muscle', 21.68, 1264, 1738, 2038, 152, 229, 56, now() - interval '30 days', now() - interval '30 days'),
('885810e8-168f-4608-a72e-e23a20dfd258', 175.00, 69.00, 18.50, 'moderately active', 'lose weight', 22.53, 1648, 2267, 1867, 140, 210, 51, now() - interval '30 days', now() - interval '30 days'),
('48069bd5-f29a-417d-bdeb-c00797968aca', 160.00, 56.10, 24.50, 'moderately active', 'gain muscle', 21.91, 1270, 1746, 2046, 153, 230, 56, now() - interval '30 days', now() - interval '30 days'),
('9afb13a5-e5a1-4342-9ce1-33bf7cc1de70', 175.00, 68.00, 18.50, 'moderately active', 'lose weight', 22.20, 1638, 2253, 1853, 138, 208, 51, now() - interval '30 days', now() - interval '30 days'),
('081b4669-b97f-4e75-b089-4c8de0151653', 160.00, 56.70, 24.50, 'moderately active', 'gain muscle', 22.15, 1276, 1754, 2054, 154, 231, 57, now() - interval '30 days', now() - interval '30 days'),
('586209d0-d3c4-43a4-bba7-5d4c73b37bc1', 175.00, 67.00, 18.50, 'moderately active', 'lose weight', 21.88, 1628, 2239, 1839, 137, 206, 51, now() - interval '30 days', now() - interval '30 days'),
('b022ccde-0aa6-4b11-bd7b-f76aaf2c2b17', 160.00, 57.30, 24.50, 'moderately active', 'gain muscle', 22.38, 1282, 1762, 2062, 154, 232, 57, now() - interval '30 days', now() - interval '30 days'),
('453681f7-f489-47ed-842c-bc3ffd220423', 175.00, 66.00, 18.50, 'moderately active', 'lose weight', 21.55, 1618, 2225, 1825, 136, 205, 50, now() - interval '30 days', now() - interval '30 days'),
('396f9dff-6c2a-422f-b0cc-8eb451168ed3', 160.00, 57.90, 24.50, 'moderately active', 'gain muscle', 22.62, 1288, 1771, 2071, 155, 232, 57, now() - interval '30 days', now() - interval '30 days'),
('5dc50160-db9e-447a-ba33-9026d8800ab5', 175.00, 65.00, 18.50, 'moderately active', 'lose weight', 21.22, 1608, 2212, 1812, 135, 203, 50, now() - interval '30 days', now() - interval '30 days'),
('212ea8ea-749e-44a1-92d2-636bd617cbc8', 160.00, 58.50, 24.50, 'moderately active', 'gain muscle', 22.85, 1294, 1779, 2079, 155, 233, 57, now() - interval '30 days', now() - interval '30 days')
ON CONFLICT DO NOTHING;

INSERT INTO ingredients ("Id", "NameVi", "NameEn", "Category", "CaloriesKcal", "ProteinG", "CarbsG", "FatG", "EstimatedPriceVnd", "UnitDefault", "ImageUrl", "IsActive", "CreatedAt")
VALUES
('73cb3e0a-5abc-5c6c-a7a2-7a9ac350f4cd', 'Ức gà', 'Chicken breast', 'Thịt/Cá', 120, 26.0, 0.0, 1.5, 80000, 'g', 'https://images.unsplash.com/photo-1604503468506-a8da13d82791?w=150', true, now()),
('81d8c5d5-4bc9-5c71-86a5-70672e7764b4', 'Xà lách', 'Lettuce', 'Rau củ', 15, 1.3, 2.8, 0.2, 25000, 'g', 'https://images.unsplash.com/photo-1556801712-74c73693f110?w=150', true, now()),
('6c224f0b-9b70-5342-8487-c7a49e2aaed4', 'Cà chua', 'Tomato', 'Rau củ', 18, 0.9, 3.9, 0.2, 20000, 'g', 'https://images.unsplash.com/photo-1595855759920-86582396756a?w=150', true, now()),
('1ddf13c6-e4f7-5042-a801-62cb588e2dbd', 'Dầu olive', 'Olive oil', 'Gia vị/Dầu', 884, 0.0, 0.0, 100.0, 250000, 'ml', 'https://images.unsplash.com/photo-1474979266404-7eaacbcd87c5?w=150', true, now()),
('5824249f-4a90-5eb8-ab3e-fe00ffdbf0bb', 'Chanh', 'Lime', 'Rau củ', 30, 0.7, 10.5, 0.2, 15000, 'g', 'https://images.unsplash.com/photo-1590502593747-42a996133562?w=150', true, now()),
('36d9374a-4dc9-5066-bf57-ded98b96a211', 'Bơ quả', 'Avocado', 'Trái cây', 160, 2.0, 8.5, 14.7, 60000, 'g', 'https://images.unsplash.com/photo-1523049673857-eb18f1d7b578?w=150', true, now()),
('9c5cd032-5b23-5f98-b8e3-db420837a526', 'Chuối', 'Banana', 'Trái cây', 89, 1.1, 22.8, 0.3, 18000, 'g', 'https://images.unsplash.com/photo-1571771894821-ce9b6c11b08e?w=150', true, now()),
('2c01232c-01f1-57e7-a8ef-d19a140ca266', 'Gạo lứt', 'Brown rice', 'Tinh bột', 111, 2.6, 23.0, 0.9, 35000, 'g', 'https://images.unsplash.com/photo-1586201375761-83865001e31c?w=150', true, now()),
('01619128-a551-5bcb-84a9-5f7ddf562db4', 'Đậu hũ', 'Tofu', 'Đậu/Hạt', 76, 8.0, 1.9, 4.8, 15000, 'g', 'https://images.unsplash.com/photo-1546069901-ba9599a7e63c?w=150', true, now()),
('53aa2eb8-e5c5-525a-a1bf-0f697cb5f048', 'Bơ đậu phộng', 'Peanut butter', 'Đậu/Hạt', 588, 25.0, 20.0, 50.0, 85000, 'g', 'https://images.unsplash.com/photo-1590080875515-8a3a8dc5735e?w=150', true, now()),
('ea000001-1111-2222-3333-444444444444', 'Thịt bò thăn', 'Beef tenderloin', 'Thịt/Cá', 143, 26.0, 0.0, 3.8, 280000, 'g', 'https://images.unsplash.com/photo-1544025162-d76694265947?w=150', true, now()),
('ea000002-1111-2222-3333-444444444444', 'Cá hồi phi lê', 'Salmon fillet', 'Thịt/Cá', 208, 20.0, 0.0, 13.0, 420000, 'g', 'https://images.unsplash.com/photo-1467003909585-2f8a72700288?w=150', true, now()),
('ea000003-1111-2222-3333-444444444444', 'Yến mạch nguyên cám', 'Rolled oats', 'Tinh bột', 389, 16.9, 66.3, 6.9, 60000, 'g', 'https://images.unsplash.com/photo-1586444248902-2f64eddc13df?w=150', true, now()),
('ea000004-1111-2222-3333-444444444444', 'Trứng gà', 'Egg', 'Trứng/Sữa', 143, 13.0, 1.1, 11.0, 4000, 'quả', 'https://images.unsplash.com/photo-1506976785307-8732e854ad03?w=150', true, now()),
('ea000005-1111-2222-3333-444444444444', 'Sữa tươi không đường', 'Unsweetened milk', 'Trứng/Sữa', 60, 3.2, 4.7, 3.3, 30000, 'ml', 'https://images.unsplash.com/photo-1563636619-e9143da7973b?w=150', true, now()),
('ea000006-1111-2222-3333-444444444444', 'Khoai lang', 'Sweet potato', 'Tinh bột', 86, 1.6, 20.1, 0.1, 20000, 'g', 'https://images.unsplash.com/photo-1590080875515-8a3a8dc5735e?w=150', true, now()),
('ea000007-1111-2222-3333-444444444444', 'Bông cải xanh', 'Broccoli', 'Rau củ', 34, 2.8, 6.6, 0.4, 30000, 'g', 'https://images.unsplash.com/photo-1584269600464-37b1b58a9fe7?w=150', true, now()),
('ea000008-1111-2222-3333-444444444444', 'Mật ong', 'Honey', 'Gia vị/Dầu', 304, 0.3, 82.4, 0.0, 180000, 'g', 'https://images.unsplash.com/photo-1587049352846-4a222e784d38?w=150', true, now()),
('ea000009-1111-2222-3333-444444444444', 'Hạt hạnh nhân', 'Almonds', 'Đậu/Hạt', 579, 21.0, 22.0, 49.0, 350000, 'g', 'https://images.unsplash.com/photo-1508061263366-f7e9f45a7b81?w=150', true, now()),
('ea000010-1111-2222-3333-444444444444', 'Nấm đùi gà', 'King oyster mushroom', 'Rau củ', 35, 2.5, 6.0, 0.3, 65000, 'g', 'https://images.unsplash.com/photo-1534422298391-e4f8c172dddb?w=150', true, now())
ON CONFLICT DO NOTHING;

INSERT INTO foods ("Id", "NameVi", "NameEn", "Category", "Description", "CaloriesKcal", "ProteinG", "CarbsG", "FatG", "FiberG", "EstimatedPriceVnd", "DefaultServingG", "ImageUrl", "IsActive", "CreatedAt")
VALUES
('fd000001-0000-0000-0000-000000000001', 'Ức gà áp chảo', 'Pan-seared chicken breast', 'Món mặn', 'Món ăn giàu protein, ít chất béo cho người giảm cân', 165, 31.0, 0.0, 3.6, 0.0, 35000, 150, 'https://images.unsplash.com/photo-1604503468506-a8da13d82791?w=400', true, now()),
('fd000002-0000-0000-0000-000000000002', 'Cơm gạo lứt', 'Cooked brown rice', 'Tinh bột', 'Cơm nấu từ gạo lứt dẻo thơm, giàu chất xơ', 111, 2.6, 23.0, 0.9, 1.8, 10000, 100, 'https://images.unsplash.com/photo-1586201375761-83865001e31c?w=400', true, now()),
('fd000003-0000-0000-0000-000000000003', 'Salad bơ ức gà', 'Avocado chicken salad', 'Salad', 'Salad tươi mát kèm ức gà xé và bơ sáp thơm ngậy', 320, 28.5, 12.0, 18.5, 5.2, 55000, 250, 'https://images.unsplash.com/photo-1540420773420-3366772f4999?w=400', true, now()),
('fd000004-0000-0000-0000-000000000004', 'Khoai lang hấp', 'Steamed sweet potato', 'Tinh bột', 'Khoai lang ngọt dịu, tinh bột hấp thụ chậm hoàn hảo', 86, 1.6, 20.1, 0.1, 3.0, 8000, 100, 'https://images.unsplash.com/photo-1590080875515-8a3a8dc5735e?w=400', true, now()),
('fd000005-0000-0000-0000-000000000005', 'Sinh tố chuối bơ đậu phộng', 'Peanut butter banana smoothie', 'Thức uống', 'Sinh tố tăng cân, cung cấp nhiều năng lượng và chất béo tốt', 450, 12.0, 52.0, 22.0, 4.5, 30000, 350, 'https://images.unsplash.com/photo-1553530666-ba11a7da3888?w=400', true, now()),
('fd000006-0000-0000-0000-000000000006', 'Bò áp chảo bông cải xanh', 'Beef steak with broccoli', 'Món mặn', 'Thịt bò thăn giàu sắt kết hợp bông cải xanh giòn ngon', 290, 32.0, 6.6, 14.5, 2.5, 95000, 200, 'https://images.unsplash.com/photo-1544025162-d76694265947?w=400', true, now()),
('fd000007-0000-0000-0000-000000000007', 'Cá hồi áp chảo sốt chanh', 'Pan-seared salmon with lemon sauce', 'Món mặn', 'Cá hồi béo ngậy sốt chanh leo chua ngọt nhẹ', 350, 25.0, 5.0, 24.0, 0.5, 120000, 150, 'https://images.unsplash.com/photo-1467003909585-2f8a72700288?w=400', true, now()),
('fd000008-0000-0000-0000-000000000008', 'Cháo yến mạch trứng gà', 'Oatmeal porridge with egg', 'Món nước', 'Món ăn sáng nhẹ bụng, dễ tiêu hóa và chế biến nhanh', 250, 11.5, 28.0, 8.5, 3.5, 15000, 250, 'https://images.unsplash.com/photo-1586444248902-2f64eddc13df?w=400', true, now()),
('fd000009-0000-0000-0000-000000000009', 'Đậu hũ sốt cà chua', 'Tofu in tomato sauce', 'Chay', 'Đậu hũ thanh đạm sốt cà chua tươi đậm đà', 180, 12.0, 8.5, 10.0, 2.0, 15000, 200, 'https://images.unsplash.com/photo-1546069901-ba9599a7e63c?w=400', true, now()),
('fd000010-0000-0000-0000-000000000010', 'Salad cá hồi bơ', 'Salmon avocado salad', 'Salad', 'Salad hỗn hợp với bơ sáp và cá hồi phi lê nướng', 380, 23.0, 9.5, 28.0, 4.0, 85000, 250, 'https://images.unsplash.com/photo-1540420773420-3366772f4999?w=400', true, now())
ON CONFLICT DO NOTHING;

INSERT INTO recipes ("Id", "FoodId", "Title", "Description", "PrepTimeMin", "CookTimeMin", "TotalTimeMin", "Servings", "Difficulty", "MealType", "EstimatedPriceVnd", "Instructions", "ImageUrl", "VideoUrl", "IsActive", "CreatedAt")
VALUES
('ec000001-0000-0000-0000-000000000001', 'fd000001-0000-0000-0000-000000000001', 'Ức gà áp chảo sốt chanh', 'Cách làm ức gà mềm mọng không bị khô sốt chanh leo thơm ngon', 10, 15, 25, 1, 'Easy', 'Lunch', 35000, '["Bước 1: Rửa sạch ức gà, khía nhẹ bề mặt.", "Bước 2: Ướp với chút muối, tiêu và tỏi băm trong 10 phút.", "Bước 3: Cho 5ml dầu olive vào chảo, áp chảo mỗi mặt 5-6 phút đến khi chín vàng.", "Bước 4: Rưới nước cốt chanh leo pha mật ong lên trên và thưởng thức."]', 'https://images.unsplash.com/photo-1604503468506-a8da13d82791?w=400', NULL, true, now()),
('ec000002-0000-0000-0000-000000000002', 'fd000003-0000-0000-0000-000000000003', 'Salad bơ ức gà giảm cân', 'Salad dầu giấm ức gà kết hợp bơ quả thơm béo', 10, 10, 20, 1, 'Easy', 'Dinner', 55000, '["Bước 1: Luộc chín ức gà và xé nhỏ.", "Bước 2: Cắt hạt lựu bơ quả và cà chua, xà lách rửa sạch cắt khúc.", "Bước 3: Trộn nước sốt gồm dầu olive, nước cốt chanh, muối và chút tiêu.", "Bước 4: Trộn đều rau quả với gà xé và rưới nước sốt."]', 'https://images.unsplash.com/photo-1540420773420-3366772f4999?w=400', NULL, true, now()),
('ec000003-0000-0000-0000-000000000003', 'fd000007-0000-0000-0000-000000000007', 'Cá hồi áp chảo sốt măng tây', 'Cá hồi áp chảo béo ngậy kèm măng tây giòn ngọt', 15, 10, 25, 1, 'Medium', 'Dinner', 120000, '["Bước 1: Thấm khô miếng cá hồi, ướp muối tiêu hai mặt.", "Bước 2: Làm nóng chảo, cho chút bơ hoặc dầu olive vào, áp chảo cá hồi mỗi bên 3 phút.", "Bước 3: Xào măng tây và tỏi băm trên chảo nóng.", "Bước 4: Bày cá ra đĩa kèm măng tây, rưới chanh tươi."]', 'https://images.unsplash.com/photo-1467003909585-2f8a72700288?w=400', NULL, true, now()),
('ec000004-0000-0000-0000-000000000004', 'fd000008-0000-0000-0000-000000000008', 'Cháo yến mạch trứng gà ăn sáng', 'Cháo yến mạch ấm nóng cung cấp năng lượng nhanh cho buổi sáng', 5, 10, 15, 1, 'Easy', 'Breakfast', 15000, '["Bước 1: Ngâm yến mạch với nước ấm khoảng 5 phút.", "Bước 2: Cho yến mạch vào nồi nhỏ đun sôi, khuấy đều tay.", "Bước 3: Đập 1 quả trứng gà vào nồi cháo, khuấy nhanh tay để trứng tan.", "Bước 4: Nêm chút nước mắm hoặc hạt nêm gia vị, đun thêm 2 phút rồi tắt bếp."]', 'https://images.unsplash.com/photo-1586444248902-2f64eddc13df?w=400', NULL, true, now())
ON CONFLICT DO NOTHING;

INSERT INTO recipe_ingredients ("Id", "RecipeId", "IngredientId", "Quantity", "Unit", "Notes")
VALUES
('76fb457a-4f5d-4a4f-94cc-b53919344857', 'ec000001-0000-0000-0000-000000000001', '73cb3e0a-5abc-5c6c-a7a2-7a9ac350f4cd', 150.0, 'g', 'Ức gà phi lê tươi'),
('50336712-b29d-4c48-b65c-1b7833d62c7a', 'ec000001-0000-0000-0000-000000000001', '1ddf13c6-e4f7-5042-a801-62cb588e2dbd', 5.0, 'ml', 'Dầu olive áp chảo'),
('3f9fdd0b-fc3a-4ee5-9367-1c7a397b7166', 'ec000001-0000-0000-0000-000000000001', '5824249f-4a90-5eb8-ab3e-fe00ffdbf0bb', 20.0, 'g', 'Chanh tươi lấy cốt'),
('1408624f-5756-48f2-b7b6-ed3e35ba413e', 'ec000002-0000-0000-0000-000000000002', '73cb3e0a-5abc-5c6c-a7a2-7a9ac350f4cd', 100.0, 'g', 'Ức gà xé nhỏ'),
('43491dab-8ac9-41c0-b1ca-53e7c7effc69', 'ec000002-0000-0000-0000-000000000002', '36d9374a-4dc9-5066-bf57-ded98b96a211', 80.0, 'g', 'Bơ sáp cắt miếng'),
('c158cda6-c97b-4efb-9216-9de49c8f63e5', 'ec000002-0000-0000-0000-000000000002', '81d8c5d5-4bc9-5c71-86a5-70672e7764b4', 50.0, 'g', 'Rau xà lách tươi'),
('b5289b5d-29b1-4962-887a-625458d015d9', 'ec000003-0000-0000-0000-000000000003', 'ea000002-1111-2222-3333-444444444444', 150.0, 'g', 'Cá hồi Nauy fillet'),
('53d97887-6858-46bd-aa72-e242af01be0f', 'ec000003-0000-0000-0000-000000000003', '1ddf13c6-e4f7-5042-a801-62cb588e2dbd', 5.0, 'ml', 'Dầu olive'),
('2de24e2b-e006-4d7b-a29e-6fe44bfecce2', 'ec000004-0000-0000-0000-000000000004', 'ea000003-1111-2222-3333-444444444444', 50.0, 'g', 'Yến mạch cán vỡ'),
('6753a2ff-eefa-44b1-961a-b2609eb14445', 'ec000004-0000-0000-0000-000000000004', 'ea000004-1111-2222-3333-444444444444', 1.0, 'quả', 'Trứng gà tươi')
ON CONFLICT DO NOTHING;

INSERT INTO allergies ("Id", "UserId", "Name", "Notes", "IsActive", "CreatedAt", "UpdatedAt")
VALUES
('f738b00b-67f6-4ba9-9edf-23d4107d09d3', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'Dị ứng hải sản', 'Ghi chú dị ứng thức ăn nhẹ', true, now(), now()),
('704d45b7-f17a-4634-845e-a2521674ddd3', 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'Dị ứng trứng', 'Ghi chú dị ứng thức ăn nhẹ', true, now(), now()),
('f3f478e9-810f-4be2-bf95-d445bcafa07a', 'cccccccc-cccc-cccc-cccc-cccccccccccc', 'Dị ứng sữa lactose', 'Ghi chú dị ứng thức ăn nhẹ', true, now(), now()),
('e48374bc-f7c7-4a1d-a522-8528e856b676', 'dddddddd-dddd-dddd-dddd-dddddddddddd', 'Dị ứng đậu phộng', 'Ghi chú dị ứng thức ăn nhẹ', true, now(), now()),
('b308cdfd-7922-4c7e-81b5-5847f28d47dc', 'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee', 'Dị ứng Gluten', 'Ghi chú dị ứng thức ăn nhẹ', true, now(), now())
ON CONFLICT DO NOTHING;

INSERT INTO user_allergies ("UserId", "AllergyId", "CreatedAt")
VALUES
('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'f738b00b-67f6-4ba9-9edf-23d4107d09d3', now()),
('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', '704d45b7-f17a-4634-845e-a2521674ddd3', now()),
('cccccccc-cccc-cccc-cccc-cccccccccccc', 'f3f478e9-810f-4be2-bf95-d445bcafa07a', now()),
('dddddddd-dddd-dddd-dddd-dddddddddddd', 'e48374bc-f7c7-4a1d-a522-8528e856b676', now()),
('eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee', 'b308cdfd-7922-4c7e-81b5-5847f28d47dc', now())
ON CONFLICT DO NOTHING;

INSERT INTO food_allergies ("FoodId", "AllergyId")
VALUES
('fd000007-0000-0000-0000-000000000007', 'f738b00b-67f6-4ba9-9edf-23d4107d09d3'),
('fd000010-0000-0000-0000-000000000010', 'f738b00b-67f6-4ba9-9edf-23d4107d09d3'),
('fd000005-0000-0000-0000-000000000005', 'f3f478e9-810f-4be2-bf95-d445bcafa07a')
ON CONFLICT DO NOTHING;

INSERT INTO food_allergen_tags ("FoodId", "AllergenKey")
VALUES
('fd000007-0000-0000-0000-000000000007', 'seafood'),
('fd000010-0000-0000-0000-000000000010', 'seafood'),
('fd000005-0000-0000-0000-000000000005', 'dairy')
ON CONFLICT DO NOTHING;

INSERT INTO favorite_foods ("UserId", "FoodId", "CreatedAt")
VALUES
('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'fd000009-0000-0000-0000-000000000009', now()),
('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'fd000002-0000-0000-0000-000000000002', now()),
('cccccccc-cccc-cccc-cccc-cccccccccccc', 'fd000010-0000-0000-0000-000000000010', now()),
('cccccccc-cccc-cccc-cccc-cccccccccccc', 'fd000007-0000-0000-0000-000000000007', now()),
('dddddddd-dddd-dddd-dddd-dddddddddddd', 'fd000001-0000-0000-0000-000000000001', now()),
('dddddddd-dddd-dddd-dddd-dddddddddddd', 'fd000010-0000-0000-0000-000000000010', now()),
('eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee', 'fd000002-0000-0000-0000-000000000002', now()),
('eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee', 'fd000004-0000-0000-0000-000000000004', now()),
('ffffffff-ffff-ffff-ffff-ffffffffffff', 'fd000004-0000-0000-0000-000000000004', now()),
('ffffffff-ffff-ffff-ffff-ffffffffffff', 'fd000009-0000-0000-0000-000000000009', now()),
('885810e8-168f-4608-a72e-e23a20dfd258', 'fd000010-0000-0000-0000-000000000010', now()),
('885810e8-168f-4608-a72e-e23a20dfd258', 'fd000001-0000-0000-0000-000000000001', now()),
('48069bd5-f29a-417d-bdeb-c00797968aca', 'fd000009-0000-0000-0000-000000000009', now()),
('48069bd5-f29a-417d-bdeb-c00797968aca', 'fd000004-0000-0000-0000-000000000004', now()),
('9afb13a5-e5a1-4342-9ce1-33bf7cc1de70', 'fd000009-0000-0000-0000-000000000009', now()),
('9afb13a5-e5a1-4342-9ce1-33bf7cc1de70', 'fd000007-0000-0000-0000-000000000007', now()),
('081b4669-b97f-4e75-b089-4c8de0151653', 'fd000004-0000-0000-0000-000000000004', now()),
('081b4669-b97f-4e75-b089-4c8de0151653', 'fd000008-0000-0000-0000-000000000008', now()),
('586209d0-d3c4-43a4-bba7-5d4c73b37bc1', 'fd000010-0000-0000-0000-000000000010', now()),
('586209d0-d3c4-43a4-bba7-5d4c73b37bc1', 'fd000005-0000-0000-0000-000000000005', now()),
('b022ccde-0aa6-4b11-bd7b-f76aaf2c2b17', 'fd000001-0000-0000-0000-000000000001', now()),
('b022ccde-0aa6-4b11-bd7b-f76aaf2c2b17', 'fd000003-0000-0000-0000-000000000003', now()),
('453681f7-f489-47ed-842c-bc3ffd220423', 'fd000007-0000-0000-0000-000000000007', now()),
('453681f7-f489-47ed-842c-bc3ffd220423', 'fd000006-0000-0000-0000-000000000006', now()),
('396f9dff-6c2a-422f-b0cc-8eb451168ed3', 'fd000005-0000-0000-0000-000000000005', now()),
('396f9dff-6c2a-422f-b0cc-8eb451168ed3', 'fd000003-0000-0000-0000-000000000003', now()),
('5dc50160-db9e-447a-ba33-9026d8800ab5', 'fd000004-0000-0000-0000-000000000004', now()),
('5dc50160-db9e-447a-ba33-9026d8800ab5', 'fd000006-0000-0000-0000-000000000006', now()),
('212ea8ea-749e-44a1-92d2-636bd617cbc8', 'fd000002-0000-0000-0000-000000000002', now()),
('212ea8ea-749e-44a1-92d2-636bd617cbc8', 'fd000010-0000-0000-0000-000000000010', now())
ON CONFLICT DO NOTHING;

INSERT INTO user_subscriptions ("Id", "UserId", "SubscriptionPlanId", "Status", "StartDate", "EndDate", "CancelledAt", "RenewedAt", "CreatedAt", "UpdatedAt")
VALUES
('97f4a742-cc44-4ab0-b2f4-bc260c245cdf', 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', '10000000-0000-0000-0000-000000000003', 'Expired', now() - interval '375 days', now() - interval '10 days', NULL, NULL, now() - interval '20 days', now() - interval '20 days'),
('5091b2d7-a9e8-41ca-ad18-407bcee846f5', 'cccccccc-cccc-cccc-cccc-cccccccccccc', '10000000-0000-0000-0000-000000000002', 'Expired', now() - interval '40 days', now() - interval '10 days', NULL, NULL, now() - interval '20 days', now() - interval '20 days'),
('5e31bbfb-1c4c-4dde-9682-41c8b22a9418', 'dddddddd-dddd-dddd-dddd-dddddddddddd', '10000000-0000-0000-0000-000000000003', 'Expired', now() - interval '375 days', now() - interval '10 days', NULL, NULL, now() - interval '20 days', now() - interval '20 days'),
('00e3373b-a66f-4ae4-acf1-873d4f21e735', 'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee', '10000000-0000-0000-0000-000000000002', 'Active', now() - interval '15 days', now() + interval '15 days', NULL, NULL, now() - interval '20 days', now() - interval '20 days'),
('5a589d0c-0879-4211-bcde-b80d8f872a2c', 'ffffffff-ffff-ffff-ffff-ffffffffffff', '10000000-0000-0000-0000-000000000003', 'Active', now() - interval '15 days', now() + interval '350 days', NULL, NULL, now() - interval '20 days', now() - interval '20 days'),
('77332cff-478c-4926-9dc4-6fd86c688d88', '885810e8-168f-4608-a72e-e23a20dfd258', '10000000-0000-0000-0000-000000000002', 'Expired', now() - interval '40 days', now() - interval '10 days', NULL, NULL, now() - interval '20 days', now() - interval '20 days'),
('4cb9db51-734f-4710-8500-9cd449938d3c', '48069bd5-f29a-417d-bdeb-c00797968aca', '10000000-0000-0000-0000-000000000003', 'Expired', now() - interval '375 days', now() - interval '10 days', NULL, NULL, now() - interval '20 days', now() - interval '20 days'),
('ca5ba96d-0c13-457f-9833-439817647424', '9afb13a5-e5a1-4342-9ce1-33bf7cc1de70', '10000000-0000-0000-0000-000000000002', 'Expired', now() - interval '40 days', now() - interval '10 days', NULL, NULL, now() - interval '20 days', now() - interval '20 days'),
('7158db3e-9416-463a-9158-c5cbdf0aa202', '081b4669-b97f-4e75-b089-4c8de0151653', '10000000-0000-0000-0000-000000000003', 'Expired', now() - interval '375 days', now() - interval '10 days', NULL, NULL, now() - interval '20 days', now() - interval '20 days'),
('137a2257-8c0b-4b56-b4fa-be8da55e7c14', '586209d0-d3c4-43a4-bba7-5d4c73b37bc1', '10000000-0000-0000-0000-000000000002', 'Active', now() - interval '15 days', now() + interval '15 days', NULL, NULL, now() - interval '20 days', now() - interval '20 days'),
('4833465b-1140-4a40-b7cd-114acaabae31', 'b022ccde-0aa6-4b11-bd7b-f76aaf2c2b17', '10000000-0000-0000-0000-000000000003', 'Expired', now() - interval '375 days', now() - interval '10 days', NULL, NULL, now() - interval '20 days', now() - interval '20 days'),
('41837cb8-7232-444c-be01-417e376de8c0', '453681f7-f489-47ed-842c-bc3ffd220423', '10000000-0000-0000-0000-000000000002', 'Expired', now() - interval '40 days', now() - interval '10 days', NULL, NULL, now() - interval '20 days', now() - interval '20 days'),
('26a8241f-a665-45c8-a083-aba9bfa8c008', '396f9dff-6c2a-422f-b0cc-8eb451168ed3', '10000000-0000-0000-0000-000000000003', 'Expired', now() - interval '375 days', now() - interval '10 days', NULL, NULL, now() - interval '20 days', now() - interval '20 days'),
('6a54cb24-29ae-49ce-b950-628c76f85fb3', '5dc50160-db9e-447a-ba33-9026d8800ab5', '10000000-0000-0000-0000-000000000002', 'Expired', now() - interval '40 days', now() - interval '10 days', NULL, NULL, now() - interval '20 days', now() - interval '20 days'),
('acbfd092-bc85-4b14-b509-d2da7f969903', '212ea8ea-749e-44a1-92d2-636bd617cbc8', '10000000-0000-0000-0000-000000000003', 'Expired', now() - interval '375 days', now() - interval '10 days', NULL, NULL, now() - interval '20 days', now() - interval '20 days')
ON CONFLICT DO NOTHING;

INSERT INTO payments ("Id", "UserId", "UserSubscriptionId", "AmountVnd", "Status", "PaymentMethod", "Provider", "ProviderOrderCode", "CreatedAt", "UpdatedAt", "ExpiredAt", "PaidAt")
VALUES
('76378876-43df-47db-88d1-1bee4c82077d', 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', '97f4a742-cc44-4ab0-b2f4-bc260c245cdf', 790000, 'PAID', 'QR_CODE', 'SEPAY', 'ORDER_76378876', now() - interval '20 days', now() - interval '20 days', NULL, now() - interval '20 days'),
('17605d97-f2f4-422b-90cc-4999a5f1fec0', 'cccccccc-cccc-cccc-cccc-cccccccccccc', '5091b2d7-a9e8-41ca-ad18-407bcee846f5', 99000, 'PAID', 'QR_CODE', 'SEPAY', 'ORDER_17605d97', now() - interval '20 days', now() - interval '20 days', NULL, now() - interval '20 days'),
('0e6db154-5c4f-435a-95e3-937ef4092015', 'dddddddd-dddd-dddd-dddd-dddddddddddd', '5e31bbfb-1c4c-4dde-9682-41c8b22a9418', 790000, 'PAID', 'QR_CODE', 'SEPAY', 'ORDER_0e6db154', now() - interval '20 days', now() - interval '20 days', NULL, now() - interval '20 days'),
('856a1f59-b430-4386-b3c9-ba5bd1ddbdd3', 'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee', '00e3373b-a66f-4ae4-acf1-873d4f21e735', 99000, 'PAID', 'QR_CODE', 'SEPAY', 'ORDER_856a1f59', now() - interval '20 days', now() - interval '20 days', NULL, now() - interval '20 days'),
('f30d1b92-6926-433f-b4c8-d2cbfd559dc6', 'ffffffff-ffff-ffff-ffff-ffffffffffff', '5a589d0c-0879-4211-bcde-b80d8f872a2c', 790000, 'PAID', 'QR_CODE', 'SEPAY', 'ORDER_f30d1b92', now() - interval '20 days', now() - interval '20 days', NULL, now() - interval '20 days'),
('ca3479ca-26f1-44db-a245-80371e7e2ce1', '885810e8-168f-4608-a72e-e23a20dfd258', '77332cff-478c-4926-9dc4-6fd86c688d88', 99000, 'PAID', 'QR_CODE', 'SEPAY', 'ORDER_ca3479ca', now() - interval '20 days', now() - interval '20 days', NULL, now() - interval '20 days'),
('b771fc44-c0d1-4175-af76-49e5ff5d64fb', '48069bd5-f29a-417d-bdeb-c00797968aca', '4cb9db51-734f-4710-8500-9cd449938d3c', 790000, 'PAID', 'QR_CODE', 'SEPAY', 'ORDER_b771fc44', now() - interval '20 days', now() - interval '20 days', NULL, now() - interval '20 days'),
('e2ae9d11-6e00-4f88-9b37-a5f5d3c0d5df', '9afb13a5-e5a1-4342-9ce1-33bf7cc1de70', 'ca5ba96d-0c13-457f-9833-439817647424', 99000, 'PAID', 'QR_CODE', 'SEPAY', 'ORDER_e2ae9d11', now() - interval '20 days', now() - interval '20 days', NULL, now() - interval '20 days'),
('9236bd02-6f32-44b1-80a6-df311178ea2b', '081b4669-b97f-4e75-b089-4c8de0151653', '7158db3e-9416-463a-9158-c5cbdf0aa202', 790000, 'PAID', 'QR_CODE', 'SEPAY', 'ORDER_9236bd02', now() - interval '20 days', now() - interval '20 days', NULL, now() - interval '20 days'),
('cca940d2-f4ad-432b-b6b2-99c504fb71f5', '586209d0-d3c4-43a4-bba7-5d4c73b37bc1', '137a2257-8c0b-4b56-b4fa-be8da55e7c14', 99000, 'PAID', 'QR_CODE', 'SEPAY', 'ORDER_cca940d2', now() - interval '20 days', now() - interval '20 days', NULL, now() - interval '20 days'),
('ee658c09-f558-4414-a659-c113b55f4125', 'b022ccde-0aa6-4b11-bd7b-f76aaf2c2b17', '4833465b-1140-4a40-b7cd-114acaabae31', 790000, 'PAID', 'QR_CODE', 'SEPAY', 'ORDER_ee658c09', now() - interval '20 days', now() - interval '20 days', NULL, now() - interval '20 days'),
('aeb230f1-5560-4e4d-b462-4c704843cdb7', '453681f7-f489-47ed-842c-bc3ffd220423', '41837cb8-7232-444c-be01-417e376de8c0', 99000, 'PAID', 'QR_CODE', 'SEPAY', 'ORDER_aeb230f1', now() - interval '20 days', now() - interval '20 days', NULL, now() - interval '20 days'),
('5cf0a99a-134f-45a1-9fae-55dee3227308', '396f9dff-6c2a-422f-b0cc-8eb451168ed3', '26a8241f-a665-45c8-a083-aba9bfa8c008', 790000, 'PAID', 'QR_CODE', 'SEPAY', 'ORDER_5cf0a99a', now() - interval '20 days', now() - interval '20 days', NULL, now() - interval '20 days'),
('482b0243-65d5-4eae-adf6-5b5b04452fd7', '5dc50160-db9e-447a-ba33-9026d8800ab5', '6a54cb24-29ae-49ce-b950-628c76f85fb3', 99000, 'PAID', 'QR_CODE', 'SEPAY', 'ORDER_482b0243', now() - interval '20 days', now() - interval '20 days', NULL, now() - interval '20 days'),
('a8bccf2c-d4cb-4a4b-b6d2-7713d38ca525', '212ea8ea-749e-44a1-92d2-636bd617cbc8', 'acbfd092-bc85-4b14-b509-d2da7f969903', 790000, 'PAID', 'QR_CODE', 'SEPAY', 'ORDER_a8bccf2c', now() - interval '20 days', now() - interval '20 days', NULL, now() - interval '20 days')
ON CONFLICT DO NOTHING;

INSERT INTO sepay_transactions ("Id", "PaymentId", "TransactionCode", "BankAccount", "TransferAmount", "TransferContent", "TransactionTime", "Status", "RawPayloadJson", "CreatedAt")
VALUES
('65ec6d7b-e59e-43ea-b97d-5c7852d91594', '76378876-43df-47db-88d1-1bee4c82077d', 'TXN_65ec6d7b', '999999999999', 790000, 'MG Topup 76378876', now() - interval '20 days', 'Success', '{}', now() - interval '20 days'),
('42eda18f-cd4b-4721-b56c-6c6f6bb8607a', '17605d97-f2f4-422b-90cc-4999a5f1fec0', 'TXN_42eda18f', '999999999999', 99000, 'MG Topup 17605d97', now() - interval '20 days', 'Success', '{}', now() - interval '20 days'),
('f04401b7-b994-4d4f-8b30-75b9b238e742', '0e6db154-5c4f-435a-95e3-937ef4092015', 'TXN_f04401b7', '999999999999', 790000, 'MG Topup 0e6db154', now() - interval '20 days', 'Success', '{}', now() - interval '20 days'),
('efe19b9b-14e2-428d-b524-6ed5ad983122', '856a1f59-b430-4386-b3c9-ba5bd1ddbdd3', 'TXN_efe19b9b', '999999999999', 99000, 'MG Topup 856a1f59', now() - interval '20 days', 'Success', '{}', now() - interval '20 days'),
('f46f1cae-d7f7-449f-9860-489636d27f30', 'f30d1b92-6926-433f-b4c8-d2cbfd559dc6', 'TXN_f46f1cae', '999999999999', 790000, 'MG Topup f30d1b92', now() - interval '20 days', 'Success', '{}', now() - interval '20 days'),
('f5f2cb80-6287-42d4-8757-e621da4025fe', 'ca3479ca-26f1-44db-a245-80371e7e2ce1', 'TXN_f5f2cb80', '999999999999', 99000, 'MG Topup ca3479ca', now() - interval '20 days', 'Success', '{}', now() - interval '20 days'),
('f573a4c2-1ca2-4fe2-905f-60aa94ab9787', 'b771fc44-c0d1-4175-af76-49e5ff5d64fb', 'TXN_f573a4c2', '999999999999', 790000, 'MG Topup b771fc44', now() - interval '20 days', 'Success', '{}', now() - interval '20 days'),
('abfe012f-314a-4053-a9f9-b35818ebb763', 'e2ae9d11-6e00-4f88-9b37-a5f5d3c0d5df', 'TXN_abfe012f', '999999999999', 99000, 'MG Topup e2ae9d11', now() - interval '20 days', 'Success', '{}', now() - interval '20 days'),
('b19bd645-e94d-45fb-a9aa-cbfd92124a37', '9236bd02-6f32-44b1-80a6-df311178ea2b', 'TXN_b19bd645', '999999999999', 790000, 'MG Topup 9236bd02', now() - interval '20 days', 'Success', '{}', now() - interval '20 days'),
('bd307c47-8151-4378-873d-490ffa990d0f', 'cca940d2-f4ad-432b-b6b2-99c504fb71f5', 'TXN_bd307c47', '999999999999', 99000, 'MG Topup cca940d2', now() - interval '20 days', 'Success', '{}', now() - interval '20 days'),
('a54ca10a-d773-4d99-a7b1-c806c94140c9', 'ee658c09-f558-4414-a659-c113b55f4125', 'TXN_a54ca10a', '999999999999', 790000, 'MG Topup ee658c09', now() - interval '20 days', 'Success', '{}', now() - interval '20 days'),
('b7ac0a16-995c-46b3-b5fa-58a0ab19cc3a', 'aeb230f1-5560-4e4d-b462-4c704843cdb7', 'TXN_b7ac0a16', '999999999999', 99000, 'MG Topup aeb230f1', now() - interval '20 days', 'Success', '{}', now() - interval '20 days'),
('30da5403-52ee-47ef-b5bc-1595838f82e2', '5cf0a99a-134f-45a1-9fae-55dee3227308', 'TXN_30da5403', '999999999999', 790000, 'MG Topup 5cf0a99a', now() - interval '20 days', 'Success', '{}', now() - interval '20 days'),
('b2b334c2-9325-4838-b702-d7c1563f548c', '482b0243-65d5-4eae-adf6-5b5b04452fd7', 'TXN_b2b334c2', '999999999999', 99000, 'MG Topup 482b0243', now() - interval '20 days', 'Success', '{}', now() - interval '20 days'),
('3f1933e0-45f2-472d-8567-9b9b9419937f', 'a8bccf2c-d4cb-4a4b-b6d2-7713d38ca525', 'TXN_3f1933e0', '999999999999', 790000, 'MG Topup a8bccf2c', now() - interval '20 days', 'Success', '{}', now() - interval '20 days')
ON CONFLICT DO NOTHING;

INSERT INTO subscription_transactions ("Id", "UserId", "UserSubscriptionId", "TransactionType", "Amount", "Status", "Note", "TransactionDate", "CreatedAt")
VALUES
('23291296-f6d4-431f-badf-71bdbff7a3bc', 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', '97f4a742-cc44-4ab0-b2f4-bc260c245cdf', 'Subscribe', 790000, 'Success', 'Đăng ký dịch vụ MenuGreen Pro', now() - interval '20 days', now() - interval '20 days'),
('530d090a-5287-43f9-8c28-f41fcd2533d0', 'cccccccc-cccc-cccc-cccc-cccccccccccc', '5091b2d7-a9e8-41ca-ad18-407bcee846f5', 'Subscribe', 99000, 'Success', 'Đăng ký dịch vụ MenuGreen Pro', now() - interval '20 days', now() - interval '20 days'),
('743dce5d-4a76-4b8c-be53-f6e55e9695b8', 'dddddddd-dddd-dddd-dddd-dddddddddddd', '5e31bbfb-1c4c-4dde-9682-41c8b22a9418', 'Subscribe', 790000, 'Success', 'Đăng ký dịch vụ MenuGreen Pro', now() - interval '20 days', now() - interval '20 days'),
('a8bc09b6-e68b-4e9c-8edc-6f180b309cfe', 'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee', '00e3373b-a66f-4ae4-acf1-873d4f21e735', 'Subscribe', 99000, 'Success', 'Đăng ký dịch vụ MenuGreen Pro', now() - interval '20 days', now() - interval '20 days'),
('68b6e8a8-f11b-476f-ab1b-a690dc51d60b', 'ffffffff-ffff-ffff-ffff-ffffffffffff', '5a589d0c-0879-4211-bcde-b80d8f872a2c', 'Subscribe', 790000, 'Success', 'Đăng ký dịch vụ MenuGreen Pro', now() - interval '20 days', now() - interval '20 days'),
('0e06b7fb-fe45-4a7b-8dec-22d814b89813', '885810e8-168f-4608-a72e-e23a20dfd258', '77332cff-478c-4926-9dc4-6fd86c688d88', 'Subscribe', 99000, 'Success', 'Đăng ký dịch vụ MenuGreen Pro', now() - interval '20 days', now() - interval '20 days'),
('2a38dfc4-a650-4f06-9b5a-80b64a069b16', '48069bd5-f29a-417d-bdeb-c00797968aca', '4cb9db51-734f-4710-8500-9cd449938d3c', 'Subscribe', 790000, 'Success', 'Đăng ký dịch vụ MenuGreen Pro', now() - interval '20 days', now() - interval '20 days'),
('685695b8-f04b-4d98-a58b-2eff5e1c115e', '9afb13a5-e5a1-4342-9ce1-33bf7cc1de70', 'ca5ba96d-0c13-457f-9833-439817647424', 'Subscribe', 99000, 'Success', 'Đăng ký dịch vụ MenuGreen Pro', now() - interval '20 days', now() - interval '20 days'),
('736e7b4f-642d-4b7a-a398-482d02f777c8', '081b4669-b97f-4e75-b089-4c8de0151653', '7158db3e-9416-463a-9158-c5cbdf0aa202', 'Subscribe', 790000, 'Success', 'Đăng ký dịch vụ MenuGreen Pro', now() - interval '20 days', now() - interval '20 days'),
('408cf856-c323-46ec-9577-2349181d9b59', '586209d0-d3c4-43a4-bba7-5d4c73b37bc1', '137a2257-8c0b-4b56-b4fa-be8da55e7c14', 'Subscribe', 99000, 'Success', 'Đăng ký dịch vụ MenuGreen Pro', now() - interval '20 days', now() - interval '20 days'),
('445a54b7-a6df-4f5d-bb47-4b222c8cab9f', 'b022ccde-0aa6-4b11-bd7b-f76aaf2c2b17', '4833465b-1140-4a40-b7cd-114acaabae31', 'Subscribe', 790000, 'Success', 'Đăng ký dịch vụ MenuGreen Pro', now() - interval '20 days', now() - interval '20 days'),
('814830ad-6df6-4b15-a5aa-a196cff97538', '453681f7-f489-47ed-842c-bc3ffd220423', '41837cb8-7232-444c-be01-417e376de8c0', 'Subscribe', 99000, 'Success', 'Đăng ký dịch vụ MenuGreen Pro', now() - interval '20 days', now() - interval '20 days'),
('870646a4-f4e7-47ea-a524-1c16c74403c6', '396f9dff-6c2a-422f-b0cc-8eb451168ed3', '26a8241f-a665-45c8-a083-aba9bfa8c008', 'Subscribe', 790000, 'Success', 'Đăng ký dịch vụ MenuGreen Pro', now() - interval '20 days', now() - interval '20 days'),
('14a337a9-d36b-4e6e-a468-7a4bd43a872a', '5dc50160-db9e-447a-ba33-9026d8800ab5', '6a54cb24-29ae-49ce-b950-628c76f85fb3', 'Subscribe', 99000, 'Success', 'Đăng ký dịch vụ MenuGreen Pro', now() - interval '20 days', now() - interval '20 days'),
('48120f28-e30a-4c75-b0e4-a3b075e7b0dc', '212ea8ea-749e-44a1-92d2-636bd617cbc8', 'acbfd092-bc85-4b14-b509-d2da7f969903', 'Subscribe', 790000, 'Success', 'Đăng ký dịch vụ MenuGreen Pro', now() - interval '20 days', now() - interval '20 days')
ON CONFLICT DO NOTHING;

INSERT INTO meal_plan_headers ("Id", "UserId", "Title", "PlanType", "StartDate", "EndDate", "TargetCalories", "GeneratedBy", "IsActive", "CreatedAt", "UpdatedAt")
VALUES
('f22fed1c-b548-4fc7-a4db-9dc571e61d74', 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'Kế hoạch dinh dưỡng tuần mới', 'WEEKLY', CURRENT_DATE, CURRENT_DATE + 7, 1800, 'AI', true, now(), now()),
('d677be5c-3bf9-45a0-838e-be2013c93934', 'cccccccc-cccc-cccc-cccc-cccccccccccc', 'Kế hoạch dinh dưỡng tuần mới', 'WEEKLY', CURRENT_DATE, CURRENT_DATE + 7, 1800, 'AI', true, now(), now()),
('dacdeef2-185a-49e1-8d10-aae4d507cb22', 'dddddddd-dddd-dddd-dddd-dddddddddddd', 'Kế hoạch dinh dưỡng tuần mới', 'WEEKLY', CURRENT_DATE, CURRENT_DATE + 7, 1800, 'AI', true, now(), now()),
('e95a2ac3-cbb8-427b-b433-3de2ea447729', 'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee', 'Kế hoạch dinh dưỡng tuần mới', 'WEEKLY', CURRENT_DATE, CURRENT_DATE + 7, 1800, 'AI', true, now(), now()),
('ee8bb747-45d4-41bf-a522-2384ef74e18c', 'ffffffff-ffff-ffff-ffff-ffffffffffff', 'Kế hoạch dinh dưỡng tuần mới', 'WEEKLY', CURRENT_DATE, CURRENT_DATE + 7, 1800, 'AI', true, now(), now()),
('43bd57bf-06ff-4391-a8f1-202e9248e7ed', '885810e8-168f-4608-a72e-e23a20dfd258', 'Kế hoạch dinh dưỡng tuần mới', 'WEEKLY', CURRENT_DATE, CURRENT_DATE + 7, 1800, 'AI', true, now(), now()),
('128cae5c-6edc-4ea3-b8ac-af67c4952f6e', '48069bd5-f29a-417d-bdeb-c00797968aca', 'Kế hoạch dinh dưỡng tuần mới', 'WEEKLY', CURRENT_DATE, CURRENT_DATE + 7, 1800, 'AI', true, now(), now()),
('44c0c107-5c01-4dc9-8cfc-e69a50ec83d7', '9afb13a5-e5a1-4342-9ce1-33bf7cc1de70', 'Kế hoạch dinh dưỡng tuần mới', 'WEEKLY', CURRENT_DATE, CURRENT_DATE + 7, 1800, 'AI', true, now(), now()),
('c1b905f7-c948-4506-87b3-cb1f359e9cbc', '081b4669-b97f-4e75-b089-4c8de0151653', 'Kế hoạch dinh dưỡng tuần mới', 'WEEKLY', CURRENT_DATE, CURRENT_DATE + 7, 1800, 'AI', true, now(), now()),
('07fbdd58-1b92-441b-ad7d-1f01c9cf1e63', '586209d0-d3c4-43a4-bba7-5d4c73b37bc1', 'Kế hoạch dinh dưỡng tuần mới', 'WEEKLY', CURRENT_DATE, CURRENT_DATE + 7, 1800, 'AI', true, now(), now()),
('457cbba7-31e6-4e56-8073-5e8067640cdc', 'b022ccde-0aa6-4b11-bd7b-f76aaf2c2b17', 'Kế hoạch dinh dưỡng tuần mới', 'WEEKLY', CURRENT_DATE, CURRENT_DATE + 7, 1800, 'AI', true, now(), now()),
('d67fd2c9-bb6b-4216-a5eb-c62b189285d0', '453681f7-f489-47ed-842c-bc3ffd220423', 'Kế hoạch dinh dưỡng tuần mới', 'WEEKLY', CURRENT_DATE, CURRENT_DATE + 7, 1800, 'AI', true, now(), now()),
('471293e8-4b51-413c-a739-9aabc9cdfbc9', '396f9dff-6c2a-422f-b0cc-8eb451168ed3', 'Kế hoạch dinh dưỡng tuần mới', 'WEEKLY', CURRENT_DATE, CURRENT_DATE + 7, 1800, 'AI', true, now(), now()),
('ed136f5e-f381-4e17-8aa7-5db67bd34146', '5dc50160-db9e-447a-ba33-9026d8800ab5', 'Kế hoạch dinh dưỡng tuần mới', 'WEEKLY', CURRENT_DATE, CURRENT_DATE + 7, 1800, 'AI', true, now(), now()),
('401f123d-9dc9-40dd-ad44-11dea7dfbe3a', '212ea8ea-749e-44a1-92d2-636bd617cbc8', 'Kế hoạch dinh dưỡng tuần mới', 'WEEKLY', CURRENT_DATE, CURRENT_DATE + 7, 1800, 'AI', true, now(), now())
ON CONFLICT DO NOTHING;

INSERT INTO meal_plan_items ("Id", "MealPlanId", "MealType", "FoodId", "RecipeId", "PlannedDate", "ScheduledTime", "TargetCalories", "IsCompleted", "CreatedAt")
VALUES
('cae386dd-3682-4e12-82a0-537df7a6461d', 'f22fed1c-b548-4fc7-a4db-9dc571e61d74', 'Breakfast', 'fd000007-0000-0000-0000-000000000007', 'ec000001-0000-0000-0000-000000000001', CURRENT_DATE + 0, '07:30:00', 500, true, now()),
('496e0876-eac2-4aec-8ef0-fb863a41c1f1', 'f22fed1c-b548-4fc7-a4db-9dc571e61d74', 'Lunch', 'fd000006-0000-0000-0000-000000000006', 'ec000003-0000-0000-0000-000000000003', CURRENT_DATE + 0, '12:15:00', 350, true, now()),
('98be5f68-6bb1-4c19-908f-745fa52f36f4', 'f22fed1c-b548-4fc7-a4db-9dc571e61d74', 'Dinner', 'fd000008-0000-0000-0000-000000000008', 'ec000001-0000-0000-0000-000000000001', CURRENT_DATE + 0, '18:45:00', 600, true, now()),
('2998664a-4d21-49dd-a120-09d93f2c1321', 'f22fed1c-b548-4fc7-a4db-9dc571e61d74', 'Breakfast', 'fd000002-0000-0000-0000-000000000002', 'ec000003-0000-0000-0000-000000000003', CURRENT_DATE + 1, '07:30:00', 500, false, now()),
('8c28e177-d9b6-4b14-889d-700469857ebe', 'f22fed1c-b548-4fc7-a4db-9dc571e61d74', 'Lunch', 'fd000010-0000-0000-0000-000000000010', 'ec000002-0000-0000-0000-000000000002', CURRENT_DATE + 1, '12:15:00', 350, false, now()),
('d93038c9-5916-4548-a071-de3a43aaec9a', 'f22fed1c-b548-4fc7-a4db-9dc571e61d74', 'Dinner', 'fd000001-0000-0000-0000-000000000001', 'ec000002-0000-0000-0000-000000000002', CURRENT_DATE + 1, '18:45:00', 500, false, now()),
('a09a952b-d542-4759-883e-82e1b022fb20', 'f22fed1c-b548-4fc7-a4db-9dc571e61d74', 'Breakfast', 'fd000002-0000-0000-0000-000000000002', 'ec000002-0000-0000-0000-000000000002', CURRENT_DATE + 2, '07:30:00', 350, false, now()),
('da7f794b-c7ea-46cd-9e24-0aab3ab95c32', 'f22fed1c-b548-4fc7-a4db-9dc571e61d74', 'Lunch', 'fd000007-0000-0000-0000-000000000007', 'ec000003-0000-0000-0000-000000000003', CURRENT_DATE + 2, '12:15:00', 600, false, now()),
('40e6098e-0965-4ed6-9f4b-1523052eb537', 'f22fed1c-b548-4fc7-a4db-9dc571e61d74', 'Dinner', 'fd000006-0000-0000-0000-000000000006', 'ec000002-0000-0000-0000-000000000002', CURRENT_DATE + 2, '18:45:00', 500, false, now()),
('3129c616-6f77-4fca-909b-c17df3f72f6f', 'd677be5c-3bf9-45a0-838e-be2013c93934', 'Breakfast', 'fd000006-0000-0000-0000-000000000006', 'ec000002-0000-0000-0000-000000000002', CURRENT_DATE + 0, '07:30:00', 500, true, now()),
('918621f6-1517-4cc1-9a7b-c20bbb021d09', 'd677be5c-3bf9-45a0-838e-be2013c93934', 'Lunch', 'fd000002-0000-0000-0000-000000000002', 'ec000002-0000-0000-0000-000000000002', CURRENT_DATE + 0, '12:15:00', 400, true, now()),
('1533c53c-17bb-42e4-b70b-b1c2260a9f91', 'd677be5c-3bf9-45a0-838e-be2013c93934', 'Dinner', 'fd000003-0000-0000-0000-000000000003', 'ec000004-0000-0000-0000-000000000004', CURRENT_DATE + 0, '18:45:00', 600, true, now()),
('12dcc145-28d9-4d50-b7ab-090f3bb48df5', 'd677be5c-3bf9-45a0-838e-be2013c93934', 'Breakfast', 'fd000005-0000-0000-0000-000000000005', 'ec000002-0000-0000-0000-000000000002', CURRENT_DATE + 1, '07:30:00', 500, false, now()),
('65db8028-ba8d-47ed-a21b-9f053281d0aa', 'd677be5c-3bf9-45a0-838e-be2013c93934', 'Lunch', 'fd000001-0000-0000-0000-000000000001', 'ec000002-0000-0000-0000-000000000002', CURRENT_DATE + 1, '12:15:00', 350, false, now()),
('fdbe131b-8843-4772-ba88-3f37a6322ee5', 'd677be5c-3bf9-45a0-838e-be2013c93934', 'Dinner', 'fd000006-0000-0000-0000-000000000006', 'ec000004-0000-0000-0000-000000000004', CURRENT_DATE + 1, '18:45:00', 500, false, now()),
('3a472f2e-76e2-4b9e-a6ef-f1547d6b393f', 'd677be5c-3bf9-45a0-838e-be2013c93934', 'Breakfast', 'fd000002-0000-0000-0000-000000000002', 'ec000002-0000-0000-0000-000000000002', CURRENT_DATE + 2, '07:30:00', 500, false, now()),
('7d506de9-4743-444d-94bb-3b5b44736420', 'd677be5c-3bf9-45a0-838e-be2013c93934', 'Lunch', 'fd000004-0000-0000-0000-000000000004', 'ec000004-0000-0000-0000-000000000004', CURRENT_DATE + 2, '12:15:00', 600, false, now()),
('8609f975-5532-4a05-9b1e-27b3a8089d11', 'd677be5c-3bf9-45a0-838e-be2013c93934', 'Dinner', 'fd000008-0000-0000-0000-000000000008', 'ec000002-0000-0000-0000-000000000002', CURRENT_DATE + 2, '18:45:00', 500, false, now()),
('f7d7775e-a2e6-4da6-a2ec-a3b641f56761', 'dacdeef2-185a-49e1-8d10-aae4d507cb22', 'Breakfast', 'fd000003-0000-0000-0000-000000000003', 'ec000002-0000-0000-0000-000000000002', CURRENT_DATE + 0, '07:30:00', 500, true, now()),
('05e5225c-5f48-4a4b-b0ee-b399cd9c0081', 'dacdeef2-185a-49e1-8d10-aae4d507cb22', 'Lunch', 'fd000010-0000-0000-0000-000000000010', 'ec000004-0000-0000-0000-000000000004', CURRENT_DATE + 0, '12:15:00', 600, true, now()),
('ab28e85c-93b9-4c7d-9312-26b1c64fb94e', 'dacdeef2-185a-49e1-8d10-aae4d507cb22', 'Dinner', 'fd000006-0000-0000-0000-000000000006', 'ec000002-0000-0000-0000-000000000002', CURRENT_DATE + 0, '18:45:00', 400, true, now()),
('3aa65285-5680-4ed8-bcc9-5ad621689b57', 'dacdeef2-185a-49e1-8d10-aae4d507cb22', 'Breakfast', 'fd000009-0000-0000-0000-000000000009', 'ec000004-0000-0000-0000-000000000004', CURRENT_DATE + 1, '07:30:00', 350, false, now()),
('24c2ed3c-0f22-4501-ae3c-b0a5fffc3cee', 'dacdeef2-185a-49e1-8d10-aae4d507cb22', 'Lunch', 'fd000001-0000-0000-0000-000000000001', 'ec000001-0000-0000-0000-000000000001', CURRENT_DATE + 1, '12:15:00', 400, false, now()),
('05a63a0d-e555-45a8-9e45-cb1021507615', 'dacdeef2-185a-49e1-8d10-aae4d507cb22', 'Dinner', 'fd000003-0000-0000-0000-000000000003', 'ec000004-0000-0000-0000-000000000004', CURRENT_DATE + 1, '18:45:00', 350, false, now()),
('067ca491-a62a-4c3d-b401-882b7225d895', 'dacdeef2-185a-49e1-8d10-aae4d507cb22', 'Breakfast', 'fd000007-0000-0000-0000-000000000007', 'ec000004-0000-0000-0000-000000000004', CURRENT_DATE + 2, '07:30:00', 600, false, now()),
('683d8e7a-9747-4330-b48c-4c2eb82834f9', 'dacdeef2-185a-49e1-8d10-aae4d507cb22', 'Lunch', 'fd000009-0000-0000-0000-000000000009', 'ec000003-0000-0000-0000-000000000003', CURRENT_DATE + 2, '12:15:00', 350, false, now()),
('7828b2b2-37a7-4940-9a7a-6fa45aa5c610', 'dacdeef2-185a-49e1-8d10-aae4d507cb22', 'Dinner', 'fd000002-0000-0000-0000-000000000002', 'ec000003-0000-0000-0000-000000000003', CURRENT_DATE + 2, '18:45:00', 500, false, now()),
('95e7b8fc-3051-4a7f-b33c-4aca7727726d', 'e95a2ac3-cbb8-427b-b433-3de2ea447729', 'Breakfast', 'fd000002-0000-0000-0000-000000000002', 'ec000003-0000-0000-0000-000000000003', CURRENT_DATE + 0, '07:30:00', 600, true, now()),
('cba430c5-a02e-4ad7-84e7-d29631df8526', 'e95a2ac3-cbb8-427b-b433-3de2ea447729', 'Lunch', 'fd000003-0000-0000-0000-000000000003', 'ec000004-0000-0000-0000-000000000004', CURRENT_DATE + 0, '12:15:00', 350, true, now()),
('ce525092-9ac2-4f6b-9c08-129cf004507e', 'e95a2ac3-cbb8-427b-b433-3de2ea447729', 'Dinner', 'fd000005-0000-0000-0000-000000000005', 'ec000002-0000-0000-0000-000000000002', CURRENT_DATE + 0, '18:45:00', 350, true, now()),
('3da72573-3313-4397-b85b-44ec46a4cbbf', 'e95a2ac3-cbb8-427b-b433-3de2ea447729', 'Breakfast', 'fd000005-0000-0000-0000-000000000005', 'ec000002-0000-0000-0000-000000000002', CURRENT_DATE + 1, '07:30:00', 400, false, now()),
('c7f33105-d6f7-41af-90cc-36c288f28815', 'e95a2ac3-cbb8-427b-b433-3de2ea447729', 'Lunch', 'fd000006-0000-0000-0000-000000000006', 'ec000002-0000-0000-0000-000000000002', CURRENT_DATE + 1, '12:15:00', 350, false, now()),
('3136ea85-2a44-447f-8aa5-72049d695819', 'e95a2ac3-cbb8-427b-b433-3de2ea447729', 'Dinner', 'fd000010-0000-0000-0000-000000000010', 'ec000003-0000-0000-0000-000000000003', CURRENT_DATE + 1, '18:45:00', 600, false, now()),
('4f5b231a-f5e7-4746-9f5d-921ece680c1d', 'e95a2ac3-cbb8-427b-b433-3de2ea447729', 'Breakfast', 'fd000001-0000-0000-0000-000000000001', 'ec000001-0000-0000-0000-000000000001', CURRENT_DATE + 2, '07:30:00', 500, false, now()),
('f10770d1-d3b6-4984-bd5a-942f5ea1cd90', 'e95a2ac3-cbb8-427b-b433-3de2ea447729', 'Lunch', 'fd000005-0000-0000-0000-000000000005', 'ec000002-0000-0000-0000-000000000002', CURRENT_DATE + 2, '12:15:00', 350, false, now()),
('0a17b146-56f6-4c63-8809-33ea23bb61db', 'e95a2ac3-cbb8-427b-b433-3de2ea447729', 'Dinner', 'fd000004-0000-0000-0000-000000000004', 'ec000001-0000-0000-0000-000000000001', CURRENT_DATE + 2, '18:45:00', 350, false, now()),
('178fb812-9921-4a65-b10b-8c175d52fa02', 'ee8bb747-45d4-41bf-a522-2384ef74e18c', 'Breakfast', 'fd000008-0000-0000-0000-000000000008', 'ec000001-0000-0000-0000-000000000001', CURRENT_DATE + 0, '07:30:00', 400, true, now()),
('2d55c496-b1de-40a1-bfe8-6fc56f49ffa5', 'ee8bb747-45d4-41bf-a522-2384ef74e18c', 'Lunch', 'fd000003-0000-0000-0000-000000000003', 'ec000004-0000-0000-0000-000000000004', CURRENT_DATE + 0, '12:15:00', 400, true, now()),
('40e52a8b-a475-4020-bec8-922f6e7d3208', 'ee8bb747-45d4-41bf-a522-2384ef74e18c', 'Dinner', 'fd000005-0000-0000-0000-000000000005', 'ec000004-0000-0000-0000-000000000004', CURRENT_DATE + 0, '18:45:00', 400, true, now()),
('cba65c4b-aa8e-45bb-a042-e6c55e6f2894', 'ee8bb747-45d4-41bf-a522-2384ef74e18c', 'Breakfast', 'fd000009-0000-0000-0000-000000000009', 'ec000002-0000-0000-0000-000000000002', CURRENT_DATE + 1, '07:30:00', 500, false, now()),
('dc4c8f51-c934-4393-81a9-5da4bf1c925f', 'ee8bb747-45d4-41bf-a522-2384ef74e18c', 'Lunch', 'fd000007-0000-0000-0000-000000000007', 'ec000003-0000-0000-0000-000000000003', CURRENT_DATE + 1, '12:15:00', 600, false, now()),
('ec822338-47ba-43de-abba-eba940f4d70b', 'ee8bb747-45d4-41bf-a522-2384ef74e18c', 'Dinner', 'fd000009-0000-0000-0000-000000000009', 'ec000004-0000-0000-0000-000000000004', CURRENT_DATE + 1, '18:45:00', 350, false, now()),
('c6a85d88-3e56-4d6d-99bb-588bb0044b74', 'ee8bb747-45d4-41bf-a522-2384ef74e18c', 'Breakfast', 'fd000004-0000-0000-0000-000000000004', 'ec000002-0000-0000-0000-000000000002', CURRENT_DATE + 2, '07:30:00', 350, false, now()),
('cfdfcc13-ed10-49d5-b39d-6ee4d2c3e2da', 'ee8bb747-45d4-41bf-a522-2384ef74e18c', 'Lunch', 'fd000006-0000-0000-0000-000000000006', 'ec000001-0000-0000-0000-000000000001', CURRENT_DATE + 2, '12:15:00', 400, false, now()),
('35c1c5da-db91-4be5-ba1f-becacc9338f6', 'ee8bb747-45d4-41bf-a522-2384ef74e18c', 'Dinner', 'fd000010-0000-0000-0000-000000000010', 'ec000002-0000-0000-0000-000000000002', CURRENT_DATE + 2, '18:45:00', 350, false, now()),
('9b19fc5d-740e-476d-a4f6-9db689998771', '43bd57bf-06ff-4391-a8f1-202e9248e7ed', 'Breakfast', 'fd000002-0000-0000-0000-000000000002', 'ec000001-0000-0000-0000-000000000001', CURRENT_DATE + 0, '07:30:00', 400, true, now()),
('2371f190-fba3-4f26-8d83-77b6fc2b37f5', '43bd57bf-06ff-4391-a8f1-202e9248e7ed', 'Lunch', 'fd000002-0000-0000-0000-000000000002', 'ec000001-0000-0000-0000-000000000001', CURRENT_DATE + 0, '12:15:00', 500, true, now()),
('5f31dd3b-bc14-409e-b4b9-f9ed00f672f7', '43bd57bf-06ff-4391-a8f1-202e9248e7ed', 'Dinner', 'fd000002-0000-0000-0000-000000000002', 'ec000002-0000-0000-0000-000000000002', CURRENT_DATE + 0, '18:45:00', 500, true, now()),
('00fb8984-5670-4397-81c4-d6ebb05c3a32', '43bd57bf-06ff-4391-a8f1-202e9248e7ed', 'Breakfast', 'fd000008-0000-0000-0000-000000000008', 'ec000002-0000-0000-0000-000000000002', CURRENT_DATE + 1, '07:30:00', 400, false, now()),
('010d83d8-a504-4a41-b4c3-7b0df10921d0', '43bd57bf-06ff-4391-a8f1-202e9248e7ed', 'Lunch', 'fd000010-0000-0000-0000-000000000010', 'ec000004-0000-0000-0000-000000000004', CURRENT_DATE + 1, '12:15:00', 400, false, now()),
('2e596cbe-caa5-4d95-b4a9-151b426f2a3c', '43bd57bf-06ff-4391-a8f1-202e9248e7ed', 'Dinner', 'fd000008-0000-0000-0000-000000000008', 'ec000004-0000-0000-0000-000000000004', CURRENT_DATE + 1, '18:45:00', 400, false, now()),
('b5114f37-91fc-443d-84af-0ad9fb79ad7f', '43bd57bf-06ff-4391-a8f1-202e9248e7ed', 'Breakfast', 'fd000002-0000-0000-0000-000000000002', 'ec000001-0000-0000-0000-000000000001', CURRENT_DATE + 2, '07:30:00', 600, false, now()),
('73d25588-e46f-4afb-a046-97cc4986d753', '43bd57bf-06ff-4391-a8f1-202e9248e7ed', 'Lunch', 'fd000006-0000-0000-0000-000000000006', 'ec000004-0000-0000-0000-000000000004', CURRENT_DATE + 2, '12:15:00', 600, false, now()),
('8f1ac6ab-d020-4137-8513-63fe70fc7bda', '43bd57bf-06ff-4391-a8f1-202e9248e7ed', 'Dinner', 'fd000008-0000-0000-0000-000000000008', 'ec000001-0000-0000-0000-000000000001', CURRENT_DATE + 2, '18:45:00', 350, false, now()),
('c2028113-b470-4ce2-b9b2-93108510b3ab', '128cae5c-6edc-4ea3-b8ac-af67c4952f6e', 'Breakfast', 'fd000001-0000-0000-0000-000000000001', 'ec000004-0000-0000-0000-000000000004', CURRENT_DATE + 0, '07:30:00', 500, true, now()),
('0ff80d36-29da-4286-84e0-08646f0e3b50', '128cae5c-6edc-4ea3-b8ac-af67c4952f6e', 'Lunch', 'fd000002-0000-0000-0000-000000000002', 'ec000002-0000-0000-0000-000000000002', CURRENT_DATE + 0, '12:15:00', 400, true, now()),
('017e17e4-4fb0-44e9-aed8-f751ef928a1e', '128cae5c-6edc-4ea3-b8ac-af67c4952f6e', 'Dinner', 'fd000004-0000-0000-0000-000000000004', 'ec000004-0000-0000-0000-000000000004', CURRENT_DATE + 0, '18:45:00', 400, true, now()),
('4afcfc76-b099-4dfd-b099-b321491e9f04', '128cae5c-6edc-4ea3-b8ac-af67c4952f6e', 'Breakfast', 'fd000007-0000-0000-0000-000000000007', 'ec000002-0000-0000-0000-000000000002', CURRENT_DATE + 1, '07:30:00', 500, false, now()),
('8043d1f2-83da-470a-837f-8d40794aad30', '128cae5c-6edc-4ea3-b8ac-af67c4952f6e', 'Lunch', 'fd000008-0000-0000-0000-000000000008', 'ec000002-0000-0000-0000-000000000002', CURRENT_DATE + 1, '12:15:00', 350, false, now()),
('5deccf8a-6038-4746-ae83-e3b9a7a21222', '128cae5c-6edc-4ea3-b8ac-af67c4952f6e', 'Dinner', 'fd000008-0000-0000-0000-000000000008', 'ec000001-0000-0000-0000-000000000001', CURRENT_DATE + 1, '18:45:00', 350, false, now()),
('75c5845d-5bd4-4944-81a0-d83c21070f7a', '128cae5c-6edc-4ea3-b8ac-af67c4952f6e', 'Breakfast', 'fd000009-0000-0000-0000-000000000009', 'ec000001-0000-0000-0000-000000000001', CURRENT_DATE + 2, '07:30:00', 350, false, now()),
('fa2f0ce3-c2a5-4585-ac22-d1fdd3c44899', '128cae5c-6edc-4ea3-b8ac-af67c4952f6e', 'Lunch', 'fd000004-0000-0000-0000-000000000004', 'ec000002-0000-0000-0000-000000000002', CURRENT_DATE + 2, '12:15:00', 600, false, now()),
('5bddc893-443f-40fa-a5c7-577701c50ac2', '128cae5c-6edc-4ea3-b8ac-af67c4952f6e', 'Dinner', 'fd000008-0000-0000-0000-000000000008', 'ec000004-0000-0000-0000-000000000004', CURRENT_DATE + 2, '18:45:00', 400, false, now()),
('ace3670b-70a1-471f-8b1a-e9758456d08e', '44c0c107-5c01-4dc9-8cfc-e69a50ec83d7', 'Breakfast', 'fd000007-0000-0000-0000-000000000007', 'ec000001-0000-0000-0000-000000000001', CURRENT_DATE + 0, '07:30:00', 400, true, now()),
('1dd0b7ea-fa08-48a2-96f3-1718d3c16642', '44c0c107-5c01-4dc9-8cfc-e69a50ec83d7', 'Lunch', 'fd000007-0000-0000-0000-000000000007', 'ec000001-0000-0000-0000-000000000001', CURRENT_DATE + 0, '12:15:00', 600, true, now()),
('48c1fafc-5089-40ed-a232-b6b4fd90ba92', '44c0c107-5c01-4dc9-8cfc-e69a50ec83d7', 'Dinner', 'fd000005-0000-0000-0000-000000000005', 'ec000004-0000-0000-0000-000000000004', CURRENT_DATE + 0, '18:45:00', 500, true, now()),
('b4b587ee-c50b-4ef3-85de-fc996bfa8432', '44c0c107-5c01-4dc9-8cfc-e69a50ec83d7', 'Breakfast', 'fd000007-0000-0000-0000-000000000007', 'ec000004-0000-0000-0000-000000000004', CURRENT_DATE + 1, '07:30:00', 400, false, now()),
('dc8587e5-1869-4f8b-bd46-28eb902f64c4', '44c0c107-5c01-4dc9-8cfc-e69a50ec83d7', 'Lunch', 'fd000004-0000-0000-0000-000000000004', 'ec000003-0000-0000-0000-000000000003', CURRENT_DATE + 1, '12:15:00', 400, false, now()),
('0e4aae99-8336-47ef-9779-4af1586e148d', '44c0c107-5c01-4dc9-8cfc-e69a50ec83d7', 'Dinner', 'fd000001-0000-0000-0000-000000000001', 'ec000001-0000-0000-0000-000000000001', CURRENT_DATE + 1, '18:45:00', 500, false, now()),
('b476fa0b-e0af-465e-82ec-c303cb1ab177', '44c0c107-5c01-4dc9-8cfc-e69a50ec83d7', 'Breakfast', 'fd000001-0000-0000-0000-000000000001', 'ec000001-0000-0000-0000-000000000001', CURRENT_DATE + 2, '07:30:00', 600, false, now()),
('0dfcf905-55a1-4ad6-bd17-88e9aa55dc1d', '44c0c107-5c01-4dc9-8cfc-e69a50ec83d7', 'Lunch', 'fd000009-0000-0000-0000-000000000009', 'ec000002-0000-0000-0000-000000000002', CURRENT_DATE + 2, '12:15:00', 350, false, now()),
('141840f4-f805-40dc-b0c3-246af38fcff7', '44c0c107-5c01-4dc9-8cfc-e69a50ec83d7', 'Dinner', 'fd000009-0000-0000-0000-000000000009', 'ec000001-0000-0000-0000-000000000001', CURRENT_DATE + 2, '18:45:00', 400, false, now()),
('95fa8247-442b-4b78-8143-c6fd81f6a0f5', 'c1b905f7-c948-4506-87b3-cb1f359e9cbc', 'Breakfast', 'fd000002-0000-0000-0000-000000000002', 'ec000001-0000-0000-0000-000000000001', CURRENT_DATE + 0, '07:30:00', 400, true, now()),
('20107c8a-8603-4edc-a2a7-ef91a94afb36', 'c1b905f7-c948-4506-87b3-cb1f359e9cbc', 'Lunch', 'fd000007-0000-0000-0000-000000000007', 'ec000001-0000-0000-0000-000000000001', CURRENT_DATE + 0, '12:15:00', 400, true, now()),
('4ae980d5-b9ed-4ca8-9752-280791667460', 'c1b905f7-c948-4506-87b3-cb1f359e9cbc', 'Dinner', 'fd000010-0000-0000-0000-000000000010', 'ec000001-0000-0000-0000-000000000001', CURRENT_DATE + 0, '18:45:00', 350, true, now()),
('2ba78809-7869-459f-934c-117d071e0075', 'c1b905f7-c948-4506-87b3-cb1f359e9cbc', 'Breakfast', 'fd000007-0000-0000-0000-000000000007', 'ec000003-0000-0000-0000-000000000003', CURRENT_DATE + 1, '07:30:00', 500, false, now()),
('4aa1dc93-8713-494e-9382-1374885f5bdd', 'c1b905f7-c948-4506-87b3-cb1f359e9cbc', 'Lunch', 'fd000004-0000-0000-0000-000000000004', 'ec000003-0000-0000-0000-000000000003', CURRENT_DATE + 1, '12:15:00', 400, false, now()),
('7926b696-a55e-450a-a2a8-43f2512a0ea0', 'c1b905f7-c948-4506-87b3-cb1f359e9cbc', 'Dinner', 'fd000005-0000-0000-0000-000000000005', 'ec000004-0000-0000-0000-000000000004', CURRENT_DATE + 1, '18:45:00', 400, false, now()),
('21f4fb30-7341-4ac0-9b39-ab05cb25e566', 'c1b905f7-c948-4506-87b3-cb1f359e9cbc', 'Breakfast', 'fd000005-0000-0000-0000-000000000005', 'ec000004-0000-0000-0000-000000000004', CURRENT_DATE + 2, '07:30:00', 500, false, now()),
('952f0369-ebd6-402f-95dc-64e7c6fdc131', 'c1b905f7-c948-4506-87b3-cb1f359e9cbc', 'Lunch', 'fd000002-0000-0000-0000-000000000002', 'ec000001-0000-0000-0000-000000000001', CURRENT_DATE + 2, '12:15:00', 600, false, now()),
('609b8acb-b9e8-4d90-a445-83d8e6d64223', 'c1b905f7-c948-4506-87b3-cb1f359e9cbc', 'Dinner', 'fd000010-0000-0000-0000-000000000010', 'ec000001-0000-0000-0000-000000000001', CURRENT_DATE + 2, '18:45:00', 350, false, now()),
('a56eb250-dc2f-4a6b-a858-6c7af9b8301f', '07fbdd58-1b92-441b-ad7d-1f01c9cf1e63', 'Breakfast', 'fd000009-0000-0000-0000-000000000009', 'ec000002-0000-0000-0000-000000000002', CURRENT_DATE + 0, '07:30:00', 500, true, now()),
('361f7a78-0d72-46bc-a755-856cc9bc90bf', '07fbdd58-1b92-441b-ad7d-1f01c9cf1e63', 'Lunch', 'fd000003-0000-0000-0000-000000000003', 'ec000003-0000-0000-0000-000000000003', CURRENT_DATE + 0, '12:15:00', 350, true, now()),
('4aa62688-24ae-4319-8302-efb13beb49e1', '07fbdd58-1b92-441b-ad7d-1f01c9cf1e63', 'Dinner', 'fd000004-0000-0000-0000-000000000004', 'ec000003-0000-0000-0000-000000000003', CURRENT_DATE + 0, '18:45:00', 500, true, now()),
('ac9263e1-d541-44ce-8d7a-152e890531ae', '07fbdd58-1b92-441b-ad7d-1f01c9cf1e63', 'Breakfast', 'fd000003-0000-0000-0000-000000000003', 'ec000004-0000-0000-0000-000000000004', CURRENT_DATE + 1, '07:30:00', 500, false, now()),
('87601fbb-3aa8-431f-806b-1bf19b6a904c', '07fbdd58-1b92-441b-ad7d-1f01c9cf1e63', 'Lunch', 'fd000010-0000-0000-0000-000000000010', 'ec000001-0000-0000-0000-000000000001', CURRENT_DATE + 1, '12:15:00', 500, false, now()),
('b2aae065-9557-4f28-95a4-46de062afe79', '07fbdd58-1b92-441b-ad7d-1f01c9cf1e63', 'Dinner', 'fd000002-0000-0000-0000-000000000002', 'ec000002-0000-0000-0000-000000000002', CURRENT_DATE + 1, '18:45:00', 500, false, now()),
('230ab30b-ae2b-41d0-9397-b5cdefad8c17', '07fbdd58-1b92-441b-ad7d-1f01c9cf1e63', 'Breakfast', 'fd000002-0000-0000-0000-000000000002', 'ec000001-0000-0000-0000-000000000001', CURRENT_DATE + 2, '07:30:00', 400, false, now()),
('8635b72a-20dc-44da-92d6-c8d333607006', '07fbdd58-1b92-441b-ad7d-1f01c9cf1e63', 'Lunch', 'fd000005-0000-0000-0000-000000000005', 'ec000003-0000-0000-0000-000000000003', CURRENT_DATE + 2, '12:15:00', 400, false, now()),
('676f5115-186b-4870-aa07-009171cd3243', '07fbdd58-1b92-441b-ad7d-1f01c9cf1e63', 'Dinner', 'fd000006-0000-0000-0000-000000000006', 'ec000002-0000-0000-0000-000000000002', CURRENT_DATE + 2, '18:45:00', 500, false, now()),
('b784dfba-48b4-4b02-801c-3a3d73cb35f0', '457cbba7-31e6-4e56-8073-5e8067640cdc', 'Breakfast', 'fd000009-0000-0000-0000-000000000009', 'ec000004-0000-0000-0000-000000000004', CURRENT_DATE + 0, '07:30:00', 500, true, now()),
('2da69f72-a346-4d20-8bf2-008f7a4c5d09', '457cbba7-31e6-4e56-8073-5e8067640cdc', 'Lunch', 'fd000001-0000-0000-0000-000000000001', 'ec000001-0000-0000-0000-000000000001', CURRENT_DATE + 0, '12:15:00', 600, true, now()),
('0c89a57e-68eb-41b8-a199-2630434af4f0', '457cbba7-31e6-4e56-8073-5e8067640cdc', 'Dinner', 'fd000005-0000-0000-0000-000000000005', 'ec000001-0000-0000-0000-000000000001', CURRENT_DATE + 0, '18:45:00', 350, true, now()),
('899412c7-c363-4749-bb96-88d3e3cfddc0', '457cbba7-31e6-4e56-8073-5e8067640cdc', 'Breakfast', 'fd000006-0000-0000-0000-000000000006', 'ec000002-0000-0000-0000-000000000002', CURRENT_DATE + 1, '07:30:00', 500, false, now()),
('bd7b2a4b-df40-443a-b9b6-f7abbfde1847', '457cbba7-31e6-4e56-8073-5e8067640cdc', 'Lunch', 'fd000003-0000-0000-0000-000000000003', 'ec000004-0000-0000-0000-000000000004', CURRENT_DATE + 1, '12:15:00', 600, false, now()),
('b6ff0f5d-eda5-4c6e-a9fd-de786b56d501', '457cbba7-31e6-4e56-8073-5e8067640cdc', 'Dinner', 'fd000009-0000-0000-0000-000000000009', 'ec000001-0000-0000-0000-000000000001', CURRENT_DATE + 1, '18:45:00', 350, false, now()),
('64dec8d4-74d3-4537-92fb-4a0bc428c397', '457cbba7-31e6-4e56-8073-5e8067640cdc', 'Breakfast', 'fd000002-0000-0000-0000-000000000002', 'ec000002-0000-0000-0000-000000000002', CURRENT_DATE + 2, '07:30:00', 350, false, now()),
('963e71db-9704-4c35-9895-85d341308e46', '457cbba7-31e6-4e56-8073-5e8067640cdc', 'Lunch', 'fd000006-0000-0000-0000-000000000006', 'ec000002-0000-0000-0000-000000000002', CURRENT_DATE + 2, '12:15:00', 600, false, now()),
('a01b3e04-a81c-491d-962d-5094382bc010', '457cbba7-31e6-4e56-8073-5e8067640cdc', 'Dinner', 'fd000003-0000-0000-0000-000000000003', 'ec000001-0000-0000-0000-000000000001', CURRENT_DATE + 2, '18:45:00', 500, false, now()),
('fb909cd1-1666-421d-8494-a03135925801', 'd67fd2c9-bb6b-4216-a5eb-c62b189285d0', 'Breakfast', 'fd000006-0000-0000-0000-000000000006', 'ec000001-0000-0000-0000-000000000001', CURRENT_DATE + 0, '07:30:00', 500, true, now()),
('797b5fec-2cf6-4bef-8b90-9fd0f53a6eef', 'd67fd2c9-bb6b-4216-a5eb-c62b189285d0', 'Lunch', 'fd000004-0000-0000-0000-000000000004', 'ec000002-0000-0000-0000-000000000002', CURRENT_DATE + 0, '12:15:00', 350, true, now()),
('e663229c-9275-4e99-bbc4-51f1d925eac5', 'd67fd2c9-bb6b-4216-a5eb-c62b189285d0', 'Dinner', 'fd000006-0000-0000-0000-000000000006', 'ec000004-0000-0000-0000-000000000004', CURRENT_DATE + 0, '18:45:00', 400, true, now()),
('a5bf0dfb-9009-4313-839b-406634c49813', 'd67fd2c9-bb6b-4216-a5eb-c62b189285d0', 'Breakfast', 'fd000004-0000-0000-0000-000000000004', 'ec000002-0000-0000-0000-000000000002', CURRENT_DATE + 1, '07:30:00', 400, false, now()),
('e8f19f1b-d972-4ec3-8f94-d1820ae6d733', 'd67fd2c9-bb6b-4216-a5eb-c62b189285d0', 'Lunch', 'fd000007-0000-0000-0000-000000000007', 'ec000001-0000-0000-0000-000000000001', CURRENT_DATE + 1, '12:15:00', 400, false, now()),
('8d595417-6bf3-4582-b8bb-6f0df151a39e', 'd67fd2c9-bb6b-4216-a5eb-c62b189285d0', 'Dinner', 'fd000006-0000-0000-0000-000000000006', 'ec000004-0000-0000-0000-000000000004', CURRENT_DATE + 1, '18:45:00', 400, false, now()),
('e08367ba-7609-442e-a830-4095d4813785', 'd67fd2c9-bb6b-4216-a5eb-c62b189285d0', 'Breakfast', 'fd000005-0000-0000-0000-000000000005', 'ec000002-0000-0000-0000-000000000002', CURRENT_DATE + 2, '07:30:00', 350, false, now()),
('2be1dac3-974c-40c9-99f5-3c50647c8550', 'd67fd2c9-bb6b-4216-a5eb-c62b189285d0', 'Lunch', 'fd000007-0000-0000-0000-000000000007', 'ec000001-0000-0000-0000-000000000001', CURRENT_DATE + 2, '12:15:00', 600, false, now()),
('8fd44856-be9c-4af7-9b95-08af0a185246', 'd67fd2c9-bb6b-4216-a5eb-c62b189285d0', 'Dinner', 'fd000004-0000-0000-0000-000000000004', 'ec000002-0000-0000-0000-000000000002', CURRENT_DATE + 2, '18:45:00', 600, false, now()),
('221e572a-10bd-452b-b11f-7fe1a1572b4b', '471293e8-4b51-413c-a739-9aabc9cdfbc9', 'Breakfast', 'fd000006-0000-0000-0000-000000000006', 'ec000003-0000-0000-0000-000000000003', CURRENT_DATE + 0, '07:30:00', 400, true, now()),
('bd5562cf-9f24-4a10-8639-63ef8628654d', '471293e8-4b51-413c-a739-9aabc9cdfbc9', 'Lunch', 'fd000004-0000-0000-0000-000000000004', 'ec000001-0000-0000-0000-000000000001', CURRENT_DATE + 0, '12:15:00', 400, true, now()),
('ae20415b-725f-4c94-8c19-8c2b90ecbdec', '471293e8-4b51-413c-a739-9aabc9cdfbc9', 'Dinner', 'fd000007-0000-0000-0000-000000000007', 'ec000003-0000-0000-0000-000000000003', CURRENT_DATE + 0, '18:45:00', 500, true, now()),
('9026b35e-75a3-46bc-a4cf-998a69c3cd03', '471293e8-4b51-413c-a739-9aabc9cdfbc9', 'Breakfast', 'fd000002-0000-0000-0000-000000000002', 'ec000003-0000-0000-0000-000000000003', CURRENT_DATE + 1, '07:30:00', 500, false, now()),
('453b7a36-b278-4807-9a7d-e52fd0bae729', '471293e8-4b51-413c-a739-9aabc9cdfbc9', 'Lunch', 'fd000009-0000-0000-0000-000000000009', 'ec000004-0000-0000-0000-000000000004', CURRENT_DATE + 1, '12:15:00', 500, false, now()),
('e6902f2c-fe36-4987-a2e7-fce4c6723f3e', '471293e8-4b51-413c-a739-9aabc9cdfbc9', 'Dinner', 'fd000001-0000-0000-0000-000000000001', 'ec000001-0000-0000-0000-000000000001', CURRENT_DATE + 1, '18:45:00', 500, false, now()),
('a304a854-d914-404d-a57e-a7451997a03a', '471293e8-4b51-413c-a739-9aabc9cdfbc9', 'Breakfast', 'fd000003-0000-0000-0000-000000000003', 'ec000003-0000-0000-0000-000000000003', CURRENT_DATE + 2, '07:30:00', 350, false, now()),
('32b5c5cc-e03f-4fe3-9c63-3b94178434a8', '471293e8-4b51-413c-a739-9aabc9cdfbc9', 'Lunch', 'fd000002-0000-0000-0000-000000000002', 'ec000004-0000-0000-0000-000000000004', CURRENT_DATE + 2, '12:15:00', 500, false, now()),
('e70e3917-949f-4f83-a481-2c2851efae5a', '471293e8-4b51-413c-a739-9aabc9cdfbc9', 'Dinner', 'fd000006-0000-0000-0000-000000000006', 'ec000004-0000-0000-0000-000000000004', CURRENT_DATE + 2, '18:45:00', 350, false, now()),
('197d6ffe-5cf0-4309-876d-f343eccb29f6', 'ed136f5e-f381-4e17-8aa7-5db67bd34146', 'Breakfast', 'fd000007-0000-0000-0000-000000000007', 'ec000002-0000-0000-0000-000000000002', CURRENT_DATE + 0, '07:30:00', 500, true, now()),
('4cb79015-12ff-4fb0-8494-5a77e5861a24', 'ed136f5e-f381-4e17-8aa7-5db67bd34146', 'Lunch', 'fd000001-0000-0000-0000-000000000001', 'ec000004-0000-0000-0000-000000000004', CURRENT_DATE + 0, '12:15:00', 350, true, now()),
('89f7a34a-7fdd-445b-aa6b-85eeee6a3162', 'ed136f5e-f381-4e17-8aa7-5db67bd34146', 'Dinner', 'fd000009-0000-0000-0000-000000000009', 'ec000002-0000-0000-0000-000000000002', CURRENT_DATE + 0, '18:45:00', 500, true, now()),
('0ccb5994-f8f1-42b3-ad88-19494c0200cf', 'ed136f5e-f381-4e17-8aa7-5db67bd34146', 'Breakfast', 'fd000007-0000-0000-0000-000000000007', 'ec000001-0000-0000-0000-000000000001', CURRENT_DATE + 1, '07:30:00', 500, false, now()),
('65d1840f-bd97-44d2-bb55-06c7b69893af', 'ed136f5e-f381-4e17-8aa7-5db67bd34146', 'Lunch', 'fd000010-0000-0000-0000-000000000010', 'ec000003-0000-0000-0000-000000000003', CURRENT_DATE + 1, '12:15:00', 350, false, now()),
('63bbafc3-bd14-464e-a1e9-b3d5580a636f', 'ed136f5e-f381-4e17-8aa7-5db67bd34146', 'Dinner', 'fd000005-0000-0000-0000-000000000005', 'ec000003-0000-0000-0000-000000000003', CURRENT_DATE + 1, '18:45:00', 600, false, now()),
('f24f32d1-509c-479b-a8b2-9693ce0d410e', 'ed136f5e-f381-4e17-8aa7-5db67bd34146', 'Breakfast', 'fd000006-0000-0000-0000-000000000006', 'ec000004-0000-0000-0000-000000000004', CURRENT_DATE + 2, '07:30:00', 500, false, now()),
('d0209497-c622-4110-be7c-44ce7b5328c4', 'ed136f5e-f381-4e17-8aa7-5db67bd34146', 'Lunch', 'fd000009-0000-0000-0000-000000000009', 'ec000002-0000-0000-0000-000000000002', CURRENT_DATE + 2, '12:15:00', 400, false, now()),
('67eb64ef-4e6a-459a-b6d8-223e76519b40', 'ed136f5e-f381-4e17-8aa7-5db67bd34146', 'Dinner', 'fd000007-0000-0000-0000-000000000007', 'ec000004-0000-0000-0000-000000000004', CURRENT_DATE + 2, '18:45:00', 400, false, now()),
('f81d5aad-2176-4cf2-8968-ecd87052d33d', '401f123d-9dc9-40dd-ad44-11dea7dfbe3a', 'Breakfast', 'fd000010-0000-0000-0000-000000000010', 'ec000003-0000-0000-0000-000000000003', CURRENT_DATE + 0, '07:30:00', 600, true, now()),
('b08a2e30-6bc8-4d41-84f6-c3a9135b9490', '401f123d-9dc9-40dd-ad44-11dea7dfbe3a', 'Lunch', 'fd000009-0000-0000-0000-000000000009', 'ec000001-0000-0000-0000-000000000001', CURRENT_DATE + 0, '12:15:00', 500, true, now()),
('b56f805d-5dcc-4297-85ae-225bf23d08d7', '401f123d-9dc9-40dd-ad44-11dea7dfbe3a', 'Dinner', 'fd000005-0000-0000-0000-000000000005', 'ec000002-0000-0000-0000-000000000002', CURRENT_DATE + 0, '18:45:00', 600, true, now()),
('7c0c374e-fba3-446a-9dd7-c9ee0028b958', '401f123d-9dc9-40dd-ad44-11dea7dfbe3a', 'Breakfast', 'fd000010-0000-0000-0000-000000000010', 'ec000003-0000-0000-0000-000000000003', CURRENT_DATE + 1, '07:30:00', 600, false, now()),
('3f654fb2-2f2c-4ba3-bb0e-4a13f51e79f3', '401f123d-9dc9-40dd-ad44-11dea7dfbe3a', 'Lunch', 'fd000008-0000-0000-0000-000000000008', 'ec000004-0000-0000-0000-000000000004', CURRENT_DATE + 1, '12:15:00', 400, false, now()),
('ef793d2d-fcba-4227-a85d-29e0eda45c76', '401f123d-9dc9-40dd-ad44-11dea7dfbe3a', 'Dinner', 'fd000009-0000-0000-0000-000000000009', 'ec000004-0000-0000-0000-000000000004', CURRENT_DATE + 1, '18:45:00', 400, false, now()),
('898a2d2e-ad2f-41a8-a6ea-7c069970153d', '401f123d-9dc9-40dd-ad44-11dea7dfbe3a', 'Breakfast', 'fd000002-0000-0000-0000-000000000002', 'ec000003-0000-0000-0000-000000000003', CURRENT_DATE + 2, '07:30:00', 500, false, now()),
('f9e3f7b5-d2ea-4219-9b70-3153ff043356', '401f123d-9dc9-40dd-ad44-11dea7dfbe3a', 'Lunch', 'fd000002-0000-0000-0000-000000000002', 'ec000002-0000-0000-0000-000000000002', CURRENT_DATE + 2, '12:15:00', 500, false, now()),
('8e122199-4efb-4264-877a-da41f7f63ddf', '401f123d-9dc9-40dd-ad44-11dea7dfbe3a', 'Dinner', 'fd000004-0000-0000-0000-000000000004', 'ec000002-0000-0000-0000-000000000002', CURRENT_DATE + 2, '18:45:00', 400, false, now())
ON CONFLICT DO NOTHING;

INSERT INTO meal_logs ("Id", "UserId", "FoodId", "RecipeId", "MealType", "QuantityG", "CaloriesKcal", "ProteinG", "CarbsG", "FatG", "SourceType", "Notes", "LoggedAt", "MealPlanItemId", "IsFromMealPlan")
VALUES
('ad196c9c-2d3f-428f-99d2-98d980203fa7', 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'fd000001-0000-0000-0000-000000000001', 'ec000001-0000-0000-0000-000000000001', 'Breakfast', 200, 330.00, 62.00, 0.00, 7.20, 'Food', 'Ghi chép bữa ăn lành mạnh', now() - interval '1 days', NULL, false),
('4d20aafd-af63-46a5-b551-021c65fb7ec3', 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'fd000010-0000-0000-0000-000000000010', 'ec000001-0000-0000-0000-000000000001', 'Lunch', 300, 1140.00, 69.00, 28.50, 84.00, 'Food', 'Ghi chép bữa ăn lành mạnh', now() - interval '1 days', NULL, false),
('21735254-d8fc-4b47-bf0b-7f44e7ffe03b', 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'fd000010-0000-0000-0000-000000000010', 'ec000002-0000-0000-0000-000000000002', 'Dinner', 300, 1140.00, 69.00, 28.50, 84.00, 'Food', 'Ghi chép bữa ăn lành mạnh', now() - interval '1 days', NULL, false),
('d1b13948-1450-4fc0-9553-f1063e6cd86d', 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'fd000007-0000-0000-0000-000000000007', 'ec000002-0000-0000-0000-000000000002', 'Breakfast', 200, 700.00, 50.00, 10.00, 48.00, 'Recipe', 'Ghi chép bữa ăn lành mạnh', now() - interval '2 days', NULL, false),
('8b169ad6-846e-45e7-a2fd-2bf46e909603', 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'fd000002-0000-0000-0000-000000000002', 'ec000004-0000-0000-0000-000000000004', 'Lunch', 200, 222.00, 5.20, 46.00, 1.80, 'Recipe', 'Ghi chép bữa ăn lành mạnh', now() - interval '2 days', NULL, false),
('87748f7d-416e-4eb7-9cbc-dbb5f2b433e4', 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'fd000009-0000-0000-0000-000000000009', 'ec000004-0000-0000-0000-000000000004', 'Dinner', 150, 270.00, 18.00, 12.75, 15.00, 'Recipe', 'Ghi chép bữa ăn lành mạnh', now() - interval '2 days', NULL, false),
('13262e0b-4da7-4516-98f4-5d8e0285a365', 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'fd000002-0000-0000-0000-000000000002', 'ec000004-0000-0000-0000-000000000004', 'Breakfast', 200, 222.00, 5.20, 46.00, 1.80, 'Food', 'Ghi chép bữa ăn lành mạnh', now() - interval '3 days', NULL, false),
('19d21233-fb2a-4ba2-910d-533ecd147d06', 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'fd000009-0000-0000-0000-000000000009', 'ec000003-0000-0000-0000-000000000003', 'Lunch', 300, 540.00, 36.00, 25.50, 30.00, 'Food', 'Ghi chép bữa ăn lành mạnh', now() - interval '3 days', NULL, false),
('a4ecd594-130a-4c1e-affd-56d20b93d40e', 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'fd000009-0000-0000-0000-000000000009', 'ec000004-0000-0000-0000-000000000004', 'Dinner', 200, 360.00, 24.00, 17.00, 20.00, 'Food', 'Ghi chép bữa ăn lành mạnh', now() - interval '3 days', NULL, false),
('32ff550e-3e1c-4408-9548-f6571694274a', 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'fd000008-0000-0000-0000-000000000008', 'ec000003-0000-0000-0000-000000000003', 'Breakfast', 200, 500.00, 23.00, 56.00, 17.00, 'Food', 'Ghi chép bữa ăn lành mạnh', now() - interval '4 days', NULL, false),
('f9541abe-efc1-40e3-9cc6-f443cb615818', 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'fd000009-0000-0000-0000-000000000009', 'ec000004-0000-0000-0000-000000000004', 'Lunch', 200, 360.00, 24.00, 17.00, 20.00, 'Food', 'Ghi chép bữa ăn lành mạnh', now() - interval '4 days', NULL, false),
('9d2f78bd-8adc-4980-a447-e0299e6f2693', 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'fd000008-0000-0000-0000-000000000008', 'ec000001-0000-0000-0000-000000000001', 'Dinner', 250, 625.00, 28.75, 70.00, 21.25, 'Recipe', 'Ghi chép bữa ăn lành mạnh', now() - interval '4 days', NULL, false),
('905ccdb9-f32b-4aea-a39a-5b45e90f24fc', 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'fd000005-0000-0000-0000-000000000005', 'ec000003-0000-0000-0000-000000000003', 'Breakfast', 250, 1125.00, 30.00, 130.00, 55.00, 'Recipe', 'Ghi chép bữa ăn lành mạnh', now() - interval '5 days', NULL, false),
('f84bc853-0c86-4d88-af08-10165f34dc8d', 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'fd000003-0000-0000-0000-000000000003', 'ec000002-0000-0000-0000-000000000002', 'Lunch', 200, 640.00, 57.00, 24.00, 37.00, 'Food', 'Ghi chép bữa ăn lành mạnh', now() - interval '5 days', NULL, false),
('d6c8569a-6d3d-4728-a9d1-c8d196642bcd', 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'fd000003-0000-0000-0000-000000000003', 'ec000002-0000-0000-0000-000000000002', 'Dinner', 150, 480.00, 42.75, 18.00, 27.75, 'Food', 'Ghi chép bữa ăn lành mạnh', now() - interval '5 days', NULL, false),
('42d4dae1-934c-4a38-a507-39aa3dfaa65e', 'cccccccc-cccc-cccc-cccc-cccccccccccc', 'fd000007-0000-0000-0000-000000000007', 'ec000003-0000-0000-0000-000000000003', 'Breakfast', 300, 1050.00, 75.00, 15.00, 72.00, 'Food', 'Ghi chép bữa ăn lành mạnh', now() - interval '1 days', NULL, false),
('7ea87f6e-19fa-4a57-9a9f-ff388dce5a3b', 'cccccccc-cccc-cccc-cccc-cccccccccccc', 'fd000001-0000-0000-0000-000000000001', 'ec000002-0000-0000-0000-000000000002', 'Lunch', 300, 495.00, 93.00, 0.00, 10.80, 'Food', 'Ghi chép bữa ăn lành mạnh', now() - interval '1 days', NULL, false),
('7e7d431e-b584-4ca0-b92f-8163d77fd597', 'cccccccc-cccc-cccc-cccc-cccccccccccc', 'fd000010-0000-0000-0000-000000000010', 'ec000001-0000-0000-0000-000000000001', 'Dinner', 300, 1140.00, 69.00, 28.50, 84.00, 'Food', 'Ghi chép bữa ăn lành mạnh', now() - interval '1 days', NULL, false),
('b331cac6-e407-4ce2-8bf8-99b73957407e', 'cccccccc-cccc-cccc-cccc-cccccccccccc', 'fd000001-0000-0000-0000-000000000001', 'ec000003-0000-0000-0000-000000000003', 'Breakfast', 250, 412.50, 77.50, 0.00, 9.00, 'Food', 'Ghi chép bữa ăn lành mạnh', now() - interval '2 days', NULL, false),
('3ba13f62-f72c-4c3c-871e-4a8be5dda2e3', 'cccccccc-cccc-cccc-cccc-cccccccccccc', 'fd000007-0000-0000-0000-000000000007', 'ec000002-0000-0000-0000-000000000002', 'Lunch', 300, 1050.00, 75.00, 15.00, 72.00, 'Recipe', 'Ghi chép bữa ăn lành mạnh', now() - interval '2 days', NULL, false),
('757ba980-e87d-442e-b700-3e434a7038ee', 'cccccccc-cccc-cccc-cccc-cccccccccccc', 'fd000005-0000-0000-0000-000000000005', 'ec000004-0000-0000-0000-000000000004', 'Dinner', 300, 1350.00, 36.00, 156.00, 66.00, 'Recipe', 'Ghi chép bữa ăn lành mạnh', now() - interval '2 days', NULL, false),
('e65b99de-5948-4ee3-b1f8-780f2e27ca82', 'cccccccc-cccc-cccc-cccc-cccccccccccc', 'fd000007-0000-0000-0000-000000000007', 'ec000003-0000-0000-0000-000000000003', 'Breakfast', 300, 1050.00, 75.00, 15.00, 72.00, 'Recipe', 'Ghi chép bữa ăn lành mạnh', now() - interval '3 days', NULL, false),
('75bb52f6-2c7f-42ef-b265-63874ffaaf22', 'cccccccc-cccc-cccc-cccc-cccccccccccc', 'fd000008-0000-0000-0000-000000000008', 'ec000002-0000-0000-0000-000000000002', 'Lunch', 150, 375.00, 17.25, 42.00, 12.75, 'Food', 'Ghi chép bữa ăn lành mạnh', now() - interval '3 days', NULL, false),
('aa273159-7210-44d7-a139-771c79844dce', 'cccccccc-cccc-cccc-cccc-cccccccccccc', 'fd000010-0000-0000-0000-000000000010', 'ec000001-0000-0000-0000-000000000001', 'Dinner', 150, 570.00, 34.50, 14.25, 42.00, 'Food', 'Ghi chép bữa ăn lành mạnh', now() - interval '3 days', NULL, false),
('05f628ab-4b95-478d-9d7a-ec4fcb7165b4', 'cccccccc-cccc-cccc-cccc-cccccccccccc', 'fd000003-0000-0000-0000-000000000003', 'ec000004-0000-0000-0000-000000000004', 'Breakfast', 200, 640.00, 57.00, 24.00, 37.00, 'Recipe', 'Ghi chép bữa ăn lành mạnh', now() - interval '4 days', NULL, false),
('40ef8296-c660-4f18-8242-1d60c9beb3ca', 'cccccccc-cccc-cccc-cccc-cccccccccccc', 'fd000005-0000-0000-0000-000000000005', 'ec000004-0000-0000-0000-000000000004', 'Lunch', 250, 1125.00, 30.00, 130.00, 55.00, 'Recipe', 'Ghi chép bữa ăn lành mạnh', now() - interval '4 days', NULL, false),
('9675c46e-faed-425c-872f-6e9aa616e0b4', 'cccccccc-cccc-cccc-cccc-cccccccccccc', 'fd000008-0000-0000-0000-000000000008', 'ec000003-0000-0000-0000-000000000003', 'Dinner', 250, 625.00, 28.75, 70.00, 21.25, 'Food', 'Ghi chép bữa ăn lành mạnh', now() - interval '4 days', NULL, false),
('e6b28fcf-562d-4e2e-98b1-8cceb0e1b901', 'cccccccc-cccc-cccc-cccc-cccccccccccc', 'fd000005-0000-0000-0000-000000000005', 'ec000004-0000-0000-0000-000000000004', 'Breakfast', 250, 1125.00, 30.00, 130.00, 55.00, 'Recipe', 'Ghi chép bữa ăn lành mạnh', now() - interval '5 days', NULL, false),
('c3672827-d7de-4459-ab25-4d52234ffda4', 'cccccccc-cccc-cccc-cccc-cccccccccccc', 'fd000008-0000-0000-0000-000000000008', 'ec000001-0000-0000-0000-000000000001', 'Lunch', 150, 375.00, 17.25, 42.00, 12.75, 'Food', 'Ghi chép bữa ăn lành mạnh', now() - interval '5 days', NULL, false),
('74ab4276-604c-472c-9aec-a2d20feae622', 'cccccccc-cccc-cccc-cccc-cccccccccccc', 'fd000004-0000-0000-0000-000000000004', 'ec000001-0000-0000-0000-000000000001', 'Dinner', 150, 129.00, 2.40, 30.15, 0.15, 'Recipe', 'Ghi chép bữa ăn lành mạnh', now() - interval '5 days', NULL, false),
('a7cf06c4-c6fd-4c37-b56c-eda1afe55cbf', 'dddddddd-dddd-dddd-dddd-dddddddddddd', 'fd000004-0000-0000-0000-000000000004', 'ec000002-0000-0000-0000-000000000002', 'Breakfast', 150, 129.00, 2.40, 30.15, 0.15, 'Recipe', 'Ghi chép bữa ăn lành mạnh', now() - interval '1 days', NULL, false),
('4a2a160a-a173-4e01-a333-fd5711a0e3db', 'dddddddd-dddd-dddd-dddd-dddddddddddd', 'fd000004-0000-0000-0000-000000000004', 'ec000002-0000-0000-0000-000000000002', 'Lunch', 300, 258.00, 4.80, 60.30, 0.30, 'Recipe', 'Ghi chép bữa ăn lành mạnh', now() - interval '1 days', NULL, false),
('6dec7d1c-6364-4240-8934-42feef86ca0a', 'dddddddd-dddd-dddd-dddd-dddddddddddd', 'fd000010-0000-0000-0000-000000000010', 'ec000002-0000-0000-0000-000000000002', 'Dinner', 300, 1140.00, 69.00, 28.50, 84.00, 'Food', 'Ghi chép bữa ăn lành mạnh', now() - interval '1 days', NULL, false),
('bbb89dcd-cd17-473f-b062-9eb7bcd29bbc', 'dddddddd-dddd-dddd-dddd-dddddddddddd', 'fd000006-0000-0000-0000-000000000006', 'ec000002-0000-0000-0000-000000000002', 'Breakfast', 150, 435.00, 48.00, 9.90, 21.75, 'Recipe', 'Ghi chép bữa ăn lành mạnh', now() - interval '2 days', NULL, false),
('a41489c1-eb9d-4006-b92f-b29f3ba1dc4e', 'dddddddd-dddd-dddd-dddd-dddddddddddd', 'fd000005-0000-0000-0000-000000000005', 'ec000001-0000-0000-0000-000000000001', 'Lunch', 150, 675.00, 18.00, 78.00, 33.00, 'Food', 'Ghi chép bữa ăn lành mạnh', now() - interval '2 days', NULL, false),
('5c2c1517-aa51-4ac7-b529-2fc155724676', 'dddddddd-dddd-dddd-dddd-dddddddddddd', 'fd000010-0000-0000-0000-000000000010', 'ec000004-0000-0000-0000-000000000004', 'Dinner', 300, 1140.00, 69.00, 28.50, 84.00, 'Recipe', 'Ghi chép bữa ăn lành mạnh', now() - interval '2 days', NULL, false),
('5d6582e9-af74-45a6-a172-e2529f113585', 'dddddddd-dddd-dddd-dddd-dddddddddddd', 'fd000002-0000-0000-0000-000000000002', 'ec000002-0000-0000-0000-000000000002', 'Breakfast', 150, 166.50, 3.90, 34.50, 1.35, 'Food', 'Ghi chép bữa ăn lành mạnh', now() - interval '3 days', NULL, false),
('a2bd10e4-7429-45d9-87ec-7bc678739e4c', 'dddddddd-dddd-dddd-dddd-dddddddddddd', 'fd000010-0000-0000-0000-000000000010', 'ec000001-0000-0000-0000-000000000001', 'Lunch', 150, 570.00, 34.50, 14.25, 42.00, 'Food', 'Ghi chép bữa ăn lành mạnh', now() - interval '3 days', NULL, false),
('6e8a6fbb-f23d-4a84-a655-1399e0560e7e', 'dddddddd-dddd-dddd-dddd-dddddddddddd', 'fd000009-0000-0000-0000-000000000009', 'ec000004-0000-0000-0000-000000000004', 'Dinner', 250, 450.00, 30.00, 21.25, 25.00, 'Recipe', 'Ghi chép bữa ăn lành mạnh', now() - interval '3 days', NULL, false),
('662522c4-0ad9-43e7-b15f-3e0b05454db6', 'dddddddd-dddd-dddd-dddd-dddddddddddd', 'fd000009-0000-0000-0000-000000000009', 'ec000003-0000-0000-0000-000000000003', 'Breakfast', 150, 270.00, 18.00, 12.75, 15.00, 'Food', 'Ghi chép bữa ăn lành mạnh', now() - interval '4 days', NULL, false),
('d38a94b2-608c-43f7-b64f-e43ac594d1cd', 'dddddddd-dddd-dddd-dddd-dddddddddddd', 'fd000008-0000-0000-0000-000000000008', 'ec000001-0000-0000-0000-000000000001', 'Lunch', 300, 750.00, 34.50, 84.00, 25.50, 'Food', 'Ghi chép bữa ăn lành mạnh', now() - interval '4 days', NULL, false),
('e16a55ce-5a44-4c65-99a8-c5656098e8f3', 'dddddddd-dddd-dddd-dddd-dddddddddddd', 'fd000008-0000-0000-0000-000000000008', 'ec000002-0000-0000-0000-000000000002', 'Dinner', 300, 750.00, 34.50, 84.00, 25.50, 'Recipe', 'Ghi chép bữa ăn lành mạnh', now() - interval '4 days', NULL, false),
('85ce8324-f953-464c-8d92-ea05a3b4867d', 'dddddddd-dddd-dddd-dddd-dddddddddddd', 'fd000009-0000-0000-0000-000000000009', 'ec000003-0000-0000-0000-000000000003', 'Breakfast', 300, 540.00, 36.00, 25.50, 30.00, 'Food', 'Ghi chép bữa ăn lành mạnh', now() - interval '5 days', NULL, false),
('b2e3d2ca-88c3-4852-897e-702855ad573f', 'dddddddd-dddd-dddd-dddd-dddddddddddd', 'fd000007-0000-0000-0000-000000000007', 'ec000003-0000-0000-0000-000000000003', 'Lunch', 250, 875.00, 62.50, 12.50, 60.00, 'Recipe', 'Ghi chép bữa ăn lành mạnh', now() - interval '5 days', NULL, false),
('12aaea6f-3270-4ffe-8027-ccdc3840c2c2', 'dddddddd-dddd-dddd-dddd-dddddddddddd', 'fd000002-0000-0000-0000-000000000002', 'ec000003-0000-0000-0000-000000000003', 'Dinner', 300, 333.00, 7.80, 69.00, 2.70, 'Recipe', 'Ghi chép bữa ăn lành mạnh', now() - interval '5 days', NULL, false),
('560b2cf9-b451-4a2d-9031-6c3ef9538e3e', 'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee', 'fd000008-0000-0000-0000-000000000008', 'ec000004-0000-0000-0000-000000000004', 'Breakfast', 250, 625.00, 28.75, 70.00, 21.25, 'Recipe', 'Ghi chép bữa ăn lành mạnh', now() - interval '1 days', NULL, false),
('99e82450-ea02-4fd5-b4af-e53d9a20d8ff', 'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee', 'fd000008-0000-0000-0000-000000000008', 'ec000003-0000-0000-0000-000000000003', 'Lunch', 200, 500.00, 23.00, 56.00, 17.00, 'Food', 'Ghi chép bữa ăn lành mạnh', now() - interval '1 days', NULL, false),
('5c73cb8e-4851-48c1-a049-5f4c2245006c', 'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee', 'fd000004-0000-0000-0000-000000000004', 'ec000003-0000-0000-0000-000000000003', 'Dinner', 250, 215.00, 4.00, 50.25, 0.25, 'Food', 'Ghi chép bữa ăn lành mạnh', now() - interval '1 days', NULL, false),
('1d7051e9-3511-4202-93b1-0035c238a0cc', 'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee', 'fd000005-0000-0000-0000-000000000005', 'ec000003-0000-0000-0000-000000000003', 'Breakfast', 150, 675.00, 18.00, 78.00, 33.00, 'Recipe', 'Ghi chép bữa ăn lành mạnh', now() - interval '2 days', NULL, false),
('fea0b161-f875-4963-8561-a57a95b0a58a', 'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee', 'fd000002-0000-0000-0000-000000000002', 'ec000002-0000-0000-0000-000000000002', 'Lunch', 300, 333.00, 7.80, 69.00, 2.70, 'Food', 'Ghi chép bữa ăn lành mạnh', now() - interval '2 days', NULL, false),
('01e13c7a-f01e-4dcd-be19-ec5f92f7b7c5', 'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee', 'fd000009-0000-0000-0000-000000000009', 'ec000002-0000-0000-0000-000000000002', 'Dinner', 300, 540.00, 36.00, 25.50, 30.00, 'Food', 'Ghi chép bữa ăn lành mạnh', now() - interval '2 days', NULL, false),
('cb69af2e-e077-4ef4-a554-e2921e7dc9da', 'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee', 'fd000008-0000-0000-0000-000000000008', 'ec000001-0000-0000-0000-000000000001', 'Breakfast', 150, 375.00, 17.25, 42.00, 12.75, 'Food', 'Ghi chép bữa ăn lành mạnh', now() - interval '3 days', NULL, false),
('d6e15c53-c37f-43f6-99cf-adad3817561e', 'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee', 'fd000004-0000-0000-0000-000000000004', 'ec000004-0000-0000-0000-000000000004', 'Lunch', 200, 172.00, 3.20, 40.20, 0.20, 'Food', 'Ghi chép bữa ăn lành mạnh', now() - interval '3 days', NULL, false),
('b5ffcea5-538c-485b-85b9-47777edfda31', 'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee', 'fd000010-0000-0000-0000-000000000010', 'ec000003-0000-0000-0000-000000000003', 'Dinner', 300, 1140.00, 69.00, 28.50, 84.00, 'Food', 'Ghi chép bữa ăn lành mạnh', now() - interval '3 days', NULL, false),
('0a727531-d235-48ae-8dbc-ca6faebed93c', 'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee', 'fd000007-0000-0000-0000-000000000007', 'ec000003-0000-0000-0000-000000000003', 'Breakfast', 250, 875.00, 62.50, 12.50, 60.00, 'Food', 'Ghi chép bữa ăn lành mạnh', now() - interval '4 days', NULL, false),
('ec05657e-400a-40d3-b345-bfd533f85c1f', 'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee', 'fd000005-0000-0000-0000-000000000005', 'ec000003-0000-0000-0000-000000000003', 'Lunch', 250, 1125.00, 30.00, 130.00, 55.00, 'Recipe', 'Ghi chép bữa ăn lành mạnh', now() - interval '4 days', NULL, false),
('d6d061d8-8360-4194-bd7e-b27bad1c603d', 'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee', 'fd000002-0000-0000-0000-000000000002', 'ec000002-0000-0000-0000-000000000002', 'Dinner', 250, 277.50, 6.50, 57.50, 2.25, 'Recipe', 'Ghi chép bữa ăn lành mạnh', now() - interval '4 days', NULL, false),
('f2b4da61-0abe-4e28-aa11-9c994e0dd0af', 'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee', 'fd000009-0000-0000-0000-000000000009', 'ec000002-0000-0000-0000-000000000002', 'Breakfast', 200, 360.00, 24.00, 17.00, 20.00, 'Recipe', 'Ghi chép bữa ăn lành mạnh', now() - interval '5 days', NULL, false),
('fd228a20-c1ff-43c4-8f5a-958ac3c7aed8', 'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee', 'fd000008-0000-0000-0000-000000000008', 'ec000003-0000-0000-0000-000000000003', 'Lunch', 250, 625.00, 28.75, 70.00, 21.25, 'Recipe', 'Ghi chép bữa ăn lành mạnh', now() - interval '5 days', NULL, false),
('7266748e-8fe4-4ce6-bd40-b10230b4cd0c', 'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee', 'fd000004-0000-0000-0000-000000000004', 'ec000003-0000-0000-0000-000000000003', 'Dinner', 200, 172.00, 3.20, 40.20, 0.20, 'Food', 'Ghi chép bữa ăn lành mạnh', now() - interval '5 days', NULL, false),
('6e2adcce-d565-45a3-89b9-0969dc9f651f', 'ffffffff-ffff-ffff-ffff-ffffffffffff', 'fd000003-0000-0000-0000-000000000003', 'ec000003-0000-0000-0000-000000000003', 'Breakfast', 150, 480.00, 42.75, 18.00, 27.75, 'Recipe', 'Ghi chép bữa ăn lành mạnh', now() - interval '1 days', NULL, false),
('83249fb1-b2b0-4ffc-92c3-880145594e10', 'ffffffff-ffff-ffff-ffff-ffffffffffff', 'fd000005-0000-0000-0000-000000000005', 'ec000001-0000-0000-0000-000000000001', 'Lunch', 150, 675.00, 18.00, 78.00, 33.00, 'Food', 'Ghi chép bữa ăn lành mạnh', now() - interval '1 days', NULL, false),
('3642a3c3-a121-4b73-9e4c-fc6fad329aef', 'ffffffff-ffff-ffff-ffff-ffffffffffff', 'fd000003-0000-0000-0000-000000000003', 'ec000004-0000-0000-0000-000000000004', 'Dinner', 150, 480.00, 42.75, 18.00, 27.75, 'Recipe', 'Ghi chép bữa ăn lành mạnh', now() - interval '1 days', NULL, false),
('7026da36-2876-43a1-a5e6-254a4e1ab615', 'ffffffff-ffff-ffff-ffff-ffffffffffff', 'fd000010-0000-0000-0000-000000000010', 'ec000003-0000-0000-0000-000000000003', 'Breakfast', 300, 1140.00, 69.00, 28.50, 84.00, 'Food', 'Ghi chép bữa ăn lành mạnh', now() - interval '2 days', NULL, false),
('3f30cb37-70b3-4ddb-850f-7ff336831c55', 'ffffffff-ffff-ffff-ffff-ffffffffffff', 'fd000008-0000-0000-0000-000000000008', 'ec000003-0000-0000-0000-000000000003', 'Lunch', 200, 500.00, 23.00, 56.00, 17.00, 'Recipe', 'Ghi chép bữa ăn lành mạnh', now() - interval '2 days', NULL, false),
('5d107b2b-f0da-467c-a82a-967cb980e164', 'ffffffff-ffff-ffff-ffff-ffffffffffff', 'fd000005-0000-0000-0000-000000000005', 'ec000004-0000-0000-0000-000000000004', 'Dinner', 150, 675.00, 18.00, 78.00, 33.00, 'Recipe', 'Ghi chép bữa ăn lành mạnh', now() - interval '2 days', NULL, false),
('a93bcf69-e076-4ff0-901b-fda051f99848', 'ffffffff-ffff-ffff-ffff-ffffffffffff', 'fd000007-0000-0000-0000-000000000007', 'ec000004-0000-0000-0000-000000000004', 'Breakfast', 150, 525.00, 37.50, 7.50, 36.00, 'Recipe', 'Ghi chép bữa ăn lành mạnh', now() - interval '3 days', NULL, false),
('afb62751-4cc1-433f-90d6-2e3706d53d54', 'ffffffff-ffff-ffff-ffff-ffffffffffff', 'fd000003-0000-0000-0000-000000000003', 'ec000002-0000-0000-0000-000000000002', 'Lunch', 250, 800.00, 71.25, 30.00, 46.25, 'Recipe', 'Ghi chép bữa ăn lành mạnh', now() - interval '3 days', NULL, false),
('a2d726a4-a190-419f-af36-ab8899aef10d', 'ffffffff-ffff-ffff-ffff-ffffffffffff', 'fd000004-0000-0000-0000-000000000004', 'ec000001-0000-0000-0000-000000000001', 'Dinner', 300, 258.00, 4.80, 60.30, 0.30, 'Recipe', 'Ghi chép bữa ăn lành mạnh', now() - interval '3 days', NULL, false),
('0cc5d3de-10fd-40d3-a12c-6c7e901fa817', 'ffffffff-ffff-ffff-ffff-ffffffffffff', 'fd000009-0000-0000-0000-000000000009', 'ec000004-0000-0000-0000-000000000004', 'Breakfast', 300, 540.00, 36.00, 25.50, 30.00, 'Food', 'Ghi chép bữa ăn lành mạnh', now() - interval '4 days', NULL, false),
('46f9631a-8f65-4619-a0ad-9f05b86c8cde', 'ffffffff-ffff-ffff-ffff-ffffffffffff', 'fd000005-0000-0000-0000-000000000005', 'ec000004-0000-0000-0000-000000000004', 'Lunch', 250, 1125.00, 30.00, 130.00, 55.00, 'Recipe', 'Ghi chép bữa ăn lành mạnh', now() - interval '4 days', NULL, false),
('c13aff74-ed86-411f-a068-a5e389320b54', 'ffffffff-ffff-ffff-ffff-ffffffffffff', 'fd000010-0000-0000-0000-000000000010', 'ec000001-0000-0000-0000-000000000001', 'Dinner', 200, 760.00, 46.00, 19.00, 56.00, 'Recipe', 'Ghi chép bữa ăn lành mạnh', now() - interval '4 days', NULL, false),
('c4e669e1-0d0a-4a87-bb4b-b5fc4e54c390', 'ffffffff-ffff-ffff-ffff-ffffffffffff', 'fd000005-0000-0000-0000-000000000005', 'ec000001-0000-0000-0000-000000000001', 'Breakfast', 200, 900.00, 24.00, 104.00, 44.00, 'Recipe', 'Ghi chép bữa ăn lành mạnh', now() - interval '5 days', NULL, false),
('9ddc33f6-d178-4bba-9349-bd1cce0b6292', 'ffffffff-ffff-ffff-ffff-ffffffffffff', 'fd000003-0000-0000-0000-000000000003', 'ec000001-0000-0000-0000-000000000001', 'Lunch', 200, 640.00, 57.00, 24.00, 37.00, 'Recipe', 'Ghi chép bữa ăn lành mạnh', now() - interval '5 days', NULL, false),
('961e5594-0e44-4500-8429-c6cf4b2f22e8', 'ffffffff-ffff-ffff-ffff-ffffffffffff', 'fd000007-0000-0000-0000-000000000007', 'ec000004-0000-0000-0000-000000000004', 'Dinner', 300, 1050.00, 75.00, 15.00, 72.00, 'Food', 'Ghi chép bữa ăn lành mạnh', now() - interval '5 days', NULL, false),
('ca4adc70-abe1-4c2a-bce2-2f8432fb5ec4', '885810e8-168f-4608-a72e-e23a20dfd258', 'fd000001-0000-0000-0000-000000000001', 'ec000002-0000-0000-0000-000000000002', 'Breakfast', 250, 412.50, 77.50, 0.00, 9.00, 'Food', 'Ghi chép bữa ăn lành mạnh', now() - interval '1 days', NULL, false),
('9599625e-43c9-49e6-ae82-19bff743c95b', '885810e8-168f-4608-a72e-e23a20dfd258', 'fd000008-0000-0000-0000-000000000008', 'ec000001-0000-0000-0000-000000000001', 'Lunch', 200, 500.00, 23.00, 56.00, 17.00, 'Food', 'Ghi chép bữa ăn lành mạnh', now() - interval '1 days', NULL, false),
('39ba3a97-ddd9-48ce-b706-76690677b03d', '885810e8-168f-4608-a72e-e23a20dfd258', 'fd000010-0000-0000-0000-000000000010', 'ec000002-0000-0000-0000-000000000002', 'Dinner', 300, 1140.00, 69.00, 28.50, 84.00, 'Recipe', 'Ghi chép bữa ăn lành mạnh', now() - interval '1 days', NULL, false),
('2c68d8d9-12b7-4cff-87ae-87d8cacfc9c7', '885810e8-168f-4608-a72e-e23a20dfd258', 'fd000009-0000-0000-0000-000000000009', 'ec000002-0000-0000-0000-000000000002', 'Breakfast', 200, 360.00, 24.00, 17.00, 20.00, 'Food', 'Ghi chép bữa ăn lành mạnh', now() - interval '2 days', NULL, false),
('c865346b-8b8b-4111-bf8f-7c4167b6f36f', '885810e8-168f-4608-a72e-e23a20dfd258', 'fd000003-0000-0000-0000-000000000003', 'ec000001-0000-0000-0000-000000000001', 'Lunch', 150, 480.00, 42.75, 18.00, 27.75, 'Recipe', 'Ghi chép bữa ăn lành mạnh', now() - interval '2 days', NULL, false),
('8f9ff30c-ed8a-4a60-b67a-28f4a2c8e197', '885810e8-168f-4608-a72e-e23a20dfd258', 'fd000005-0000-0000-0000-000000000005', 'ec000003-0000-0000-0000-000000000003', 'Dinner', 300, 1350.00, 36.00, 156.00, 66.00, 'Recipe', 'Ghi chép bữa ăn lành mạnh', now() - interval '2 days', NULL, false),
('3984863b-949d-499d-bd1b-33c649e165f8', '885810e8-168f-4608-a72e-e23a20dfd258', 'fd000008-0000-0000-0000-000000000008', 'ec000003-0000-0000-0000-000000000003', 'Breakfast', 300, 750.00, 34.50, 84.00, 25.50, 'Food', 'Ghi chép bữa ăn lành mạnh', now() - interval '3 days', NULL, false),
('2ac5b3b7-0d76-4290-8159-9720cee9d777', '885810e8-168f-4608-a72e-e23a20dfd258', 'fd000009-0000-0000-0000-000000000009', 'ec000004-0000-0000-0000-000000000004', 'Lunch', 300, 540.00, 36.00, 25.50, 30.00, 'Recipe', 'Ghi chép bữa ăn lành mạnh', now() - interval '3 days', NULL, false),
('97dbc9ab-e9a3-4212-9b10-3cd50c57f732', '885810e8-168f-4608-a72e-e23a20dfd258', 'fd000010-0000-0000-0000-000000000010', 'ec000001-0000-0000-0000-000000000001', 'Dinner', 300, 1140.00, 69.00, 28.50, 84.00, 'Food', 'Ghi chép bữa ăn lành mạnh', now() - interval '3 days', NULL, false),
('c8dfb6fa-e45f-446f-8c6c-1523e4d2c02d', '885810e8-168f-4608-a72e-e23a20dfd258', 'fd000010-0000-0000-0000-000000000010', 'ec000003-0000-0000-0000-000000000003', 'Breakfast', 150, 570.00, 34.50, 14.25, 42.00, 'Recipe', 'Ghi chép bữa ăn lành mạnh', now() - interval '4 days', NULL, false),
('dfc447c6-bc1e-4f8c-af6c-7b085d08e2b0', '885810e8-168f-4608-a72e-e23a20dfd258', 'fd000004-0000-0000-0000-000000000004', 'ec000001-0000-0000-0000-000000000001', 'Lunch', 250, 215.00, 4.00, 50.25, 0.25, 'Recipe', 'Ghi chép bữa ăn lành mạnh', now() - interval '4 days', NULL, false),
('a6f4928c-9994-4c6d-ad7e-685bbff4af7c', '885810e8-168f-4608-a72e-e23a20dfd258', 'fd000003-0000-0000-0000-000000000003', 'ec000004-0000-0000-0000-000000000004', 'Dinner', 300, 960.00, 85.50, 36.00, 55.50, 'Food', 'Ghi chép bữa ăn lành mạnh', now() - interval '4 days', NULL, false),
('0304cbb0-8f78-4a72-94d3-829da9941806', '885810e8-168f-4608-a72e-e23a20dfd258', 'fd000003-0000-0000-0000-000000000003', 'ec000004-0000-0000-0000-000000000004', 'Breakfast', 300, 960.00, 85.50, 36.00, 55.50, 'Recipe', 'Ghi chép bữa ăn lành mạnh', now() - interval '5 days', NULL, false),
('8382b1b3-e43a-44a3-bab1-33376fc30cb8', '885810e8-168f-4608-a72e-e23a20dfd258', 'fd000008-0000-0000-0000-000000000008', 'ec000003-0000-0000-0000-000000000003', 'Lunch', 300, 750.00, 34.50, 84.00, 25.50, 'Food', 'Ghi chép bữa ăn lành mạnh', now() - interval '5 days', NULL, false),
('0d27d6ca-fffb-4cbe-9e4b-d82f4dd851be', '885810e8-168f-4608-a72e-e23a20dfd258', 'fd000006-0000-0000-0000-000000000006', 'ec000001-0000-0000-0000-000000000001', 'Dinner', 200, 580.00, 64.00, 13.20, 29.00, 'Food', 'Ghi chép bữa ăn lành mạnh', now() - interval '5 days', NULL, false),
('5984a17b-a613-4cce-bae4-11d48a758403', '48069bd5-f29a-417d-bdeb-c00797968aca', 'fd000007-0000-0000-0000-000000000007', 'ec000004-0000-0000-0000-000000000004', 'Breakfast', 250, 875.00, 62.50, 12.50, 60.00, 'Food', 'Ghi chép bữa ăn lành mạnh', now() - interval '1 days', NULL, false),
('fb523cd0-8954-4e4f-9a2f-9accef5197ca', '48069bd5-f29a-417d-bdeb-c00797968aca', 'fd000009-0000-0000-0000-000000000009', 'ec000001-0000-0000-0000-000000000001', 'Lunch', 300, 540.00, 36.00, 25.50, 30.00, 'Recipe', 'Ghi chép bữa ăn lành mạnh', now() - interval '1 days', NULL, false),
('b58d7071-38a9-4ecc-9d72-b2a341191393', '48069bd5-f29a-417d-bdeb-c00797968aca', 'fd000006-0000-0000-0000-000000000006', 'ec000003-0000-0000-0000-000000000003', 'Dinner', 250, 725.00, 80.00, 16.50, 36.25, 'Recipe', 'Ghi chép bữa ăn lành mạnh', now() - interval '1 days', NULL, false),
('169b199b-cb22-4599-b50b-d98a1fe6ad84', '48069bd5-f29a-417d-bdeb-c00797968aca', 'fd000007-0000-0000-0000-000000000007', 'ec000001-0000-0000-0000-000000000001', 'Breakfast', 300, 1050.00, 75.00, 15.00, 72.00, 'Food', 'Ghi chép bữa ăn lành mạnh', now() - interval '2 days', NULL, false),
('ac43b2d4-fc81-466c-acfd-aaedf15164cf', '48069bd5-f29a-417d-bdeb-c00797968aca', 'fd000001-0000-0000-0000-000000000001', 'ec000002-0000-0000-0000-000000000002', 'Lunch', 250, 412.50, 77.50, 0.00, 9.00, 'Food', 'Ghi chép bữa ăn lành mạnh', now() - interval '2 days', NULL, false),
('ce2b6446-2407-49a2-9ee0-374cb657f6c8', '48069bd5-f29a-417d-bdeb-c00797968aca', 'fd000008-0000-0000-0000-000000000008', 'ec000001-0000-0000-0000-000000000001', 'Dinner', 200, 500.00, 23.00, 56.00, 17.00, 'Food', 'Ghi chép bữa ăn lành mạnh', now() - interval '2 days', NULL, false),
('9450bfac-db9e-43ff-97e3-773cd72b4a8a', '48069bd5-f29a-417d-bdeb-c00797968aca', 'fd000009-0000-0000-0000-000000000009', 'ec000002-0000-0000-0000-000000000002', 'Breakfast', 250, 450.00, 30.00, 21.25, 25.00, 'Food', 'Ghi chép bữa ăn lành mạnh', now() - interval '3 days', NULL, false),
('3745040a-f638-495e-a7ef-30d271c0e75c', '48069bd5-f29a-417d-bdeb-c00797968aca', 'fd000008-0000-0000-0000-000000000008', 'ec000001-0000-0000-0000-000000000001', 'Lunch', 150, 375.00, 17.25, 42.00, 12.75, 'Recipe', 'Ghi chép bữa ăn lành mạnh', now() - interval '3 days', NULL, false),
('58864b3d-9e02-4b5b-a60a-0b428cbe1e81', '48069bd5-f29a-417d-bdeb-c00797968aca', 'fd000003-0000-0000-0000-000000000003', 'ec000003-0000-0000-0000-000000000003', 'Dinner', 150, 480.00, 42.75, 18.00, 27.75, 'Food', 'Ghi chép bữa ăn lành mạnh', now() - interval '3 days', NULL, false),
('472f7619-22e1-47b3-8108-353df11d2135', '48069bd5-f29a-417d-bdeb-c00797968aca', 'fd000002-0000-0000-0000-000000000002', 'ec000002-0000-0000-0000-000000000002', 'Breakfast', 150, 166.50, 3.90, 34.50, 1.35, 'Food', 'Ghi chép bữa ăn lành mạnh', now() - interval '4 days', NULL, false),
('7ef9aa37-8248-4878-8aff-c70a9d835ff1', '48069bd5-f29a-417d-bdeb-c00797968aca', 'fd000002-0000-0000-0000-000000000002', 'ec000002-0000-0000-0000-000000000002', 'Lunch', 300, 333.00, 7.80, 69.00, 2.70, 'Food', 'Ghi chép bữa ăn lành mạnh', now() - interval '4 days', NULL, false),
('9c2e1a30-b8df-4f0e-8464-94a2fb22a3cd', '48069bd5-f29a-417d-bdeb-c00797968aca', 'fd000009-0000-0000-0000-000000000009', 'ec000003-0000-0000-0000-000000000003', 'Dinner', 300, 540.00, 36.00, 25.50, 30.00, 'Food', 'Ghi chép bữa ăn lành mạnh', now() - interval '4 days', NULL, false),
('711db6d8-12d4-4bdf-af4b-13824cec21f5', '48069bd5-f29a-417d-bdeb-c00797968aca', 'fd000008-0000-0000-0000-000000000008', 'ec000002-0000-0000-0000-000000000002', 'Breakfast', 300, 750.00, 34.50, 84.00, 25.50, 'Recipe', 'Ghi chép bữa ăn lành mạnh', now() - interval '5 days', NULL, false),
('a293a6cf-ea2e-4769-b3a0-693e080de223', '48069bd5-f29a-417d-bdeb-c00797968aca', 'fd000007-0000-0000-0000-000000000007', 'ec000002-0000-0000-0000-000000000002', 'Lunch', 200, 700.00, 50.00, 10.00, 48.00, 'Recipe', 'Ghi chép bữa ăn lành mạnh', now() - interval '5 days', NULL, false),
('f8d0566b-a593-4c9b-8eb1-c254b9ddd27b', '48069bd5-f29a-417d-bdeb-c00797968aca', 'fd000005-0000-0000-0000-000000000005', 'ec000004-0000-0000-0000-000000000004', 'Dinner', 250, 1125.00, 30.00, 130.00, 55.00, 'Food', 'Ghi chép bữa ăn lành mạnh', now() - interval '5 days', NULL, false),
('d70a6d3e-041b-449d-b5b9-36edfb2f8096', '9afb13a5-e5a1-4342-9ce1-33bf7cc1de70', 'fd000001-0000-0000-0000-000000000001', 'ec000003-0000-0000-0000-000000000003', 'Breakfast', 250, 412.50, 77.50, 0.00, 9.00, 'Food', 'Ghi chép bữa ăn lành mạnh', now() - interval '1 days', NULL, false),
('3a24fa88-c723-4986-a918-0ab232da1cdc', '9afb13a5-e5a1-4342-9ce1-33bf7cc1de70', 'fd000003-0000-0000-0000-000000000003', 'ec000004-0000-0000-0000-000000000004', 'Lunch', 300, 960.00, 85.50, 36.00, 55.50, 'Food', 'Ghi chép bữa ăn lành mạnh', now() - interval '1 days', NULL, false),
('59eb8504-3553-433d-bed8-b8d434afdd96', '9afb13a5-e5a1-4342-9ce1-33bf7cc1de70', 'fd000006-0000-0000-0000-000000000006', 'ec000004-0000-0000-0000-000000000004', 'Dinner', 300, 870.00, 96.00, 19.80, 43.50, 'Food', 'Ghi chép bữa ăn lành mạnh', now() - interval '1 days', NULL, false),
('69f5fcbf-b599-4c5d-8dee-b9a63a8c1311', '9afb13a5-e5a1-4342-9ce1-33bf7cc1de70', 'fd000004-0000-0000-0000-000000000004', 'ec000002-0000-0000-0000-000000000002', 'Breakfast', 300, 258.00, 4.80, 60.30, 0.30, 'Recipe', 'Ghi chép bữa ăn lành mạnh', now() - interval '2 days', NULL, false),
('fb286401-a457-469a-89a2-b37085cf9309', '9afb13a5-e5a1-4342-9ce1-33bf7cc1de70', 'fd000007-0000-0000-0000-000000000007', 'ec000001-0000-0000-0000-000000000001', 'Lunch', 250, 875.00, 62.50, 12.50, 60.00, 'Food', 'Ghi chép bữa ăn lành mạnh', now() - interval '2 days', NULL, false),
('4fb509c0-1125-4edc-84de-6c4f36e6928d', '9afb13a5-e5a1-4342-9ce1-33bf7cc1de70', 'fd000007-0000-0000-0000-000000000007', 'ec000004-0000-0000-0000-000000000004', 'Dinner', 200, 700.00, 50.00, 10.00, 48.00, 'Food', 'Ghi chép bữa ăn lành mạnh', now() - interval '2 days', NULL, false),
('575939c8-57e0-49c2-8814-bcb826be5252', '9afb13a5-e5a1-4342-9ce1-33bf7cc1de70', 'fd000001-0000-0000-0000-000000000001', 'ec000002-0000-0000-0000-000000000002', 'Breakfast', 250, 412.50, 77.50, 0.00, 9.00, 'Recipe', 'Ghi chép bữa ăn lành mạnh', now() - interval '3 days', NULL, false),
('128cfbfb-8e00-462d-8289-b47e15598894', '9afb13a5-e5a1-4342-9ce1-33bf7cc1de70', 'fd000008-0000-0000-0000-000000000008', 'ec000001-0000-0000-0000-000000000001', 'Lunch', 300, 750.00, 34.50, 84.00, 25.50, 'Recipe', 'Ghi chép bữa ăn lành mạnh', now() - interval '3 days', NULL, false),
('b4c7d4cd-2d37-49a5-a53f-64e9f5b9e26a', '9afb13a5-e5a1-4342-9ce1-33bf7cc1de70', 'fd000003-0000-0000-0000-000000000003', 'ec000004-0000-0000-0000-000000000004', 'Dinner', 200, 640.00, 57.00, 24.00, 37.00, 'Recipe', 'Ghi chép bữa ăn lành mạnh', now() - interval '3 days', NULL, false),
('85316538-eaec-4a61-abf6-3278c3f81fbf', '9afb13a5-e5a1-4342-9ce1-33bf7cc1de70', 'fd000008-0000-0000-0000-000000000008', 'ec000003-0000-0000-0000-000000000003', 'Breakfast', 250, 625.00, 28.75, 70.00, 21.25, 'Food', 'Ghi chép bữa ăn lành mạnh', now() - interval '4 days', NULL, false),
('d16fa819-fb0e-45fb-8387-8de9fbbf15b9', '9afb13a5-e5a1-4342-9ce1-33bf7cc1de70', 'fd000002-0000-0000-0000-000000000002', 'ec000003-0000-0000-0000-000000000003', 'Lunch', 300, 333.00, 7.80, 69.00, 2.70, 'Food', 'Ghi chép bữa ăn lành mạnh', now() - interval '4 days', NULL, false),
('c733440e-12a5-463c-abd3-e92ccd547f19', '9afb13a5-e5a1-4342-9ce1-33bf7cc1de70', 'fd000008-0000-0000-0000-000000000008', 'ec000001-0000-0000-0000-000000000001', 'Dinner', 150, 375.00, 17.25, 42.00, 12.75, 'Recipe', 'Ghi chép bữa ăn lành mạnh', now() - interval '4 days', NULL, false),
('99022dec-e6a1-41df-a85c-4a7e49042687', '9afb13a5-e5a1-4342-9ce1-33bf7cc1de70', 'fd000005-0000-0000-0000-000000000005', 'ec000002-0000-0000-0000-000000000002', 'Breakfast', 150, 675.00, 18.00, 78.00, 33.00, 'Food', 'Ghi chép bữa ăn lành mạnh', now() - interval '5 days', NULL, false),
('b3bd27a2-007e-4131-a30c-af1fc29f9aa3', '9afb13a5-e5a1-4342-9ce1-33bf7cc1de70', 'fd000002-0000-0000-0000-000000000002', 'ec000001-0000-0000-0000-000000000001', 'Lunch', 300, 333.00, 7.80, 69.00, 2.70, 'Recipe', 'Ghi chép bữa ăn lành mạnh', now() - interval '5 days', NULL, false),
('9143cf62-72f3-4de7-9fca-de7a5a67a16c', '9afb13a5-e5a1-4342-9ce1-33bf7cc1de70', 'fd000005-0000-0000-0000-000000000005', 'ec000001-0000-0000-0000-000000000001', 'Dinner', 150, 675.00, 18.00, 78.00, 33.00, 'Food', 'Ghi chép bữa ăn lành mạnh', now() - interval '5 days', NULL, false),
('1d151dce-45e8-470d-91e9-bb001adfe1be', '081b4669-b97f-4e75-b089-4c8de0151653', 'fd000001-0000-0000-0000-000000000001', 'ec000003-0000-0000-0000-000000000003', 'Breakfast', 250, 412.50, 77.50, 0.00, 9.00, 'Food', 'Ghi chép bữa ăn lành mạnh', now() - interval '1 days', NULL, false),
('11f16b15-ac24-4593-baf7-b59bbc68fcd2', '081b4669-b97f-4e75-b089-4c8de0151653', 'fd000007-0000-0000-0000-000000000007', 'ec000002-0000-0000-0000-000000000002', 'Lunch', 200, 700.00, 50.00, 10.00, 48.00, 'Food', 'Ghi chép bữa ăn lành mạnh', now() - interval '1 days', NULL, false),
('61f96d33-1d5b-4b0d-9111-9a98edab02cb', '081b4669-b97f-4e75-b089-4c8de0151653', 'fd000010-0000-0000-0000-000000000010', 'ec000002-0000-0000-0000-000000000002', 'Dinner', 200, 760.00, 46.00, 19.00, 56.00, 'Recipe', 'Ghi chép bữa ăn lành mạnh', now() - interval '1 days', NULL, false),
('def3491a-700c-4de3-9461-876efd1932ef', '081b4669-b97f-4e75-b089-4c8de0151653', 'fd000002-0000-0000-0000-000000000002', 'ec000004-0000-0000-0000-000000000004', 'Breakfast', 200, 222.00, 5.20, 46.00, 1.80, 'Food', 'Ghi chép bữa ăn lành mạnh', now() - interval '2 days', NULL, false),
('9b017971-b27b-40b9-9daa-a17ee8b1e722', '081b4669-b97f-4e75-b089-4c8de0151653', 'fd000010-0000-0000-0000-000000000010', 'ec000002-0000-0000-0000-000000000002', 'Lunch', 200, 760.00, 46.00, 19.00, 56.00, 'Food', 'Ghi chép bữa ăn lành mạnh', now() - interval '2 days', NULL, false),
('2a860371-cac3-402c-a801-1903cd902198', '081b4669-b97f-4e75-b089-4c8de0151653', 'fd000005-0000-0000-0000-000000000005', 'ec000004-0000-0000-0000-000000000004', 'Dinner', 250, 1125.00, 30.00, 130.00, 55.00, 'Recipe', 'Ghi chép bữa ăn lành mạnh', now() - interval '2 days', NULL, false),
('ceeef264-4739-4adf-894b-c12486785415', '081b4669-b97f-4e75-b089-4c8de0151653', 'fd000008-0000-0000-0000-000000000008', 'ec000003-0000-0000-0000-000000000003', 'Breakfast', 200, 500.00, 23.00, 56.00, 17.00, 'Recipe', 'Ghi chép bữa ăn lành mạnh', now() - interval '3 days', NULL, false),
('6f3e97c5-5b52-4bc4-b394-0e87d77d205b', '081b4669-b97f-4e75-b089-4c8de0151653', 'fd000008-0000-0000-0000-000000000008', 'ec000003-0000-0000-0000-000000000003', 'Lunch', 250, 625.00, 28.75, 70.00, 21.25, 'Food', 'Ghi chép bữa ăn lành mạnh', now() - interval '3 days', NULL, false),
('8509472e-9d36-46ab-95d2-cfdf935e1072', '081b4669-b97f-4e75-b089-4c8de0151653', 'fd000005-0000-0000-0000-000000000005', 'ec000004-0000-0000-0000-000000000004', 'Dinner', 250, 1125.00, 30.00, 130.00, 55.00, 'Recipe', 'Ghi chép bữa ăn lành mạnh', now() - interval '3 days', NULL, false),
('21282c6b-01e9-4265-95e3-eea012791a70', '081b4669-b97f-4e75-b089-4c8de0151653', 'fd000007-0000-0000-0000-000000000007', 'ec000004-0000-0000-0000-000000000004', 'Breakfast', 150, 525.00, 37.50, 7.50, 36.00, 'Recipe', 'Ghi chép bữa ăn lành mạnh', now() - interval '4 days', NULL, false),
('f297e26f-7329-4658-8684-3d0234254728', '081b4669-b97f-4e75-b089-4c8de0151653', 'fd000007-0000-0000-0000-000000000007', 'ec000003-0000-0000-0000-000000000003', 'Lunch', 250, 875.00, 62.50, 12.50, 60.00, 'Food', 'Ghi chép bữa ăn lành mạnh', now() - interval '4 days', NULL, false),
('9d776a7b-f6ba-4b82-908a-4c5ee48b6fef', '081b4669-b97f-4e75-b089-4c8de0151653', 'fd000001-0000-0000-0000-000000000001', 'ec000004-0000-0000-0000-000000000004', 'Dinner', 250, 412.50, 77.50, 0.00, 9.00, 'Recipe', 'Ghi chép bữa ăn lành mạnh', now() - interval '4 days', NULL, false),
('638a7f55-5c0e-4b10-85be-1565ce384175', '081b4669-b97f-4e75-b089-4c8de0151653', 'fd000010-0000-0000-0000-000000000010', 'ec000001-0000-0000-0000-000000000001', 'Breakfast', 300, 1140.00, 69.00, 28.50, 84.00, 'Food', 'Ghi chép bữa ăn lành mạnh', now() - interval '5 days', NULL, false),
('14eb6bc4-6628-44a7-8049-82a140437e24', '081b4669-b97f-4e75-b089-4c8de0151653', 'fd000004-0000-0000-0000-000000000004', 'ec000003-0000-0000-0000-000000000003', 'Lunch', 200, 172.00, 3.20, 40.20, 0.20, 'Recipe', 'Ghi chép bữa ăn lành mạnh', now() - interval '5 days', NULL, false),
('5ac53ca8-8cd3-4e5e-950a-025a0037dee6', '081b4669-b97f-4e75-b089-4c8de0151653', 'fd000010-0000-0000-0000-000000000010', 'ec000003-0000-0000-0000-000000000003', 'Dinner', 200, 760.00, 46.00, 19.00, 56.00, 'Recipe', 'Ghi chép bữa ăn lành mạnh', now() - interval '5 days', NULL, false),
('9f0c9d9d-7f7d-4b16-80ff-52d79063d17d', '586209d0-d3c4-43a4-bba7-5d4c73b37bc1', 'fd000001-0000-0000-0000-000000000001', 'ec000003-0000-0000-0000-000000000003', 'Breakfast', 300, 495.00, 93.00, 0.00, 10.80, 'Recipe', 'Ghi chép bữa ăn lành mạnh', now() - interval '1 days', NULL, false),
('d455b894-019f-47b1-ab48-a98016e68adf', '586209d0-d3c4-43a4-bba7-5d4c73b37bc1', 'fd000010-0000-0000-0000-000000000010', 'ec000003-0000-0000-0000-000000000003', 'Lunch', 200, 760.00, 46.00, 19.00, 56.00, 'Recipe', 'Ghi chép bữa ăn lành mạnh', now() - interval '1 days', NULL, false),
('baea31a6-b62f-4415-ac2b-0405b7377e5b', '586209d0-d3c4-43a4-bba7-5d4c73b37bc1', 'fd000005-0000-0000-0000-000000000005', 'ec000003-0000-0000-0000-000000000003', 'Dinner', 300, 1350.00, 36.00, 156.00, 66.00, 'Recipe', 'Ghi chép bữa ăn lành mạnh', now() - interval '1 days', NULL, false),
('e34ec04e-a87d-4c9d-b028-f09924b95b22', '586209d0-d3c4-43a4-bba7-5d4c73b37bc1', 'fd000004-0000-0000-0000-000000000004', 'ec000002-0000-0000-0000-000000000002', 'Breakfast', 250, 215.00, 4.00, 50.25, 0.25, 'Food', 'Ghi chép bữa ăn lành mạnh', now() - interval '2 days', NULL, false),
('e52e040e-742a-43c4-bc57-984a779f7c45', '586209d0-d3c4-43a4-bba7-5d4c73b37bc1', 'fd000003-0000-0000-0000-000000000003', 'ec000003-0000-0000-0000-000000000003', 'Lunch', 300, 960.00, 85.50, 36.00, 55.50, 'Food', 'Ghi chép bữa ăn lành mạnh', now() - interval '2 days', NULL, false),
('9cf0a951-ed04-4d61-a1ac-acaf962f3d28', '586209d0-d3c4-43a4-bba7-5d4c73b37bc1', 'fd000006-0000-0000-0000-000000000006', 'ec000001-0000-0000-0000-000000000001', 'Dinner', 300, 870.00, 96.00, 19.80, 43.50, 'Recipe', 'Ghi chép bữa ăn lành mạnh', now() - interval '2 days', NULL, false),
('2d1c0726-9cd3-42be-914f-bd5ebd629a21', '586209d0-d3c4-43a4-bba7-5d4c73b37bc1', 'fd000003-0000-0000-0000-000000000003', 'ec000002-0000-0000-0000-000000000002', 'Breakfast', 300, 960.00, 85.50, 36.00, 55.50, 'Food', 'Ghi chép bữa ăn lành mạnh', now() - interval '3 days', NULL, false),
('e97b02bd-7329-4b69-99d9-c0f0cb5ee461', '586209d0-d3c4-43a4-bba7-5d4c73b37bc1', 'fd000002-0000-0000-0000-000000000002', 'ec000004-0000-0000-0000-000000000004', 'Lunch', 150, 166.50, 3.90, 34.50, 1.35, 'Food', 'Ghi chép bữa ăn lành mạnh', now() - interval '3 days', NULL, false),
('ecc5616b-5e62-4cdc-8ff8-644e2ad94c99', '586209d0-d3c4-43a4-bba7-5d4c73b37bc1', 'fd000009-0000-0000-0000-000000000009', 'ec000001-0000-0000-0000-000000000001', 'Dinner', 300, 540.00, 36.00, 25.50, 30.00, 'Food', 'Ghi chép bữa ăn lành mạnh', now() - interval '3 days', NULL, false),
('c9aca8f8-df9a-4bae-99de-6b97bd7b3a41', '586209d0-d3c4-43a4-bba7-5d4c73b37bc1', 'fd000005-0000-0000-0000-000000000005', 'ec000004-0000-0000-0000-000000000004', 'Breakfast', 250, 1125.00, 30.00, 130.00, 55.00, 'Recipe', 'Ghi chép bữa ăn lành mạnh', now() - interval '4 days', NULL, false),
('ced2b807-1584-42fb-8a32-cb8691d4c641', '586209d0-d3c4-43a4-bba7-5d4c73b37bc1', 'fd000004-0000-0000-0000-000000000004', 'ec000004-0000-0000-0000-000000000004', 'Lunch', 150, 129.00, 2.40, 30.15, 0.15, 'Food', 'Ghi chép bữa ăn lành mạnh', now() - interval '4 days', NULL, false),
('d3bc7899-fc21-4d15-8574-7a62052f35ca', '586209d0-d3c4-43a4-bba7-5d4c73b37bc1', 'fd000010-0000-0000-0000-000000000010', 'ec000002-0000-0000-0000-000000000002', 'Dinner', 150, 570.00, 34.50, 14.25, 42.00, 'Food', 'Ghi chép bữa ăn lành mạnh', now() - interval '4 days', NULL, false),
('359b11e9-3c89-4279-8c3c-8a18ab4b8de5', '586209d0-d3c4-43a4-bba7-5d4c73b37bc1', 'fd000005-0000-0000-0000-000000000005', 'ec000004-0000-0000-0000-000000000004', 'Breakfast', 150, 675.00, 18.00, 78.00, 33.00, 'Recipe', 'Ghi chép bữa ăn lành mạnh', now() - interval '5 days', NULL, false),
('359c46b7-297a-4340-b2cc-1bbd0359d554', '586209d0-d3c4-43a4-bba7-5d4c73b37bc1', 'fd000001-0000-0000-0000-000000000001', 'ec000001-0000-0000-0000-000000000001', 'Lunch', 250, 412.50, 77.50, 0.00, 9.00, 'Food', 'Ghi chép bữa ăn lành mạnh', now() - interval '5 days', NULL, false),
('fde702fb-1a39-425e-b4bf-916b30441b09', '586209d0-d3c4-43a4-bba7-5d4c73b37bc1', 'fd000002-0000-0000-0000-000000000002', 'ec000001-0000-0000-0000-000000000001', 'Dinner', 200, 222.00, 5.20, 46.00, 1.80, 'Recipe', 'Ghi chép bữa ăn lành mạnh', now() - interval '5 days', NULL, false),
('a975874d-58f8-4adf-ae55-6d288247323f', 'b022ccde-0aa6-4b11-bd7b-f76aaf2c2b17', 'fd000007-0000-0000-0000-000000000007', 'ec000004-0000-0000-0000-000000000004', 'Breakfast', 250, 875.00, 62.50, 12.50, 60.00, 'Food', 'Ghi chép bữa ăn lành mạnh', now() - interval '1 days', NULL, false),
('bec0a4e5-9f25-42a0-89fe-462f2e3430be', 'b022ccde-0aa6-4b11-bd7b-f76aaf2c2b17', 'fd000010-0000-0000-0000-000000000010', 'ec000002-0000-0000-0000-000000000002', 'Lunch', 300, 1140.00, 69.00, 28.50, 84.00, 'Recipe', 'Ghi chép bữa ăn lành mạnh', now() - interval '1 days', NULL, false),
('e33a318c-8866-489f-90b8-f33fdfd23655', 'b022ccde-0aa6-4b11-bd7b-f76aaf2c2b17', 'fd000008-0000-0000-0000-000000000008', 'ec000004-0000-0000-0000-000000000004', 'Dinner', 250, 625.00, 28.75, 70.00, 21.25, 'Recipe', 'Ghi chép bữa ăn lành mạnh', now() - interval '1 days', NULL, false),
('cf1bd6e3-3fab-40af-b3ec-577c09eec05f', 'b022ccde-0aa6-4b11-bd7b-f76aaf2c2b17', 'fd000006-0000-0000-0000-000000000006', 'ec000002-0000-0000-0000-000000000002', 'Breakfast', 300, 870.00, 96.00, 19.80, 43.50, 'Food', 'Ghi chép bữa ăn lành mạnh', now() - interval '2 days', NULL, false),
('697066f5-f568-4f59-89e9-8828829cd66a', 'b022ccde-0aa6-4b11-bd7b-f76aaf2c2b17', 'fd000004-0000-0000-0000-000000000004', 'ec000003-0000-0000-0000-000000000003', 'Lunch', 150, 129.00, 2.40, 30.15, 0.15, 'Food', 'Ghi chép bữa ăn lành mạnh', now() - interval '2 days', NULL, false),
('1eee61a4-f2d5-4577-825c-189b6fcb7417', 'b022ccde-0aa6-4b11-bd7b-f76aaf2c2b17', 'fd000009-0000-0000-0000-000000000009', 'ec000003-0000-0000-0000-000000000003', 'Dinner', 150, 270.00, 18.00, 12.75, 15.00, 'Food', 'Ghi chép bữa ăn lành mạnh', now() - interval '2 days', NULL, false),
('a0efb00a-e428-4355-b663-91b735baad94', 'b022ccde-0aa6-4b11-bd7b-f76aaf2c2b17', 'fd000005-0000-0000-0000-000000000005', 'ec000002-0000-0000-0000-000000000002', 'Breakfast', 150, 675.00, 18.00, 78.00, 33.00, 'Food', 'Ghi chép bữa ăn lành mạnh', now() - interval '3 days', NULL, false),
('b0c0ee86-de0c-4e95-aa6b-7fa7c3176d28', 'b022ccde-0aa6-4b11-bd7b-f76aaf2c2b17', 'fd000002-0000-0000-0000-000000000002', 'ec000002-0000-0000-0000-000000000002', 'Lunch', 150, 166.50, 3.90, 34.50, 1.35, 'Recipe', 'Ghi chép bữa ăn lành mạnh', now() - interval '3 days', NULL, false),
('3d96d1e5-50ec-47d2-baf2-d74b3fbdd399', 'b022ccde-0aa6-4b11-bd7b-f76aaf2c2b17', 'fd000006-0000-0000-0000-000000000006', 'ec000002-0000-0000-0000-000000000002', 'Dinner', 200, 580.00, 64.00, 13.20, 29.00, 'Recipe', 'Ghi chép bữa ăn lành mạnh', now() - interval '3 days', NULL, false),
('85d847ab-5c1c-44c3-a15b-a094965a86d4', 'b022ccde-0aa6-4b11-bd7b-f76aaf2c2b17', 'fd000002-0000-0000-0000-000000000002', 'ec000002-0000-0000-0000-000000000002', 'Breakfast', 200, 222.00, 5.20, 46.00, 1.80, 'Recipe', 'Ghi chép bữa ăn lành mạnh', now() - interval '4 days', NULL, false),
('df610986-8722-498a-be85-35086c2b56d2', 'b022ccde-0aa6-4b11-bd7b-f76aaf2c2b17', 'fd000006-0000-0000-0000-000000000006', 'ec000002-0000-0000-0000-000000000002', 'Lunch', 150, 435.00, 48.00, 9.90, 21.75, 'Food', 'Ghi chép bữa ăn lành mạnh', now() - interval '4 days', NULL, false),
('4cb5a2bf-19f2-4e9d-b79f-1e2fadf91892', 'b022ccde-0aa6-4b11-bd7b-f76aaf2c2b17', 'fd000003-0000-0000-0000-000000000003', 'ec000002-0000-0000-0000-000000000002', 'Dinner', 250, 800.00, 71.25, 30.00, 46.25, 'Recipe', 'Ghi chép bữa ăn lành mạnh', now() - interval '4 days', NULL, false),
('e8a4f3c3-01b4-4d7d-b7da-1c974dbf2d84', 'b022ccde-0aa6-4b11-bd7b-f76aaf2c2b17', 'fd000002-0000-0000-0000-000000000002', 'ec000001-0000-0000-0000-000000000001', 'Breakfast', 200, 222.00, 5.20, 46.00, 1.80, 'Recipe', 'Ghi chép bữa ăn lành mạnh', now() - interval '5 days', NULL, false),
('0c2985d4-8dd5-40d9-b6a0-5a35a8067d55', 'b022ccde-0aa6-4b11-bd7b-f76aaf2c2b17', 'fd000006-0000-0000-0000-000000000006', 'ec000002-0000-0000-0000-000000000002', 'Lunch', 250, 725.00, 80.00, 16.50, 36.25, 'Recipe', 'Ghi chép bữa ăn lành mạnh', now() - interval '5 days', NULL, false),
('65613e65-b278-430b-b8eb-fe416e4c7cbd', 'b022ccde-0aa6-4b11-bd7b-f76aaf2c2b17', 'fd000003-0000-0000-0000-000000000003', 'ec000003-0000-0000-0000-000000000003', 'Dinner', 150, 480.00, 42.75, 18.00, 27.75, 'Recipe', 'Ghi chép bữa ăn lành mạnh', now() - interval '5 days', NULL, false),
('e01ec5fd-dc56-46cd-91f7-5529b0a25040', '453681f7-f489-47ed-842c-bc3ffd220423', 'fd000007-0000-0000-0000-000000000007', 'ec000001-0000-0000-0000-000000000001', 'Breakfast', 150, 525.00, 37.50, 7.50, 36.00, 'Food', 'Ghi chép bữa ăn lành mạnh', now() - interval '1 days', NULL, false),
('71b99616-c62b-4423-9580-a98b8dc09665', '453681f7-f489-47ed-842c-bc3ffd220423', 'fd000008-0000-0000-0000-000000000008', 'ec000003-0000-0000-0000-000000000003', 'Lunch', 150, 375.00, 17.25, 42.00, 12.75, 'Food', 'Ghi chép bữa ăn lành mạnh', now() - interval '1 days', NULL, false),
('fd733750-6453-46b8-92b8-12ebf16e962c', '453681f7-f489-47ed-842c-bc3ffd220423', 'fd000009-0000-0000-0000-000000000009', 'ec000002-0000-0000-0000-000000000002', 'Dinner', 150, 270.00, 18.00, 12.75, 15.00, 'Food', 'Ghi chép bữa ăn lành mạnh', now() - interval '1 days', NULL, false),
('b74da185-917c-4c88-ae38-54c246936da1', '453681f7-f489-47ed-842c-bc3ffd220423', 'fd000008-0000-0000-0000-000000000008', 'ec000001-0000-0000-0000-000000000001', 'Breakfast', 150, 375.00, 17.25, 42.00, 12.75, 'Food', 'Ghi chép bữa ăn lành mạnh', now() - interval '2 days', NULL, false),
('98d5600c-29e2-42ae-9602-05e7b497574c', '453681f7-f489-47ed-842c-bc3ffd220423', 'fd000007-0000-0000-0000-000000000007', 'ec000004-0000-0000-0000-000000000004', 'Lunch', 150, 525.00, 37.50, 7.50, 36.00, 'Food', 'Ghi chép bữa ăn lành mạnh', now() - interval '2 days', NULL, false),
('72f6b7c7-44ea-44bf-af6c-0ec1c3b20ba8', '453681f7-f489-47ed-842c-bc3ffd220423', 'fd000008-0000-0000-0000-000000000008', 'ec000001-0000-0000-0000-000000000001', 'Dinner', 150, 375.00, 17.25, 42.00, 12.75, 'Food', 'Ghi chép bữa ăn lành mạnh', now() - interval '2 days', NULL, false),
('b4541178-9665-43ac-b5e5-93d4da66dbbd', '453681f7-f489-47ed-842c-bc3ffd220423', 'fd000010-0000-0000-0000-000000000010', 'ec000002-0000-0000-0000-000000000002', 'Breakfast', 150, 570.00, 34.50, 14.25, 42.00, 'Recipe', 'Ghi chép bữa ăn lành mạnh', now() - interval '3 days', NULL, false),
('1039e30b-a19f-4fda-b51d-f0dd1e3b52d1', '453681f7-f489-47ed-842c-bc3ffd220423', 'fd000005-0000-0000-0000-000000000005', 'ec000003-0000-0000-0000-000000000003', 'Lunch', 300, 1350.00, 36.00, 156.00, 66.00, 'Food', 'Ghi chép bữa ăn lành mạnh', now() - interval '3 days', NULL, false),
('505634b8-f855-4e21-bfc2-1040c66502b3', '453681f7-f489-47ed-842c-bc3ffd220423', 'fd000008-0000-0000-0000-000000000008', 'ec000004-0000-0000-0000-000000000004', 'Dinner', 150, 375.00, 17.25, 42.00, 12.75, 'Recipe', 'Ghi chép bữa ăn lành mạnh', now() - interval '3 days', NULL, false),
('30dc9d86-6fb6-4c25-ac4e-2bff84c0572a', '453681f7-f489-47ed-842c-bc3ffd220423', 'fd000009-0000-0000-0000-000000000009', 'ec000002-0000-0000-0000-000000000002', 'Breakfast', 300, 540.00, 36.00, 25.50, 30.00, 'Food', 'Ghi chép bữa ăn lành mạnh', now() - interval '4 days', NULL, false),
('42385cd5-6074-4fc6-9531-fded6efc3430', '453681f7-f489-47ed-842c-bc3ffd220423', 'fd000004-0000-0000-0000-000000000004', 'ec000004-0000-0000-0000-000000000004', 'Lunch', 250, 215.00, 4.00, 50.25, 0.25, 'Food', 'Ghi chép bữa ăn lành mạnh', now() - interval '4 days', NULL, false),
('a7b18b65-e871-4aaa-9e7d-3ad2f9e7b501', '453681f7-f489-47ed-842c-bc3ffd220423', 'fd000007-0000-0000-0000-000000000007', 'ec000004-0000-0000-0000-000000000004', 'Dinner', 150, 525.00, 37.50, 7.50, 36.00, 'Food', 'Ghi chép bữa ăn lành mạnh', now() - interval '4 days', NULL, false),
('cda8bf2b-cc27-422b-b381-d6ac239f676a', '453681f7-f489-47ed-842c-bc3ffd220423', 'fd000007-0000-0000-0000-000000000007', 'ec000003-0000-0000-0000-000000000003', 'Breakfast', 250, 875.00, 62.50, 12.50, 60.00, 'Food', 'Ghi chép bữa ăn lành mạnh', now() - interval '5 days', NULL, false),
('c8c2ed6a-c64a-4811-974f-2609a5ca32cc', '453681f7-f489-47ed-842c-bc3ffd220423', 'fd000003-0000-0000-0000-000000000003', 'ec000004-0000-0000-0000-000000000004', 'Lunch', 150, 480.00, 42.75, 18.00, 27.75, 'Recipe', 'Ghi chép bữa ăn lành mạnh', now() - interval '5 days', NULL, false),
('546de4d6-d45a-44b2-a2b5-ca507f4fe631', '453681f7-f489-47ed-842c-bc3ffd220423', 'fd000002-0000-0000-0000-000000000002', 'ec000001-0000-0000-0000-000000000001', 'Dinner', 300, 333.00, 7.80, 69.00, 2.70, 'Recipe', 'Ghi chép bữa ăn lành mạnh', now() - interval '5 days', NULL, false),
('e47414e6-071b-4ea6-b4e7-b5ab81e2d06c', '396f9dff-6c2a-422f-b0cc-8eb451168ed3', 'fd000006-0000-0000-0000-000000000006', 'ec000002-0000-0000-0000-000000000002', 'Breakfast', 150, 435.00, 48.00, 9.90, 21.75, 'Food', 'Ghi chép bữa ăn lành mạnh', now() - interval '1 days', NULL, false),
('8bbc6d79-412a-46e4-b901-d4e2f45f97ee', '396f9dff-6c2a-422f-b0cc-8eb451168ed3', 'fd000002-0000-0000-0000-000000000002', 'ec000004-0000-0000-0000-000000000004', 'Lunch', 250, 277.50, 6.50, 57.50, 2.25, 'Food', 'Ghi chép bữa ăn lành mạnh', now() - interval '1 days', NULL, false),
('aa3a7def-254f-470c-b06c-570af50b7bd1', '396f9dff-6c2a-422f-b0cc-8eb451168ed3', 'fd000001-0000-0000-0000-000000000001', 'ec000003-0000-0000-0000-000000000003', 'Dinner', 250, 412.50, 77.50, 0.00, 9.00, 'Food', 'Ghi chép bữa ăn lành mạnh', now() - interval '1 days', NULL, false),
('5444ebc0-019e-411c-a42f-57f52c995f33', '396f9dff-6c2a-422f-b0cc-8eb451168ed3', 'fd000002-0000-0000-0000-000000000002', 'ec000002-0000-0000-0000-000000000002', 'Breakfast', 200, 222.00, 5.20, 46.00, 1.80, 'Food', 'Ghi chép bữa ăn lành mạnh', now() - interval '2 days', NULL, false),
('ff490e8d-b639-4393-94e1-fe2f1a66ac7c', '396f9dff-6c2a-422f-b0cc-8eb451168ed3', 'fd000004-0000-0000-0000-000000000004', 'ec000001-0000-0000-0000-000000000001', 'Lunch', 250, 215.00, 4.00, 50.25, 0.25, 'Food', 'Ghi chép bữa ăn lành mạnh', now() - interval '2 days', NULL, false),
('ece48ccc-8941-4f15-b15f-d354144e2339', '396f9dff-6c2a-422f-b0cc-8eb451168ed3', 'fd000002-0000-0000-0000-000000000002', 'ec000003-0000-0000-0000-000000000003', 'Dinner', 200, 222.00, 5.20, 46.00, 1.80, 'Food', 'Ghi chép bữa ăn lành mạnh', now() - interval '2 days', NULL, false),
('c618b083-47f7-466d-a2de-8e1d1f2eeadc', '396f9dff-6c2a-422f-b0cc-8eb451168ed3', 'fd000009-0000-0000-0000-000000000009', 'ec000001-0000-0000-0000-000000000001', 'Breakfast', 250, 450.00, 30.00, 21.25, 25.00, 'Recipe', 'Ghi chép bữa ăn lành mạnh', now() - interval '3 days', NULL, false),
('9b4c51eb-b7d8-4cda-9577-62f2c2f1c37f', '396f9dff-6c2a-422f-b0cc-8eb451168ed3', 'fd000003-0000-0000-0000-000000000003', 'ec000003-0000-0000-0000-000000000003', 'Lunch', 250, 800.00, 71.25, 30.00, 46.25, 'Food', 'Ghi chép bữa ăn lành mạnh', now() - interval '3 days', NULL, false),
('7642275a-b72c-418b-8921-427ac1f79601', '396f9dff-6c2a-422f-b0cc-8eb451168ed3', 'fd000006-0000-0000-0000-000000000006', 'ec000001-0000-0000-0000-000000000001', 'Dinner', 200, 580.00, 64.00, 13.20, 29.00, 'Recipe', 'Ghi chép bữa ăn lành mạnh', now() - interval '3 days', NULL, false),
('9a5eb42a-8565-41e6-adf9-ac7d7e50925e', '396f9dff-6c2a-422f-b0cc-8eb451168ed3', 'fd000010-0000-0000-0000-000000000010', 'ec000004-0000-0000-0000-000000000004', 'Breakfast', 150, 570.00, 34.50, 14.25, 42.00, 'Recipe', 'Ghi chép bữa ăn lành mạnh', now() - interval '4 days', NULL, false),
('26fac867-d41e-4a1d-a23c-df75c21807a9', '396f9dff-6c2a-422f-b0cc-8eb451168ed3', 'fd000001-0000-0000-0000-000000000001', 'ec000001-0000-0000-0000-000000000001', 'Lunch', 200, 330.00, 62.00, 0.00, 7.20, 'Food', 'Ghi chép bữa ăn lành mạnh', now() - interval '4 days', NULL, false),
('0934dd87-9c19-4eb4-a138-b64ba88961bb', '396f9dff-6c2a-422f-b0cc-8eb451168ed3', 'fd000007-0000-0000-0000-000000000007', 'ec000004-0000-0000-0000-000000000004', 'Dinner', 250, 875.00, 62.50, 12.50, 60.00, 'Recipe', 'Ghi chép bữa ăn lành mạnh', now() - interval '4 days', NULL, false),
('d044ce56-7bd9-480a-96ff-721c9b668957', '396f9dff-6c2a-422f-b0cc-8eb451168ed3', 'fd000006-0000-0000-0000-000000000006', 'ec000003-0000-0000-0000-000000000003', 'Breakfast', 250, 725.00, 80.00, 16.50, 36.25, 'Recipe', 'Ghi chép bữa ăn lành mạnh', now() - interval '5 days', NULL, false),
('6a552b10-2f10-433c-b4c3-565d79d396e0', '396f9dff-6c2a-422f-b0cc-8eb451168ed3', 'fd000001-0000-0000-0000-000000000001', 'ec000002-0000-0000-0000-000000000002', 'Lunch', 200, 330.00, 62.00, 0.00, 7.20, 'Recipe', 'Ghi chép bữa ăn lành mạnh', now() - interval '5 days', NULL, false),
('19655d84-5560-4cfd-bfc9-8c54a86476f1', '396f9dff-6c2a-422f-b0cc-8eb451168ed3', 'fd000002-0000-0000-0000-000000000002', 'ec000003-0000-0000-0000-000000000003', 'Dinner', 300, 333.00, 7.80, 69.00, 2.70, 'Food', 'Ghi chép bữa ăn lành mạnh', now() - interval '5 days', NULL, false),
('e3b1bbdb-9e61-4022-b5af-63b8f914fd7b', '5dc50160-db9e-447a-ba33-9026d8800ab5', 'fd000008-0000-0000-0000-000000000008', 'ec000004-0000-0000-0000-000000000004', 'Breakfast', 300, 750.00, 34.50, 84.00, 25.50, 'Food', 'Ghi chép bữa ăn lành mạnh', now() - interval '1 days', NULL, false),
('e86aed2e-23e7-4f0d-884c-7edfd7b70140', '5dc50160-db9e-447a-ba33-9026d8800ab5', 'fd000004-0000-0000-0000-000000000004', 'ec000001-0000-0000-0000-000000000001', 'Lunch', 250, 215.00, 4.00, 50.25, 0.25, 'Food', 'Ghi chép bữa ăn lành mạnh', now() - interval '1 days', NULL, false),
('298d189b-ca7f-4fd0-9f1a-38159a940e95', '5dc50160-db9e-447a-ba33-9026d8800ab5', 'fd000002-0000-0000-0000-000000000002', 'ec000003-0000-0000-0000-000000000003', 'Dinner', 300, 333.00, 7.80, 69.00, 2.70, 'Food', 'Ghi chép bữa ăn lành mạnh', now() - interval '1 days', NULL, false),
('97ba7dd2-f4e0-4871-a75c-f093b5448724', '5dc50160-db9e-447a-ba33-9026d8800ab5', 'fd000001-0000-0000-0000-000000000001', 'ec000002-0000-0000-0000-000000000002', 'Breakfast', 300, 495.00, 93.00, 0.00, 10.80, 'Recipe', 'Ghi chép bữa ăn lành mạnh', now() - interval '2 days', NULL, false),
('377e045b-7e9c-493d-9be4-424978444bbf', '5dc50160-db9e-447a-ba33-9026d8800ab5', 'fd000001-0000-0000-0000-000000000001', 'ec000002-0000-0000-0000-000000000002', 'Lunch', 250, 412.50, 77.50, 0.00, 9.00, 'Recipe', 'Ghi chép bữa ăn lành mạnh', now() - interval '2 days', NULL, false),
('c5332343-57d2-44ef-8384-0c897ab396a3', '5dc50160-db9e-447a-ba33-9026d8800ab5', 'fd000003-0000-0000-0000-000000000003', 'ec000003-0000-0000-0000-000000000003', 'Dinner', 250, 800.00, 71.25, 30.00, 46.25, 'Food', 'Ghi chép bữa ăn lành mạnh', now() - interval '2 days', NULL, false),
('536425f6-e269-4ab4-886c-dc87beefb960', '5dc50160-db9e-447a-ba33-9026d8800ab5', 'fd000002-0000-0000-0000-000000000002', 'ec000001-0000-0000-0000-000000000001', 'Breakfast', 300, 333.00, 7.80, 69.00, 2.70, 'Food', 'Ghi chép bữa ăn lành mạnh', now() - interval '3 days', NULL, false),
('157155f1-7805-479f-9631-1a4536e59357', '5dc50160-db9e-447a-ba33-9026d8800ab5', 'fd000003-0000-0000-0000-000000000003', 'ec000002-0000-0000-0000-000000000002', 'Lunch', 300, 960.00, 85.50, 36.00, 55.50, 'Recipe', 'Ghi chép bữa ăn lành mạnh', now() - interval '3 days', NULL, false),
('c54fd68d-5887-404e-8139-5d81cbea8028', '5dc50160-db9e-447a-ba33-9026d8800ab5', 'fd000009-0000-0000-0000-000000000009', 'ec000003-0000-0000-0000-000000000003', 'Dinner', 150, 270.00, 18.00, 12.75, 15.00, 'Food', 'Ghi chép bữa ăn lành mạnh', now() - interval '3 days', NULL, false),
('d40b22aa-6bc9-45b6-b39f-40805776fbbe', '5dc50160-db9e-447a-ba33-9026d8800ab5', 'fd000001-0000-0000-0000-000000000001', 'ec000004-0000-0000-0000-000000000004', 'Breakfast', 150, 247.50, 46.50, 0.00, 5.40, 'Food', 'Ghi chép bữa ăn lành mạnh', now() - interval '4 days', NULL, false),
('835a602f-f73f-4f22-997d-5caabe272f32', '5dc50160-db9e-447a-ba33-9026d8800ab5', 'fd000002-0000-0000-0000-000000000002', 'ec000003-0000-0000-0000-000000000003', 'Lunch', 300, 333.00, 7.80, 69.00, 2.70, 'Food', 'Ghi chép bữa ăn lành mạnh', now() - interval '4 days', NULL, false),
('f0252fdd-d326-425d-91ab-8c6f13e1bb26', '5dc50160-db9e-447a-ba33-9026d8800ab5', 'fd000007-0000-0000-0000-000000000007', 'ec000003-0000-0000-0000-000000000003', 'Dinner', 150, 525.00, 37.50, 7.50, 36.00, 'Food', 'Ghi chép bữa ăn lành mạnh', now() - interval '4 days', NULL, false),
('1b755920-e80a-413a-8d45-6971695cc625', '5dc50160-db9e-447a-ba33-9026d8800ab5', 'fd000001-0000-0000-0000-000000000001', 'ec000003-0000-0000-0000-000000000003', 'Breakfast', 200, 330.00, 62.00, 0.00, 7.20, 'Food', 'Ghi chép bữa ăn lành mạnh', now() - interval '5 days', NULL, false),
('9af042d8-65a0-44b0-9f2f-d1d44466920c', '5dc50160-db9e-447a-ba33-9026d8800ab5', 'fd000006-0000-0000-0000-000000000006', 'ec000001-0000-0000-0000-000000000001', 'Lunch', 300, 870.00, 96.00, 19.80, 43.50, 'Recipe', 'Ghi chép bữa ăn lành mạnh', now() - interval '5 days', NULL, false),
('5a1f30a9-dc3e-4441-856a-699e3c6e5464', '5dc50160-db9e-447a-ba33-9026d8800ab5', 'fd000004-0000-0000-0000-000000000004', 'ec000004-0000-0000-0000-000000000004', 'Dinner', 300, 258.00, 4.80, 60.30, 0.30, 'Recipe', 'Ghi chép bữa ăn lành mạnh', now() - interval '5 days', NULL, false),
('a3e05e4e-16b8-47b3-a45b-a329a0464fd2', '212ea8ea-749e-44a1-92d2-636bd617cbc8', 'fd000007-0000-0000-0000-000000000007', 'ec000003-0000-0000-0000-000000000003', 'Breakfast', 250, 875.00, 62.50, 12.50, 60.00, 'Recipe', 'Ghi chép bữa ăn lành mạnh', now() - interval '1 days', NULL, false),
('d38c9ff7-19e8-4d55-8408-4cc4ee2a0e80', '212ea8ea-749e-44a1-92d2-636bd617cbc8', 'fd000006-0000-0000-0000-000000000006', 'ec000002-0000-0000-0000-000000000002', 'Lunch', 150, 435.00, 48.00, 9.90, 21.75, 'Recipe', 'Ghi chép bữa ăn lành mạnh', now() - interval '1 days', NULL, false),
('b9070efe-895b-47af-8249-4f2ee6a56b92', '212ea8ea-749e-44a1-92d2-636bd617cbc8', 'fd000009-0000-0000-0000-000000000009', 'ec000002-0000-0000-0000-000000000002', 'Dinner', 250, 450.00, 30.00, 21.25, 25.00, 'Food', 'Ghi chép bữa ăn lành mạnh', now() - interval '1 days', NULL, false),
('d83de16b-dfa4-4ae2-aa48-6a21c3adcccc', '212ea8ea-749e-44a1-92d2-636bd617cbc8', 'fd000003-0000-0000-0000-000000000003', 'ec000002-0000-0000-0000-000000000002', 'Breakfast', 150, 480.00, 42.75, 18.00, 27.75, 'Recipe', 'Ghi chép bữa ăn lành mạnh', now() - interval '2 days', NULL, false),
('74e9464a-c76c-46b0-8fd1-7dbc35d488a4', '212ea8ea-749e-44a1-92d2-636bd617cbc8', 'fd000005-0000-0000-0000-000000000005', 'ec000002-0000-0000-0000-000000000002', 'Lunch', 200, 900.00, 24.00, 104.00, 44.00, 'Recipe', 'Ghi chép bữa ăn lành mạnh', now() - interval '2 days', NULL, false),
('d3c45306-768e-4109-96fc-e9358420e40b', '212ea8ea-749e-44a1-92d2-636bd617cbc8', 'fd000002-0000-0000-0000-000000000002', 'ec000002-0000-0000-0000-000000000002', 'Dinner', 300, 333.00, 7.80, 69.00, 2.70, 'Food', 'Ghi chép bữa ăn lành mạnh', now() - interval '2 days', NULL, false),
('e69c5557-e785-4fff-ba72-da26280645b7', '212ea8ea-749e-44a1-92d2-636bd617cbc8', 'fd000010-0000-0000-0000-000000000010', 'ec000004-0000-0000-0000-000000000004', 'Breakfast', 250, 950.00, 57.50, 23.75, 70.00, 'Food', 'Ghi chép bữa ăn lành mạnh', now() - interval '3 days', NULL, false),
('9457729f-6fe6-4fb2-a62a-87ab56b31b76', '212ea8ea-749e-44a1-92d2-636bd617cbc8', 'fd000003-0000-0000-0000-000000000003', 'ec000004-0000-0000-0000-000000000004', 'Lunch', 150, 480.00, 42.75, 18.00, 27.75, 'Food', 'Ghi chép bữa ăn lành mạnh', now() - interval '3 days', NULL, false),
('8f827c6b-5292-4f2a-b532-a19952998d10', '212ea8ea-749e-44a1-92d2-636bd617cbc8', 'fd000008-0000-0000-0000-000000000008', 'ec000003-0000-0000-0000-000000000003', 'Dinner', 250, 625.00, 28.75, 70.00, 21.25, 'Recipe', 'Ghi chép bữa ăn lành mạnh', now() - interval '3 days', NULL, false),
('700d91cf-723a-4a93-b059-f64a6a3d60af', '212ea8ea-749e-44a1-92d2-636bd617cbc8', 'fd000006-0000-0000-0000-000000000006', 'ec000001-0000-0000-0000-000000000001', 'Breakfast', 250, 725.00, 80.00, 16.50, 36.25, 'Food', 'Ghi chép bữa ăn lành mạnh', now() - interval '4 days', NULL, false),
('c7672051-4e11-459e-a496-3f9141f15646', '212ea8ea-749e-44a1-92d2-636bd617cbc8', 'fd000008-0000-0000-0000-000000000008', 'ec000001-0000-0000-0000-000000000001', 'Lunch', 150, 375.00, 17.25, 42.00, 12.75, 'Food', 'Ghi chép bữa ăn lành mạnh', now() - interval '4 days', NULL, false),
('aee77bf2-724b-474b-ab94-4fcee05cb8c5', '212ea8ea-749e-44a1-92d2-636bd617cbc8', 'fd000005-0000-0000-0000-000000000005', 'ec000001-0000-0000-0000-000000000001', 'Dinner', 150, 675.00, 18.00, 78.00, 33.00, 'Food', 'Ghi chép bữa ăn lành mạnh', now() - interval '4 days', NULL, false),
('48e8e87f-996f-4ce4-bf30-2dae008b156b', '212ea8ea-749e-44a1-92d2-636bd617cbc8', 'fd000008-0000-0000-0000-000000000008', 'ec000001-0000-0000-0000-000000000001', 'Breakfast', 300, 750.00, 34.50, 84.00, 25.50, 'Recipe', 'Ghi chép bữa ăn lành mạnh', now() - interval '5 days', NULL, false),
('d4fb912c-cd5b-4adc-a675-3379581faf87', '212ea8ea-749e-44a1-92d2-636bd617cbc8', 'fd000006-0000-0000-0000-000000000006', 'ec000004-0000-0000-0000-000000000004', 'Lunch', 200, 580.00, 64.00, 13.20, 29.00, 'Recipe', 'Ghi chép bữa ăn lành mạnh', now() - interval '5 days', NULL, false),
('9e4fcf06-5ac2-4e8b-93c9-1a93ce162071', '212ea8ea-749e-44a1-92d2-636bd617cbc8', 'fd000008-0000-0000-0000-000000000008', 'ec000001-0000-0000-0000-000000000001', 'Dinner', 250, 625.00, 28.75, 70.00, 21.25, 'Recipe', 'Ghi chép bữa ăn lành mạnh', now() - interval '5 days', NULL, false)
ON CONFLICT DO NOTHING;

INSERT INTO weight_logs ("Id", "UserId", "WeightKg", "BodyFatPercent", "RecordedAt")
VALUES
('ac69c5dd-31e2-4d0c-a76f-fc374449e02e', 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 82.06, 21.91, now() - interval '28 days'),
('b0244994-4276-4dac-914b-772d08196487', 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 81.58, 21.90, now() - interval '21 days'),
('c2c35afc-b5c4-4926-bbf8-2d8610263b04', 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 81.01, 21.62, now() - interval '14 days'),
('f2d547b3-189f-4f4d-8e3e-f2d8b0f130f2', 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 80.45, 21.48, now() - interval '7 days'),
('253b3e45-ea59-4865-9d54-b230b6367bf1', 'cccccccc-cccc-cccc-cccc-cccccccccccc', 73.96, 21.97, now() - interval '28 days'),
('6dfa31cf-267d-43ba-86a3-bf018d707fe6', 'cccccccc-cccc-cccc-cccc-cccccccccccc', 73.54, 21.86, now() - interval '21 days'),
('96428698-01ab-4436-a230-cf48edd990fe', 'cccccccc-cccc-cccc-cccc-cccccccccccc', 73.06, 21.51, now() - interval '14 days'),
('d49c2814-8e27-4be1-827a-7b97730fb456', 'cccccccc-cccc-cccc-cccc-cccccccccccc', 72.34, 21.44, now() - interval '7 days'),
('2e85aca3-8e93-456b-ad03-6960c43d0fc9', 'dddddddd-dddd-dddd-dddd-dddddddddddd', 67.90, 22.07, now() - interval '28 days'),
('985383e8-7e6e-4cb2-9b7b-7997cd48def8', 'dddddddd-dddd-dddd-dddd-dddddddddddd', 67.69, 21.82, now() - interval '21 days'),
('3c3fac95-3022-4416-88ba-d7160de2d1c5', 'dddddddd-dddd-dddd-dddd-dddddddddddd', 66.86, 21.52, now() - interval '14 days'),
('fff332ea-645a-4d1a-8c63-ea53112a8d5d', 'dddddddd-dddd-dddd-dddd-dddddddddddd', 66.57, 21.48, now() - interval '7 days'),
('8ec32686-c349-4b8a-b389-1a0eab5bb076', 'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee', 69.19, 22.04, now() - interval '28 days'),
('eb987b73-df49-4259-b53e-dfaa3788e6f3', 'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee', 68.46, 21.82, now() - interval '21 days'),
('a6fe79e6-eebc-4f41-b7ca-efec24de96b4', 'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee', 68.18, 21.56, now() - interval '14 days'),
('3b76a290-3288-4ab6-95d5-ecd65f44d39b', 'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee', 67.45, 21.46, now() - interval '7 days'),
('4dbd4692-53f4-471a-8a73-5d483aca23ae', 'ffffffff-ffff-ffff-ffff-ffffffffffff', 58.07, 22.07, now() - interval '28 days'),
('3d81f1db-94f3-4843-acbb-08e34486a291', 'ffffffff-ffff-ffff-ffff-ffffffffffff', 57.60, 21.84, now() - interval '21 days'),
('4253d013-ba43-4442-96e8-2425ffb3ddde', 'ffffffff-ffff-ffff-ffff-ffffffffffff', 57.01, 21.63, now() - interval '14 days'),
('10508f99-04f3-42bb-aedc-a3f8126ce156', 'ffffffff-ffff-ffff-ffff-ffffffffffff', 56.47, 21.37, now() - interval '7 days'),
('0f832e5d-ded7-4803-851a-1cd74d1a6a91', '885810e8-168f-4608-a72e-e23a20dfd258', 72.92, 22.09, now() - interval '28 days'),
('07048139-11dd-446e-a2d3-c517461c692b', '885810e8-168f-4608-a72e-e23a20dfd258', 72.44, 21.85, now() - interval '21 days'),
('697f8ee1-7fb3-4dff-b20b-ca4707f4680c', '885810e8-168f-4608-a72e-e23a20dfd258', 71.88, 21.70, now() - interval '14 days'),
('de1fb61d-c19d-4a6a-9eed-5af631a560dd', '885810e8-168f-4608-a72e-e23a20dfd258', 71.36, 21.36, now() - interval '7 days'),
('e984f502-2780-407b-8d50-abf3efbc6b80', '48069bd5-f29a-417d-bdeb-c00797968aca', 56.00, 22.01, now() - interval '28 days'),
('fb0182ae-724a-4b8e-a1ea-86e334a650fa', '48069bd5-f29a-417d-bdeb-c00797968aca', 55.60, 21.81, now() - interval '21 days'),
('9b08bc9a-5143-44b4-93b9-64059ed904f4', '48069bd5-f29a-417d-bdeb-c00797968aca', 55.06, 21.68, now() - interval '14 days'),
('55d1d193-385b-4761-9e63-466f7bf9922e', '48069bd5-f29a-417d-bdeb-c00797968aca', 54.55, 21.42, now() - interval '7 days'),
('03c9397e-a0cd-441e-a55e-edc40fa79fa0', '9afb13a5-e5a1-4342-9ce1-33bf7cc1de70', 58.86, 22.07, now() - interval '28 days'),
('bfac2181-c829-47d6-9615-4c0739469bbd', '9afb13a5-e5a1-4342-9ce1-33bf7cc1de70', 58.61, 21.86, now() - interval '21 days'),
('58537744-cbb2-4da0-9e4f-adfbaaf23227', '9afb13a5-e5a1-4342-9ce1-33bf7cc1de70', 57.87, 21.59, now() - interval '14 days'),
('244b3d63-78ec-4506-90ff-5c0301a87d04', '9afb13a5-e5a1-4342-9ce1-33bf7cc1de70', 57.46, 21.44, now() - interval '7 days'),
('2b1e842b-e9bd-43f8-87bf-32f7a9c40386', '081b4669-b97f-4e75-b089-4c8de0151653', 65.19, 22.02, now() - interval '28 days'),
('826cf924-6ff3-40c1-9ca8-5c6866983a2d', '081b4669-b97f-4e75-b089-4c8de0151653', 64.60, 21.86, now() - interval '21 days'),
('9debbe2b-4c6a-415a-b267-139f42974f3d', '081b4669-b97f-4e75-b089-4c8de0151653', 63.89, 21.55, now() - interval '14 days'),
('b918a963-e3c1-4f53-bdff-4139de78c6ba', '081b4669-b97f-4e75-b089-4c8de0151653', 63.69, 21.46, now() - interval '7 days'),
('836e9352-23ee-463b-9448-a7e441fdb58b', '586209d0-d3c4-43a4-bba7-5d4c73b37bc1', 61.95, 22.09, now() - interval '28 days'),
('7bd546a6-de9c-46f4-956a-5caed9fffad8', '586209d0-d3c4-43a4-bba7-5d4c73b37bc1', 61.69, 21.79, now() - interval '21 days'),
('43a4cd13-2e9c-4a13-a1f0-89490cb25ecd', '586209d0-d3c4-43a4-bba7-5d4c73b37bc1', 60.91, 21.58, now() - interval '14 days'),
('c2e75774-254c-4ade-88ee-3acb3a520a97', '586209d0-d3c4-43a4-bba7-5d4c73b37bc1', 60.51, 21.49, now() - interval '7 days'),
('424d0dbc-930f-45b8-919f-b606ca47e582', 'b022ccde-0aa6-4b11-bd7b-f76aaf2c2b17', 62.12, 21.93, now() - interval '28 days'),
('8fa97ace-c2fb-4782-9713-9c00e2913958', 'b022ccde-0aa6-4b11-bd7b-f76aaf2c2b17', 61.40, 21.83, now() - interval '21 days'),
('be695f45-0a31-40c4-b8cc-80e682dcbce6', 'b022ccde-0aa6-4b11-bd7b-f76aaf2c2b17', 61.15, 21.61, now() - interval '14 days'),
('890578da-54b0-44ce-bb45-e67abe04f09b', 'b022ccde-0aa6-4b11-bd7b-f76aaf2c2b17', 60.34, 21.47, now() - interval '7 days'),
('d7c4af0d-2845-43c6-b565-cd8f6af2bca3', '453681f7-f489-47ed-842c-bc3ffd220423', 56.91, 22.05, now() - interval '28 days'),
('444915e8-9b7a-4ebd-bcfa-70e8cb01ef0c', '453681f7-f489-47ed-842c-bc3ffd220423', 56.41, 21.88, now() - interval '21 days'),
('0097a3fa-beec-4bd1-93a8-a9cb6a3f1184', '453681f7-f489-47ed-842c-bc3ffd220423', 55.86, 21.59, now() - interval '14 days'),
('41e7813b-2a51-44f5-823d-b089b2e9672a', '453681f7-f489-47ed-842c-bc3ffd220423', 55.68, 21.34, now() - interval '7 days'),
('e645657e-44bb-4fd4-95d2-7fd58d273af1', '396f9dff-6c2a-422f-b0cc-8eb451168ed3', 78.15, 22.09, now() - interval '28 days'),
('0016be3c-4f84-4555-a3af-40be9dd625a2', '396f9dff-6c2a-422f-b0cc-8eb451168ed3', 77.47, 21.78, now() - interval '21 days'),
('6b281699-8a40-420d-a4fe-cdcad92ab499', '396f9dff-6c2a-422f-b0cc-8eb451168ed3', 76.95, 21.58, now() - interval '14 days'),
('b5b098ff-1bb8-422d-ab01-f3b1b40ea1dd', '396f9dff-6c2a-422f-b0cc-8eb451168ed3', 76.33, 21.34, now() - interval '7 days'),
('41b9f7f6-cbd0-440d-84df-cbddcbd44469', '5dc50160-db9e-447a-ba33-9026d8800ab5', 70.17, 22.07, now() - interval '28 days'),
('7f2c73b0-f4dc-42fa-820b-e591a1011fa8', '5dc50160-db9e-447a-ba33-9026d8800ab5', 69.56, 21.86, now() - interval '21 days'),
('e1dadbb6-a2b1-4b69-95a6-965b898d3195', '5dc50160-db9e-447a-ba33-9026d8800ab5', 68.86, 21.56, now() - interval '14 days'),
('a599477e-73fe-4ff1-9aa5-317163e82c0b', '5dc50160-db9e-447a-ba33-9026d8800ab5', 68.63, 21.44, now() - interval '7 days'),
('5a62ec45-94b4-438f-8b33-ff0385a5e738', '212ea8ea-749e-44a1-92d2-636bd617cbc8', 58.10, 21.99, now() - interval '28 days'),
('cb4aae16-eaa1-40fc-8402-b538d805b1d2', '212ea8ea-749e-44a1-92d2-636bd617cbc8', 57.55, 21.88, now() - interval '21 days'),
('beef822b-e498-422d-a042-5e29c62431cb', '212ea8ea-749e-44a1-92d2-636bd617cbc8', 56.81, 21.54, now() - interval '14 days'),
('c5f7d51d-3fdf-45f5-bdab-c5bf16f52e2e', '212ea8ea-749e-44a1-92d2-636bd617cbc8', 56.36, 21.49, now() - interval '7 days')
ON CONFLICT DO NOTHING;

INSERT INTO nutrition_snapshots ("Id", "UserId", "SnapshotDate", "TotalCalories", "TotalProteinG", "TotalCarbsG", "TotalFatG", "GoalCompletionPercent")
VALUES
('6389e5be-6ec0-4445-a5d0-a12d3e5d42aa', 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', CURRENT_DATE - 0, 2123, 133, 254, 53, 100.52),
('9cdf2333-6c6d-4265-a861-08038bdb962c', 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', CURRENT_DATE - 1, 1743, 119, 215, 51, 89.77),
('1ebc0bd2-ad27-496b-85e8-58aa9d236bb8', 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', CURRENT_DATE - 2, 2154, 150, 279, 64, 86.26),
('720bba68-900f-409e-b56a-e544b3993301', 'cccccccc-cccc-cccc-cccc-cccccccccccc', CURRENT_DATE - 0, 2011, 138, 268, 50, 97.64),
('8d8d01b9-ef37-4784-9ddd-4969030043ae', 'cccccccc-cccc-cccc-cccc-cccccccccccc', CURRENT_DATE - 1, 2088, 115, 291, 54, 90.83),
('2a27c8e8-5221-485a-82d7-78497ee487db', 'cccccccc-cccc-cccc-cccc-cccccccccccc', CURRENT_DATE - 2, 1501, 139, 245, 57, 96.41),
('6ec866c4-236c-4086-876d-392a3af6f586', 'dddddddd-dddd-dddd-dddd-dddddddddddd', CURRENT_DATE - 0, 1691, 142, 285, 52, 95.47),
('1b1c9fd4-8c5e-4896-9b47-652f8c58c208', 'dddddddd-dddd-dddd-dddd-dddddddddddd', CURRENT_DATE - 1, 1869, 104, 267, 67, 95.15),
('fae149ee-0e1b-4591-b1a5-f091aa316100', 'dddddddd-dddd-dddd-dddd-dddddddddddd', CURRENT_DATE - 2, 2019, 135, 202, 62, 102.47),
('41af12d6-330a-4ced-ad3c-15d4abda4f95', 'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee', CURRENT_DATE - 0, 1544, 140, 249, 61, 90.07),
('cd3c05bd-7d20-4822-bd45-b15f06e8edf0', 'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee', CURRENT_DATE - 1, 1516, 122, 300, 52, 91.90),
('e90a4e3a-63ed-4fe9-b9dc-5779277fe745', 'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee', CURRENT_DATE - 2, 2172, 140, 213, 74, 96.64),
('bcb8b2df-475a-4863-8b90-eb5e9446721e', 'ffffffff-ffff-ffff-ffff-ffffffffffff', CURRENT_DATE - 0, 1840, 108, 205, 61, 95.92),
('d290a83e-f5d0-4169-8720-03074eaee004', 'ffffffff-ffff-ffff-ffff-ffffffffffff', CURRENT_DATE - 1, 2158, 111, 299, 71, 94.29),
('11f901e4-3f12-4dcf-acd1-7de1bb04e6fb', 'ffffffff-ffff-ffff-ffff-ffffffffffff', CURRENT_DATE - 2, 1990, 140, 223, 75, 87.70),
('74cb58f0-6512-41f4-8af3-4feb0db7485e', '885810e8-168f-4608-a72e-e23a20dfd258', CURRENT_DATE - 0, 1968, 102, 237, 56, 85.88),
('47ab7579-fe5d-4a6b-a9f3-1e824f19b049', '885810e8-168f-4608-a72e-e23a20dfd258', CURRENT_DATE - 1, 1704, 102, 240, 79, 91.20),
('dabbc0c9-2e6d-4819-ba5a-11d717b305bb', '885810e8-168f-4608-a72e-e23a20dfd258', CURRENT_DATE - 2, 1907, 134, 260, 58, 85.73),
('0e3b8f4d-1db6-4bfd-adf4-654143480c4d', '48069bd5-f29a-417d-bdeb-c00797968aca', CURRENT_DATE - 0, 2162, 112, 236, 61, 102.24),
('dfc87f96-b2f5-435c-b3df-f92ebf724d21', '48069bd5-f29a-417d-bdeb-c00797968aca', CURRENT_DATE - 1, 1548, 141, 242, 58, 87.49),
('4d445772-22a1-4e94-8de4-00bcad0de704', '48069bd5-f29a-417d-bdeb-c00797968aca', CURRENT_DATE - 2, 1876, 127, 251, 73, 93.79),
('e29cbeff-76b3-45b5-b762-570cf71155c3', '9afb13a5-e5a1-4342-9ce1-33bf7cc1de70', CURRENT_DATE - 0, 1895, 121, 223, 65, 98.84),
('48735f0f-5e56-4a50-81fe-a93e9cf44a5d', '9afb13a5-e5a1-4342-9ce1-33bf7cc1de70', CURRENT_DATE - 1, 1876, 133, 234, 75, 86.65),
('8b64cc37-428a-493f-8a6a-b6090d831ac5', '9afb13a5-e5a1-4342-9ce1-33bf7cc1de70', CURRENT_DATE - 2, 1934, 105, 255, 69, 104.90),
('7299293e-1228-4a96-8af6-e6c400337e4f', '081b4669-b97f-4e75-b089-4c8de0151653', CURRENT_DATE - 0, 1684, 134, 237, 60, 87.05),
('e5a229d9-3e0c-4986-a94d-782e50595576', '081b4669-b97f-4e75-b089-4c8de0151653', CURRENT_DATE - 1, 1835, 142, 237, 59, 93.92),
('d160a11a-d415-4894-a0ea-b3b761e40f57', '081b4669-b97f-4e75-b089-4c8de0151653', CURRENT_DATE - 2, 1936, 110, 288, 64, 92.03),
('4471bf9a-3c9f-430f-82b3-77ed89cf2179', '586209d0-d3c4-43a4-bba7-5d4c73b37bc1', CURRENT_DATE - 0, 1543, 146, 245, 69, 104.96),
('6e0c393b-3a04-4f97-bc26-8605a28e32c4', '586209d0-d3c4-43a4-bba7-5d4c73b37bc1', CURRENT_DATE - 1, 1781, 140, 207, 52, 98.42),
('422ea35b-e930-472a-a186-b26f37e7b708', '586209d0-d3c4-43a4-bba7-5d4c73b37bc1', CURRENT_DATE - 2, 1915, 123, 265, 75, 100.00),
('914d284b-eadf-4eb0-a87b-a5aeeffa2402', 'b022ccde-0aa6-4b11-bd7b-f76aaf2c2b17', CURRENT_DATE - 0, 1663, 101, 218, 77, 97.15),
('1dcecdcb-4ff6-4305-8d07-0fbb812d2f8e', 'b022ccde-0aa6-4b11-bd7b-f76aaf2c2b17', CURRENT_DATE - 1, 1948, 102, 216, 52, 89.72),
('0171048c-c5a7-4780-9500-50e5c1e8b3ad', 'b022ccde-0aa6-4b11-bd7b-f76aaf2c2b17', CURRENT_DATE - 2, 2160, 123, 246, 62, 103.99),
('536d3d21-5fae-49f1-b162-8c57cd5d1950', '453681f7-f489-47ed-842c-bc3ffd220423', CURRENT_DATE - 0, 1533, 138, 219, 71, 94.00),
('11336e27-0eaa-4d35-a4a1-e4fd311db712', '453681f7-f489-47ed-842c-bc3ffd220423', CURRENT_DATE - 1, 1879, 123, 256, 74, 86.54),
('71939293-f910-4399-905d-0b71c5db929c', '453681f7-f489-47ed-842c-bc3ffd220423', CURRENT_DATE - 2, 1640, 133, 246, 62, 91.29),
('50160f0e-1630-4e0b-84a2-918d88ebdc49', '396f9dff-6c2a-422f-b0cc-8eb451168ed3', CURRENT_DATE - 0, 1785, 115, 214, 50, 99.71),
('0c726677-9854-4454-9c01-ce675ce48a44', '396f9dff-6c2a-422f-b0cc-8eb451168ed3', CURRENT_DATE - 1, 2011, 133, 249, 79, 96.23),
('0fd2ff57-26ec-45c4-b8d9-eff9c3a12759', '396f9dff-6c2a-422f-b0cc-8eb451168ed3', CURRENT_DATE - 2, 1768, 149, 233, 72, 93.93),
('6b5ee94d-2091-4b97-b5b4-992ebdc99c6e', '5dc50160-db9e-447a-ba33-9026d8800ab5', CURRENT_DATE - 0, 2126, 118, 288, 79, 104.97),
('b4b7167b-49ca-4621-a55c-8f5266eaecb3', '5dc50160-db9e-447a-ba33-9026d8800ab5', CURRENT_DATE - 1, 1704, 107, 217, 77, 86.48),
('0bbf0dda-c594-48ed-a230-318582a8546a', '5dc50160-db9e-447a-ba33-9026d8800ab5', CURRENT_DATE - 2, 1676, 145, 256, 52, 101.21),
('0e1170a7-7f80-45cf-932a-3e202d4a44b7', '212ea8ea-749e-44a1-92d2-636bd617cbc8', CURRENT_DATE - 0, 1827, 142, 244, 72, 86.30),
('5a740f18-7472-4598-875e-88b8f3927bee', '212ea8ea-749e-44a1-92d2-636bd617cbc8', CURRENT_DATE - 1, 2055, 118, 238, 77, 88.15),
('f9088778-2705-4cf8-8e6d-71d4d3382a44', '212ea8ea-749e-44a1-92d2-636bd617cbc8', CURRENT_DATE - 2, 2153, 111, 246, 66, 89.48)
ON CONFLICT DO NOTHING;

INSERT INTO ai_conversations ("Id", "UserId", "Title", "CreatedAt")
VALUES
('1dda1f54-2e1c-4b44-adaa-d71e55270f8c', 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'Tư vấn giảm cân', now() - interval '2 days'),
('4ab8fafe-c92c-452f-97ae-57f0b4729099', 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'Thực đơn tập gym tăng cơ', now() - interval '2 days'),
('1a0854c9-fbf6-48d9-812c-49c7cce7ee06', 'cccccccc-cccc-cccc-cccc-cccccccccccc', 'Tư vấn giảm cân', now() - interval '2 days'),
('f2fce726-40f7-49ba-a9ed-ecce006c1e61', 'cccccccc-cccc-cccc-cccc-cccccccccccc', 'Thực đơn tập gym tăng cơ', now() - interval '2 days'),
('71c3d48a-392f-46f6-af0b-c136f4faf1eb', 'dddddddd-dddd-dddd-dddd-dddddddddddd', 'Tư vấn giảm cân', now() - interval '2 days'),
('087d1351-99fd-4644-b997-2a59c68d8521', 'dddddddd-dddd-dddd-dddd-dddddddddddd', 'Thực đơn tập gym tăng cơ', now() - interval '2 days'),
('cd6451d7-008e-4d66-a500-e213c35613ec', 'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee', 'Tư vấn giảm cân', now() - interval '2 days'),
('b48896d7-d728-45f9-b544-f951ac4d62a0', 'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee', 'Thực đơn tập gym tăng cơ', now() - interval '2 days'),
('0521115f-b220-479a-93bd-16107fbceadc', 'ffffffff-ffff-ffff-ffff-ffffffffffff', 'Tư vấn giảm cân', now() - interval '2 days'),
('9bf431b6-3a64-4017-ab1f-7a354ed503b8', 'ffffffff-ffff-ffff-ffff-ffffffffffff', 'Thực đơn tập gym tăng cơ', now() - interval '2 days'),
('5cf92fb1-e906-459f-9cb1-2b31ae9cbfd5', '885810e8-168f-4608-a72e-e23a20dfd258', 'Tư vấn giảm cân', now() - interval '2 days'),
('67e6d1e8-1a0a-4625-9333-3ffdc0981b74', '885810e8-168f-4608-a72e-e23a20dfd258', 'Thực đơn tập gym tăng cơ', now() - interval '2 days'),
('91f676bf-2d0e-4002-9e79-ff48ce390a29', '48069bd5-f29a-417d-bdeb-c00797968aca', 'Tư vấn giảm cân', now() - interval '2 days'),
('0148f946-b794-4ea4-b6e0-307a0ac6a70b', '48069bd5-f29a-417d-bdeb-c00797968aca', 'Thực đơn tập gym tăng cơ', now() - interval '2 days'),
('ffb7ad29-6e56-4fac-8deb-25ed12c90698', '9afb13a5-e5a1-4342-9ce1-33bf7cc1de70', 'Tư vấn giảm cân', now() - interval '2 days'),
('3c1144cd-778e-4413-87fe-939805b3419e', '9afb13a5-e5a1-4342-9ce1-33bf7cc1de70', 'Thực đơn tập gym tăng cơ', now() - interval '2 days'),
('a7d62c32-d5a7-421f-be2f-19ecd79d66a2', '081b4669-b97f-4e75-b089-4c8de0151653', 'Tư vấn giảm cân', now() - interval '2 days'),
('53d8c70b-a6c5-449c-8685-8b3e2df94e6d', '081b4669-b97f-4e75-b089-4c8de0151653', 'Thực đơn tập gym tăng cơ', now() - interval '2 days'),
('3a68eec3-0766-4152-b14d-163e359c5f54', '586209d0-d3c4-43a4-bba7-5d4c73b37bc1', 'Tư vấn giảm cân', now() - interval '2 days'),
('89cbeb02-f385-453e-85c1-3713bdfd64bb', '586209d0-d3c4-43a4-bba7-5d4c73b37bc1', 'Thực đơn tập gym tăng cơ', now() - interval '2 days'),
('2e13f918-6c28-476c-ab18-58b3aecc8700', 'b022ccde-0aa6-4b11-bd7b-f76aaf2c2b17', 'Tư vấn giảm cân', now() - interval '2 days'),
('9f09129b-0854-403d-b2fd-a8b84d6eb029', 'b022ccde-0aa6-4b11-bd7b-f76aaf2c2b17', 'Thực đơn tập gym tăng cơ', now() - interval '2 days'),
('f3519ca6-9581-4e0c-8f39-fbb591b021eb', '453681f7-f489-47ed-842c-bc3ffd220423', 'Tư vấn giảm cân', now() - interval '2 days'),
('a088a941-7975-4a45-8ddc-ed3f28210969', '453681f7-f489-47ed-842c-bc3ffd220423', 'Thực đơn tập gym tăng cơ', now() - interval '2 days'),
('2e97c0b5-7c0d-46ea-a36a-60e1e375f6bd', '396f9dff-6c2a-422f-b0cc-8eb451168ed3', 'Tư vấn giảm cân', now() - interval '2 days'),
('9a5a2c52-6d4c-494a-92a7-f194a564a1e3', '396f9dff-6c2a-422f-b0cc-8eb451168ed3', 'Thực đơn tập gym tăng cơ', now() - interval '2 days'),
('9877c046-f1fc-460a-b5b8-cbc472248b5e', '5dc50160-db9e-447a-ba33-9026d8800ab5', 'Tư vấn giảm cân', now() - interval '2 days'),
('61907a0d-f782-4440-a0e3-ce70857f1dc1', '5dc50160-db9e-447a-ba33-9026d8800ab5', 'Thực đơn tập gym tăng cơ', now() - interval '2 days'),
('ea792b53-85d6-44d5-b266-ce649e298b2d', '212ea8ea-749e-44a1-92d2-636bd617cbc8', 'Tư vấn giảm cân', now() - interval '2 days'),
('122f09d2-1081-4f20-88b9-bd4effe769de', '212ea8ea-749e-44a1-92d2-636bd617cbc8', 'Thực đơn tập gym tăng cơ', now() - interval '2 days')
ON CONFLICT DO NOTHING;

INSERT INTO ai_messages ("Id", "ConversationId", "Role", "Content", "TokensUsed", "CreatedAt")
VALUES
('279d3925-1acf-4fcb-9412-89b609da5301', '1dda1f54-2e1c-4b44-adaa-d71e55270f8c', 'user', 'Tôi muốn giảm 5kg trong 1 tháng, nên ăn uống thế nào?', 13, now() - interval '2 days' + interval '0 minutes'),
('f4af67de-8440-42f9-95b1-c531ec9de6be', '1dda1f54-2e1c-4b44-adaa-d71e55270f8c', 'assistant', 'Chào bạn! Giảm 5kg/tháng là mục tiêu khả thi nhưng cần thâm hụt calo khoảng 500 kcal mỗi ngày. Bạn nên ưu tiên ăn tinh bột chuyển hóa chậm (gạo lứt, khoai lang), tăng cường ức gà, cá hồi và rau xanh. Hạn chế tối đa đồ chiên xào và trà sữa nhé!', 60, now() - interval '2 days' + interval '5 minutes'),
('7e1baf42-ff2c-4e89-be67-636bdec12917', '4ab8fafe-c92c-452f-97ae-57f0b4729099', 'user', 'Tôi đang tập gym tăng cơ, mỗi ngày cần nạp bao nhiêu protein?', 15, now() - interval '2 days' + interval '0 minutes'),
('64401dff-88fc-4a0f-9241-21f3abf14f66', '4ab8fafe-c92c-452f-97ae-57f0b4729099', 'assistant', 'Chào bạn, đối với người tập gym tăng cơ, lượng protein cần thiết là khoảng 1.6g - 2.2g trên mỗi kg thể trọng. Ví dụ bạn nặng 60kg, bạn cần nạp khoảng 96g - 132g protein mỗi ngày từ ức gà, trứng, thịt bò hoặc whey protein.', 55, now() - interval '2 days' + interval '5 minutes'),
('88fb4d57-f0d1-46d9-a1c6-2209b3d6e5bf', '1a0854c9-fbf6-48d9-812c-49c7cce7ee06', 'user', 'Tôi muốn giảm 5kg trong 1 tháng, nên ăn uống thế nào?', 13, now() - interval '2 days' + interval '0 minutes'),
('97d44089-abe3-4f73-a8b6-0fc4d5aae3b8', '1a0854c9-fbf6-48d9-812c-49c7cce7ee06', 'assistant', 'Chào bạn! Giảm 5kg/tháng là mục tiêu khả thi nhưng cần thâm hụt calo khoảng 500 kcal mỗi ngày. Bạn nên ưu tiên ăn tinh bột chuyển hóa chậm (gạo lứt, khoai lang), tăng cường ức gà, cá hồi và rau xanh. Hạn chế tối đa đồ chiên xào và trà sữa nhé!', 60, now() - interval '2 days' + interval '5 minutes'),
('bfc30d80-3c3f-4cee-ab14-8c330ee1de63', 'f2fce726-40f7-49ba-a9ed-ecce006c1e61', 'user', 'Tôi đang tập gym tăng cơ, mỗi ngày cần nạp bao nhiêu protein?', 15, now() - interval '2 days' + interval '0 minutes'),
('1e46a845-5430-4c0f-93f4-63f767ce2176', 'f2fce726-40f7-49ba-a9ed-ecce006c1e61', 'assistant', 'Chào bạn, đối với người tập gym tăng cơ, lượng protein cần thiết là khoảng 1.6g - 2.2g trên mỗi kg thể trọng. Ví dụ bạn nặng 60kg, bạn cần nạp khoảng 96g - 132g protein mỗi ngày từ ức gà, trứng, thịt bò hoặc whey protein.', 55, now() - interval '2 days' + interval '5 minutes'),
('1e52931f-1b9f-4d03-9d4f-69ec3639e3bb', '71c3d48a-392f-46f6-af0b-c136f4faf1eb', 'user', 'Tôi muốn giảm 5kg trong 1 tháng, nên ăn uống thế nào?', 13, now() - interval '2 days' + interval '0 minutes'),
('6ac9983d-bbc5-40ee-a1f4-c290dbe131cf', '71c3d48a-392f-46f6-af0b-c136f4faf1eb', 'assistant', 'Chào bạn! Giảm 5kg/tháng là mục tiêu khả thi nhưng cần thâm hụt calo khoảng 500 kcal mỗi ngày. Bạn nên ưu tiên ăn tinh bột chuyển hóa chậm (gạo lứt, khoai lang), tăng cường ức gà, cá hồi và rau xanh. Hạn chế tối đa đồ chiên xào và trà sữa nhé!', 60, now() - interval '2 days' + interval '5 minutes'),
('255d0cec-0b99-4751-8401-2a48caa9b5eb', '087d1351-99fd-4644-b997-2a59c68d8521', 'user', 'Tôi đang tập gym tăng cơ, mỗi ngày cần nạp bao nhiêu protein?', 15, now() - interval '2 days' + interval '0 minutes'),
('a0b3672b-aa20-4067-9968-c905f7d56239', '087d1351-99fd-4644-b997-2a59c68d8521', 'assistant', 'Chào bạn, đối với người tập gym tăng cơ, lượng protein cần thiết là khoảng 1.6g - 2.2g trên mỗi kg thể trọng. Ví dụ bạn nặng 60kg, bạn cần nạp khoảng 96g - 132g protein mỗi ngày từ ức gà, trứng, thịt bò hoặc whey protein.', 55, now() - interval '2 days' + interval '5 minutes'),
('1412c425-8b0b-40a2-b974-fed01e9b3a33', 'cd6451d7-008e-4d66-a500-e213c35613ec', 'user', 'Tôi muốn giảm 5kg trong 1 tháng, nên ăn uống thế nào?', 13, now() - interval '2 days' + interval '0 minutes'),
('69787d44-88cd-4d36-80c8-783b1635eab3', 'cd6451d7-008e-4d66-a500-e213c35613ec', 'assistant', 'Chào bạn! Giảm 5kg/tháng là mục tiêu khả thi nhưng cần thâm hụt calo khoảng 500 kcal mỗi ngày. Bạn nên ưu tiên ăn tinh bột chuyển hóa chậm (gạo lứt, khoai lang), tăng cường ức gà, cá hồi và rau xanh. Hạn chế tối đa đồ chiên xào và trà sữa nhé!', 60, now() - interval '2 days' + interval '5 minutes'),
('17443414-e826-4c63-85ac-6f9477e2106c', 'b48896d7-d728-45f9-b544-f951ac4d62a0', 'user', 'Tôi đang tập gym tăng cơ, mỗi ngày cần nạp bao nhiêu protein?', 15, now() - interval '2 days' + interval '0 minutes'),
('b11c22d4-6b3b-459d-8d8b-5506a8736b8f', 'b48896d7-d728-45f9-b544-f951ac4d62a0', 'assistant', 'Chào bạn, đối với người tập gym tăng cơ, lượng protein cần thiết là khoảng 1.6g - 2.2g trên mỗi kg thể trọng. Ví dụ bạn nặng 60kg, bạn cần nạp khoảng 96g - 132g protein mỗi ngày từ ức gà, trứng, thịt bò hoặc whey protein.', 55, now() - interval '2 days' + interval '5 minutes'),
('f44994d4-5bca-4371-bc3d-f7719aeff0c8', '0521115f-b220-479a-93bd-16107fbceadc', 'user', 'Tôi muốn giảm 5kg trong 1 tháng, nên ăn uống thế nào?', 13, now() - interval '2 days' + interval '0 minutes'),
('0e16a08e-7b90-45aa-b067-62703205aec0', '0521115f-b220-479a-93bd-16107fbceadc', 'assistant', 'Chào bạn! Giảm 5kg/tháng là mục tiêu khả thi nhưng cần thâm hụt calo khoảng 500 kcal mỗi ngày. Bạn nên ưu tiên ăn tinh bột chuyển hóa chậm (gạo lứt, khoai lang), tăng cường ức gà, cá hồi và rau xanh. Hạn chế tối đa đồ chiên xào và trà sữa nhé!', 60, now() - interval '2 days' + interval '5 minutes'),
('2b73254f-fffc-4a6d-a41a-e92586aed874', '9bf431b6-3a64-4017-ab1f-7a354ed503b8', 'user', 'Tôi đang tập gym tăng cơ, mỗi ngày cần nạp bao nhiêu protein?', 15, now() - interval '2 days' + interval '0 minutes'),
('11962de1-c993-4ac8-86d8-7359f9ce3a85', '9bf431b6-3a64-4017-ab1f-7a354ed503b8', 'assistant', 'Chào bạn, đối với người tập gym tăng cơ, lượng protein cần thiết là khoảng 1.6g - 2.2g trên mỗi kg thể trọng. Ví dụ bạn nặng 60kg, bạn cần nạp khoảng 96g - 132g protein mỗi ngày từ ức gà, trứng, thịt bò hoặc whey protein.', 55, now() - interval '2 days' + interval '5 minutes'),
('4a36bdc2-856b-4ad5-9255-7ed0aa6ffeb9', '5cf92fb1-e906-459f-9cb1-2b31ae9cbfd5', 'user', 'Tôi muốn giảm 5kg trong 1 tháng, nên ăn uống thế nào?', 13, now() - interval '2 days' + interval '0 minutes'),
('7ab950ad-e542-44db-8230-500f4b6d1ef2', '5cf92fb1-e906-459f-9cb1-2b31ae9cbfd5', 'assistant', 'Chào bạn! Giảm 5kg/tháng là mục tiêu khả thi nhưng cần thâm hụt calo khoảng 500 kcal mỗi ngày. Bạn nên ưu tiên ăn tinh bột chuyển hóa chậm (gạo lứt, khoai lang), tăng cường ức gà, cá hồi và rau xanh. Hạn chế tối đa đồ chiên xào và trà sữa nhé!', 60, now() - interval '2 days' + interval '5 minutes'),
('cfb47224-f185-4a02-b9fe-4669d84cbf1a', '67e6d1e8-1a0a-4625-9333-3ffdc0981b74', 'user', 'Tôi đang tập gym tăng cơ, mỗi ngày cần nạp bao nhiêu protein?', 15, now() - interval '2 days' + interval '0 minutes'),
('7aab9830-7745-4b7e-8d99-75c6a57d133a', '67e6d1e8-1a0a-4625-9333-3ffdc0981b74', 'assistant', 'Chào bạn, đối với người tập gym tăng cơ, lượng protein cần thiết là khoảng 1.6g - 2.2g trên mỗi kg thể trọng. Ví dụ bạn nặng 60kg, bạn cần nạp khoảng 96g - 132g protein mỗi ngày từ ức gà, trứng, thịt bò hoặc whey protein.', 55, now() - interval '2 days' + interval '5 minutes'),
('d2106a0c-fcc6-4979-a4d8-8df915d692cf', '91f676bf-2d0e-4002-9e79-ff48ce390a29', 'user', 'Tôi muốn giảm 5kg trong 1 tháng, nên ăn uống thế nào?', 13, now() - interval '2 days' + interval '0 minutes'),
('b449fadc-00de-40d7-9810-bb630edaa466', '91f676bf-2d0e-4002-9e79-ff48ce390a29', 'assistant', 'Chào bạn! Giảm 5kg/tháng là mục tiêu khả thi nhưng cần thâm hụt calo khoảng 500 kcal mỗi ngày. Bạn nên ưu tiên ăn tinh bột chuyển hóa chậm (gạo lứt, khoai lang), tăng cường ức gà, cá hồi và rau xanh. Hạn chế tối đa đồ chiên xào và trà sữa nhé!', 60, now() - interval '2 days' + interval '5 minutes'),
('5598fae9-f8e4-4fc4-99cf-ce82f806bdcc', '0148f946-b794-4ea4-b6e0-307a0ac6a70b', 'user', 'Tôi đang tập gym tăng cơ, mỗi ngày cần nạp bao nhiêu protein?', 15, now() - interval '2 days' + interval '0 minutes'),
('bc12e138-4718-4bc9-b0ef-72b3b9b534bb', '0148f946-b794-4ea4-b6e0-307a0ac6a70b', 'assistant', 'Chào bạn, đối với người tập gym tăng cơ, lượng protein cần thiết là khoảng 1.6g - 2.2g trên mỗi kg thể trọng. Ví dụ bạn nặng 60kg, bạn cần nạp khoảng 96g - 132g protein mỗi ngày từ ức gà, trứng, thịt bò hoặc whey protein.', 55, now() - interval '2 days' + interval '5 minutes'),
('842fecf3-39d5-4ff3-b9c8-8e3fd087b5a2', 'ffb7ad29-6e56-4fac-8deb-25ed12c90698', 'user', 'Tôi muốn giảm 5kg trong 1 tháng, nên ăn uống thế nào?', 13, now() - interval '2 days' + interval '0 minutes'),
('508be6f6-4ee9-4701-be3d-24d585ade69e', 'ffb7ad29-6e56-4fac-8deb-25ed12c90698', 'assistant', 'Chào bạn! Giảm 5kg/tháng là mục tiêu khả thi nhưng cần thâm hụt calo khoảng 500 kcal mỗi ngày. Bạn nên ưu tiên ăn tinh bột chuyển hóa chậm (gạo lứt, khoai lang), tăng cường ức gà, cá hồi và rau xanh. Hạn chế tối đa đồ chiên xào và trà sữa nhé!', 60, now() - interval '2 days' + interval '5 minutes'),
('57371354-c338-4f5a-b25c-c7d536eb426c', '3c1144cd-778e-4413-87fe-939805b3419e', 'user', 'Tôi đang tập gym tăng cơ, mỗi ngày cần nạp bao nhiêu protein?', 15, now() - interval '2 days' + interval '0 minutes'),
('36895cab-dfc7-460c-99cd-0c04b13ffc4a', '3c1144cd-778e-4413-87fe-939805b3419e', 'assistant', 'Chào bạn, đối với người tập gym tăng cơ, lượng protein cần thiết là khoảng 1.6g - 2.2g trên mỗi kg thể trọng. Ví dụ bạn nặng 60kg, bạn cần nạp khoảng 96g - 132g protein mỗi ngày từ ức gà, trứng, thịt bò hoặc whey protein.', 55, now() - interval '2 days' + interval '5 minutes'),
('4bd3f5e7-4a2e-4ec0-901a-61432d88e855', 'a7d62c32-d5a7-421f-be2f-19ecd79d66a2', 'user', 'Tôi muốn giảm 5kg trong 1 tháng, nên ăn uống thế nào?', 13, now() - interval '2 days' + interval '0 minutes'),
('d1f97243-93aa-4fac-9de9-97e50dec3ad7', 'a7d62c32-d5a7-421f-be2f-19ecd79d66a2', 'assistant', 'Chào bạn! Giảm 5kg/tháng là mục tiêu khả thi nhưng cần thâm hụt calo khoảng 500 kcal mỗi ngày. Bạn nên ưu tiên ăn tinh bột chuyển hóa chậm (gạo lứt, khoai lang), tăng cường ức gà, cá hồi và rau xanh. Hạn chế tối đa đồ chiên xào và trà sữa nhé!', 60, now() - interval '2 days' + interval '5 minutes'),
('63076949-844b-4225-9fb1-e9d8025d4ff2', '53d8c70b-a6c5-449c-8685-8b3e2df94e6d', 'user', 'Tôi đang tập gym tăng cơ, mỗi ngày cần nạp bao nhiêu protein?', 15, now() - interval '2 days' + interval '0 minutes'),
('b230bd64-2b65-463b-89d1-302eeab078ec', '53d8c70b-a6c5-449c-8685-8b3e2df94e6d', 'assistant', 'Chào bạn, đối với người tập gym tăng cơ, lượng protein cần thiết là khoảng 1.6g - 2.2g trên mỗi kg thể trọng. Ví dụ bạn nặng 60kg, bạn cần nạp khoảng 96g - 132g protein mỗi ngày từ ức gà, trứng, thịt bò hoặc whey protein.', 55, now() - interval '2 days' + interval '5 minutes'),
('64ab17cd-54b8-4da6-ac9e-f71a7248f13d', '3a68eec3-0766-4152-b14d-163e359c5f54', 'user', 'Tôi muốn giảm 5kg trong 1 tháng, nên ăn uống thế nào?', 13, now() - interval '2 days' + interval '0 minutes'),
('94af42c3-872a-43e0-b5e6-4bb15054171a', '3a68eec3-0766-4152-b14d-163e359c5f54', 'assistant', 'Chào bạn! Giảm 5kg/tháng là mục tiêu khả thi nhưng cần thâm hụt calo khoảng 500 kcal mỗi ngày. Bạn nên ưu tiên ăn tinh bột chuyển hóa chậm (gạo lứt, khoai lang), tăng cường ức gà, cá hồi và rau xanh. Hạn chế tối đa đồ chiên xào và trà sữa nhé!', 60, now() - interval '2 days' + interval '5 minutes'),
('5e18b9ce-6524-4274-b49e-4e3a73404023', '89cbeb02-f385-453e-85c1-3713bdfd64bb', 'user', 'Tôi đang tập gym tăng cơ, mỗi ngày cần nạp bao nhiêu protein?', 15, now() - interval '2 days' + interval '0 minutes'),
('64885feb-fe30-4acc-af8f-a5160dcff612', '89cbeb02-f385-453e-85c1-3713bdfd64bb', 'assistant', 'Chào bạn, đối với người tập gym tăng cơ, lượng protein cần thiết là khoảng 1.6g - 2.2g trên mỗi kg thể trọng. Ví dụ bạn nặng 60kg, bạn cần nạp khoảng 96g - 132g protein mỗi ngày từ ức gà, trứng, thịt bò hoặc whey protein.', 55, now() - interval '2 days' + interval '5 minutes'),
('0eb02c48-883e-44d0-8cc1-fb2fe9d7557c', '2e13f918-6c28-476c-ab18-58b3aecc8700', 'user', 'Tôi muốn giảm 5kg trong 1 tháng, nên ăn uống thế nào?', 13, now() - interval '2 days' + interval '0 minutes'),
('6dffdda8-aead-4797-a49d-24c4895a2c27', '2e13f918-6c28-476c-ab18-58b3aecc8700', 'assistant', 'Chào bạn! Giảm 5kg/tháng là mục tiêu khả thi nhưng cần thâm hụt calo khoảng 500 kcal mỗi ngày. Bạn nên ưu tiên ăn tinh bột chuyển hóa chậm (gạo lứt, khoai lang), tăng cường ức gà, cá hồi và rau xanh. Hạn chế tối đa đồ chiên xào và trà sữa nhé!', 60, now() - interval '2 days' + interval '5 minutes'),
('2b7fce20-9bc1-4a0a-b9cb-2288120d8ab8', '9f09129b-0854-403d-b2fd-a8b84d6eb029', 'user', 'Tôi đang tập gym tăng cơ, mỗi ngày cần nạp bao nhiêu protein?', 15, now() - interval '2 days' + interval '0 minutes'),
('c03dba3d-926d-47a4-90dd-cf77a2a504c1', '9f09129b-0854-403d-b2fd-a8b84d6eb029', 'assistant', 'Chào bạn, đối với người tập gym tăng cơ, lượng protein cần thiết là khoảng 1.6g - 2.2g trên mỗi kg thể trọng. Ví dụ bạn nặng 60kg, bạn cần nạp khoảng 96g - 132g protein mỗi ngày từ ức gà, trứng, thịt bò hoặc whey protein.', 55, now() - interval '2 days' + interval '5 minutes'),
('2ba822e3-2c7c-4d27-b2dd-825cd57d9c0c', 'f3519ca6-9581-4e0c-8f39-fbb591b021eb', 'user', 'Tôi muốn giảm 5kg trong 1 tháng, nên ăn uống thế nào?', 13, now() - interval '2 days' + interval '0 minutes'),
('3c6194f9-5c2e-4467-a268-514b25b82c5c', 'f3519ca6-9581-4e0c-8f39-fbb591b021eb', 'assistant', 'Chào bạn! Giảm 5kg/tháng là mục tiêu khả thi nhưng cần thâm hụt calo khoảng 500 kcal mỗi ngày. Bạn nên ưu tiên ăn tinh bột chuyển hóa chậm (gạo lứt, khoai lang), tăng cường ức gà, cá hồi và rau xanh. Hạn chế tối đa đồ chiên xào và trà sữa nhé!', 60, now() - interval '2 days' + interval '5 minutes'),
('cf22840f-8a83-4b59-ba06-661d124bc396', 'a088a941-7975-4a45-8ddc-ed3f28210969', 'user', 'Tôi đang tập gym tăng cơ, mỗi ngày cần nạp bao nhiêu protein?', 15, now() - interval '2 days' + interval '0 minutes'),
('b441e975-5dca-45d8-83dc-d1b943a110e1', 'a088a941-7975-4a45-8ddc-ed3f28210969', 'assistant', 'Chào bạn, đối với người tập gym tăng cơ, lượng protein cần thiết là khoảng 1.6g - 2.2g trên mỗi kg thể trọng. Ví dụ bạn nặng 60kg, bạn cần nạp khoảng 96g - 132g protein mỗi ngày từ ức gà, trứng, thịt bò hoặc whey protein.', 55, now() - interval '2 days' + interval '5 minutes'),
('54c041f4-7c25-4099-b192-df14662af140', '2e97c0b5-7c0d-46ea-a36a-60e1e375f6bd', 'user', 'Tôi muốn giảm 5kg trong 1 tháng, nên ăn uống thế nào?', 13, now() - interval '2 days' + interval '0 minutes'),
('bb9d6c94-1b66-4e7e-99d5-1e8000505028', '2e97c0b5-7c0d-46ea-a36a-60e1e375f6bd', 'assistant', 'Chào bạn! Giảm 5kg/tháng là mục tiêu khả thi nhưng cần thâm hụt calo khoảng 500 kcal mỗi ngày. Bạn nên ưu tiên ăn tinh bột chuyển hóa chậm (gạo lứt, khoai lang), tăng cường ức gà, cá hồi và rau xanh. Hạn chế tối đa đồ chiên xào và trà sữa nhé!', 60, now() - interval '2 days' + interval '5 minutes'),
('c4e34401-91b6-4a97-bbf3-8ace15e2f08b', '9a5a2c52-6d4c-494a-92a7-f194a564a1e3', 'user', 'Tôi đang tập gym tăng cơ, mỗi ngày cần nạp bao nhiêu protein?', 15, now() - interval '2 days' + interval '0 minutes'),
('8f8690df-0682-427b-abe7-ae8eaddcc052', '9a5a2c52-6d4c-494a-92a7-f194a564a1e3', 'assistant', 'Chào bạn, đối với người tập gym tăng cơ, lượng protein cần thiết là khoảng 1.6g - 2.2g trên mỗi kg thể trọng. Ví dụ bạn nặng 60kg, bạn cần nạp khoảng 96g - 132g protein mỗi ngày từ ức gà, trứng, thịt bò hoặc whey protein.', 55, now() - interval '2 days' + interval '5 minutes'),
('5050de50-fb80-4cf2-a9e9-c5562824e2ad', '9877c046-f1fc-460a-b5b8-cbc472248b5e', 'user', 'Tôi muốn giảm 5kg trong 1 tháng, nên ăn uống thế nào?', 13, now() - interval '2 days' + interval '0 minutes'),
('24fb0c82-cbcb-4532-8e72-89670cb4d5b3', '9877c046-f1fc-460a-b5b8-cbc472248b5e', 'assistant', 'Chào bạn! Giảm 5kg/tháng là mục tiêu khả thi nhưng cần thâm hụt calo khoảng 500 kcal mỗi ngày. Bạn nên ưu tiên ăn tinh bột chuyển hóa chậm (gạo lứt, khoai lang), tăng cường ức gà, cá hồi và rau xanh. Hạn chế tối đa đồ chiên xào và trà sữa nhé!', 60, now() - interval '2 days' + interval '5 minutes'),
('88481a01-8476-4d8c-b64d-dcfa6787862e', '61907a0d-f782-4440-a0e3-ce70857f1dc1', 'user', 'Tôi đang tập gym tăng cơ, mỗi ngày cần nạp bao nhiêu protein?', 15, now() - interval '2 days' + interval '0 minutes'),
('22911b37-bda6-4fae-aa40-a54e17eb02ab', '61907a0d-f782-4440-a0e3-ce70857f1dc1', 'assistant', 'Chào bạn, đối với người tập gym tăng cơ, lượng protein cần thiết là khoảng 1.6g - 2.2g trên mỗi kg thể trọng. Ví dụ bạn nặng 60kg, bạn cần nạp khoảng 96g - 132g protein mỗi ngày từ ức gà, trứng, thịt bò hoặc whey protein.', 55, now() - interval '2 days' + interval '5 minutes'),
('a00a6085-65f6-4649-bc82-e58600fa93a6', 'ea792b53-85d6-44d5-b266-ce649e298b2d', 'user', 'Tôi muốn giảm 5kg trong 1 tháng, nên ăn uống thế nào?', 13, now() - interval '2 days' + interval '0 minutes'),
('c9900fb6-d2d2-4788-a33f-e25991119162', 'ea792b53-85d6-44d5-b266-ce649e298b2d', 'assistant', 'Chào bạn! Giảm 5kg/tháng là mục tiêu khả thi nhưng cần thâm hụt calo khoảng 500 kcal mỗi ngày. Bạn nên ưu tiên ăn tinh bột chuyển hóa chậm (gạo lứt, khoai lang), tăng cường ức gà, cá hồi và rau xanh. Hạn chế tối đa đồ chiên xào và trà sữa nhé!', 60, now() - interval '2 days' + interval '5 minutes'),
('cb6973fe-1b45-4cba-87a1-8c510dc36b17', '122f09d2-1081-4f20-88b9-bd4effe769de', 'user', 'Tôi đang tập gym tăng cơ, mỗi ngày cần nạp bao nhiêu protein?', 15, now() - interval '2 days' + interval '0 minutes'),
('8c37731b-b4db-4145-be28-1c497c544cc2', '122f09d2-1081-4f20-88b9-bd4effe769de', 'assistant', 'Chào bạn, đối với người tập gym tăng cơ, lượng protein cần thiết là khoảng 1.6g - 2.2g trên mỗi kg thể trọng. Ví dụ bạn nặng 60kg, bạn cần nạp khoảng 96g - 132g protein mỗi ngày từ ức gà, trứng, thịt bò hoặc whey protein.', 55, now() - interval '2 days' + interval '5 minutes')
ON CONFLICT DO NOTHING;

INSERT INTO recommendation_history ("Id", "UserId", "Type", "Input", "Output", "Confidence", "CreatedAt")
VALUES
('140e2a62-2316-4185-a98b-f5b5b6287ca5', 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'MealPlan', '{"calories": 1800, "goal": "lose weight", "preferred": "Vietnamese"}', '{"breakfast": "Cháo yến mạch", "lunch": "Salad ức gà", "dinner": "Cá hồi áp chảo"}', 0.95, now() - interval '1 day'),
('a8e10ff4-a461-4c2f-aeb3-1ca94cede19f', 'cccccccc-cccc-cccc-cccc-cccccccccccc', 'MealPlan', '{"calories": 1800, "goal": "lose weight", "preferred": "Vietnamese"}', '{"breakfast": "Cháo yến mạch", "lunch": "Salad ức gà", "dinner": "Cá hồi áp chảo"}', 0.95, now() - interval '1 day'),
('f2138dcd-8a30-4827-a0e3-7df069f05190', 'dddddddd-dddd-dddd-dddd-dddddddddddd', 'MealPlan', '{"calories": 1800, "goal": "lose weight", "preferred": "Vietnamese"}', '{"breakfast": "Cháo yến mạch", "lunch": "Salad ức gà", "dinner": "Cá hồi áp chảo"}', 0.95, now() - interval '1 day'),
('5c0b848c-95a3-4a92-8de8-8ccc6e400531', 'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee', 'MealPlan', '{"calories": 1800, "goal": "lose weight", "preferred": "Vietnamese"}', '{"breakfast": "Cháo yến mạch", "lunch": "Salad ức gà", "dinner": "Cá hồi áp chảo"}', 0.95, now() - interval '1 day'),
('eea98ac7-8b45-481e-8ae6-5c549004e1eb', 'ffffffff-ffff-ffff-ffff-ffffffffffff', 'MealPlan', '{"calories": 1800, "goal": "lose weight", "preferred": "Vietnamese"}', '{"breakfast": "Cháo yến mạch", "lunch": "Salad ức gà", "dinner": "Cá hồi áp chảo"}', 0.95, now() - interval '1 day'),
('277d5e7a-7dcf-4395-93e7-357f7cbf8dcc', '885810e8-168f-4608-a72e-e23a20dfd258', 'MealPlan', '{"calories": 1800, "goal": "lose weight", "preferred": "Vietnamese"}', '{"breakfast": "Cháo yến mạch", "lunch": "Salad ức gà", "dinner": "Cá hồi áp chảo"}', 0.95, now() - interval '1 day'),
('e313742d-5776-4568-8c02-831cde456d23', '48069bd5-f29a-417d-bdeb-c00797968aca', 'MealPlan', '{"calories": 1800, "goal": "lose weight", "preferred": "Vietnamese"}', '{"breakfast": "Cháo yến mạch", "lunch": "Salad ức gà", "dinner": "Cá hồi áp chảo"}', 0.95, now() - interval '1 day'),
('5b4dbeef-0350-4be0-8ee5-659f9e86a9bd', '9afb13a5-e5a1-4342-9ce1-33bf7cc1de70', 'MealPlan', '{"calories": 1800, "goal": "lose weight", "preferred": "Vietnamese"}', '{"breakfast": "Cháo yến mạch", "lunch": "Salad ức gà", "dinner": "Cá hồi áp chảo"}', 0.95, now() - interval '1 day'),
('fddb765c-9e8a-4781-a1f7-cee4c9b3fc2b', '081b4669-b97f-4e75-b089-4c8de0151653', 'MealPlan', '{"calories": 1800, "goal": "lose weight", "preferred": "Vietnamese"}', '{"breakfast": "Cháo yến mạch", "lunch": "Salad ức gà", "dinner": "Cá hồi áp chảo"}', 0.95, now() - interval '1 day'),
('4bd2dd83-48b4-46de-8ef0-066b3abb978c', '586209d0-d3c4-43a4-bba7-5d4c73b37bc1', 'MealPlan', '{"calories": 1800, "goal": "lose weight", "preferred": "Vietnamese"}', '{"breakfast": "Cháo yến mạch", "lunch": "Salad ức gà", "dinner": "Cá hồi áp chảo"}', 0.95, now() - interval '1 day'),
('ae83de28-51fa-405b-bd68-c86375f7b7b1', 'b022ccde-0aa6-4b11-bd7b-f76aaf2c2b17', 'MealPlan', '{"calories": 1800, "goal": "lose weight", "preferred": "Vietnamese"}', '{"breakfast": "Cháo yến mạch", "lunch": "Salad ức gà", "dinner": "Cá hồi áp chảo"}', 0.95, now() - interval '1 day'),
('9770f4e1-b730-4a87-ab8b-4c5c3e2bfaea', '453681f7-f489-47ed-842c-bc3ffd220423', 'MealPlan', '{"calories": 1800, "goal": "lose weight", "preferred": "Vietnamese"}', '{"breakfast": "Cháo yến mạch", "lunch": "Salad ức gà", "dinner": "Cá hồi áp chảo"}', 0.95, now() - interval '1 day'),
('7ac9afe9-6031-4e98-8d93-b98131187e59', '396f9dff-6c2a-422f-b0cc-8eb451168ed3', 'MealPlan', '{"calories": 1800, "goal": "lose weight", "preferred": "Vietnamese"}', '{"breakfast": "Cháo yến mạch", "lunch": "Salad ức gà", "dinner": "Cá hồi áp chảo"}', 0.95, now() - interval '1 day'),
('cd2ee33c-d1d6-4877-9522-21f36c0b363a', '5dc50160-db9e-447a-ba33-9026d8800ab5', 'MealPlan', '{"calories": 1800, "goal": "lose weight", "preferred": "Vietnamese"}', '{"breakfast": "Cháo yến mạch", "lunch": "Salad ức gà", "dinner": "Cá hồi áp chảo"}', 0.95, now() - interval '1 day'),
('02d7b550-4ee9-474c-aedd-19eb5f834bef', '212ea8ea-749e-44a1-92d2-636bd617cbc8', 'MealPlan', '{"calories": 1800, "goal": "lose weight", "preferred": "Vietnamese"}', '{"breakfast": "Cháo yến mạch", "lunch": "Salad ức gà", "dinner": "Cá hồi áp chảo"}', 0.95, now() - interval '1 day')
ON CONFLICT DO NOTHING;

INSERT INTO recommendation_feedbacks ("Id", "RecommendationId", "Rating", "Feedback", "CreatedAt")
VALUES
('d7af81fb-f3d3-4ac5-9ae6-2a3b06638c22', '140e2a62-2316-4185-a98b-f5b5b6287ca5', 4, 'Đề xuất thực đơn rất ngon và phù hợp với khẩu vị của tôi', now() - interval '1 day'),
('d4abff69-db29-423a-b5b4-1f62180d7703', 'a8e10ff4-a461-4c2f-aeb3-1ca94cede19f', 4, 'Đề xuất thực đơn rất ngon và phù hợp với khẩu vị của tôi', now() - interval '1 day'),
('6d37395d-4641-4a09-ba8d-520a3eef52ff', 'f2138dcd-8a30-4827-a0e3-7df069f05190', 4, 'Đề xuất thực đơn rất ngon và phù hợp với khẩu vị của tôi', now() - interval '1 day'),
('46b8b2b1-20b8-446e-9110-c758d4adec9d', '5c0b848c-95a3-4a92-8de8-8ccc6e400531', 5, 'Đề xuất thực đơn rất ngon và phù hợp với khẩu vị của tôi', now() - interval '1 day'),
('1fa9347a-6a7d-49aa-bb4e-d1fcf200727d', 'eea98ac7-8b45-481e-8ae6-5c549004e1eb', 4, 'Đề xuất thực đơn rất ngon và phù hợp với khẩu vị của tôi', now() - interval '1 day'),
('2874c206-d07b-4075-8beb-c33eb6cf2db0', '277d5e7a-7dcf-4395-93e7-357f7cbf8dcc', 5, 'Đề xuất thực đơn rất ngon và phù hợp với khẩu vị của tôi', now() - interval '1 day'),
('01257e42-6e83-4271-babd-29d2f677dfa5', 'e313742d-5776-4568-8c02-831cde456d23', 5, 'Đề xuất thực đơn rất ngon và phù hợp với khẩu vị của tôi', now() - interval '1 day'),
('3b06095c-0851-4a19-82a2-a5fcf4aa64cd', '5b4dbeef-0350-4be0-8ee5-659f9e86a9bd', 5, 'Đề xuất thực đơn rất ngon và phù hợp với khẩu vị của tôi', now() - interval '1 day'),
('91c636bd-0db1-4301-b3c7-a999c4bdda67', 'fddb765c-9e8a-4781-a1f7-cee4c9b3fc2b', 4, 'Đề xuất thực đơn rất ngon và phù hợp với khẩu vị của tôi', now() - interval '1 day'),
('3035f852-cca9-4e4b-a0dd-11c6922e0597', '4bd2dd83-48b4-46de-8ef0-066b3abb978c', 4, 'Đề xuất thực đơn rất ngon và phù hợp với khẩu vị của tôi', now() - interval '1 day'),
('6824c371-0f79-4c8d-89cf-be9193af6ee4', 'ae83de28-51fa-405b-bd68-c86375f7b7b1', 4, 'Đề xuất thực đơn rất ngon và phù hợp với khẩu vị của tôi', now() - interval '1 day'),
('90b3c35f-4e54-4090-8025-a39f86ac6e0f', '9770f4e1-b730-4a87-ab8b-4c5c3e2bfaea', 5, 'Đề xuất thực đơn rất ngon và phù hợp với khẩu vị của tôi', now() - interval '1 day'),
('8809745c-b5b0-451f-8bbb-63a5e3449582', '7ac9afe9-6031-4e98-8d93-b98131187e59', 5, 'Đề xuất thực đơn rất ngon và phù hợp với khẩu vị của tôi', now() - interval '1 day'),
('78aadd79-57af-41dd-9d5f-003749d0a459', 'cd2ee33c-d1d6-4877-9522-21f36c0b363a', 5, 'Đề xuất thực đơn rất ngon và phù hợp với khẩu vị của tôi', now() - interval '1 day'),
('7c542d46-75f9-4e26-9dcb-d278619754bc', '02d7b550-4ee9-474c-aedd-19eb5f834bef', 5, 'Đề xuất thực đơn rất ngon và phù hợp với khẩu vị của tôi', now() - interval '1 day')
ON CONFLICT DO NOTHING;

INSERT INTO budget_requests ("Id", "UserId", "BudgetVnd", "TimeLimitMin", "Result", "CreatedAt")
VALUES
('0160fb8e-51cf-4bbe-a263-bf4d98430f89', 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 150000, 30, '{"status": "success", "suggested_meals": [{"name": "Ức gà áp chảo", "price": 35000}, {"name": "Cơm gạo lứt", "price": 10000}]}', now() - interval '1 day'),
('e91f53ce-36da-4ea6-90c8-0cf15b310c62', 'cccccccc-cccc-cccc-cccc-cccccccccccc', 150000, 30, '{"status": "success", "suggested_meals": [{"name": "Ức gà áp chảo", "price": 35000}, {"name": "Cơm gạo lứt", "price": 10000}]}', now() - interval '1 day'),
('cc3e1f16-2760-4e1c-ab8b-f14860bfbc02', 'dddddddd-dddd-dddd-dddd-dddddddddddd', 150000, 30, '{"status": "success", "suggested_meals": [{"name": "Ức gà áp chảo", "price": 35000}, {"name": "Cơm gạo lứt", "price": 10000}]}', now() - interval '1 day'),
('5080dc5e-170a-4aab-ad82-05d2bdb6d1c5', 'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee', 150000, 30, '{"status": "success", "suggested_meals": [{"name": "Ức gà áp chảo", "price": 35000}, {"name": "Cơm gạo lứt", "price": 10000}]}', now() - interval '1 day'),
('4ed09661-4d04-43c7-a696-d653152f8b47', 'ffffffff-ffff-ffff-ffff-ffffffffffff', 150000, 30, '{"status": "success", "suggested_meals": [{"name": "Ức gà áp chảo", "price": 35000}, {"name": "Cơm gạo lứt", "price": 10000}]}', now() - interval '1 day'),
('998bb36f-306c-42f0-b643-a7ff76fa4d3b', '885810e8-168f-4608-a72e-e23a20dfd258', 150000, 30, '{"status": "success", "suggested_meals": [{"name": "Ức gà áp chảo", "price": 35000}, {"name": "Cơm gạo lứt", "price": 10000}]}', now() - interval '1 day'),
('6710a97b-55c1-4edd-bbb5-deba8205635b', '48069bd5-f29a-417d-bdeb-c00797968aca', 150000, 30, '{"status": "success", "suggested_meals": [{"name": "Ức gà áp chảo", "price": 35000}, {"name": "Cơm gạo lứt", "price": 10000}]}', now() - interval '1 day'),
('10683c83-6861-4fd9-a317-258e2d952811', '9afb13a5-e5a1-4342-9ce1-33bf7cc1de70', 150000, 30, '{"status": "success", "suggested_meals": [{"name": "Ức gà áp chảo", "price": 35000}, {"name": "Cơm gạo lứt", "price": 10000}]}', now() - interval '1 day'),
('cdcf3b60-e5d2-47eb-b1a0-d9b75cd44021', '081b4669-b97f-4e75-b089-4c8de0151653', 150000, 30, '{"status": "success", "suggested_meals": [{"name": "Ức gà áp chảo", "price": 35000}, {"name": "Cơm gạo lứt", "price": 10000}]}', now() - interval '1 day'),
('1a24704f-d494-4feb-a0f3-f9f95a90e7cc', '586209d0-d3c4-43a4-bba7-5d4c73b37bc1', 150000, 30, '{"status": "success", "suggested_meals": [{"name": "Ức gà áp chảo", "price": 35000}, {"name": "Cơm gạo lứt", "price": 10000}]}', now() - interval '1 day'),
('2fd2e3a0-de5e-4be8-bedd-c97f00597835', 'b022ccde-0aa6-4b11-bd7b-f76aaf2c2b17', 150000, 30, '{"status": "success", "suggested_meals": [{"name": "Ức gà áp chảo", "price": 35000}, {"name": "Cơm gạo lứt", "price": 10000}]}', now() - interval '1 day'),
('176b1981-0a1d-485d-976e-a4fe0094f0a5', '453681f7-f489-47ed-842c-bc3ffd220423', 150000, 30, '{"status": "success", "suggested_meals": [{"name": "Ức gà áp chảo", "price": 35000}, {"name": "Cơm gạo lứt", "price": 10000}]}', now() - interval '1 day'),
('dea2301f-0b62-422c-b502-c7613510bb75', '396f9dff-6c2a-422f-b0cc-8eb451168ed3', 150000, 30, '{"status": "success", "suggested_meals": [{"name": "Ức gà áp chảo", "price": 35000}, {"name": "Cơm gạo lứt", "price": 10000}]}', now() - interval '1 day'),
('5613c5d4-404e-4a82-99b3-c64c754df45e', '5dc50160-db9e-447a-ba33-9026d8800ab5', 150000, 30, '{"status": "success", "suggested_meals": [{"name": "Ức gà áp chảo", "price": 35000}, {"name": "Cơm gạo lứt", "price": 10000}]}', now() - interval '1 day'),
('77687b5f-0881-445a-bca9-addffd534305', '212ea8ea-749e-44a1-92d2-636bd617cbc8', 150000, 30, '{"status": "success", "suggested_meals": [{"name": "Ức gà áp chảo", "price": 35000}, {"name": "Cơm gạo lứt", "price": 10000}]}', now() - interval '1 day')
ON CONFLICT DO NOTHING;

INSERT INTO notification_settings ("Id", "UserId", "MealReminderEnabled", "MealReminderOffsetMinutes", "PrepReminderEnabled", "PrepReminderOffsetMinutes", "InAppEnabled", "PushEnabled", "CreatedAt", "UpdatedAt")
VALUES
('9cfd98b1-345a-495e-9b88-818957d1d4d7', 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', true, 30, true, 20, true, true, now(), now()),
('45456983-3d83-4b3c-bb18-c16943b88c6c', 'cccccccc-cccc-cccc-cccc-cccccccccccc', true, 30, true, 20, true, true, now(), now()),
('925c4319-7aaa-47f3-ac63-fbe69c8ec8a6', 'dddddddd-dddd-dddd-dddd-dddddddddddd', true, 30, true, 20, true, true, now(), now()),
('0ad58745-4382-40fc-952c-6c5533af072e', 'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee', true, 30, true, 20, true, true, now(), now()),
('42824d36-8062-4974-ad23-bd639987b249', 'ffffffff-ffff-ffff-ffff-ffffffffffff', true, 30, true, 20, true, true, now(), now()),
('c2a4a5c4-5d46-4479-97d5-568a31856220', '885810e8-168f-4608-a72e-e23a20dfd258', true, 30, true, 20, true, true, now(), now()),
('7dafb9de-2c68-4168-bf05-6c21676a6c7a', '48069bd5-f29a-417d-bdeb-c00797968aca', true, 30, true, 20, true, true, now(), now()),
('b9183c29-0125-47a7-a2e8-bfc140686ff2', '9afb13a5-e5a1-4342-9ce1-33bf7cc1de70', true, 30, true, 20, true, true, now(), now()),
('63d15ccc-6ba0-4c3c-98dd-787d75352155', '081b4669-b97f-4e75-b089-4c8de0151653', true, 30, true, 20, true, true, now(), now()),
('43f82d5c-bd79-4646-81b7-ccf3282a7829', '586209d0-d3c4-43a4-bba7-5d4c73b37bc1', true, 30, true, 20, true, true, now(), now()),
('8f813477-425d-4758-89dc-63f5e10b6b44', 'b022ccde-0aa6-4b11-bd7b-f76aaf2c2b17', true, 30, true, 20, true, true, now(), now()),
('3b64a3c3-4da5-449a-8b44-cc8c03d0f2e6', '453681f7-f489-47ed-842c-bc3ffd220423', true, 30, true, 20, true, true, now(), now()),
('675434c6-f437-4535-b7bc-cbed45cfafa2', '396f9dff-6c2a-422f-b0cc-8eb451168ed3', true, 30, true, 20, true, true, now(), now()),
('f47f9094-d6db-42ba-ab9b-f8908e4a3efa', '5dc50160-db9e-447a-ba33-9026d8800ab5', true, 30, true, 20, true, true, now(), now()),
('2b50ba2d-4f52-422b-827c-d460412636ec', '212ea8ea-749e-44a1-92d2-636bd617cbc8', true, 30, true, 20, true, true, now(), now())
ON CONFLICT DO NOTHING;

INSERT INTO notifications ("Id", "UserId", "Title", "Body", "Type", "IsRead", "CreatedAt", "ScheduledAt", "SentAt", "ReadAt")
VALUES
('95928080-6408-4adf-84de-1d23029e7c38', 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'Nhắc nhở bữa ăn 1', 'Đã đến giờ ghi nhận nhật ký ăn uống cho bữa ăn của bạn rồi!', 'Reminder', true, now() - interval '1 day', now() - interval '1 day', now() - interval '1 day', now() - interval '1 day'),
('3ebbc27a-46cc-4e11-b3bf-df782b2aa329', 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'Nhắc nhở bữa ăn 2', 'Đã đến giờ ghi nhận nhật ký ăn uống cho bữa ăn của bạn rồi!', 'Reminder', true, now() - interval '1 day', now() - interval '1 day', now() - interval '1 day', now() - interval '1 day'),
('51c7b2f0-6011-46a0-9abc-e52b183c3f05', 'cccccccc-cccc-cccc-cccc-cccccccccccc', 'Nhắc nhở bữa ăn 1', 'Đã đến giờ ghi nhận nhật ký ăn uống cho bữa ăn của bạn rồi!', 'Reminder', true, now() - interval '1 day', now() - interval '1 day', now() - interval '1 day', now() - interval '1 day'),
('18598911-2096-4ea5-a79d-cc6e5ce7141e', 'cccccccc-cccc-cccc-cccc-cccccccccccc', 'Nhắc nhở bữa ăn 2', 'Đã đến giờ ghi nhận nhật ký ăn uống cho bữa ăn của bạn rồi!', 'Reminder', true, now() - interval '1 day', now() - interval '1 day', now() - interval '1 day', now() - interval '1 day'),
('b4ec9ee4-a64f-4949-b9fe-09cdbc8aaf95', 'dddddddd-dddd-dddd-dddd-dddddddddddd', 'Nhắc nhở bữa ăn 1', 'Đã đến giờ ghi nhận nhật ký ăn uống cho bữa ăn của bạn rồi!', 'Reminder', true, now() - interval '1 day', now() - interval '1 day', now() - interval '1 day', now() - interval '1 day'),
('5925de1d-dfe4-47f4-b2bd-d11d79ab676b', 'dddddddd-dddd-dddd-dddd-dddddddddddd', 'Nhắc nhở bữa ăn 2', 'Đã đến giờ ghi nhận nhật ký ăn uống cho bữa ăn của bạn rồi!', 'Reminder', true, now() - interval '1 day', now() - interval '1 day', now() - interval '1 day', now() - interval '1 day'),
('ca7d4918-75c4-4f0c-bfc8-d1f160575094', 'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee', 'Nhắc nhở bữa ăn 1', 'Đã đến giờ ghi nhận nhật ký ăn uống cho bữa ăn của bạn rồi!', 'Reminder', true, now() - interval '1 day', now() - interval '1 day', now() - interval '1 day', now() - interval '1 day'),
('ba3a8a24-5b8a-4ea3-9151-f73ea84f4119', 'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee', 'Nhắc nhở bữa ăn 2', 'Đã đến giờ ghi nhận nhật ký ăn uống cho bữa ăn của bạn rồi!', 'Reminder', true, now() - interval '1 day', now() - interval '1 day', now() - interval '1 day', now() - interval '1 day'),
('56c7ba5b-e3b9-43d9-a7a4-f650a5ae8110', 'ffffffff-ffff-ffff-ffff-ffffffffffff', 'Nhắc nhở bữa ăn 1', 'Đã đến giờ ghi nhận nhật ký ăn uống cho bữa ăn của bạn rồi!', 'Reminder', true, now() - interval '1 day', now() - interval '1 day', now() - interval '1 day', now() - interval '1 day'),
('d83f5ca9-d60e-455b-bee4-e15bf778debb', 'ffffffff-ffff-ffff-ffff-ffffffffffff', 'Nhắc nhở bữa ăn 2', 'Đã đến giờ ghi nhận nhật ký ăn uống cho bữa ăn của bạn rồi!', 'Reminder', true, now() - interval '1 day', now() - interval '1 day', now() - interval '1 day', now() - interval '1 day'),
('589cb3c8-2ba1-4a5d-af32-52d493ac7c4b', '885810e8-168f-4608-a72e-e23a20dfd258', 'Nhắc nhở bữa ăn 1', 'Đã đến giờ ghi nhận nhật ký ăn uống cho bữa ăn của bạn rồi!', 'Reminder', true, now() - interval '1 day', now() - interval '1 day', now() - interval '1 day', now() - interval '1 day'),
('a5d13fcb-7a61-44ea-9b8e-c3063737b568', '885810e8-168f-4608-a72e-e23a20dfd258', 'Nhắc nhở bữa ăn 2', 'Đã đến giờ ghi nhận nhật ký ăn uống cho bữa ăn của bạn rồi!', 'Reminder', true, now() - interval '1 day', now() - interval '1 day', now() - interval '1 day', now() - interval '1 day'),
('2ba4a0af-4e8d-4cdd-b804-74be91f9b885', '48069bd5-f29a-417d-bdeb-c00797968aca', 'Nhắc nhở bữa ăn 1', 'Đã đến giờ ghi nhận nhật ký ăn uống cho bữa ăn của bạn rồi!', 'Reminder', true, now() - interval '1 day', now() - interval '1 day', now() - interval '1 day', now() - interval '1 day'),
('263f369d-4601-4b53-828e-84e4cb59fb82', '48069bd5-f29a-417d-bdeb-c00797968aca', 'Nhắc nhở bữa ăn 2', 'Đã đến giờ ghi nhận nhật ký ăn uống cho bữa ăn của bạn rồi!', 'Reminder', true, now() - interval '1 day', now() - interval '1 day', now() - interval '1 day', now() - interval '1 day'),
('c3f968ed-6a54-470b-bf76-396fd755a9db', '9afb13a5-e5a1-4342-9ce1-33bf7cc1de70', 'Nhắc nhở bữa ăn 1', 'Đã đến giờ ghi nhận nhật ký ăn uống cho bữa ăn của bạn rồi!', 'Reminder', true, now() - interval '1 day', now() - interval '1 day', now() - interval '1 day', now() - interval '1 day'),
('0cb889a8-6d69-4c5e-9de1-4818c7300a05', '9afb13a5-e5a1-4342-9ce1-33bf7cc1de70', 'Nhắc nhở bữa ăn 2', 'Đã đến giờ ghi nhận nhật ký ăn uống cho bữa ăn của bạn rồi!', 'Reminder', true, now() - interval '1 day', now() - interval '1 day', now() - interval '1 day', now() - interval '1 day'),
('a0b6b137-5632-461e-b7b5-e3a8df2666dc', '081b4669-b97f-4e75-b089-4c8de0151653', 'Nhắc nhở bữa ăn 1', 'Đã đến giờ ghi nhận nhật ký ăn uống cho bữa ăn của bạn rồi!', 'Reminder', true, now() - interval '1 day', now() - interval '1 day', now() - interval '1 day', now() - interval '1 day'),
('36a43dec-790c-4d68-b6cd-d6aabb897231', '081b4669-b97f-4e75-b089-4c8de0151653', 'Nhắc nhở bữa ăn 2', 'Đã đến giờ ghi nhận nhật ký ăn uống cho bữa ăn của bạn rồi!', 'Reminder', true, now() - interval '1 day', now() - interval '1 day', now() - interval '1 day', now() - interval '1 day'),
('b7e34712-b822-4a16-be9d-5aacc070b1a4', '586209d0-d3c4-43a4-bba7-5d4c73b37bc1', 'Nhắc nhở bữa ăn 1', 'Đã đến giờ ghi nhận nhật ký ăn uống cho bữa ăn của bạn rồi!', 'Reminder', true, now() - interval '1 day', now() - interval '1 day', now() - interval '1 day', now() - interval '1 day'),
('39ffb556-87cc-4c92-88cd-d57316123416', '586209d0-d3c4-43a4-bba7-5d4c73b37bc1', 'Nhắc nhở bữa ăn 2', 'Đã đến giờ ghi nhận nhật ký ăn uống cho bữa ăn của bạn rồi!', 'Reminder', true, now() - interval '1 day', now() - interval '1 day', now() - interval '1 day', now() - interval '1 day'),
('280b7fad-6dd2-4870-bb4e-75282670843c', 'b022ccde-0aa6-4b11-bd7b-f76aaf2c2b17', 'Nhắc nhở bữa ăn 1', 'Đã đến giờ ghi nhận nhật ký ăn uống cho bữa ăn của bạn rồi!', 'Reminder', true, now() - interval '1 day', now() - interval '1 day', now() - interval '1 day', now() - interval '1 day'),
('c69c0b6d-4f60-46f9-bdb1-aaaf0dce5564', 'b022ccde-0aa6-4b11-bd7b-f76aaf2c2b17', 'Nhắc nhở bữa ăn 2', 'Đã đến giờ ghi nhận nhật ký ăn uống cho bữa ăn của bạn rồi!', 'Reminder', true, now() - interval '1 day', now() - interval '1 day', now() - interval '1 day', now() - interval '1 day'),
('6cd1c54a-8f1f-40b9-9594-058e3fa516f2', '453681f7-f489-47ed-842c-bc3ffd220423', 'Nhắc nhở bữa ăn 1', 'Đã đến giờ ghi nhận nhật ký ăn uống cho bữa ăn của bạn rồi!', 'Reminder', true, now() - interval '1 day', now() - interval '1 day', now() - interval '1 day', now() - interval '1 day'),
('01907e6f-51d4-48e1-bbd7-610f3861cbfd', '453681f7-f489-47ed-842c-bc3ffd220423', 'Nhắc nhở bữa ăn 2', 'Đã đến giờ ghi nhận nhật ký ăn uống cho bữa ăn của bạn rồi!', 'Reminder', true, now() - interval '1 day', now() - interval '1 day', now() - interval '1 day', now() - interval '1 day'),
('0f4073d6-1273-446b-a7d6-3393636b4655', '396f9dff-6c2a-422f-b0cc-8eb451168ed3', 'Nhắc nhở bữa ăn 1', 'Đã đến giờ ghi nhận nhật ký ăn uống cho bữa ăn của bạn rồi!', 'Reminder', true, now() - interval '1 day', now() - interval '1 day', now() - interval '1 day', now() - interval '1 day'),
('ee4bfdcc-3047-4bf9-a037-d919aa21cb19', '396f9dff-6c2a-422f-b0cc-8eb451168ed3', 'Nhắc nhở bữa ăn 2', 'Đã đến giờ ghi nhận nhật ký ăn uống cho bữa ăn của bạn rồi!', 'Reminder', true, now() - interval '1 day', now() - interval '1 day', now() - interval '1 day', now() - interval '1 day'),
('9cf0d1f9-6e77-465d-8139-e6f8812a47f2', '5dc50160-db9e-447a-ba33-9026d8800ab5', 'Nhắc nhở bữa ăn 1', 'Đã đến giờ ghi nhận nhật ký ăn uống cho bữa ăn của bạn rồi!', 'Reminder', true, now() - interval '1 day', now() - interval '1 day', now() - interval '1 day', now() - interval '1 day'),
('e9101e62-9484-4f9b-878b-85fd489ee64d', '5dc50160-db9e-447a-ba33-9026d8800ab5', 'Nhắc nhở bữa ăn 2', 'Đã đến giờ ghi nhận nhật ký ăn uống cho bữa ăn của bạn rồi!', 'Reminder', true, now() - interval '1 day', now() - interval '1 day', now() - interval '1 day', now() - interval '1 day'),
('62de0955-2f9b-47a9-b4de-0ed0114313d1', '212ea8ea-749e-44a1-92d2-636bd617cbc8', 'Nhắc nhở bữa ăn 1', 'Đã đến giờ ghi nhận nhật ký ăn uống cho bữa ăn của bạn rồi!', 'Reminder', true, now() - interval '1 day', now() - interval '1 day', now() - interval '1 day', now() - interval '1 day'),
('f5554745-5d56-44c8-b7d7-a4b4822a9dfe', '212ea8ea-749e-44a1-92d2-636bd617cbc8', 'Nhắc nhở bữa ăn 2', 'Đã đến giờ ghi nhận nhật ký ăn uống cho bữa ăn của bạn rồi!', 'Reminder', true, now() - interval '1 day', now() - interval '1 day', now() - interval '1 day', now() - interval '1 day')
ON CONFLICT DO NOTHING;

INSERT INTO activity_logs ("Id", "UserId", "Action", "EntityType", "EntityId", "Metadata", "CreatedAt")
VALUES
('18e33332-e911-4278-9787-52142237fa61', 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'LogMeal', 'Meal', '463bf7db-2969-40a5-b260-71f45597718e', '{"action": "logmeal", "status": "completed"}', now()),
('9481ae88-b18a-4f11-92bc-6b239b6d19e2', 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'UpdateWeight', 'UpdateWeight', '4bd1352f-e9b1-4c72-b235-e9ecf5c0eb03', '{"action": "updateweight", "status": "completed"}', now()),
('ba598eaf-c510-4e8f-8ee8-0db1be28280b', 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'GenerateMenu', 'GenerateMenu', '115ee720-3c3d-4211-b505-c1ec83144c91', '{"action": "generatemenu", "status": "completed"}', now()),
('b2de76de-d544-4232-ae4d-7252d0c88c0b', 'cccccccc-cccc-cccc-cccc-cccccccccccc', 'LogMeal', 'Meal', 'f0dc792c-81a5-40d8-94de-d9ec174b5028', '{"action": "logmeal", "status": "completed"}', now()),
('825e70fe-a4b5-48a6-a4c9-c56c1130a779', 'cccccccc-cccc-cccc-cccc-cccccccccccc', 'UpdateWeight', 'UpdateWeight', 'a48d6e62-b796-4636-b044-100029f4f116', '{"action": "updateweight", "status": "completed"}', now()),
('87996d51-dda2-438d-b5e3-449b4cf956a1', 'cccccccc-cccc-cccc-cccc-cccccccccccc', 'GenerateMenu', 'GenerateMenu', '556d60d9-62e0-4d64-a146-208462f64a53', '{"action": "generatemenu", "status": "completed"}', now()),
('eeea0976-9b5e-47f0-ad63-9101cf6a2024', 'dddddddd-dddd-dddd-dddd-dddddddddddd', 'LogMeal', 'Meal', '68ebeaf5-6098-4335-9c1c-1d05ffabf553', '{"action": "logmeal", "status": "completed"}', now()),
('b4de3d82-12bc-4141-9e09-3b0326c5f7f2', 'dddddddd-dddd-dddd-dddd-dddddddddddd', 'UpdateWeight', 'UpdateWeight', '4077a8c7-d0f8-4ae7-88ae-bfa634d49354', '{"action": "updateweight", "status": "completed"}', now()),
('784f2081-98f9-45eb-9d79-ce771e3ed9c3', 'dddddddd-dddd-dddd-dddd-dddddddddddd', 'GenerateMenu', 'GenerateMenu', 'e6e2002a-bd3b-4b41-9ba1-e9ea7e32f399', '{"action": "generatemenu", "status": "completed"}', now()),
('11b04250-d71b-4cc4-8dbf-58cb7b5f54e3', 'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee', 'LogMeal', 'Meal', '37e47a60-ba94-4c2c-9f72-c159eb90cfe0', '{"action": "logmeal", "status": "completed"}', now()),
('f7629037-2ded-4780-b6f9-3e8354091e17', 'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee', 'UpdateWeight', 'UpdateWeight', '7f0ae97a-893b-4176-8f47-7cbeb764d24a', '{"action": "updateweight", "status": "completed"}', now()),
('ff565c2d-2d71-4925-8c3d-8a77aaa9ae2f', 'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee', 'GenerateMenu', 'GenerateMenu', '31f660d6-1c32-4278-9ba3-fb5eb0094793', '{"action": "generatemenu", "status": "completed"}', now()),
('26351991-b495-4e48-893b-2640a05ceb41', 'ffffffff-ffff-ffff-ffff-ffffffffffff', 'LogMeal', 'Meal', 'ccfe56d9-18ef-4665-9cdb-1e187eef273d', '{"action": "logmeal", "status": "completed"}', now()),
('d335ae8d-fb93-452d-bf91-6559f07431bd', 'ffffffff-ffff-ffff-ffff-ffffffffffff', 'UpdateWeight', 'UpdateWeight', '555968c9-4208-47d2-8f38-c7997ce35e35', '{"action": "updateweight", "status": "completed"}', now()),
('8a7ed5ef-f558-40e8-8972-186863eb1645', 'ffffffff-ffff-ffff-ffff-ffffffffffff', 'GenerateMenu', 'GenerateMenu', 'f2290cd6-b56c-480e-85dc-93a1379f1b33', '{"action": "generatemenu", "status": "completed"}', now()),
('7f3e8a93-654f-47be-97de-48d8913474f1', '885810e8-168f-4608-a72e-e23a20dfd258', 'LogMeal', 'Meal', '5562ea50-17bd-434f-b52a-fd013296b0a6', '{"action": "logmeal", "status": "completed"}', now()),
('5275b495-f698-4cf7-9b94-b08ddcd5179d', '885810e8-168f-4608-a72e-e23a20dfd258', 'UpdateWeight', 'UpdateWeight', 'b2c00e49-676b-44b4-a128-33e163ade53d', '{"action": "updateweight", "status": "completed"}', now()),
('ca0207dd-ded1-4f8b-aee2-df7d74c6573f', '885810e8-168f-4608-a72e-e23a20dfd258', 'GenerateMenu', 'GenerateMenu', '1e5fda65-73d9-46a7-8140-a628d71f1212', '{"action": "generatemenu", "status": "completed"}', now()),
('30250d36-e5ad-46ac-b474-422489fff6f5', '48069bd5-f29a-417d-bdeb-c00797968aca', 'LogMeal', 'Meal', 'd09cf3d0-b11e-40f0-84e0-706493516aa3', '{"action": "logmeal", "status": "completed"}', now()),
('3fcdc3d9-2cdc-4028-af45-a35ab44128a2', '48069bd5-f29a-417d-bdeb-c00797968aca', 'UpdateWeight', 'UpdateWeight', 'c2d7d052-f966-4d0b-a71b-fdd7ca921a92', '{"action": "updateweight", "status": "completed"}', now()),
('ae7922bf-ef14-432c-9363-05212438747e', '48069bd5-f29a-417d-bdeb-c00797968aca', 'GenerateMenu', 'GenerateMenu', '854a2207-9d3e-4f61-929a-56d55d51de42', '{"action": "generatemenu", "status": "completed"}', now()),
('cd8c2d94-4c89-4dd8-bcd8-d1069bc85867', '9afb13a5-e5a1-4342-9ce1-33bf7cc1de70', 'LogMeal', 'Meal', '88be103a-9402-48c1-97a7-ecd937731519', '{"action": "logmeal", "status": "completed"}', now()),
('27d30de2-832e-4dc2-a6b1-85be5ba17fc2', '9afb13a5-e5a1-4342-9ce1-33bf7cc1de70', 'UpdateWeight', 'UpdateWeight', '41345e37-452d-44e8-a644-3142ba46c4d1', '{"action": "updateweight", "status": "completed"}', now()),
('5d8f3a75-6cf8-41df-9508-52f956d385c3', '9afb13a5-e5a1-4342-9ce1-33bf7cc1de70', 'GenerateMenu', 'GenerateMenu', '9949cf3f-cd57-4b0d-a314-c913cf48b412', '{"action": "generatemenu", "status": "completed"}', now()),
('fd09b0e5-9ba1-4e3f-acfe-368f26d9683b', '081b4669-b97f-4e75-b089-4c8de0151653', 'LogMeal', 'Meal', 'b9b5bfb7-05e9-4887-bc62-f875c1a98c04', '{"action": "logmeal", "status": "completed"}', now()),
('21669d47-6356-42db-b669-447bf695b647', '081b4669-b97f-4e75-b089-4c8de0151653', 'UpdateWeight', 'UpdateWeight', '6a45ecdb-3234-4958-b108-425e8a7f66f0', '{"action": "updateweight", "status": "completed"}', now()),
('ec5dd194-3e23-491b-a3d6-5b824dfb40de', '081b4669-b97f-4e75-b089-4c8de0151653', 'GenerateMenu', 'GenerateMenu', '73d0ff28-fbff-409d-ac15-1817c5828565', '{"action": "generatemenu", "status": "completed"}', now()),
('c7713320-7e17-4717-869f-3a609f1050b1', '586209d0-d3c4-43a4-bba7-5d4c73b37bc1', 'LogMeal', 'Meal', 'c44786e4-3c24-444d-a17e-7bbf6c299560', '{"action": "logmeal", "status": "completed"}', now()),
('9c1647b8-1617-4b34-a9cd-a000323a2e54', '586209d0-d3c4-43a4-bba7-5d4c73b37bc1', 'UpdateWeight', 'UpdateWeight', 'ca0f68f2-0808-494e-8add-13a375564e9b', '{"action": "updateweight", "status": "completed"}', now()),
('224049c4-cd82-4f6c-9e0d-bf23fcb93c7c', '586209d0-d3c4-43a4-bba7-5d4c73b37bc1', 'GenerateMenu', 'GenerateMenu', '125945b3-66c5-4cae-9cce-4aafdc864a19', '{"action": "generatemenu", "status": "completed"}', now()),
('f58fdcba-8585-489b-aff4-64756e757db0', 'b022ccde-0aa6-4b11-bd7b-f76aaf2c2b17', 'LogMeal', 'Meal', 'c978de22-72e2-4beb-9259-e21353595b07', '{"action": "logmeal", "status": "completed"}', now()),
('51f3fc15-a4a2-46af-bd9c-76d4fb77f24a', 'b022ccde-0aa6-4b11-bd7b-f76aaf2c2b17', 'UpdateWeight', 'UpdateWeight', '62716105-fda9-4685-8eb1-38445720c932', '{"action": "updateweight", "status": "completed"}', now()),
('b68aab7e-9b4d-4c0d-9821-5d6d1646eea5', 'b022ccde-0aa6-4b11-bd7b-f76aaf2c2b17', 'GenerateMenu', 'GenerateMenu', '03178b72-9d27-44bc-93c9-bd1dbdfae1d3', '{"action": "generatemenu", "status": "completed"}', now()),
('db1ab812-e0f2-4648-9443-bdf5bed47ae7', '453681f7-f489-47ed-842c-bc3ffd220423', 'LogMeal', 'Meal', '354d0ab8-44bc-4584-9d8b-4af03b84f7e3', '{"action": "logmeal", "status": "completed"}', now()),
('87ee463a-3c23-4f29-9046-2b373f9c88db', '453681f7-f489-47ed-842c-bc3ffd220423', 'UpdateWeight', 'UpdateWeight', 'de5025a8-647a-40d6-b7b4-194e4d284097', '{"action": "updateweight", "status": "completed"}', now()),
('f6c913a5-af14-4413-ab23-683056b7399d', '453681f7-f489-47ed-842c-bc3ffd220423', 'GenerateMenu', 'GenerateMenu', 'd8d449a6-9469-456a-afe8-0c517469deac', '{"action": "generatemenu", "status": "completed"}', now()),
('d47baecd-4666-4a41-a30d-d6372596d141', '396f9dff-6c2a-422f-b0cc-8eb451168ed3', 'LogMeal', 'Meal', 'b823a687-3245-4098-8f6e-f0d248c62bb8', '{"action": "logmeal", "status": "completed"}', now()),
('b8410c77-d6b5-4b83-add1-1611d67c8b8d', '396f9dff-6c2a-422f-b0cc-8eb451168ed3', 'UpdateWeight', 'UpdateWeight', '5cf3ed87-8ab6-41a1-a3bd-f3381544e03b', '{"action": "updateweight", "status": "completed"}', now()),
('c8aada2f-314c-4dc7-901e-00a4b562e58f', '396f9dff-6c2a-422f-b0cc-8eb451168ed3', 'GenerateMenu', 'GenerateMenu', 'a1ff4b70-b028-425c-8ca3-aba4b5ace4f5', '{"action": "generatemenu", "status": "completed"}', now()),
('e30b77fb-59cb-4623-a93d-593694912793', '5dc50160-db9e-447a-ba33-9026d8800ab5', 'LogMeal', 'Meal', '25c7ff77-ebe9-4983-91ad-6cd4fd463226', '{"action": "logmeal", "status": "completed"}', now()),
('4d7e653e-9701-4154-a796-5bec66ccfa59', '5dc50160-db9e-447a-ba33-9026d8800ab5', 'UpdateWeight', 'UpdateWeight', 'e9a478cd-f789-40c8-801c-0772590fa52d', '{"action": "updateweight", "status": "completed"}', now()),
('37fc8a36-429d-4de2-8ad2-820039150b06', '5dc50160-db9e-447a-ba33-9026d8800ab5', 'GenerateMenu', 'GenerateMenu', 'dd53de3d-a5d1-496b-973f-668cb3da2c2c', '{"action": "generatemenu", "status": "completed"}', now()),
('6a7f2eb2-e86e-492c-8d57-b2b5c4e2bf9e', '212ea8ea-749e-44a1-92d2-636bd617cbc8', 'LogMeal', 'Meal', '4f7dd928-b2ff-4dc9-9d4a-f295db710c19', '{"action": "logmeal", "status": "completed"}', now()),
('abc7ecf1-420d-4f5f-acb9-40cb7f58756b', '212ea8ea-749e-44a1-92d2-636bd617cbc8', 'UpdateWeight', 'UpdateWeight', 'c1a47938-29c2-4f26-8caa-edff28002a92', '{"action": "updateweight", "status": "completed"}', now()),
('7c095881-3ca4-4b09-8e26-cecf1bdd6281', '212ea8ea-749e-44a1-92d2-636bd617cbc8', 'GenerateMenu', 'GenerateMenu', '1c870950-f843-45ee-be3a-ab94d5e677f3', '{"action": "generatemenu", "status": "completed"}', now())
ON CONFLICT DO NOTHING;

COMMIT;
