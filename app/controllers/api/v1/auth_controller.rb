module Api; module V1
  class AuthController < ApplicationController
    skip_before_action :verify_authenticity_token
    skip_before_action :require_login

    def login
      user = User.first

      return render json: { error: 'No user configured' }, status: 404 unless user

      # Note: Your User model hashes both username and password
      # So we compare the hashed values
      if BCrypt::Password.new(user.password) == params[:password] &&
         BCrypt::Password.new(user.username) == params[:username]

        token = generate_token
        render json: {
          token: token,
          user: {
            id: user.id,
            monthly_goal: user.monthly_goal
          }
        }
      else
        render json: { error: 'Invalid credentials' }, status: 401
      end
    end

    def validate
      # This endpoint is called by iOS app to check network connectivity
      # It's protected by authenticate_api_request in BaseController when called with token
      token = request.headers['Authorization']&.split(' ')&.last

      if token
        begin
          JWT.decode(token, Rails.application.secret_key_base, true, { algorithm: 'HS256' })
          user = User.first
          render json: {
            valid: true,
            user: {
              id: user.id,
              monthly_goal: user.monthly_goal
            }
          }
        rescue JWT::ExpiredSignature, JWT::DecodeError
          render json: { valid: false, error: 'Invalid token' }, status: 401
        end
      else
        render json: { valid: false, error: 'No token' }, status: 401
      end
    end

    private

    def generate_token
      payload = {
        user_id: User.first.id,
        exp: 90.days.from_now.to_i  # Long expiry for personal use
      }
      JWT.encode(payload, Rails.application.secret_key_base, 'HS256')
    end
  end
end; end


