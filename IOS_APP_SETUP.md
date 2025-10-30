# iOS App Backend Setup - COMPLETE ✅

## What Was Done

All backend changes for iOS app support have been successfully applied!

### 1. ✅ Added Required Gems
- `rack-cors` - For CORS support (allows iOS app to make API calls)
- `jwt` - For token-based authentication

### 2. ✅ Created CORS Configuration
**File:** `config/initializers/cors.rb`
- Allows API requests from any origin (safe since Tailscale provides security)
- iOS app will use Bearer token authentication (not cookies)

### 3. ✅ Updated Host Configuration
**File:** `config/environments/development.rb`
- Cleared host checking for easy local network + Tailscale access
- Rails will accept connections from any hostname/IP

### 4. ✅ Added JWT Authentication
**File:** `app/controllers/api/v1/base_controller.rb`
- All API endpoints now require Bearer token
- Tokens are validated using JWT
- 90-day token expiry (convenient for personal use)

### 5. ✅ Created Auth Controller
**File:** `app/controllers/api/v1/auth_controller.rb`
- `POST /api/v1/auth/login` - Login endpoint for iOS app
- `GET /api/v1/auth/validate` - Network connectivity test endpoint

### 6. ✅ Updated Routes
**File:** `config/routes.rb`
- Added auth endpoints to API routes

---

## Starting Your Server

### Option 1: Using the existing script (recommended)
```bash
cd /Users/djamgade/personal/ontrack/ontrack
sh scripts.sh start
```

### Option 2: Manual start
```bash
cd /Users/djamgade/personal/ontrack/ontrack
eval "$(rbenv init -)"
bundle exec rails s -b 0.0.0.0
```

The server will start on port 3000 and be accessible from:
- **Local network:** `http://192.168.x.x:3000`
- **Tailscale:** `http://100.x.x.x:3000`

---

## Testing the API

### 1. Get your server IPs
```bash
# Local IP
ifconfig | grep "inet " | grep -v 127.0.0.1

# Tailscale IP
tailscale ip -4
```

### 2. Test login endpoint
```bash
# Replace with your actual username, password, and server IP
curl -X POST http://YOUR_SERVER_IP:3000/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"your_username","password":"your_password"}'

# Expected response:
# {"token":"eyJhbGci...","user":{"id":1,"monthly_goal":0}}
```

### 3. Test authenticated endpoint
```bash
# Use the token from step 2
TOKEN="your_token_here"

curl http://YOUR_SERVER_IP:3000/api/v1/expenses \
  -H "Authorization: Bearer ${TOKEN}"

# Should return your expenses list
```

---

## Available API Endpoints

All endpoints require `Authorization: Bearer <token>` header except login:

### Authentication
- `POST /api/v1/auth/login` - Login (username, password) → returns token
- `GET /api/v1/auth/validate` - Validate token (for connectivity check)

### Expenses
- `GET /api/v1/expenses` - List expenses (supports filters)
- `POST /api/v1/expenses` - Create expense
- `PUT /api/v1/expenses/:id` - Update expense
- `DELETE /api/v1/expenses/:id` - Delete expense
- `POST /api/v1/expenses/bulk_create` - Bulk create expenses

### Categories
- `GET /api/v1/categories` - List categories
- `POST /api/v1/categories` - Create category
- `PUT /api/v1/categories/:id` - Update category
- `DELETE /api/v1/categories/:id` - Delete category

### Goals
- `GET /api/v1/goals` - Get monthly goal
- `PUT /api/v1/goals` - Update monthly goal

### Reports
- `GET /api/v1/reports/month` - Monthly report
- `GET /api/v1/reports/year` - Yearly report

---

## iOS App Configuration

When building your iOS app, you'll need to configure these settings:

```swift
// NetworkConfiguration.swift
let localIP = "192.168.x.x"        // Your Pi's local IP
let tailscaleIP = "100.x.x.x"      // Your Pi's Tailscale IP
let port = "3000"
```

The iOS app will:
1. Try local network first (faster)
2. Fall back to Tailscale if local fails
3. Automatically switch between them

---

## Troubleshooting

### Server won't start
```bash
# Make sure you're using the right Ruby version
cd /Users/djamgade/personal/ontrack/ontrack
eval "$(rbenv init -)"
ruby -v  # Should show: ruby 3.1.2

# If bundle fails, run:
bundle install
```

### Can't connect from iOS
1. Check server is running: `curl http://localhost:3000`
2. Check firewall allows port 3000
3. Verify Tailscale is connected on both devices
4. Test with curl from your Mac first

### Token expired
- Tokens last 90 days
- Just login again to get a new token
- iOS app will handle this automatically

---

## Next Steps

1. ✅ Backend is ready!
2. ⏭️ Start building the iOS app in Xcode
3. ⏭️ Test API connectivity from iOS Simulator
4. ⏭️ Deploy to your iPhone

---

## Security Notes

For personal use on Tailscale:
- ✅ Tailscale provides encrypted connection
- ✅ JWT tokens prevent unauthorized access
- ✅ Only you have access to your Tailscale network
- ✅ No public internet exposure needed

This setup is **secure and appropriate for personal use**!

---

## Questions?

If you encounter any issues:
1. Check server logs: `tail -f log/development.log`
2. Verify Rails is running: `ps aux | grep rails`
3. Test endpoints with curl before trying iOS app

