# Usage: rails runner scripts/setup_video_demo.rb

puts "🎥 Setting up Video Demo Data for 'OnTrack'..."

user_login = "video_demo"
user_pass = "demo123"

# 1. User Setup
user = User.find_by(login_id: user_login)
if user
  puts "   Found existing user '#{user_login}', clearing data..."
  user.expenses.destroy_all
  user.categories.destroy_all
else
  puts "   Creating user '#{user_login}'..."
  user = User.create!(
    login_id: user_login,
    username: user_login,
    password: user_pass,
    monthly_goal: 300000 # $3000.00
  )
end

# 2. Categories
puts "   Creating Categories..."
cats = {}
[
  { name: "Housing", color: "#4A90E2", goal: 150000, rank: 1 }, # Blue
  { name: "Food", color: "#50E3C2", goal: 60000, rank: 2 },    # Teal
  { name: "Fun", color: "#E94E77", goal: 40000, rank: 3 },     # Pink
  { name: "Transport", color: "#F5A623", goal: 20000, rank: 4 } # Orange
].each do |c|
  cats[c[:name]] = Category.create!(
    user: user,
    name: c[:name],
    color: c[:color],
    monthly_goal: c[:goal],
    rank: c[:rank]
  )
end

# 3. Expenses
puts "   Generating Expenses (last 90 days)..."
end_date = Date.today
start_date = end_date - 90.days

count = 0
(start_date..end_date).each do |date|
  # Rent: 1st of month
  if date.day == 1
    Expense.create!(
      user: user,
      category: cats["Housing"],
      amount: 120000, # $1200
      description: "Apartment Rent",
      paid_at: date
    )
    count += 1
  end

  # Groceries: Every ~Saturday
  if date.saturday?
    Expense.create!(
      user: user,
      category: cats["Food"],
      amount: rand(8000..15000), # $80-$150
      description: ["Trader Joe's", "Whole Foods", "Supermarket"].sample,
      paid_at: date
    )
    count += 1
  end

  # Coffee: Frequent (30% chance daily)
  if rand < 0.3
    Expense.create!(
      user: user,
      category: cats["Food"],
      amount: rand(400..800), # $4-$8
      description: ["Starbucks", "Morning Coffee", "Cafe"].sample,
      paid_at: date
    )
    count += 1
  end

  # Transport: Random
  if rand < 0.1
    Expense.create!(
      user: user,
      category: cats["Transport"],
      amount: rand(1500..4000), # $15-$40
      description: ["Uber", "Lyft", "Gas"].sample,
      paid_at: date
    )
    count += 1
  end

  # Fun: Weekends mostly
  if (date.saturday? || date.sunday?) && rand < 0.5
    Expense.create!(
      user: user,
      category: cats["Fun"],
      amount: rand(2000..8000), # $20-$80
      description: ["Cinema", "Drinks", "Concert", "Dinner Out"].sample,
      paid_at: date
    )
    count += 1
  end
end

puts "✅ Done! Generated #{count} expenses."
puts "   Login with -> Username: #{user_login} | Password: #{user_pass}"
