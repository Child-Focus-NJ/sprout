class NoteCategoriesController < ApplicationController
  restrict_to_feature :note_categories

  def create
    category = NoteCategory.new(name: params[:name])
    if category.save
      redirect_to system_management_path(tab: "note_categories"), notice: "Note category added."
    else
      redirect_to system_management_path(tab: "note_categories"), alert: category.errors.full_messages.to_sentence
    end
  end

  def update
    category = NoteCategory.find(params[:id])
    if category.update(name: params[:name])
      redirect_to system_management_path(tab: "note_categories"), notice: "Note category updated."
    else
      redirect_to system_management_path(tab: "note_categories", edit_note_category_id: category.id),
                  alert: category.errors.full_messages.to_sentence
    end
  end

  def destroy
    category = NoteCategory.find(params[:id])
    if category.destroy
      redirect_to system_management_path(tab: "note_categories"), notice: "Note category removed."
    else
      redirect_to system_management_path(tab: "note_categories"), alert: category.errors.full_messages.to_sentence
    end
  end
end
