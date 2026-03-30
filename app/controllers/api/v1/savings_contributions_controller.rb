module Api; module V1
  class SavingsContributionsController < BaseController
    before_action :load_goal

    def index
      render json: @goal.savings_contributions
    end

    def create
      category = find_or_create_savings_category
      rupees = params[:amount].to_i / 100
      formatted = ActionController::Base.helpers.number_with_delimiter(rupees)
      n = @goal.savings_contributions.count + 1
      ordinal = ordinal_suffix(n)
      expense = @current_user.expenses.new(
        amount: params[:amount],
        description: "#{@goal.name} — ₹#{formatted} (#{ordinal} contribution)",
        category: category,
        paid_at: params[:contributed_on]
      )
      contribution = @goal.savings_contributions.new(
        user: @current_user,
        amount: params[:amount],
        note: params[:note].presence,
        contributed_on: params[:contributed_on],
        expense: expense
      )
      if expense.save && contribution.save
        render json: { contribution: contribution, goal_current_amount: @goal.current_amount }, status: 200
      else
        expense.destroy if expense.persisted?
        render json: nil, status: 500
      end
    end

    def destroy
      contribution = @goal.savings_contributions.find(params[:id])
      successful = contribution.destroy
      if successful
        render json: { goal_current_amount: @goal.reload.current_amount }, status: 200
      else
        render json: nil, status: 500
      end
    end

    private

    def load_goal
      @goal = @current_user.savings_goals.find(params[:savings_goal_id])
    end

    def ordinal_suffix(n)
      suffix = case n % 100
               when 11, 12, 13 then "th"
               else
                 case n % 10
                 when 1 then "st"
                 when 2 then "nd"
                 when 3 then "rd"
                 else "th"
                 end
               end
      "#{n}#{suffix}"
    end

    def find_or_create_savings_category
      @current_user.categories.find_or_create_by(name: "Savings") do |c|
        c.color = "#2a9d8f"
      end
    end
  end
end; end
