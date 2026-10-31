-- CreateSchema
CREATE SCHEMA IF NOT EXISTS "public";

-- CreateEnum
CREATE TYPE "ComponentNature" AS ENUM ('REQUIRED', 'ELECTIVE', 'COMPLEMENTARY');

-- CreateEnum
CREATE TYPE "ItemKind" AS ENUM ('ANNOUNCEMENT', 'ASSIGNMENT', 'ASSESSMENT', 'MATERIAL', 'FORUM_TOPIC', 'OTHER');

-- CreateEnum
CREATE TYPE "SourceProvider" AS ENUM ('SIGAA', 'MOODLE', 'CLASSROOM', 'CALENDAR');

-- CreateEnum
CREATE TYPE "SourceAccountStatus" AS ENUM ('OK', 'REAUTH_NEEDED', 'BLOCKED');

-- CreateEnum
CREATE TYPE "ChangeEntityType" AS ENUM ('COURSE_SPACE', 'ITEM', 'GRADE_ENTRY', 'CALENDAR_EVENT');

-- CreateEnum
CREATE TYPE "ChangeKind" AS ENUM ('CREATED', 'UPDATED', 'REMOVED');

-- CreateEnum
CREATE TYPE "SyncScope" AS ENUM ('ALL', 'COURSE', 'ITEM');

-- CreateEnum
CREATE TYPE "SyncRunStatus" AS ENUM ('RUNNING', 'SUCCEEDED', 'FAILED');

-- CreateTable
CREATE TABLE "enrollments" (
    "user_id" UUID NOT NULL,
    "section_id" UUID NOT NULL,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "enrollments_pkey" PRIMARY KEY ("user_id","section_id")
);

