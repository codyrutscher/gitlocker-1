module Marketplace
class CreatorsController < ApplicationController
  before_action :authenticate_user!
  def index
    @users = User.filter_and_sort(params).page(params[:page]).per(40)
     respond_to do |format|
      format.html
      format.js
    end
  end

  def show
    @user = User.friendly.find(params[:id])
    @products = @user.products.published.page(params[:page]).per(15)
    @languages = @user.languages
    @categories = @user.categories
  end
end
end
