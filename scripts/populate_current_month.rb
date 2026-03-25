# scripts/populate_current_month.rb
# usage: rails runner scripts/populate_current_month.rb

puts "🔄 Checking database for current month data..."

current_date = Date.today
current_month_range = current_date.beginning_of_month..current_date.end_of_month

if Expense.where(paid_at: current_month_range).exists?
  puts "✅ Data already exists for #{current_date.strftime('%B %Y')}. Skipping population."
else
  puts "⚠️  No data for #{current_date.strftime('%B %Y')}. Backfilling..."
  
  # Ensure we have categories and user
  if User.count == 0
    puts "Creating default user..."
    User.create!(username: "Diptanshu", password: "finance", monthly_goal: 9000000)
  end
  
  if Category.count == 0
    puts "Creating default categories..."
    # (Same list as before)
    categories_data = [
      { name: "Coffee", color: "#6f4e37", monthly_goal: 200000 },
      { name: "Tech Improvements", color: "#3366cc", monthly_goal: 500000 },
      { name: "Groceries", color: "#109618", monthly_goal: 500000 },
      { name: "MF Investments", color: "#ff9900", monthly_goal: 3950000 },
      { name: "Food (outside)", color: "#dc3912", monthly_goal: 500000 },
      { name: "Gifts", color: "#990099", monthly_goal: 500000 },
      { name: "Vehicular Expenses", color: "#0099c6", monthly_goal: 500000 },
      { name: "Self Care", color: "#dd4477", monthly_goal: 500000 },
      { name: "Home Improvements", color: "#66aa00", monthly_goal: 500000 },
      { name: "Travel", color: "#b82e2e", monthly_goal: 1000000 },
      { name: "Insurances", color: "#316395", monthly_goal: 1500000 },
      { name: "Shadi", color: "#994499", monthly_goal: 0 }
    ]
    categories_data.each { |d| Category.create!(d) }
  end

  # Find last month with expenses
  last_expense = Expense.order(paid_at: :desc).first
  source_expenses = []
  
  if last_expense
    target_month = last_expense.paid_at.beginning_of_month
    puts "Copying data from #{target_month.strftime('%B %Y')}..."
    source_expenses = Expense.where(paid_at: target_month.all_month)
  end

  if source_expenses.empty?
    puts "No previous data found. Generating synthetic data..."
    categories = Category.all
    50.times do |i|
      day = (i % 28) + 1
      Expense.create!(
        description: "Auto-gen Expense #{i}",
        amount: rand(100..5000) * 100,
        category: categories.sample,
        paid_at: current_date.change(day: day)
      )
    end
  else
    source_expenses.each do |e|
      new_day = [e.paid_at.day, 28].min # Clamp to 28 to avoid Feb issues
      new_date = current_date.change(day: new_day)
      Expense.create!(
        description: e.description,
        amount: e.amount,
        category: e.category,
        paid_at: new_date
      )
    end
  end
  puts "✅ Created #{Expense.where(paid_at: current_month_range).count} expenses for #{current_date.strftime('%B %Y')}."
end
