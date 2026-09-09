require "rails_helper"

RSpec.describe "Admin data exports", type: :request do
  let(:admin) { create(:user, role: :admin) }
  let(:filename) { "sprout-full-export-#{Date.current.iso8601}.xlsx" }
  let(:workbook_path) { Rails.root.join("tmp", filename) }

  after { File.delete(workbook_path) if File.exist?(workbook_path) }

  describe "POST /admin/data_export" do
    context "as an admin" do
      before { login_as(admin, scope: :user) }

      it "returns an xlsx workbook containing every table" do
        create(:volunteer, email: "grace@example.org")

        post admin_data_export_path

        expect(response).to have_http_status(:ok)
        expect(response.media_type).to eq("application/vnd.openxmlformats-officedocument.spreadsheetml.sheet")
        expect(response.headers["Content-Disposition"]).to include("attachment", filename)

        File.binwrite(workbook_path, response.body)
        workbook = Roo::Spreadsheet.open(workbook_path.to_s)
        expect(workbook.sheets).to include("volunteers", "users")
        expect(workbook.sheet("volunteers").to_a.flatten).to include("grace@example.org")
      end

      it "records a completed DataExportLog for the current admin" do
        expect { post admin_data_export_path }.to change(DataExportLog, :count).by(1)

        log = DataExportLog.last
        expect(log).to have_attributes(user: admin, trigger: "manual", status: "completed")
        expect(log.byte_size).to be_positive
        expect(log.completed_at).to be_present
      end

      it "records a failed DataExportLog when the export raises" do
        allow(FullDataExport).to receive(:call).and_raise("boom")

        expect { post admin_data_export_path }.to raise_error("boom")

        log = DataExportLog.last
        expect(log.status).to eq("failed")
        expect(log.error_message).to eq("boom")
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

      it "does not return an xlsx attachment or log an export" do
        expect { post admin_data_export_path }.not_to change(DataExportLog, :count)
        expect(response.headers["Content-Disposition"]).to be_nil
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
