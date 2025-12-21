class ApplicationController < ActionController::Base
  before_action :require_login

  helper_method :current_user

  def current_user
    return @current_user if defined?(@current_user)
    
    if cookies.signed[:logged_in] && cookies.signed[:user_id]
      @current_user = User.find_by(id: cookies.signed[:user_id])
    else
      @current_user = nil
    end
    
    @current_user
  end

  def require_login
    redirect_to root_path and return if current_user.nil?
  end

  def require_no_login
    redirect_to dashboard_index_path and return unless current_user.nil?
  end
end
