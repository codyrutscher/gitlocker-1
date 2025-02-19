class BlogsController < ApplicationController
  def index
    @blogs = Blog.includes([:image_attachment], image_attachment: :blob).page(params[:page]).per(60)
  end

  def show
    @blog = Blog.includes([:image_attachment], image_attachment: :blob).friendly.find(params[:slug])
  end

  def export_data
    csv_data = CSV.generate(headers: true) do |csv|
      csv << Blog.column_names + ["image_filename"]
    
      Blog.find_each do |blog|
        image_filename = blog.image.attached? ? blog.image.filename.to_s : nil
        csv << blog.attributes.values + [image_filename]
      end
    end
    send_data csv_data, filename: "blogs_data.csv"
    respond_to do |format|
      format.csv
    end
  end
end
