class InquiryFormsController < ApplicationController
  def new
    @information_sessions = InformationSession.all
    @inquiry = InquiryFormSubmission.new
  end

  def create
    @inquiry = InquiryFormSubmission.new(inquiry_params)
    if @inquiry.save
      redirect_to new_inquiry_form_path, notice: "Inquiry submitted!"
    else
      render :new
    end
  end

  private

  def inquiry_params
    params.require(:inquiry).permit(
      :first_name, :last_name, :email, :phone, :county,
      :how_did_you_hear, :other_info, :preferred_session_id
    )
  end
end
