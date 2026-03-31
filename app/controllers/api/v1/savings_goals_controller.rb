module Api; module V1
  class SavingsGoalsController < BaseController
    def index
      goals = @current_user.savings_goals.order(created_at: :desc)
      render json: goals.map { |g| goal_json(g) }
    end

    def create
      goal = @current_user.savings_goals.new(
        name: params[:name],
        target_amount: params[:target_amount],
        color: params[:color],
        deadline: params[:deadline].presence
      )
      if goal.save
        render json: goal_json(goal), status: 200
      else
        render json: { error: goal.errors.full_messages.to_sentence }, status: 422
      end
    end

    def update
      goal = @current_user.savings_goals.find(params[:id])
      successful = goal.update(
        name: params.fetch(:name, goal.name),
        target_amount: params.fetch(:target_amount, goal.target_amount),
        color: params.fetch(:color, goal.color),
        deadline: params.key?(:deadline) ? params[:deadline].presence : goal.deadline
      )
      render json: goal_json(goal), status: successful ? 200 : 500
    end

    def destroy
      goal = @current_user.savings_goals.find(params[:id])
      successful = goal.destroy
      render json: nil, status: successful ? 200 : 500
    end

    private

    def goal_json(goal)
      {
        id: goal.id,
        name: goal.name,
        target_amount: goal.target_amount,
        current_amount: goal.current_amount,
        color: goal.color,
        deadline: goal.deadline&.iso8601,
        created_at: goal.created_at,
        updated_at: goal.updated_at
      }
    end
  end
end; end
