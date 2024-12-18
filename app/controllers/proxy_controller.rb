# app/controllers/proxy_controller.rb
class ProxyController < ApplicationController
  require 'net/http'
  require 'uri'

  def fetch_forum
    url = URI.parse("https://www.gitlocker.freeforums.net")

    # Setting up custom headers (simulate a browser request)
    headers = {
      "User-Agent" => "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36"
    }

    begin
      http = Net::HTTP.new(url.host, url.port)
      http.use_ssl = true if url.scheme == 'https'
      request = Net::HTTP::Get.new(url.path, headers)
      response = http.request(request)
      @content = response.body
    rescue StandardError => e
      @error = "Failed to load the forum: #{e.message}"
    end
  end

   def fetch_youtube
    url = URI.parse("https://www.youtube.com/channel/UCyjfk_yoecwHoiEYbV0ndMQ")

    # Setting up custom headers (simulate a browser request)
    headers = {
      "User-Agent" => "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36"
    }

    begin
      http = Net::HTTP.new(url.host, url.port)
      http.use_ssl = true if url.scheme == 'https'
      request = Net::HTTP::Get.new(url.path, headers)
      response = http.request(request)
      @content = response.body
    rescue StandardError => e
      @error = "Failed to load the forum: #{e.message}"
    end
  end
end
