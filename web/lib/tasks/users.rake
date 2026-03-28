namespace :users do
  ADJECTIVES = %w[bouncy fluffy sneaky wobbly grumpy sparkly chunky wiggly squishy dizzy
                  spooky crusty funky lumpy gloopy zesty wacky soggy crispy wobbly].freeze
  NOUNS      = %w[penguin taco waffle narwhal burrito pickle unicorn noodle muffin platypus
                  biscuit nugget goblin turnip hamster pretzel raccoon dumpling lobster donut].freeze

  def funny_password
    "#{ADJECTIVES.sample}-#{NOUNS.sample}-#{rand(10..99)}"
  end

  desc "Create a user with a generated password: rails users:create EMAIL=you@example.com"
  task create: :environment do
    email    = ENV.fetch("EMAIL")
    password = funny_password

    user = User.create!(
      email_address:     email,
      password:          password,
      email_verified_at: Time.current
    )

    puts "Created user: #{user.email_address} (id=#{user.id})"
    puts "Password:     #{password}"
    puts "They can change it after logging in via Account > Change Password."
  end

  desc "List all users: rails users:list"
  task list: :environment do
    User.order(:email_address).each do |u|
      puts "#{u.id}\t#{u.email_address}"
    end
  end

  desc "Delete a user: rails users:delete EMAIL=you@example.com"
  task delete: :environment do
    email = ENV.fetch("EMAIL")
    user  = User.find_by!(email_address: email)
    user.destroy!
    puts "Deleted user: #{email}"
  end

  desc "Reset a user's password to a new generated one: rails users:reset EMAIL=you@example.com"
  task reset: :environment do
    email    = ENV.fetch("EMAIL")
    password = funny_password
    user     = User.find_by!(email_address: email)
    user.update!(password: password)
    puts "Reset password for: #{email}"
    puts "New password:       #{password}"
  end
end
