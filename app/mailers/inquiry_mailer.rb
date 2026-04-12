class InquiryMailer < ApplicationMailer
  def confirmation(to_email)
    mail(
      to: to_email,
      subject: "Thanks for your inquiry",
      body: "Thanks for reaching out to Child Focus NJ. We'll be in touch soon."
    )
  end
end
