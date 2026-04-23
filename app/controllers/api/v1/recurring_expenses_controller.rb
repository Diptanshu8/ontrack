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
    def confirm
      expected = params[:expected_next_due_date]
      if @template.next_due_date.iso8601 != expected
        return render json: { error: "stale", recurring_expense: template_json(@template) }, status: 409
      end

      amount    = params.fetch(:amount_override, @template.amount).to_i
      paid_at   = params[:paid_at].presence || @template.next_due_date.to_datetime

      # Prefix with 🔁 so the expense is visually distinguishable in History/reports
      # as originating from a recurring template (forensic marker, no schema change).
      expense = nil
      RecurringExpense.transaction do
        expense = @current_user.expenses.create!(
          description: "🔁 #{@template.description}",
          amount:      amount,
          category_id: @template.category_id,
          paid_at:     paid_at
        )
        @template.advance_next_due_date!
      end

      render json: {
        expense: expense.as_json(include: :category),
        recurring_expense: template_json(@template)
      }, status: 200
    rescue ActiveRecord::RecordInvalid => e
      render json: { error: e.message }, status: 422
    end

    # Atomic: advance next_due_date only (skip this cycle without creating an expense).
    def skip
      expected = params[:expected_next_due_date]
      if @template.next_due_date.iso8601 != expected
        return render json: { error: "stale", recurring_expense: template_json(@template) }, status: 409
      end

      @template.advance_next_due_date!
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
