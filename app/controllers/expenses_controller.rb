class ExpensesController < ApplicationController
  def index
    @category_id = params[:category_id].to_json
    @has_data = current_user.expenses.count > 0
    @categories = current_user.categories.order(:name).to_json
  end
end
