module Api; module V1
  class ExpensesController < BaseController
    def index
      expenses = @current_user.expenses
      
      # Support both timestamp-based and date-based filtering
      expenses = expenses.where('paid_at >= ?', Time.at(params[:paid_after].to_i).to_datetime) if params[:paid_after].present?
      expenses = expenses.where('paid_at <= ?', Time.at(params[:paid_before].to_i).to_datetime) if params[:paid_before].present?
      
      # Add support for start_date and end_date (YYYY-MM-DD format)
      if params[:start_date].present?
        start_date = Date.parse(params[:start_date])
        expenses = expenses.where('paid_at >= ?', start_date.beginning_of_day)
      end
      
      if params[:end_date].present?
        end_date = Date.parse(params[:end_date])
        expenses = expenses.where('paid_at <= ?', end_date.end_of_day)
      end
      
      expenses = expenses.where("lower(description) ILIKE ?", "%#{params[:search].strip}%") if params[:search]&.strip.present?
      expenses = expenses.where(category_id: params[:category_id]) if params[:category_id].present?
      expenses = expenses.includes(:category) if params[:include_category] == true.to_s
      expenses = expenses.paginate(params[:page], params[:per_page]) if params[:page]
      expenses = expenses.order(normalized_sort(params[:sort], params[:sort_desc])).order(id: :desc) if params[:sort]

      if params[:page]
        opts = {}
        opts = { include: :category } if params[:include_category] == true.to_s
        paginate(expenses, opts)
      else
        render json: expenses
      end
    end

    def create
      # Idempotency: if the client supplied a client_id and we already have a
      # row for it, return that row instead of creating a duplicate. The DB
      # partial unique index on (user_id, client_id) is the real guarantee;
      # the find_by short-circuits the common case to avoid an exception path.
      if (key = params[:client_id].presence) && (existing = @current_user.expenses.find_by(client_id: key))
        return render json: existing, status: 200
      end

      expense = @current_user.expenses.new(
        description: params[:description],
        category_id: params[:category_id],
        amount: params[:amount],
        paid_at: params[:paid_at],
        client_id: params[:client_id]
      )
      successful = expense.save
      render json: expense, status: successful ? 200 : 500
    rescue ActiveRecord::RecordNotUnique
      # Lost a race with a concurrent retry — fetch and return the winner.
      expense = @current_user.expenses.find_by(client_id: params[:client_id])
      render json: expense, status: 200
    end

    def bulk_create
      Expense.transaction do
        params[:expenses].each_with_index do |expense, idx|
          @current_user.expenses.create!(amount: expense['amount'], category_id: expense['category_id'], description: expense['description'], paid_at: expense['paid_at'])
        end
      end
    end

    def destroy
      expense = @current_user.expenses.find(params[:id])
      successful = expense.destroy
      render json: nil, status: successful ? 200 : 500
    end

    def update
      expense = @current_user.expenses.find(params[:id])
      successful = expense.update(
        category_id: params.fetch(:category_id, expense.category_id),
        description: params.fetch(:description, expense.description),
        paid_at: params.fetch(:paid_at, expense.paid_at),
        amount: params.fetch(:amount, expense.amount),
      )
      # Return the updated expense so clients can refresh their local state
      render json: expense, status: successful ? 200 : 500
    end

    private

    def normalized_sort(key, sort_desc)
      cols = { paid_at: "paid_at", amount: "amount" }
      col = cols[key.to_sym] || "paid_at"
      dir = sort_desc == "true" ? "DESC" : "ASC"
      "#{col} #{dir}"
    end
  end
end; end
