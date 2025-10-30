# CORS configuration for iOS app access
# Allows API requests from local network and Tailscale

Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    # Allow from anywhere since Tailscale handles security
    # and local network is trusted
    origins '*'
    
    resource '/api/*',
      headers: :any,
      methods: [:get, :post, :put, :patch, :delete, :options, :head],
      credentials: false,  # iOS app uses Bearer token, not cookies
      expose: ['X-Total-Count', 'X-Total-Pages']
  end
end


