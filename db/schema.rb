# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_01_31_000013) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "communication_templates", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.text "body", null: false
    t.datetime "created_at", null: false
    t.integer "funnel_stage", null: false
    t.integer "interval_weeks"
    t.string "name", null: false
    t.string "subject"
    t.integer "template_type", default: 0, null: false
    t.integer "trigger_type", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["active"], name: "index_communication_templates_on_active"
    t.index ["funnel_stage", "trigger_type"], name: "index_communication_templates_on_funnel_stage_and_trigger_type"
  end

  create_table "communications", force: :cascade do |t|
    t.text "body"
    t.bigint "communication_template_id"
    t.integer "communication_type", default: 0, null: false
    t.datetime "created_at", null: false
    t.string "external_id"
    t.datetime "sent_at"
    t.bigint "sent_by_user_id"
    t.integer "status", default: 0, null: false
    t.string "subject"
    t.datetime "updated_at", null: false
    t.bigint "volunteer_id", null: false
    t.index ["communication_template_id"], name: "index_communications_on_communication_template_id"
    t.index ["sent_at"], name: "index_communications_on_sent_at"
    t.index ["sent_by_user_id"], name: "index_communications_on_sent_by_user_id"
    t.index ["status"], name: "index_communications_on_status"
    t.index ["volunteer_id"], name: "index_communications_on_volunteer_id"
  end

  create_table "external_sync_logs", force: :cascade do |t|
    t.datetime "completed_at"
    t.datetime "created_at", null: false
    t.text "error_message"
    t.jsonb "payload_snapshot"
    t.integer "records_processed"
    t.datetime "started_at"
    t.integer "status", default: 0, null: false
    t.integer "sync_direction", default: 0, null: false
    t.integer "sync_type", default: 0, null: false
    t.datetime "updated_at", null: false
    t.bigint "volunteer_id"
    t.index ["started_at"], name: "index_external_sync_logs_on_started_at"
    t.index ["status"], name: "index_external_sync_logs_on_status"
    t.index ["volunteer_id"], name: "index_external_sync_logs_on_volunteer_id"
  end

  create_table "information_sessions", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.integer "capacity"
    t.datetime "created_at", null: false
    t.string "location"
    t.string "name"
    t.text "notes"
    t.datetime "scheduled_at", null: false
    t.integer "session_type", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["active"], name: "index_information_sessions_on_active"
    t.index ["scheduled_at"], name: "index_information_sessions_on_scheduled_at"
  end

  create_table "inquiry_form_submissions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.boolean "processed", default: false, null: false
    t.datetime "processed_at"
    t.jsonb "raw_data"
    t.string "source"
    t.datetime "updated_at", null: false
    t.bigint "volunteer_id"
    t.index ["processed"], name: "index_inquiry_form_submissions_on_processed"
    t.index ["source"], name: "index_inquiry_form_submissions_on_source"
    t.index ["volunteer_id"], name: "index_inquiry_form_submissions_on_volunteer_id"
  end

  create_table "notes", force: :cascade do |t|
    t.text "content", null: false
    t.datetime "created_at", null: false
    t.integer "note_type", default: 0, null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.bigint "volunteer_id", null: false
    t.index ["user_id"], name: "index_notes_on_user_id"
    t.index ["volunteer_id"], name: "index_notes_on_volunteer_id"
  end

  create_table "referral_sources", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_referral_sources_on_name", unique: true
  end

  create_table "scheduled_reminders", force: :cascade do |t|
    t.bigint "communication_template_id", null: false
    t.datetime "created_at", null: false
    t.datetime "scheduled_for", null: false
    t.datetime "sent_at"
    t.string "skip_reason"
    t.integer "status", default: 0, null: false
    t.datetime "updated_at", null: false
    t.bigint "volunteer_id", null: false
    t.index ["communication_template_id"], name: "index_scheduled_reminders_on_communication_template_id"
    t.index ["scheduled_for", "status"], name: "index_scheduled_reminders_on_scheduled_for_and_status"
    t.index ["volunteer_id", "status"], name: "index_scheduled_reminders_on_volunteer_id_and_status"
    t.index ["volunteer_id"], name: "index_scheduled_reminders_on_volunteer_id"
  end

  create_table "session_registrations", force: :cascade do |t|
    t.text "cancellation_reason"
    t.datetime "checked_in_at"
    t.datetime "created_at", null: false
    t.bigint "information_session_id", null: false
    t.datetime "registered_at"
    t.integer "status", default: 0, null: false
    t.datetime "updated_at", null: false
    t.bigint "volunteer_id", null: false
    t.index ["information_session_id"], name: "index_session_registrations_on_information_session_id"
    t.index ["status"], name: "index_session_registrations_on_status"
    t.index ["volunteer_id", "information_session_id"], name: "idx_session_registrations_volunteer_session", unique: true
    t.index ["volunteer_id"], name: "index_session_registrations_on_volunteer_id"
  end

  create_table "status_changes", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "from_funnel_stage"
    t.string "to_funnel_stage"
    t.integer "trigger", default: 0, null: false
    t.string "trigger_details"
    t.datetime "updated_at", null: false
    t.bigint "user_id"
    t.bigint "volunteer_id", null: false
    t.index ["user_id"], name: "index_status_changes_on_user_id"
    t.index ["volunteer_id", "created_at"], name: "index_status_changes_on_volunteer_id_and_created_at"
    t.index ["volunteer_id"], name: "index_status_changes_on_volunteer_id"
  end

  create_table "system_settings", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "description"
    t.string "key", null: false
    t.datetime "updated_at", null: false
    t.bigint "updated_by_user_id"
    t.text "value"
    t.integer "value_type", default: 0, null: false
    t.index ["key"], name: "index_system_settings_on_key", unique: true
    t.index ["updated_by_user_id"], name: "index_system_settings_on_updated_by_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.string "email", null: false
    t.string "first_name"
    t.string "last_name"
    t.integer "role", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
  end

  create_table "volunteers", force: :cascade do |t|
    t.datetime "application_sent_at"
    t.datetime "application_submitted_at"
    t.datetime "became_inactive_at"
    t.datetime "created_at", null: false
    t.integer "current_funnel_stage", default: 0, null: false
    t.string "email", null: false
    t.string "external_id"
    t.datetime "external_synced_at"
    t.string "first_name", null: false
    t.datetime "first_session_attended_at"
    t.integer "inactive_reason"
    t.datetime "inquiry_date"
    t.string "last_name", null: false
    t.string "phone"
    t.integer "preferred_contact_method", default: 0, null: false
    t.datetime "reactivated_at"
    t.integer "reactivation_count", default: 0, null: false
    t.bigint "referral_source_id"
    t.bigint "referred_by_volunteer_id"
    t.datetime "updated_at", null: false
    t.integer "weeks_at_inactivation"
    t.index ["became_inactive_at"], name: "index_volunteers_on_became_inactive_at"
    t.index ["current_funnel_stage"], name: "index_volunteers_on_current_funnel_stage"
    t.index ["email"], name: "index_volunteers_on_email", unique: true
    t.index ["external_id"], name: "index_volunteers_on_external_id"
    t.index ["inquiry_date"], name: "index_volunteers_on_inquiry_date"
    t.index ["referral_source_id"], name: "index_volunteers_on_referral_source_id"
    t.index ["referred_by_volunteer_id"], name: "index_volunteers_on_referred_by_volunteer_id"
  end

  add_foreign_key "communications", "communication_templates"
  add_foreign_key "communications", "users", column: "sent_by_user_id"
  add_foreign_key "communications", "volunteers"
  add_foreign_key "external_sync_logs", "volunteers"
  add_foreign_key "inquiry_form_submissions", "volunteers"
  add_foreign_key "notes", "users"
  add_foreign_key "notes", "volunteers"
  add_foreign_key "scheduled_reminders", "communication_templates"
  add_foreign_key "scheduled_reminders", "volunteers"
  add_foreign_key "session_registrations", "information_sessions"
  add_foreign_key "session_registrations", "volunteers"
  add_foreign_key "status_changes", "users"
  add_foreign_key "status_changes", "volunteers"
  add_foreign_key "system_settings", "users", column: "updated_by_user_id"
  add_foreign_key "volunteers", "referral_sources"
  add_foreign_key "volunteers", "volunteers", column: "referred_by_volunteer_id"
end