-- CreateTable
CREATE TABLE "plan_items" (
    "id" UUID NOT NULL,
    "user_id" UUID NOT NULL,
    "code" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "hours" INTEGER NOT NULL,
    "term" TEXT,

    CONSTRAINT "plan_items_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "sections" (
    "id" UUID NOT NULL,
    "term" TEXT NOT NULL,
    "code" TEXT NOT NULL,
    "number" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "instructor" TEXT,
    "valid_from" TEXT NOT NULL,
    "valid_to" TEXT NOT NULL,
    "slots" JSONB NOT NULL,
    "updated_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "sections_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "transcripts" (
    "id" UUID NOT NULL,
    "user_id" UUID NOT NULL,
    "issued_at" TIMESTAMP(3) NOT NULL,
    "curriculum_code" TEXT NOT NULL,
    "program_name" TEXT NOT NULL,
    "current_term" INTEGER NOT NULL,
    "standard_terms" TEXT NOT NULL,
    "max_terms" TEXT NOT NULL,
    "cr" DECIMAL(6,4),
    "iap" DECIMAL(6,4),
    "hours_matrix" JSONB NOT NULL,
    "equivalences" TEXT[],
    "notes" TEXT[],
    "fetched_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "transcripts_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "transcript_entries" (
    "id" UUID NOT NULL,
    "transcript_id" UUID NOT NULL,
    "term" TEXT NOT NULL,
    "nature" TEXT,
    "code" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "hours" INTEGER NOT NULL,
    "grade" DECIMAL(3,1),
    "status" TEXT NOT NULL,
    "instructor" TEXT,

    CONSTRAINT "transcript_entries_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "transcript_pending" (
    "id" UUID NOT NULL,
    "transcript_id" UUID NOT NULL,
    "code" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "hours" INTEGER NOT NULL,
    "enrolled" BOOLEAN NOT NULL,

    CONSTRAINT "transcript_pending_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "curriculum_components" (
    "id" UUID NOT NULL,
    "curriculum_id" TEXT NOT NULL,
    "sigaa_id" TEXT NOT NULL,
    "code" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "hours" INTEGER NOT NULL,
    "nature" "ComponentNature" NOT NULL,
    "term" INTEGER,
    "responsible_unit" TEXT,
    "prerequisite_expr" TEXT,
    "corequisite_expr" TEXT,
    "equivalence_expr" TEXT,

    CONSTRAINT "curriculum_components_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "curricula" (
    "sigaa_id" TEXT NOT NULL,
    "program_id" TEXT NOT NULL,
    "code" TEXT NOT NULL,
    "implementation_term" TEXT NOT NULL,
    "total_hours" INTEGER NOT NULL,
    "required_hours" INTEGER NOT NULL,
    "min_elective_hours" INTEGER NOT NULL,
    "min_complementary_hours" INTEGER NOT NULL,
    "min_terms" INTEGER NOT NULL,
    "avg_terms" INTEGER NOT NULL,
    "max_terms" INTEGER NOT NULL,
    "fetched_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "curricula_pkey" PRIMARY KEY ("sigaa_id")
);

-- CreateTable
CREATE TABLE "programs" (
    "sigaa_id" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "campus" TEXT NOT NULL,
    "level" TEXT NOT NULL,
    "updated_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "programs_pkey" PRIMARY KEY ("sigaa_id")
);

-- CreateTable
CREATE TABLE "attachments" (
    "id" UUID NOT NULL,
    "item_id" UUID NOT NULL,
    "external_id" TEXT,
    "name" TEXT NOT NULL,
    "mime_type" TEXT,
    "size_bytes" BIGINT,
    "source_url" TEXT,
    "extra" JSONB,

    CONSTRAINT "attachments_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "calendar_events" (
    "id" UUID NOT NULL,
    "source_account_id" UUID NOT NULL,
    "calendar_id" TEXT NOT NULL,
    "external_id" TEXT NOT NULL,
    "title" TEXT NOT NULL,
    "description" TEXT,
    "location" TEXT,
    "starts_at" TIMESTAMP(3) NOT NULL,
    "ends_at" TIMESTAMP(3),
    "all_day" BOOLEAN NOT NULL DEFAULT false,
    "status" TEXT,
    "content_hash" TEXT NOT NULL,
    "first_seen_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "last_seen_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "deleted_at" TIMESTAMP(3),

    CONSTRAINT "calendar_events_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "course_spaces" (
    "id" UUID NOT NULL,
    "source_account_id" UUID NOT NULL,
    "external_id" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "section_id" UUID,
    "link_confirmed_at" TIMESTAMP(3),
    "extra" JSONB,
    "first_seen_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "last_seen_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "deleted_at" TIMESTAMP(3),

    CONSTRAINT "course_spaces_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "grade_entries" (
    "id" UUID NOT NULL,
    "course_space_id" UUID NOT NULL,
    "source_account_id" UUID NOT NULL,
    "item_id" UUID,
    "external_id" TEXT NOT NULL,
    "label" TEXT NOT NULL,
    "score" DECIMAL(8,3),
    "max_score" DECIMAL(8,3),
    "weight" DECIMAL(8,3),
    "graded_at" TIMESTAMP(3),
    "content_hash" TEXT NOT NULL,
    "first_seen_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "last_seen_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "deleted_at" TIMESTAMP(3),

    CONSTRAINT "grade_entries_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "items" (
    "id" UUID NOT NULL,
    "course_space_id" UUID NOT NULL,
    "source_account_id" UUID NOT NULL,
    "kind" "ItemKind" NOT NULL,
    "external_id" TEXT NOT NULL,
    "title" TEXT NOT NULL,
    "body" TEXT,
    "due_at" TIMESTAMP(3),
    "published_at" TIMESTAMP(3),
    "state" TEXT,
    "extra" JSONB,
    "content_hash" TEXT NOT NULL,
    "detail_fetched_at" TIMESTAMP(3),
    "first_seen_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "last_seen_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "deleted_at" TIMESTAMP(3),

    CONSTRAINT "items_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "api_keys" (
    "id" UUID NOT NULL,
    "user_id" UUID NOT NULL,
    "key_hash" TEXT NOT NULL,
    "prefix" TEXT NOT NULL,
    "label" TEXT,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "last_used_at" TIMESTAMP(3),
    "revoked_at" TIMESTAMP(3),

    CONSTRAINT "api_keys_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "source_accounts" (
    "id" UUID NOT NULL,
    "user_id" UUID NOT NULL,
    "provider" "SourceProvider" NOT NULL,
    "account_key" TEXT NOT NULL,
    "site_url" TEXT,
    "status" "SourceAccountStatus" NOT NULL DEFAULT 'OK',
    "status_reason" TEXT,
    "secret_ciphertext" TEXT,
    "secret_iv" TEXT,
    "secret_auth_tag" TEXT,
    "last_synced_at" TIMESTAMP(3),
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "source_accounts_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "student_profiles" (
    "id" UUID NOT NULL,
    "user_id" UUID NOT NULL,
    "registration" TEXT,
    "program_name" TEXT,
    "entry_term" TEXT,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "student_profiles_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "users" (
    "id" UUID NOT NULL,
    "name" TEXT,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "users_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "change_events" (
    "id" UUID NOT NULL,
    "sync_run_id" UUID NOT NULL,
    "source_account_id" UUID NOT NULL,
    "entity_type" "ChangeEntityType" NOT NULL,
    "entity_id" UUID NOT NULL,
    "change" "ChangeKind" NOT NULL,
    "summary" TEXT,
    "occurred_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "change_events_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "sync_runs" (
    "id" UUID NOT NULL,
    "source_account_id" UUID NOT NULL,
    "scope" "SyncScope" NOT NULL,
    "scope_ref" TEXT,
    "status" "SyncRunStatus" NOT NULL DEFAULT 'RUNNING',
    "started_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "finished_at" TIMESTAMP(3),
    "created_count" INTEGER NOT NULL DEFAULT 0,
    "updated_count" INTEGER NOT NULL DEFAULT 0,
    "removed_count" INTEGER NOT NULL DEFAULT 0,
    "unchanged_count" INTEGER NOT NULL DEFAULT 0,
    "error_code" TEXT,
    "error_message" TEXT,

    CONSTRAINT "sync_runs_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "plan_items_user_id_code_key" ON "plan_items"("user_id", "code");

-- CreateIndex
CREATE UNIQUE INDEX "sections_term_code_number_key" ON "sections"("term", "code", "number");

-- CreateIndex
CREATE UNIQUE INDEX "transcripts_user_id_key" ON "transcripts"("user_id");

-- CreateIndex
CREATE INDEX "transcript_entries_transcript_id_term_idx" ON "transcript_entries"("transcript_id", "term");

-- CreateIndex
CREATE UNIQUE INDEX "transcript_entries_transcript_id_term_code_key" ON "transcript_entries"("transcript_id", "term", "code");

-- CreateIndex
CREATE UNIQUE INDEX "transcript_pending_transcript_id_code_name_key" ON "transcript_pending"("transcript_id", "code", "name");

-- CreateIndex
CREATE UNIQUE INDEX "curriculum_components_curriculum_id_code_key" ON "curriculum_components"("curriculum_id", "code");

-- CreateIndex
CREATE UNIQUE INDEX "curricula_program_id_code_key" ON "curricula"("program_id", "code");

-- CreateIndex
CREATE UNIQUE INDEX "attachments_item_id_external_id_key" ON "attachments"("item_id", "external_id");

-- CreateIndex
CREATE INDEX "calendar_events_source_account_id_starts_at_idx" ON "calendar_events"("source_account_id", "starts_at");

-- CreateIndex
CREATE UNIQUE INDEX "calendar_events_source_account_id_calendar_id_external_id_key" ON "calendar_events"("source_account_id", "calendar_id", "external_id");

-- CreateIndex
CREATE INDEX "course_spaces_section_id_idx" ON "course_spaces"("section_id");

-- CreateIndex
CREATE UNIQUE INDEX "course_spaces_source_account_id_external_id_key" ON "course_spaces"("source_account_id", "external_id");

-- CreateIndex
CREATE INDEX "grade_entries_source_account_id_idx" ON "grade_entries"("source_account_id");

-- CreateIndex
CREATE UNIQUE INDEX "grade_entries_course_space_id_external_id_key" ON "grade_entries"("course_space_id", "external_id");

-- CreateIndex
CREATE INDEX "items_source_account_id_due_at_idx" ON "items"("source_account_id", "due_at");

-- CreateIndex
CREATE INDEX "items_source_account_id_published_at_idx" ON "items"("source_account_id", "published_at");

-- CreateIndex
CREATE UNIQUE INDEX "items_course_space_id_kind_external_id_key" ON "items"("course_space_id", "kind", "external_id");

-- CreateIndex
CREATE UNIQUE INDEX "api_keys_key_hash_key" ON "api_keys"("key_hash");

-- CreateIndex
CREATE INDEX "api_keys_user_id_idx" ON "api_keys"("user_id");

-- CreateIndex
CREATE UNIQUE INDEX "source_accounts_user_id_provider_account_key_key" ON "source_accounts"("user_id", "provider", "account_key");

-- CreateIndex
CREATE UNIQUE INDEX "student_profiles_user_id_key" ON "student_profiles"("user_id");

-- CreateIndex
CREATE INDEX "change_events_source_account_id_occurred_at_idx" ON "change_events"("source_account_id", "occurred_at");

-- CreateIndex
CREATE INDEX "sync_runs_source_account_id_started_at_idx" ON "sync_runs"("source_account_id", "started_at");

-- AddForeignKey
ALTER TABLE "enrollments" ADD CONSTRAINT "enrollments_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "enrollments" ADD CONSTRAINT "enrollments_section_id_fkey" FOREIGN KEY ("section_id") REFERENCES "sections"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "plan_items" ADD CONSTRAINT "plan_items_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "transcripts" ADD CONSTRAINT "transcripts_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "transcript_entries" ADD CONSTRAINT "transcript_entries_transcript_id_fkey" FOREIGN KEY ("transcript_id") REFERENCES "transcripts"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "transcript_pending" ADD CONSTRAINT "transcript_pending_transcript_id_fkey" FOREIGN KEY ("transcript_id") REFERENCES "transcripts"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "curriculum_components" ADD CONSTRAINT "curriculum_components_curriculum_id_fkey" FOREIGN KEY ("curriculum_id") REFERENCES "curricula"("sigaa_id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "curricula" ADD CONSTRAINT "curricula_program_id_fkey" FOREIGN KEY ("program_id") REFERENCES "programs"("sigaa_id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "attachments" ADD CONSTRAINT "attachments_item_id_fkey" FOREIGN KEY ("item_id") REFERENCES "items"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "calendar_events" ADD CONSTRAINT "calendar_events_source_account_id_fkey" FOREIGN KEY ("source_account_id") REFERENCES "source_accounts"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "course_spaces" ADD CONSTRAINT "course_spaces_source_account_id_fkey" FOREIGN KEY ("source_account_id") REFERENCES "source_accounts"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "course_spaces" ADD CONSTRAINT "course_spaces_section_id_fkey" FOREIGN KEY ("section_id") REFERENCES "sections"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "grade_entries" ADD CONSTRAINT "grade_entries_course_space_id_fkey" FOREIGN KEY ("course_space_id") REFERENCES "course_spaces"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "grade_entries" ADD CONSTRAINT "grade_entries_source_account_id_fkey" FOREIGN KEY ("source_account_id") REFERENCES "source_accounts"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "grade_entries" ADD CONSTRAINT "grade_entries_item_id_fkey" FOREIGN KEY ("item_id") REFERENCES "items"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "items" ADD CONSTRAINT "items_course_space_id_fkey" FOREIGN KEY ("course_space_id") REFERENCES "course_spaces"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "items" ADD CONSTRAINT "items_source_account_id_fkey" FOREIGN KEY ("source_account_id") REFERENCES "source_accounts"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "api_keys" ADD CONSTRAINT "api_keys_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "source_accounts" ADD CONSTRAINT "source_accounts_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "student_profiles" ADD CONSTRAINT "student_profiles_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "change_events" ADD CONSTRAINT "change_events_sync_run_id_fkey" FOREIGN KEY ("sync_run_id") REFERENCES "sync_runs"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "change_events" ADD CONSTRAINT "change_events_source_account_id_fkey" FOREIGN KEY ("source_account_id") REFERENCES "source_accounts"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "sync_runs" ADD CONSTRAINT "sync_runs_source_account_id_fkey" FOREIGN KEY ("source_account_id") REFERENCES "source_accounts"("id") ON DELETE CASCADE ON UPDATE CASCADE;

