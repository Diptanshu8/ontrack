# Multi-User Support Implementation Plan

## Phase 1: Database Schema Updates
- [ ] Create migration to add `user_id` to `expenses` table.
- [ ] Create migration to add `user_id` to `categories` table.
- [ ] Add foreign key constraints to ensure data integrity.
- [ ] Add indexes on `user_id` for query performance.
- [ ] **Crucial:** Implement data migration strategy to assign all existing records to `User.first` (ID: 1) to prevent data loss.

## Phase 2: Model Associations
- [ ] Update `User.rb`: Add `has_many :expenses`, `has_many :categories`.
- [ ] Update `Expense.rb`: Add `belongs_to :user`.
- [ ] Update `Category.rb`: Add `belongs_to :user`.
- [ ] Add validations to ensure `user_id` is mandatory for new records.

## Phase 3: Authentication & Controller Refactoring
- [ ] **Auth Controller:**
    - [ ] Remove `User.first` hardcoding in `login`.
    - [ ] Implement lookup by username (requires handling hashed usernames or migrating to a lookup-friendly auth system).
    - [ ] *Decision:* Since usernames are currently hashed, we might need to add a `username_digest` or just store username in plain text (if security policy permits) or use a salt.
    - [ ] **Better Approach:** Add a `email` or `login_id` column that is unique and searchable, or accept that we can't look up by username easily without changing the auth mechanism.
    - [ ] *Alternative:* Re-implement User model to use `has_secure_password` (standard Rails) and store username as plain text (unique index). This is the standard way.

- [ ] **Application Controller:**
    - [ ] Implement `current_user` helper based on JWT token (already partially there).
    - [ ] Ensure `authenticate_request` correctly sets `@current_user`.

- [ ] **Resource Controllers (Expenses, Categories, etc.):**
    - [ ] Scope all queries to `current_user`.
    - [ ] Replace `Expense.all` with `current_user.expenses`.
    - [ ] Replace `Category.all` with `current_user.categories`.
    - [ ] Ensure `create` actions automatically associate the record with `current_user`.

## Phase 4: API Verification
- [ ] Test User Creation (via Runner/Console).
- [ ] Test Login with User A -> Get Token A.
- [ ] Test Login with User B -> Get Token B.
- [ ] User A creates Expense.
- [ ] User B tries to fetch Expense (should be 404 or empty).
- [ ] User B lists expenses (should be empty).

## Phase 5: Cleanup
- [ ] Remove any global query interfaces.
- [ ] Verify `Year` and `Month` reports also respect user scope.
