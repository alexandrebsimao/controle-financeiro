namespace :due_transactions do
  desc "Send due transactions notification emails to all users"
  task send_notifications: :environment do
    puts "Starting due transactions notification job..."
    
    DueTransactionsNotificationJob.perform_async
    
    puts "✓ Emails sent successfully!"
  end

  desc "Send test notification to a specific user (pass user_id as EMAIL_USER_ID)"
  task test_notification: :environment do
    user_id = ENV['EMAIL_USER_ID']
    
    if user_id.blank?
      puts "Usage: rails due_transactions:test_notification EMAIL_USER_ID=1"
      puts "Example: rails due_transactions:test_notification EMAIL_USER_ID=1"
      return
    end

    user = User.find(user_id)
    
    if user.email.blank?
      puts "✗ User #{user_id} does not have an email address"
      return
    end

    puts "Sending test notification to #{user.email}..."
    
    TransactionMailer.due_transactions_notification(user).deliver_now
    
    puts "✓ Email sent to #{user.email}!"
  end

  desc "List all users and their due transactions"
  task list_due_transactions: :environment do
    User.find_each do |user|
      transactions = {
        overdue: user.transactions.unpaid.where("due_date < ?", Date.today),
        due_today: user.transactions.unpaid.where(due_date: Date.today),
        due_in_3_days: user.transactions.unpaid.where(due_date: 3.days.from_now.to_date),
        due_in_5_days: user.transactions.unpaid.where(due_date: 5.days.from_now.to_date)
      }

      has_transactions = transactions.values.any? { |t| t.any? }
      
      puts "\n=== User: #{user.name} (#{user.email}) ==="
      puts "Has due transactions: #{has_transactions ? '✓ Yes' : '✗ No'}"

      if transactions[:overdue].any?
        puts "\n  Vencidas:"
        transactions[:overdue].each do |t|
          puts "    - #{t.title}: #{t.formatted_amount} (#{t.due_date})"
        end
      end

      if transactions[:due_today].any?
        puts "\n  Vence Hoje:"
        transactions[:due_today].each do |t|
          puts "    - #{t.title}: #{t.formatted_amount} (#{t.due_date})"
        end
      end

      if transactions[:due_in_3_days].any?
        puts "\n  Vence em 3 Dias:"
        transactions[:due_in_3_days].each do |t|
          puts "    - #{t.title}: #{t.formatted_amount} (#{t.due_date})"
        end
      end

      if transactions[:due_in_5_days].any?
        puts "\n  Vence em 5 Dias:"
        transactions[:due_in_5_days].each do |t|
          puts "    - #{t.title}: #{t.formatted_amount} (#{t.due_date})"
        end
      end
    end

    puts "\n" + "="*50
  end
end
