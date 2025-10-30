# 📱 OnTrack iOS App - Xcode Setup Guide

## Prerequisites ✅

- ✅ **Xcode Version:** 16.0.1 (17A400) - Installed
- ✅ **macOS:** Compatible with Xcode 16
- ✅ **Backend Server:** Running on Mac (http://172.29.14.90:3000)
- ✅ **Test User:** admin / password123
- ✅ **API Endpoints:** All tested and working

---

## Part 1: Create New Xcode Project

### Step 1: Launch Xcode and Create Project

1. Open **Xcode 16.0.1**
2. Select **"Create New Project"** or File → New → Project
3. Choose template:
   - **iOS** tab
   - **App** template
   - Click **Next**

### Step 2: Configure Project Settings

**Project Configuration:**
- **Product Name:** `OnTrack`
- **Team:** Select your Apple ID (or add one)
  - If not signed in: Xcode → Settings → Accounts → Add Apple ID
- **Organization Identifier:** `com.yourname.ontrack` (change `yourname` to your name)
- **Bundle Identifier:** Will auto-generate as `com.yourname.ontrack.OnTrack`
- **Interface:** **SwiftUI** ✅
- **Language:** **Swift** ✅
- **Storage:** **None** (we'll handle our own data)
- **Include Tests:** ☑️ (optional)

Click **Next**

### Step 3: Choose Location

- Save location: `/Users/djamgade/personal/ontrack/OnTrack-iOS/`
- **Create Git repository:** ☑️ (recommended)
- Click **Create**

---

## Part 2: Project Structure Setup

### Step 4: Create Folder Structure

In Xcode Project Navigator (left sidebar), create these groups:

**Right-click on OnTrack folder → New Group**

Create these folders:
```
OnTrack/
├── Models/
├── ViewModels/
├── Views/
│   ├── Auth/
│   ├── Dashboard/
│   ├── Expenses/
│   ├── Insights/
│   └── Settings/
├── Services/
├── Utilities/
└── Resources/
```

**How to create folders:**
1. Right-click "OnTrack" in Project Navigator
2. Select "New Group"
3. Name it (e.g., "Models")
4. Repeat for all folders above

---

## Part 3: Configure Project Settings

### Step 5: iOS Deployment Target

1. Click **OnTrack** project in navigator (top blue icon)
2. Select **OnTrack** target (under TARGETS)
3. Go to **General** tab
4. Set **Minimum Deployments:** `iOS 17.0` or `iOS 18.0`
   - Your iPhone 12 is on iOS 18.5, so iOS 17.0+ will work

### Step 6: App Transport Security (for HTTP API)

Since your backend is running on HTTP (not HTTPS) locally:

1. In Project Navigator, open **Info.plist**
   - If you don't see it, right-click OnTrack → Add Files → Create new file → Property List
2. Add these keys:

**Method 1: Using Xcode Interface**
- Right-click in Info.plist → Add Row
- Key: `App Transport Security Settings` (type: Dictionary)
- Expand it, add row: `Allow Arbitrary Loads` (type: Boolean) → YES

**Method 2: Source Code** (if you prefer)
Right-click Info.plist → Open As → Source Code, add:
```xml
<key>NSAppTransportSecuritySettings</key>
<dict>
    <key>NSAllowsArbitraryLoads</key>
    <true/>
</dict>
```

⚠️ **Note:** This is for development only. In production, use HTTPS.

### Step 7: Local Network Access Permission

Add this to Info.plist (for local network access):
```xml
<key>NSLocalNetworkUsageDescription</key>
<string>OnTrack needs to connect to your local server for expense tracking.</string>
```

---

## Part 4: Create Core Swift Files

### Step 8: Create Configuration File

**Create:** `Utilities/NetworkConfiguration.swift`

1. Right-click **Utilities** folder → New File
2. Choose **Swift File**
3. Name: `NetworkConfiguration.swift`
4. Add this code:

```swift
import Foundation
import Network

class NetworkConfiguration: ObservableObject {
    static let shared = NetworkConfiguration()
    
    // IMPORTANT: Update this with your Mac's IP address
    let localIP = "172.29.14.90"        // Your Mac's local IP
    let port = "3000"                    // Rails server port
    
    @Published var currentBaseURL: String
    @Published var isOnline = true
    
    private init() {
        currentBaseURL = "http://\(localIP):\(port)/api/v1"
    }
    
    func testConnection() async {
        guard let url = URL(string: "\(currentBaseURL)/auth/validate") else {
            await MainActor.run { isOnline = false }
            return
        }
        
        var request = URLRequest(url: url)
        request.timeoutInterval = 5.0
        
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse {
                await MainActor.run {
                    isOnline = (httpResponse.statusCode == 200 || httpResponse.statusCode == 401)
                }
            }
        } catch {
            await MainActor.run { isOnline = false }
        }
    }
}
```

### Step 9: Create Models

**Create:** `Models/Expense.swift`

```swift
import Foundation

struct Expense: Codable, Identifiable {
    let id: Int
    var description: String
    var amount: Int  // Amount in cents
    var categoryId: Int
    var paidAt: Date
    let createdAt: Date?
    let updatedAt: Date?
    var category: Category?
    
    enum CodingKeys: String, CodingKey {
        case id, description, amount
        case categoryId = "category_id"
        case paidAt = "paid_at"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case category
    }
    
    var amountInDollars: Double {
        Double(amount) / 100.0
    }
    
    var formattedAmount: String {
        String(format: "$%.2f", amountInDollars)
    }
}

struct Category: Codable, Identifiable {
    let id: Int
    var name: String
    var color: String
    var monthlyGoal: Int
    var rank: Int?
    
    enum CodingKeys: String, CodingKey {
        case id, name, color, rank
        case monthlyGoal = "monthly_goal"
    }
}

struct ExpenseCreate: Codable {
    let description: String
    let amount: Int
    let categoryId: Int
    let paidAt: String
    
    enum CodingKeys: String, CodingKey {
        case description, amount
        case categoryId = "category_id"
        case paidAt = "paid_at"
    }
}
```

### Step 10: Create Keychain Manager

**Create:** `Services/KeychainManager.swift`

```swift
import Foundation
import Security

class KeychainManager {
    static let shared = KeychainManager()
    private let service = "com.ontrack.app"
    private let account = "authToken"
    
    private init() {}
    
    func saveToken(_ token: String) {
        let data = token.data(using: .utf8)!
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data
        ]
        
        // Delete any existing item
        SecItemDelete(query as CFDictionary)
        
        // Add new item
        SecItemAdd(query as CFDictionary, nil)
    }
    
    func getToken() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess,
              let data = result as? Data,
              let token = String(data: data, encoding: .utf8) else {
            return nil
        }
        
        return token
    }
    
    func deleteToken() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        
        SecItemDelete(query as CFDictionary)
    }
}
```

### Step 11: Create API Service

**Create:** `Services/APIService.swift`

```swift
import Foundation

class APIService {
    static let shared = APIService()
    private let networkConfig = NetworkConfiguration.shared
    
    private init() {}
    
    // MARK: - Authentication
    
    func login(username: String, password: String) async throws -> AuthResponse {
        let url = URL(string: "\(networkConfig.currentBaseURL)/auth/login")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: String] = [
            "username": username,
            "password": password
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw APIError.invalidCredentials
        }
        
        let authResponse = try JSONDecoder().decode(AuthResponse.self, from: data)
        KeychainManager.shared.saveToken(authResponse.token)
        
        return authResponse
    }
    
    // MARK: - Categories
    
    func fetchCategories() async throws -> [Category] {
        return try await makeRequest(endpoint: "/categories")
    }
    
    // MARK: - Expenses
    
    func fetchExpenses() async throws -> [Expense] {
        return try await makeRequest(endpoint: "/expenses")
    }
    
    func createExpense(_ expense: ExpenseCreate) async throws -> Expense {
        let url = URL(string: "\(networkConfig.currentBaseURL)/expenses")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if let token = KeychainManager.shared.getToken() {
            request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        let encoder = JSONEncoder()
        request.httpBody = try encoder.encode(expense)
        
        let (data, _) = try await URLSession.shared.data(for: request)
        return try JSONDecoder().decode(Expense.self, from: data)
    }
    
    // MARK: - Generic Request
    
    private func makeRequest<T: Decodable>(endpoint: String) async throws -> T {
        let url = URL(string: "\(networkConfig.currentBaseURL)\(endpoint)")!
        var request = URLRequest(url: url)
        
        if let token = KeychainManager.shared.getToken() {
            request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw APIError.requestFailed
        }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(T.self, from: data)
    }
}

// MARK: - Response Models

struct AuthResponse: Codable {
    let token: String
    let user: UserInfo
}

struct UserInfo: Codable {
    let id: Int
    let monthlyGoal: Int
    
    enum CodingKeys: String, CodingKey {
        case id
        case monthlyGoal = "monthly_goal"
    }
}

// MARK: - Errors

enum APIError: LocalizedError {
    case invalidCredentials
    case requestFailed
    case offline
    
    var errorDescription: String? {
        switch self {
        case .invalidCredentials:
            return "Invalid username or password"
        case .requestFailed:
            return "Request failed. Please try again."
        case .offline:
            return "Cannot connect to server"
        }
    }
}
```

### Step 12: Create Login View

**Create:** `Views/Auth/LoginView.swift`

```swift
import SwiftUI

struct LoginView: View {
    @State private var username = "admin"
    @State private var password = "password123"
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var isLoggedIn = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("OnTrack")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("Expense Tracker")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                VStack(spacing: 15) {
                    TextField("Username", text: $username)
                        .textFieldStyle(.roundedBorder)
                        .textContentType(.username)
                        .autocapitalization(.none)
                    
                    SecureField("Password", text: $password)
                        .textFieldStyle(.roundedBorder)
                        .textContentType(.password)
                    
                    if let error = errorMessage {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                    
                    Button(action: login) {
                        if isLoading {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Text("Sign In")
                                .fontWeight(.semibold)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                    .disabled(isLoading)
                }
                .padding()
                
                Spacer()
                
                Text("Local Network: 172.29.14.90:3000")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .navigationDestination(isPresented: $isLoggedIn) {
                DashboardView()
            }
        }
    }
    
    func login() {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                let _ = try await APIService.shared.login(username: username, password: password)
                await MainActor.run {
                    isLoggedIn = true
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isLoading = false
                }
            }
        }
    }
}
```

### Step 13: Create Dashboard View (Placeholder)

**Create:** `Views/Dashboard/DashboardView.swift`

```swift
import SwiftUI

struct DashboardView: View {
    @State private var categories: [Category] = []
    @State private var expenses: [Expense] = []
    @State private var isLoading = true
    
    var body: some View {
        NavigationStack {
            List {
                Section("Quick Stats") {
                    Text("Total Expenses: \(expenses.count)")
                    Text("Categories: \(categories.count)")
                }
                
                Section("Recent Expenses") {
                    if expenses.isEmpty {
                        Text("No expenses yet")
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(expenses.prefix(5)) { expense in
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(expense.description)
                                        .font(.headline)
                                    Text(expense.paidAt, style: .date)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                Text(expense.formattedAmount)
                                    .font(.headline)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Dashboard")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Logout") {
                        KeychainManager.shared.deleteToken()
                        // Handle logout
                    }
                }
            }
            .task {
                await loadData()
            }
        }
    }
    
    func loadData() async {
        do {
            categories = try await APIService.shared.fetchCategories()
            expenses = try await APIService.shared.fetchExpenses()
            isLoading = false
        } catch {
            print("Error loading data: \(error)")
            isLoading = false
        }
    }
}
```

### Step 14: Update App Entry Point

**Edit:** `OnTrackApp.swift` (should already exist)

```swift
import SwiftUI

@main
struct OnTrackApp: App {
    var body: some Scene {
        WindowGroup {
            LoginView()
        }
    }
}
```

---

## Part 5: Test in Simulator

### Step 15: Run in Simulator

1. **Select Simulator:**
   - Top toolbar: Click device selector (next to scheme)
   - Choose **iPhone 15 Pro** or any iOS 17+ simulator
   - Click ▶️ **Run** button (or Cmd+R)

2. **Wait for Build:**
   - First build may take 1-2 minutes
   - Watch for any compilation errors in bottom panel

3. **Test Login:**
   - Simulator should launch with login screen
   - Username: `admin`
   - Password: `password123`
   - Click **Sign In**

**Expected Result:** Should show dashboard with categories and expenses!

---

## Part 6: Deploy to iPhone

### Step 16: Connect iPhone

1. **Connect iPhone 12 to Mac** via USB cable
2. **Trust Computer:** On iPhone, tap "Trust" when prompted
3. **In Xcode:** Device selector should now show your iPhone

### Step 17: Register Device (Free Developer Account)

1. **Xcode → Settings → Accounts**
2. Add your Apple ID if not already added
3. Select your Apple ID → **Manage Certificates**
4. Click **+** → **Apple Development** (if not exists)

### Step 18: Configure Signing

1. **Project Navigator** → Click **OnTrack** (blue icon)
2. Select **OnTrack** target
3. **Signing & Capabilities** tab
4. **Team:** Select your Apple ID
5. **Check:** "Automatically manage signing" ☑️
6. **Bundle Identifier:** Ensure it's unique (e.g., `com.djamgade.ontrack.OnTrack`)

### Step 19: Build and Run on iPhone

1. **Select your iPhone** from device dropdown (top toolbar)
2. Click ▶️ **Run** (or Cmd+R)
3. **First time:** Xcode will register your device
4. **On iPhone:** Settings → General → VPN & Device Management
   - Tap your email → **Trust "[Your Name]"**
5. **Run again** from Xcode

**App will install and launch on your iPhone!** 🎉

---

## Part 7: Troubleshooting

### Common Issues

#### 1. "Cannot connect to server"
**Solution:**
- Ensure Mac and iPhone are on same WiFi
- Verify server is running: `curl http://172.29.14.90:3000`
- Check IP address is correct in `NetworkConfiguration.swift`

#### 2. "App Transport Security" error
**Solution:**
- Ensure Info.plist has `NSAllowsArbitraryLoads` = YES
- This allows HTTP connections for development

#### 3. "No provisioning profiles found"
**Solution:**
- Xcode → Settings → Accounts
- Select Apple ID → Download Manual Profiles
- Or: Change Bundle Identifier to something unique

#### 4. App crashes on launch
**Solution:**
- Check Xcode console for error messages
- Ensure all files are added to target (check in File Inspector)
- Clean build folder: Product → Clean Build Folder (Cmd+Shift+K)

#### 5. "Signing requires a development team"
**Solution:**
- Add Apple ID in Xcode Settings → Accounts
- Select the team in project settings

---

## Part 8: Next Steps

### After Basic App Works:

1. **Add More Views:**
   - Expenses list and detail
   - Add expense form
   - Categories management
   - Insights/reports

2. **Improve UI:**
   - Custom color schemes
   - Charts for spending
   - Animations

3. **Add Features:**
   - Pull to refresh
   - Search expenses
   - Filter by category
   - Date range selection

4. **Offline Support:**
   - Cache data locally
   - Sync when online
   - Core Data or SwiftData

---

## Quick Reference

### Important Files
- `NetworkConfiguration.swift` - Update IP address here
- `APIService.swift` - All API calls
- `LoginView.swift` - Login screen
- `Info.plist` - Permissions and settings

### Server Details
- **Local URL:** http://172.29.14.90:3000
- **API Base:** http://172.29.14.90:3000/api/v1
- **Test User:** admin / password123

### Useful Xcode Shortcuts
- **Run:** Cmd+R
- **Stop:** Cmd+.
- **Clean:** Cmd+Shift+K
- **Build:** Cmd+B
- **Quick Open:** Cmd+Shift+O

---

## Support

If you encounter issues:
1. Check Xcode console for errors
2. Verify server is running and accessible
3. Test API with curl first
4. Check all code has been copied correctly
5. Ensure all files are added to target

**Your iOS app development journey starts now!** 🚀📱

