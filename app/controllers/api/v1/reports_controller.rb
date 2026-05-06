module Api; module V1
  class ReportsController < BaseController
    def year
      year_int = params[:year].to_i
      start_date = Date.new(year_int, 1, 1)
      end_date   = Date.new(year_int + 1, 1, 1)

      total = @current_user.expenses
        .where(paid_at: start_date...end_date)
        .sum(:amount)

      category_percentages = exec_with_binds(<<~SQL, total.to_f, start_date, end_date, @current_user.id)
        SELECT categories.name AS category, SUM(expenses.amount) / NULLIF(?, 0) AS percentage
        FROM expenses
        JOIN categories ON expenses.category_id = categories.id
        WHERE paid_at >= ? AND paid_at < ? AND expenses.user_id = ?
        GROUP BY categories.id
        ORDER BY percentage
      SQL

      category_totals = exec_with_binds(<<~SQL, start_date, end_date, @current_user.id)
        SELECT categories.name AS category, SUM(expenses.amount) AS amount, categories.color AS color
        FROM expenses
        JOIN categories ON expenses.category_id = categories.id
        WHERE paid_at >= ? AND paid_at < ? AND expenses.user_id = ?
        GROUP BY categories.id
        ORDER BY amount DESC
      SQL

      category_amounts_by_month = exec_with_binds(<<~SQL, start_date, end_date, @current_user.id)
        SELECT categories.name AS category, to_char(date_trunc('month', paid_at), 'Mon') AS month, SUM(expenses.amount) AS amount
        FROM expenses
        JOIN categories ON expenses.category_id = categories.id
        WHERE paid_at >= ? AND paid_at < ? AND expenses.user_id = ?
        GROUP BY month, categories.id
        ORDER BY categories.rank ASC, categories.id ASC
      SQL

      render json: {
        category_percentages: category_percentages,
        category_totals: category_totals,
        category_amounts_by_month: category_amounts_by_month,
        category_averages_for_year: average_by_category(year_int),
        total: total,
        categories: @current_user.categories.select(:id, :name, :color).order(:name)
      }
    end

    def month
      start_date = Date.strptime(params[:month], '%B %Y')
      end_date = start_date + 1.month

      category_totals = exec_with_binds(<<~SQL, start_date, end_date, @current_user.id)
        SELECT categories.name AS category, categories.monthly_goal AS monthly_goal, SUM(expenses.amount) AS spend
        FROM expenses
        JOIN categories ON expenses.category_id = categories.id
        WHERE paid_at >= ? AND paid_at < ? AND expenses.user_id = ?
        GROUP BY categories.rank, categories.id
        ORDER BY categories.rank ASC, categories.id ASC
      SQL

      render json: {
        category_totals: category_totals,
        category_averages_for_year: average_by_category(start_date.year),
        total: @current_user.expenses.where(paid_at: start_date...end_date).sum(:amount),
        monthly_goal: @current_user.monthly_goal
      }
    end

    def available_years
      years = @current_user.expenses
        .distinct
        .pluck(Arel.sql("EXTRACT(YEAR FROM paid_at)::integer"))
        .sort
        .reverse

      render json: { years: years }
    end

    private

    # Safely interpolate `?` placeholders in raw SQL. `sanitize_sql` is the
    # public alias that delegates to `sanitize_sql_array` for Array inputs and
    # routes through the connection's `quote`, so values are properly escaped
    # for the active adapter (Postgres handles Date/Float/Integer correctly).
    def exec_with_binds(sql, *binds)
      sanitized = ActiveRecord::Base.sanitize_sql([sql, *binds])
      ActiveRecord::Base.connection.execute(sanitized)
    end

    def average_by_category(year)
      months_to_average = year == Date.today.year ? Date.today.month - 1 : 12
      months_to_average = [months_to_average, 1].max
      start_date = Date.new(year, 1, 1)
      end_date = start_date + months_to_average.month

      category_totals = exec_with_binds(<<~SQL, start_date, end_date, @current_user.id)
        SELECT categories.name AS category, SUM(expenses.amount) AS amount
        FROM expenses
        JOIN categories ON expenses.category_id = categories.id
        WHERE paid_at >= ? AND paid_at < ? AND expenses.user_id = ?
        GROUP BY categories.id
      SQL

      total_sum = 0
      averages = category_totals.map do |c|
        total_sum += c['amount']
        { category: c['category'], amount: (c['amount'] / months_to_average.to_f).round }
      end

      averages << { category: 'All', amount: (total_sum / months_to_average.to_f).round }

      { averages: averages, start_date: start_date, end_date: end_date - 1.second }
    end
  end
end; end
