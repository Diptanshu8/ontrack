class SessionsController < ApplicationController
  skip_before_action :require_login, only: [:new, :create]
  before_action :require_no_login, only: [:new, :create]

  def new
  end

  def create
    username = params[:username]
    password = params[:password]

    # 1. Try lookup by login_id
    user = User.find_by(login_id: username)

    # 2. Legacy Fallback (Migration)
    unless user
      User.where(login_id: nil).find_each do |u|
        if BCrypt::Password.new(u.username) == username
          user = u
          user.update(login_id: username)
          break
        end
      end
    end

    if user && BCrypt::Password.new(user.password) == password
      cookies.signed[:user_id] = user.id
      cookies.signed[:logged_in] = true
    else
      flash[:error] = "Incorrect login"
    end

    redirect_to :root
  end

  def logout
    cookies.delete(:user_id)
    cookies.delete(:logged_in)
    redirect_to :root
  end
end
