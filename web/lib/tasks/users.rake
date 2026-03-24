namespace :users do
  desc "Create a user: rake users:create EMAIL=you@example.com PASSWORD=secret"
  task create: :environment do
    email    = ENV.fetch("EMAIL")
    password = ENV.fetch("PASSWORD")

    user = User.create!(
      email_address:     email,
      password:          password,
      email_verified_at: Time.current
    )

    puts "Created user: #{user.email_address} (id=#{user.id})"
  end
end
