# 🧪 OnTrack iOS App - Testing Guide

## ✅ Fixes Applied

**Date:** October 30, 2025

### What Was Fixed:
1. ✅ Removed conflicting `convertFromSnakeCase` decoder strategy
2. ✅ Added better error logging for debugging
3. ✅ Verified all model fields match API response
4. ✅ Verified IP address is correct (192.168.1.110)

---

## 🚀 Build and Test Now

### Step 1: Clean Build in Xcode

**In Xcode:**
1. **Product** → **Clean Build Folder** (Shift+Cmd+K)
2. Wait for "Clean Finished"
3. **Product** → **Build** (Cmd+B)
4. Watch for any build errors

**Expected:** Build Succeeded ✅

---

### Step 2: Run in Simulator

1. **Make sure** device selector shows a simulator (iPhone 15 Pro, etc.)
2. **Click** Play ▶️ button (or Cmd+R)
3. **Watch** the console output at bottom of Xcode

---

### Step 3: Login and Test

**When app opens:**

1. **Enter Credentials:**
   - Username: `Diptanshu`
   - Password: `finance`

2. **Click** "Sign In"

3. **Watch Console - Expected Output:**
```
📡 API Base URL: http://192.168.1.110:3000/api/v1
🔑 Attempting login for user: Diptanshu
🔑 Login response status: 200
🔐 Token saved successfully
✅ Login successful!
📁 Fetching categories...
🔐 Token retrieved
💰 Fetching expenses...
```

4. **App Should Show:**
   - Dashboard with "Quick Stats"
   - Total Expenses: 600
   - Categories: 12
   - Total Spent: $2,258,441.00
   - List of 12 categories with colored dots
   - Recent expenses list

---

## ✅ Success Criteria

### Dashboard Loads Successfully If You See:

**Quick Stats Section:**
- ✅ Total Expenses: 600
- ✅ Categories: 12
- ✅ Total Spent: $2,258,441.00

**Categories Section (12 categories):**
- ✅ Coffee - $2,000/month
- ✅ Tech Improvements - $5,000/month
- ✅ Groceries - $5,000/month
- ✅ MF Investments - $39,500/month
- ✅ Food (outside) - $5,000/month
- ✅ Gifts - $5,000/month
- ✅ Vehicular Expenses - $5,000/month
- ✅ Self Care - $5,000/month
- ✅ Home Improvements - $5,000/month
- ✅ Travel - $10,000/month
- ✅ Insurances - $15,000/month
- ✅ Shadi - $0/month

**Recent Expenses Section:**
- ✅ Shows list of recent transactions
- ✅ Each shows: description, date, amount
- ✅ Amounts formatted as currency ($X.XX)

---

## 🐛 If Something Goes Wrong

### Check Console for Errors

**Look for lines starting with:**
- `❌` - Error indicator
- `🔴` - Critical error

**Common errors and meanings:**

1. **`❌ Missing key: ...`**
   - Means: API returned different field names
   - Copy the error and I'll fix it

2. **`❌ Type mismatch: ...`**
   - Means: API returned wrong data type
   - Copy the error and I'll fix it

3. **`❌ Request failed with status: 401`**
   - Means: Token expired or invalid
   - Try logging out and back in

4. **`❌ Request failed with status: 404`**
   - Means: API endpoint not found
   - Check server is running

---

## 📱 Test on iPhone (After Simulator Works)

### Prerequisites:
- Simulator test passed ✅
- iPhone connected via USB
- Trust certificate installed on iPhone

### Steps:
1. **Select your iPhone** from device dropdown in Xcode
2. **Click** Play ▶️
3. **On iPhone:** Trust the developer certificate if prompted
   - Settings → General → VPN & Device Management
   - Tap your email → Trust
4. **Launch app** from home screen
5. **Login** with same credentials
6. **Verify** dashboard loads with your data

---

## 🎯 What to Report

If dashboard loads successfully:
- ✅ **Report:** "Dashboard loaded! I see X expenses and Y categories"

If there's an error:
- ❌ **Copy paste:**
  - The EXACT console error (lines with ❌)
  - What you see on the app screen
  - The last 10-20 lines of console output

---

## 🚀 Next Steps After Success

Once dashboard works:

1. **Test Pull to Refresh**
   - Pull down on the list
   - Should reload data

2. **Test Scrolling**
   - Scroll through expenses
   - Should be smooth

3. **Test Logout**
   - Click logout button (top right)
   - Should return to login screen

4. **Ready for Features!**
   - Add expense view
   - Edit expense
   - Delete expense
   - Category management
   - Insights/reports

---

## 📊 Server Status Check

**Before testing, verify server is running:**

```bash
curl http://192.168.1.110:3000
# Should return HTML (OnTrack login page)

curl http://192.168.1.110:3000/api/v1/categories
# Should return 401 (needs auth) - this is correct!
```

---

**Ready to test! Build and run the app now!** 🎉


