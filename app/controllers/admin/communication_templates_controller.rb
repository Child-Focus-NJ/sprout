class Admin::CommunicationTemplatesController < ApplicationController
  def index
    @templates = CommunicationTemplate.all
  end

  def new
    @template = CommunicationTemplate.new
  end

  def create
    @template = CommunicationTemplate.new(template_params)
    if @template.save
      redirect_to admin_communication_templates_path, notice: "Template created."
    else
      render :new
    end
  end

  def show
    @template = CommunicationTemplate.find(params[:id])
  end

  def preview
    @template = CommunicationTemplate.find(params[:id])
    if request.post?
      first_name = params[:first_name]
      @preview_subject = @template.subject.gsub("{{first_name}}", first_name)
      @preview_body = @template.body.gsub("{{first_name}}", first_name)
    end
  end


  private

  def template_params
    params.require(:communication_template).permit(:name, :subject, :body, :funnel_stage, :template_type, :trigger_type)
  end
end
