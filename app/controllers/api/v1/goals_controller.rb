module Api; module V1
  class GoalsController < BaseController
    def index
      render json: { monthly: @current_user.monthly_goal }
    end

    def update
      successful = @current_user.update(monthly_goal: params[:monthly_goal])
      render json: { monthly: @current_user.monthly_goal }, status: successful ? 200 : 500
    end
  end
end; end
