# frozen_string_literal: true

module Admin
  class CampaignsController < ApplicationController
    before_action :require_admin!

    def index
      client = Mailchimp::MarketingClient.new
      payload = client.list_campaigns(count: 50)
      @campaigns = Array(payload["campaigns"])
      @total_items = payload["total_items"]
      @mailchimp_error = nil
    rescue Mailchimp::MarketingClient::Error => e
      @campaigns = []
      @total_items = 0
      @mailchimp_error = e.message
    end
  end
end
