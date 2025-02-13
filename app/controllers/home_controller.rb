require 'open-uri'

class HomeController < ApplicationController
  def privacy
  end

  def terms
  end

  def refund_policy
  end

  def test
  end

  def pricing
  end
  
  def contact
  end

  def deployment_options
  end

  def explore
    current_user.update(state: User.states[:buyer])
    redirect_to marketplace_root_path
  end

  def robots
    respond_to :text
  end

  def sitemap
    send_data URI.parse("https://#{ENV["S3_BUCKET"]}.s3.us-east-2.amazonaws.com/sitemaps/#{params[:filename]}.xml").open.read, filename: params[:filename], type: 'text/xml', disposition: "inline", stream: true
  end
end
