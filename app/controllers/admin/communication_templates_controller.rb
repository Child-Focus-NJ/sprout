class Admin::CommunicationTemplatesController < ApplicationController
  before_action :set_template, only: [ :show, :edit, :update, :destroy, :preview ]

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
  end

  def edit
  end

  def update
    if @template.update(template_params)
      redirect_to admin_communication_template_path(@template), notice: "Template updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    name = @template.name
    @template.destroy
    redirect_to admin_communication_templates_path, notice: "#{name} was deleted."
  end

  def preview
    if request.post?
      sample_volunteer = Volunteer.new(
        first_name: params[:first_name].to_s,
        last_name: params[:last_name].to_s,
        email: params[:email].to_s
      )
      @preview_subject = @template.render_subject(sample_volunteer)
      @preview_body = @template.render_body(sample_volunteer)
    end
  end

  private

  def set_template
    @template = CommunicationTemplate.find(params[:id])
  end

  def template_params
    params.require(:communication_template).permit(
      :name, :subject, :body, :funnel_stage, :template_type, :trigger_type,
      :interval_weeks, :interval_days, :active
    )
  end
end
