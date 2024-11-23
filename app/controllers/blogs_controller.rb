class BlogsController < ApplicationController
  def index
    @blogs = Blog.includes([:image_attachment], image_attachment: :blob).page(params[:page]).per(60)
  end

  def show
    @blog = Blog.includes([:image_attachment], image_attachment: :blob).friendly.find(params[:slug])
  end
end
