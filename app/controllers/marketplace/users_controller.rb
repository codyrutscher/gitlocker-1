module Marketplace
  class UsersController < ApplicationController
    before_action :authenticate_user!, except: :show
    before_action :set_user, except: :search

    def show
      @user = User.friendly.find(params[:id])
      @products = @user.products.published.page(params[:page]).per(15)
      @languages = @user.languages
      @categories = @user.categories
    end

    def edit
      @user = User.friendly.find(params[:id])
      authorize(@user)
    end

    def search
      query = params[:q].to_s.strip.downcase
    
      users = User.where("id != :current_user_id AND (username ILIKE :q OR email ILIKE :q)",
                         current_user_id: current_user.id, q: "%#{query}%")
                  .select(:id, :username)
                  .limit(10)
    
      render json: users.map { |user| { id: user.id, text: user.username } }
    end

    def update
      @user = User.friendly.find(params[:id])
      authorize(@user)
      if @user.update(user_params)
        if params[:user][:category_ids].present?
          @user.categories = Category.where(id: params[:user][:category_ids])
        else
          @user.categories.clear
        end
        if params[:user][:language_ids].present?
          @user.languages = Language.where(id: params[:user][:language_ids])
        else
          @user.languages.clear
        end
        redirect_to marketplace_user_path(@user), notice: 'Profile is successfully updated.'
      else
        redirect_to edit_marketplace_user_path(@user)
      end
    end

    def follow
      @user = User.friendly.find(params[:id])
      current_user.followees << @user
      FollowNotification.create!(recipient: @user, follower: current_user)
      redirect_back(fallback_location: marketplace_user_path(@user))
    end

    def unfollow
      @user = User.friendly.find(params[:id])
      current_user.followed_users.find_by(followee_id: @user.id).destroy
      redirect_back(fallback_location: marketplace_user_path(@user))
    end

    def followers
      @followers = @user.followers
    end

    def followees
      @followees = @user.followees
    end

    def destroy
      @user.destroy
      redirect_to root_path, notice: 'Account is successfully deleted.'
    end

    private

    def user_params
      params.require(:user).permit(:username, :email, :name, :profile_picture, :bio, :location, :company, :facebook_url, :instagram_url, :linkedin_url, :youtube_url, category_ids: [], language_ids: [])
    end

    def set_user
      @user = User.friendly.find(params[:id])
    end
  end
end
