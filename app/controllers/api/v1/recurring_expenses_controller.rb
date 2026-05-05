module Api; module V1
  class RecurringExpensesController < BaseController
    before_action :load_template, only: [:update, :destroy, :confirm, :skip]

    def index
      templates = @current_user.recurring_expenses.order(:next_due_date)
      render json: templates.map { |t| template_json(t) }
    end

    def create
      template = @current_user.recurring_expenses.new(
        description:   params[:description],
        amount:        params[:amount],
        category_id:   params[:category_id],
        frequency:     params[:frequency],
        next_due_date: params[:next_due_date],
        active:        params.fetch(:active, true)
      )
      if template.save
        render json: template_json(template), status: 200
      else
        render json: { error: template.errors.full_messages.to_sentence }, status: 422
      end
    end

    def update
      successful = @template.update(
        description:   params.fetch(:description, @template.description),
        amount:        params.fetch(:amount, @template.amount),
        category_id:   params.fetch(:category_id, @template.category_id),
        frequency:     params.fetch(:frequency, @template.frequency),
        next_due_date: params.fetch(:next_due_date, @template.next_due_date),
        active:        params.fetch(:active, @template.active)
      )
      if successful
        render json: template_json(@template), status: 200
      else
        render json: { error: @template.errors.full_messages.to_sentence }, status: 422
      end
    end

    def destroy
      successful = @template.destroy
      render json: nil, status: successful ? 200 : 500
    end

    # Atomic: create expense + advance next_due_date, guarded by
    # expected_next_due_date to prevent duplicate commits across devices.
    # The freshness check runs INSIDE the transaction under SELECT FOR UPDATE,
    # so two concurrent requests with the same expected_next_due_date can't
    # both pass the guard — the loser sees the advanced date and gets a 409.
    def confirm
      expected = params[:expected_next_due_date]
      # Use .present? rather than .fetch — the iOS client today omits the key when
      # there's no override, but a non-iOS caller (curl, future client) could send
      # `amount_override: null` explicitly. `params.fetch(:k, default)` returns the
      # explicit nil (not the default) when the key is present, so `nil.to_i = 0`
      # would silently create a zero-amount expense. `.present?` treats both absent
      # and explicit-null correctly.
      amount   = params[:amount_override].present? ? params[:amount_override].to_i : @template.amount

      expense = nil
      stale   = false

      RecurringExpense.transaction do
        @template.lock!  # SELECT ... FOR UPDATE
        if @template.next_due_date.iso8601 != expected
          stale = true
          raise ActiveRecord::Rollback
        end
        paid_at = params[:paid_at].presence || @template.next_due_date.to_datetime
        # Prefix with 🔁 so the expense is visually distinguishable in History/reports
        # as originating from a recurring template (forensic marker, no schema change).
        expense = @current_user.expenses.create!(
          description: "🔁 #{@template.description}",
          amount:      amount,
          category_id: @template.category_id,
          paid_at:     paid_at
        )
        @template.advance_next_due_date!
      end

      if stale
        return render json: { error: "stale", recurring_expense: template_json(@template) }, status: 409
      end

      render json: {
        expense: expense.as_json(include: :category),
        recurring_expense: template_json(@template)
      }, status: 200
    rescue ActiveRecord::RecordInvalid => e
      render json: { error: e.message }, status: 422
    end

    # Atomic: advance next_due_date only (skip this cycle without creating an expense).
    # Same row-lock guard as `confirm` — concurrent skip+skip or confirm+skip races
    # can't both succeed.
    def skip
      expected = params[:expected_next_due_date]
      stale    = false

      RecurringExpense.transaction do
        @template.lock!
        if @template.next_due_date.iso8601 != expected
          stale = true
          raise ActiveRecord::Rollback
        end
        @template.advance_next_due_date!
      end

      if stale
        return render json: { error: "stale", recurring_expense: template_json(@template) }, status: 409
      end

      render json: { recurring_expense: template_json(@template) }, status: 200
    end

    private

    def load_template
      @template = @current_user.recurring_expenses.find(params[:id])
    end

    def template_json(template)
      {
        id:            template.id,
        description:   template.description,
        amount:        template.amount,
        category_id:   template.category_id,
        frequency:     template.frequency,
        next_due_date: template.next_due_date&.iso8601,
        active:        template.active,
        created_at:    template.created_at,
        updated_at:    template.updated_at
      }
    end
  end
end; end
