require "rails_helper"

RSpec.describe "Admin communication templates", type: :request do
  let(:admin) { create(:user, role: :admin) }

  before { login_as(admin, scope: :user) }

  describe "GET /admin/communication_templates/:id/edit" do
    it "renders the edit form pre-filled with the template's values" do
      template = CommunicationTemplate.create!(name: "Welcome", subject: "Hi", body: "Hi there", funnel_stage: :inquiry)

      get edit_admin_communication_template_path(template)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Edit Email Template")
      expect(response.body).to include("Welcome")
    end
  end

  describe "PATCH /admin/communication_templates/:id" do
    it "updates the template and redirects to it" do
      template = CommunicationTemplate.create!(name: "Welcome", subject: "Hi", body: "Hi there", funnel_stage: :inquiry)

      patch admin_communication_template_path(template),
        params: { communication_template: { name: "Welcome v2", subject: "Hi {{first_name}}", interval_days: 30, trigger_type: "interval" } }

      expect(response).to redirect_to(admin_communication_template_path(template))
      template.reload
      expect(template.name).to eq("Welcome v2")
      expect(template.subject).to eq("Hi {{first_name}}")
      expect(template.interval_days).to eq(30)
    end

    it "re-renders the form with errors when invalid" do
      template = CommunicationTemplate.create!(name: "Welcome", body: "Hi there", funnel_stage: :inquiry)

      patch admin_communication_template_path(template), params: { communication_template: { name: "" } }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(template.reload.name).to eq("Welcome")
    end
  end

  describe "DELETE /admin/communication_templates/:id" do
    it "shows an in-page confirmation step before deleting" do
      template = CommunicationTemplate.create!(name: "Welcome", body: "Hi there", funnel_stage: :inquiry)

      get admin_communication_template_path(template, confirm_delete: 1)

      expect(response).to be_successful
      expect(response.body).to include("Delete <strong>Welcome</strong>?")
      expect(response.body).to include("Yes, delete")
    end

    it "deletes the template and redirects to the list" do
      template = CommunicationTemplate.create!(name: "Welcome", body: "Hi there", funnel_stage: :inquiry)

      expect {
        delete admin_communication_template_path(template)
      }.to change(CommunicationTemplate, :count).by(-1)

      expect(response).to redirect_to(admin_communication_templates_path)
      follow_redirect!
      expect(response.body).to include("Welcome was deleted.")
    end
  end

  describe "POST /admin/communication_templates/:id/preview" do
    it "renders all supported merge fields, not just first_name" do
      template = CommunicationTemplate.create!(
        name: "Welcome",
        subject: "Hi {{first_name}} {{last_name}}",
        body: "Reach us at {{email}}.",
        funnel_stage: :inquiry
      )

      post preview_admin_communication_template_path(template),
        params: { first_name: "Jane", last_name: "Doe", email: "jane@example.com" }

      expect(response.body).to include("Hi Jane Doe")
      expect(response.body).to include("Reach us at jane@example.com.")
    end
  end
end
