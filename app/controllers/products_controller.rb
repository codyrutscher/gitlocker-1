require 'zip'
require 'tempfile'
require 'aws-sdk-s3'
require 'open3'
class ProductsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_product, only: [:like, :unlike]
  before_action :update_state
  before_action :set_user_repos

  def index
    @products = current_user.products.page(params[:page]).per(50)
  end

  def show
    @product = current_user.products.includes(:reviews, :languages).friendly.find(params[:id])
    @related_products = @product.related_products
    @reviews = @product.reviews.page(params[:page]).per(5)
    @languages = @product.languages
    @categories = @product.categories
  end

  def like
    @product.likes.create
    render json: { likes_count: @product.likes.count }
  end

  def unlike
    @product.likes.last&.destroy
    render json: { likes_count: @product.likes.count }
  end

  def edit
    @product = current_user.products.friendly.find(params[:id])
    @product_categories = @product.product_categories.includes(:category)
  end

  def update

    uploaded_file = product_params[:upload_file]
    file_path = ""
  
    if uploaded_file
      Tempfile.open(['uploaded_file', File.extname(uploaded_file.original_filename)], binmode: true) do |temp_file|
        temp_file.write(uploaded_file.read)
  
        temp_file.flush
        temp_file.close
  
        # Set the file path for the worker
        file_path = temp_file.path
      end
    end
    product_params_without_file = product_params.dup

    product_params_without_file.delete(:upload_file)
    # product_params_with_user = product_params_without_file.merge(user_id: current_user.id)


    @product = current_user.products.friendly.find(params[:id])
    @product.update(product_params_without_file)
    @product.categories.destroy_all
    if params[:product][:category_ids].present?
      category_ids = params[:product][:category_ids][0].split(",").map(&:to_i)
      categories = Category.find(category_ids)
      @product.categories << categories
    end
    params[:user_id]=current_user.id
    params[:product_id] = @product.id
    params[:file_path] = file_path

    AddGitRepoWorkerJob.perform_async(params.to_json, "update")
    render json: { message: 'Your file was large so we are finishing updating it in the background. You will be notified when it is on the market.' }, status: :ok 
  
  rescue => e
    render json: { message: e.message }, status: :unprocessable_entity
    
  end

  def new
    @product = Product.unscoped.new
    @filtered_repos = import_table
  end

  def create


    boost_price = product_params[:boost_price].to_d
    unit_amount = (boost_price * 100).to_i
    
    line_items = [{
      price_data: {
        currency: 'usd',
        product_data: {
          name: 'Boost Price',
        },
        unit_amount: unit_amount,
      },
      quantity: 1,
    }]

    session = Stripe::Checkout::Session.create(
      payment_method_types: ['card'],
      line_items: line_items,
      mode: 'payment',
      automatic_tax: { enabled: true },
      success_url: marketplace_product_boost_success_payment_url(product_id:  current_user.id),
      cancel_url: marketplace_cancel_payment_url,
    )

    payment = Payment.create!(user: current_user, total_cents: 5000, stripe_session_id: session.id)
    binding.pry
    redirect_to session.url, allow_other_host: true


















    uploaded_file = product_params[:upload_file]
    file_path = ""
  
    if uploaded_file
      Tempfile.open(['uploaded_file', File.extname(uploaded_file.original_filename)], binmode: true) do |temp_file|
        temp_file.write(uploaded_file.read)
  
        temp_file.flush
        temp_file.close
  
        # Set the file path for the worker
        file_path = temp_file.path
      end
    end
    product_params_without_file = product_params.dup

    product_params_without_file.delete(:upload_file)
    product_params_with_user = product_params_without_file.merge(user_id: current_user.id)

    @product = Product.unscoped.new(product_params_with_user)
    if @product.save
      params[:user_id]=current_user.id
      params[:product_id] = @product.id
      params[:file_path] = file_path

      AddGitRepoWorkerJob.perform_async(params.to_json)
      render json: { message: 'Your file was large so we are finishing uploading it in the background. You will be notified when it is on the market.' }, status: :ok
    else
      render json: { message: 'Failed to create product. Repositry Aleady Exist.' }, status: :unprocessable_entity
    end    
    
  rescue => e
    render json: { message: e.message }, status: :unprocessable_entity
  end

  def destroy
    @product = current_user.products.friendly.find(params[:id])
    @product.destroy
    redirect_to products_path, notice: 'Product was successfully deleted.'
  end

  private

  def import_table
    private_repos = @user_repos.select { |repo| repo[:private] }
    product_urls = current_user.products.unscoped.pluck("url")
    repo_hash = private_repos.map do |repo|
    {
      id: repo[:id],
      name: repo[:name],
      url: repo[:html_url],
      avatar_url: repo[:owner][:avatar_url],
      description: repo[:description],
      created_at: repo[:created_at]
    }
    end
    @filtered_repos = repo_hash.reject do |repo|
      product_urls.include?(repo[:url])
    end
    @filtered_repos = Kaminari.paginate_array(@filtered_repos).page(params[:page]).per(5)
  end

  def product_params
    params.require(:product).permit(
      :name, :description, :price,:boost_price, :active, :published, :category_ids,:preview_video_url, :video_file,:upload_file, :features, :instructions, :requirements, :demo_url,
      covers: [],
      product_categories_attributes: [:id, :active],
      covers_attributes: [:id, :image]
    )
  end

  def extract_owner_and_repo_name(repo_url)
    parts = URI.parse(repo_url).path.split('/')
    [parts[1], parts[2]]
  end

  def octokit_client
    @octokit_client ||= Octokit::Client.new(access_token: current_user.token)
  end

  def repositories
    return @repositories if defined?(@repositories)

    Retriable.retriable(tries: 3, base_interval: 2.seconds) do
      all_repositories = octokit_client.repositories(
        nil, { per_page: repositories_count }
      )
      @repositories = all_repositories.select do |repository|
        repository.owner.login == github_login && repository.private?
      end
    end
  rescue => e
    Rails.logger.info(e.message)
    []
  end

  def github_login
    octokit_client.login
  end

  def update_state
    current_user.update(state: User.states[:seller])
  end

  def repositories_count
    octokit_client.user.public_repos + octokit_client.user.total_private_repos
  end

  def set_product
    @product = Product.friendly.find(params[:id])
  end

  def set_user_repos
    @user_repos ||= octokit_client.repositories(nil, per_page: repositories_count)
  end

  def download_repository_as_zip(owner, repo, ref, token)
    begin
      zip_link = "https://github.com/#{owner}/#{repo}/archive/refs/heads/#{ref}.zip"
      temp_file = Tempfile.new([repo, '.zip'])
      
      curl_command = "curl -L -H 'Authorization: token #{token}' -o #{temp_file.path} #{zip_link}"
      
      stdout, stderr, status = Open3.capture3(curl_command)
      
      if status.success?
        puts "Successfully downloaded #{temp_file.path}"
        
        @product.folder.attach(
          io: File.open(temp_file.path), 
          filename: "#{repo}-#{ref}.zip", 
          content_type: 'application/zip'
        )
        puts "Successfully attached #{repo}-#{ref}.zip to the product"
        
        temp_file.path
      else
        puts "Failed to download ZIP: #{stderr}"
        nil
      end
    rescue => e
      puts "Exception occurred: #{e.message}"
      nil
    ensure
      temp_file.close
      temp_file.unlink
    end
  end
  
end
