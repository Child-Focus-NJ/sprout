class UsersController < ApplicationController
  def create
    @user = User.new(
      first_name: params[:first_name],
      last_name:  params[:last_name],
      email:      params[:email],
      role:       params[:role]
    )
    if @user.save
      redirect_to system_management_path
    else
      redirect_to system_management_path
    end
  end

  def destroy
    @user = User.find(params[:id])
    @user.destroy
    redirect_to system_management_path, notice: "User removed."
  end

  private

  def user_params
    params.require(:user).permit(:first_name, :last_name, :email, :role)
  end
end
