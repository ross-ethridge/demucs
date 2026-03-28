class ApplicationMailer < ActionMailer::Base
  default from: ENV.fetch("SMTP_FROM", "noreply@localhost")
  layout "mailer"
end
