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

ActiveRecord::Schema.define(version: 2026_04_23_050059) do

  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "categories", force: :cascade do |t|
    t.text "name", null: false
    t.string "color", null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.integer "monthly_goal", default: 0
    t.integer "rank", default: 0
    t.bigint "user_id"
    t.index ["rank"], name: "index_categories_on_rank"
    t.index ["user_id"], name: "index_categories_on_user_id"
  end

  create_table "csv_configs", force: :cascade do |t|
    t.text "name", null: false
    t.text "config_json", null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
  end

  create_table "expenses", force: :cascade do |t|
    t.text "description", null: false
    t.integer "amount", null: false
    t.integer "category_id", null: false
    t.datetime "paid_at", null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.bigint "user_id"
    t.index ["amount"], name: "index_expenses_on_amount"
    t.index ["category_id"], name: "index_expenses_on_category_id"
    t.index ["paid_at"], name: "index_expenses_on_paid_at"
    t.index ["user_id"], name: "index_expenses_on_user_id"
  end

  create_table "recurring_expenses", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "category_id", null: false
    t.text "description", null: false
    t.integer "amount", null: false
    t.string "frequency", null: false
    t.date "next_due_date", null: false
    t.boolean "active", default: true, null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["next_due_date"], name: "index_recurring_expenses_on_next_due_date"
    t.index ["user_id"], name: "index_recurring_expenses_on_user_id"
  end

  create_table "savings_contributions", force: :cascade do |t|
    t.bigint "savings_goal_id", null: false
    t.bigint "user_id", null: false
    t.integer "amount", null: false
    t.text "note"
    t.date "contributed_on", null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.bigint "expense_id"
    t.index ["contributed_on"], name: "index_savings_contributions_on_contributed_on"
    t.index ["savings_goal_id"], name: "index_savings_contributions_on_savings_goal_id"
    t.index ["user_id"], name: "index_savings_contributions_on_user_id"
  end

  create_table "savings_goals", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.text "name", null: false
    t.integer "target_amount", null: false
    t.string "color", default: "#2a9d8f", null: false
    t.date "deadline"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["user_id"], name: "index_savings_goals_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "username", null: false
    t.string "password", null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.integer "monthly_goal", default: 0
    t.string "login_id"
    t.index ["login_id"], name: "index_users_on_login_id", unique: true
  end

end
