class UsersController < ApplicationController
  def create
    @user = User.new(employee_attributes)
    if @user.save
      redirect_to system_management_path(tab: "employees"), notice: "Employee added."
    else
      redirect_to system_management_path(tab: "employees"), alert: @user.errors.full_messages.to_sentence
    end
  end

  def update
    @user = User.find(params[:id])
    if @user.update(employee_attributes)
      redirect_to system_management_path(tab: "employees"), notice: "Employee updated."
    else
      redirect_to system_management_path(tab: "employees", edit_user_id: @user.id),
                  alert: @user.errors.full_messages.to_sentence
    end
  end

  def destroy
    @user = User.find(params[:id])
    @user.destroy
    redirect_to system_management_path(tab: "employees"), notice: "User removed."
  end

  private

  def employee_attributes
    attrs = {
      first_name: params[:first_name],
      last_name: params[:last_name],
      email: params[:email]
    }
    attrs[:role] = params[:role] if User.roles.key?(params[:role])
    attrs
  end
end
