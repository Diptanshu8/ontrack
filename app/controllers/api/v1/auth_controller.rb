module Api; module V1
  class AuthController < ApplicationController
    skip_before_action :verify_authenticity_token
    skip_before_action :require_login

    def login
      username = params[:username]
      password = params[:password]
      
      # 1. Try lookup by login_id (New system)
      user = User.find_by(login_id: username)

      # 2. Legacy Fallback (Migration)
      # If not found via login_id, check legacy users who haven't been migrated yet
      unless user
        User.where(login_id: nil).find_each do |u|
          if BCrypt::Password.new(u.username) == username
            user = u
            # Auto-migrate: Save the plain text username for future lookups
            user.update(login_id: username)
            break
          end
        end
      end

      return render json: { error: 'Invalid credentials' }, status: 401 unless user

      # 3. Verify Password
      if BCrypt::Password.new(user.password) == password
        token = generate_token(user)
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
      token = request.headers['Authorization']&.split(' ')&.last

      if token
        begin
          decoded = JWT.decode(token, Rails.application.secret_key_base, true, { algorithm: 'HS256' })
          user_id = decoded[0]['user_id']
          user = User.find_by(id: user_id)
          
          if user
            render json: {
              valid: true,
              user: {
                id: user.id,
                monthly_goal: user.monthly_goal
              }
            }
          else
            render json: { valid: false, error: 'User not found' }, status: 404
          end
        rescue JWT::ExpiredSignature, JWT::DecodeError
          render json: { valid: false, error: 'Invalid token' }, status: 401
        end
      else
        render json: { valid: false, error: 'No token' }, status: 401
      end
    end

    private

    def generate_token(user)
      payload = {
        user_id: user.id,
        exp: 90.days.from_now.to_i  # Long expiry for personal use
      }
      JWT.encode(payload, Rails.application.secret_key_base, 'HS256')
    end
  end
end; end











