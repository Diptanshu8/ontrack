module Api; module V1
  class BaseController < ApplicationController
    skip_before_action :verify_authenticity_token
    skip_before_action :require_login
    before_action :authenticate_api_request

    private

    def authenticate_api_request
      # Support both cookie-based auth (for web app) and JWT token (for iOS app)
      
      # First, try cookie-based authentication (for web app)
      if cookies.signed[:logged_in]
        @current_user = User.first
        return
      end

      # If no cookie, try JWT token authentication (for iOS app)
      token = request.headers['Authorization']&.split(' ')&.last

      return render json: { error: 'No token or session provided' }, status: 401 unless token

      begin
        decoded = JWT.decode(token, Rails.application.secret_key_base, true, { algorithm: 'HS256' })
        @current_user = User.first  # Since there's only one user
      rescue JWT::ExpiredSignature
        render json: { error: 'Token expired' }, status: 401
      rescue JWT::DecodeError
        render json: { error: 'Invalid token' }, status: 401
      end
    end

    def paginate(query, json_opts = {})
      page = query.page
      per_page = query.per_page
      total = query.total_items
      total_pages = query.total_pages
      items = query

      render json: { page: page, per_page: per_page, total: total, items: items.as_json(json_opts), total_pages: total_pages }
    end
  end
end; end
