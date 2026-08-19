class ReferralSourcesController < ApplicationController
  def create
    ReferralSource.create!(name: params[:name], active: active_from_params(default: true))
    redirect_to system_management_path(tab: "referral_sources"), notice: "Referral source added."
  end

  def update
    ReferralSource.find(params[:id]).update!(name: params[:name], active: active_from_params(default: false))
    redirect_to system_management_path(tab: "referral_sources"), notice: "Referral source updated."
  end

  def destroy
    ReferralSource.find(params[:id]).destroy
    redirect_to system_management_path(tab: "referral_sources"), notice: "Referral source removed."
  end

  private

  def active_from_params(default:)
    return default if params[:active].nil?

    ActiveModel::Type::Boolean.new.cast(params[:active])
  end
end
