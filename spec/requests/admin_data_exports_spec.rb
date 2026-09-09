require "rails_helper"

RSpec.describe "Admin data exports", type: :request do
  let(:filename) { "sprout-full-export-#{Date.current.iso8601}.xlsx" }
  let(:download_path) { Rails.root.join("tmp", "test_downloads", filename) }

  before { FileUtils.mkdir_p(Rails.root.join("tmp", "test_downloads")) }
  after { FileUtils.rm_f(download_path) }

  describe "POST /admin/data_export" do
    context "as an admin" do
      before { login_as(create(:user, role: :admin), scope: :user) }

      it "writes an xlsx workbook containing every table" do
        create(:volunteer, email: "grace@example.org")

        post admin_data_export_path

        expect(response).to have_http_status(:ok)
        expect(download_path).to exist

        workbook = Roo::Spreadsheet.open(download_path.to_s)
        expect(workbook.sheets).to include("volunteers", "users")
        expect(workbook.sheet("volunteers").to_a.flatten).to include("grace@example.org")
      end
    end

    context "as a non-admin" do
      before { login_as(create(:user, :staff), scope: :user) }

      it "redirects to root with an authorization alert" do
        post admin_data_export_path

        expect(response).to redirect_to(root_path)
        follow_redirect!
        expect(response.body).to include("not authorized")
      end

      it "does not write a file" do
        expect { post admin_data_export_path }
          .not_to change { Dir[Rails.root.join("tmp", "test_downloads", "*")].length }
      end
    end

    context "when signed out" do
      it "redirects to the login page" do
        post admin_data_export_path

        expect(response).to redirect_to(login_path)
      end
    end
  end
end
