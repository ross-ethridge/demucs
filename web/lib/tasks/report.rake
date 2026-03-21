namespace :report do
  desc "List all registered users and their email addresses"
  task users: :environment do
    users = User.order(:created_at)
    puts "%-5s %-40s %s" % ["ID", "Email", "Registered"]
    puts "-" * 70
    users.each do |user|
      puts "%-5s %-40s %s" % [user.id, user.email_address, user.created_at.strftime("%Y-%m-%d %H:%M")]
    end
    puts "\nTotal: #{users.count} user(s)"
  end
end
