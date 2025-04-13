require 'zip'
require 'tempfile'
require 'aws-sdk-s3'
require 'open3'
require 'fileutils'

class ProductsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_product, only: [:like, :unlike, :code, :commits, :team, :configurations, :deployments, :issues, :branches, :pullrequests]
  before_action :update_state
  before_action :set_user_repos, if: -> { current_user.token.present? }
  before_action :set_gitlab_repos, if: -> { current_user.gitlab_token.present? }
  before_action :set_bitbucket_repos, if: -> { current_user.bitbucket_token.present? }
  include ProductConcern
  include AiResponseConcern

  def index
    @products = current_user.products.page(params[:page]).per(50)
  end

  def show
    @product = current_user.products.includes(:reviews, :languages).friendly.find(params[:id])
    @related_products = @product.related_products
    @reviews = @product.reviews.page(params[:page]).per(5)
    @languages = @product.languages.uniq
    @categories = @product.categories.uniq
    @directory_tree_json = fetch_product_directory_tree(@product)
    @user = User.friendly.find(params[:id])
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

  def export_data
    csv_data = CSV.generate(headers: true) do |csv|
      csv << Product.column_names
    
      Product.limit(50).find_each do |product|
        csv << product.attributes.values
      end
    end
    send_data csv_data, filename: "products_data.csv"
    respond_to do |format|
      format.csv
    end
  end

  def add_collaborator
    
    respond_to do |format|
      format.js
    end
  end

  def add_collaborator
    
    product = Product.find(params[:id])
    user = User.find(params[:user_id])
  
    if product.users.exists?(user.id)
      render json: { error: 'User already added' }, status: :unprocessable_entity
    else
      product.users << user
      render json: { success: true }
    end
  end

   # DELETE /products/:id/remove_collaborator
   def remove_collaborator
    product = Product.find(params[:id])
    user = User.find(params[:user_id])

    if product.users.exists?(user.id)
      # Find the join record and destroy it.
      product_user = product.product_users.find_by(user_id: user.id)
      if product_user&.destroy
        render json: { success: true }
      else
        render json: { error: 'Unable to remove collaborator' }, status: :unprocessable_entity
      end
    else
      render json: { error: 'Collaborator not found' }, status: :not_found
    end
  end

  def update

    uploaded_file = product_params[:upload_file]
    file_path = ""
  
    
    product_params_without_file = product_params.dup

    product_params_without_file.delete(:upload_file)
    # product_params_with_user = product_params_without_file.merge(user_id: current_user.id)


    @product = current_user.products.friendly.find(params[:id])
    featured =  product_params_without_file[:featured]
    product_params_without_file[:featured] = false
    @product.update(product_params_without_file)


      if uploaded_file

      Tempfile.open(['uploaded_file', File.extname(uploaded_file.original_filename)], binmode: true) do |temp_file|
        temp_file.write(uploaded_file.read)
        temp_file.flush
        temp_file.close
        @product.folder.attach(
          io: File.open(temp_file.path), 
          filename: "#{@product.name.gsub(' ', '_')}.zip",
          content_type: 'application/zip'
        )
      end
    end

    # @product.categories.destroy_all
    # if params[:product][:category_ids].present?
    #   category_ids = params[:product][:category_ids][0].split(",").map(&:to_i)
    #   categories = Category.find(category_ids)
    #   @product.categories << categories
    # end
    params[:user_id]=current_user.id
    params[:product_id] = @product.id
    params[:file_path] = file_path

    AddGitRepoWorkerJob.perform_async(params.to_json, "update")
    
    if featured == "1" && @product.featured_payment_intent.nil? 
      session = featured_stripe_session(@product)
      render json: { url: session.url, status: :ok} and return
    elsif featured == "1" && @product.featured_payment_intent.present?
      session_id = @product.featured_payment_intent.session_id
      session_object = Stripe::Checkout::Session.retrieve(session_id) rescue nil
      if session_object.present? && session_object["status"] == "complete"
        product_id = session_object["metadata"]["product_id"]
        product = Product.find(product_id)
        product.update(featured: true)
        product.featured_payment_intent.update(status: "paid", session_id: session_object.id)
      end       
    end
    render json: { message: 'Your file was large so we are finishing uploading it in the background. You will be notified when it is on the market.' }, status: :ok and return
  
  rescue => e
    render json: { message: e.message }, status: :unprocessable_entity
    
  end

  def new_product
    @templates = Template.first(4)
    @product = Product.unscoped.new
  end

  def code
  end

  def commits
    @product = Product.friendly.find(params[:id])
    @commits = @product.commits.includes(:user)
  end

  def team
  end

  def configurations
  end

  def deployments
  end

  def issues
  end

  def branches
  end

  def pullrequests
  end

  def teamrepositories
  end

  def create_from_gitlab
    repo_ids = params[:repo_ids]
    failed_repos = []
    skipped_repos = []
    successful_repos = []

    repo_ids&.each do |repo_id|
      ActiveRecord::Base.transaction do
        begin
          repo = gitlab_client.project(repo_id)
          owner_name = repo.namespace.full_path
          repo_name = repo.name
          if Product.exists?(url: repo.web_url)
            Rails.logger.info "Repository #{repo_name} already exists. Skipping..."
            skipped_repos << repo_name
            next
          end

          product = Product.new(
            name: repo.name,
            description: repo.description,
            url: repo.web_url,
            user_id: current_user.id,
            active: true,
            published: true
          )
          if product.save
            result = load_repo_and_link_tree(owner_name, repo_name, 'master', current_user.token, product, 'gitlab')
            if result
              successful_repos << repo_name
            else
              Rails.logger.error "Failed to process repository #{repo_name}, skipping..."
              failed_repos << repo_name
              product.destroy
            end
          else
            Rails.logger.error "Failed to save product for repo #{repo_name}, skipping..."
            failed_repos << repo_name
            raise ActiveRecord::Rollback
          end
        rescue => e
          Rails.logger.error "Error processing repo #{repo_id}: #{e.message}"
          failed_repos << repo_name
        end
      end
    end
  
    message = []
    message << "✅ Successfully added: #{successful_repos.join(', ')}" unless successful_repos.empty?
    message << "⚠️ Skipped existing repositories: #{skipped_repos.join(', ')}" unless skipped_repos.empty?
    message << "❌ Failed to process: #{failed_repos.join(', ')}" unless failed_repos.empty?
  
    redirect_to products_path, alert: message.join(' ')
  end

  def load_more_github_repos
    @github_page = params[:page]&.to_i || 2
    @total_repos_count = repositories_count
    @display_next_page_link = @total_repos_count < (Product::PER_PAGE_REPOS * @github_page)
    @repos = octokit_client.repositories(nil, per_page: Product::PER_PAGE_REPOS, page: @github_page)
    respond_to do |format|
      format.js
    end
  end

  def load_more_gitlab_repos
    @gitlab_page = params[:page]&.to_i || 2
    @gitlab_total_repos_count = gitlab_client.projects(membership: true).length
    @display_next_page_link_gitlab = @gitlab_total_repos_count <= (Product::PER_PAGE_REPOS * @gitlab_page)
    @repos = gitlab_client.projects(membership: true, per_page: Product::PER_PAGE_REPOS, page: @gitlab_page)
    respond_to do |format|
      format.js
    end
  end

  def import_products
    repo_ids = params[:repo_ids].first&.split(",")
    failed_repos = []
    skipped_repos = []
    successful_repos = []
    repo_ids&.each do |repo_id|
      ActiveRecord::Base.transaction do
        begin
          if params[:source] == 'github'
            repo = octokit_client.repository(repo_id.to_i)
            owner, repo_name = extract_owner_and_repo_name(repo[:html_url])
            repo_url = repo[:html_url]
            token = current_user.token
            source = 'github'
          elsif params[:source] == 'gitlab'
            repo = gitlab_client.project(repo_id)
            owner = repo.namespace.full_path
            repo_name = repo.name
            repo_url = repo.web_url
            token = current_user.gitlab_token
            source = 'gitlab'
          elsif params[:source] == 'bitbucket'
            workspace_name, repo_slug, repo_id = repo_id.split('|')
            repo = bitbucket_client.get("repositories/#{workspace_name}/#{repo_slug}")
            unless repo.success?
              puts "❌ Failed to fetch Bitbucket repository details: #{repo.status} - #{repo.body}"
              failed_repos << repo_slug
              next
            end
            repo_data = JSON.parse(repo.body)
            owner = repo_data["owner"]["username"] || repo_data["workspace"]["slug"]
            repo_name = repo_data["name"]
            repo_url = repo_data["links"]["html"]["href"]
            source = 'bitbucket'
            token = current_user.bitbucket_token
          end

          product = Product.new(
            name: params[:name] || repo[:name],
            description: params[:description] || repo[:description],
            url: repo_url,
            repo_id: repo_id,
            user_id: current_user.id,
            active: true,
            published: true,
            featured: params[:featured],
            price: params[:price].presence || 0,
            preview_video_url: params[:preview_video_url],
            video_file: params[:video_file],
            features: params[:features],
            instructions: params[:instructions],
            requirements: params[:requirements],
            category_ids: params[:category_ids],
            covers: params[:covers],
            language_ids: params[:language_ids]
          )
          featured = product.featured
          product.featured = false
          if product.save
            result = load_repo_and_link_tree(owner, repo_name, 'master', token, product, source)
            if result
              if featured
                session = featured_stripe_session(product)
              end
              successful_repos << repo_name
            else
              Rails.logger.error "Failed to process repository #{repo_name}, skipping..."
              failed_repos << repo_name
              product.destroy
            end
          else
            Rails.logger.error "Failed to save product for repo #{repo_name}, skipping..."
            failed_repos << repo_name
            raise ActiveRecord::Rollback
          end
        rescue Exception => e
          Rails.logger.error "Error processing repo #{repo_id}: #{e.message}"
          product.destroy if product.persisted?
          failed_repos << repo_name
        end
      end
    end

    message = []
    message << "✅ Successfully added: #{successful_repos.join(', ')}" unless successful_repos.empty?
    message << "⚠️ Skipped existing repositories: #{skipped_repos.join(', ')}" unless skipped_repos.empty?
    message << "❌ Failed to process: #{failed_repos.join(', ')}" unless failed_repos.empty?
  
    redirect_to products_path, alert: message.join(' ')
  end

  def create_from_github
    repo_ids = params[:repo_ids]
    failed_repos = []
    skipped_repos = []
    successful_repos = []
  
    repo_ids&.each do |repo_id|
      ActiveRecord::Base.transaction do
        begin
          repo = octokit_client.repository(repo_id.to_i)
          owner, repo_name = extract_owner_and_repo_name(repo[:html_url])
  
          if Product.exists?(url: repo[:html_url])
            Rails.logger.info "Repository #{repo_name} already exists. Skipping..."
            skipped_repos << repo_name
            next
          end
  
          product = Product.new(
            name: repo[:name],
            description: repo[:description],
            url: repo[:html_url],
            user_id: current_user.id,
            active: true,
            published: true
          )
  
          if product.save
            result = load_repo_and_link_tree(owner, repo_name, 'master', current_user.token, product)
            if result
              successful_repos << repo_name
            else
              Rails.logger.error "Failed to process repository #{repo_name}, skipping..."
              failed_repos << repo_name
              product.destroy
            end
          else
            Rails.logger.error "Failed to save product for repo #{repo_name}, skipping..."
            failed_repos << repo_name
            raise ActiveRecord::Rollback
          end
        rescue => e
          Rails.logger.error "Error processing repo #{repo_id}: #{e.message}"
          failed_repos << repo_name
        end
      end
    end
  
    message = []
    message << "✅ Successfully added: #{successful_repos.join(', ')}" unless successful_repos.empty?
    message << "⚠️ Skipped existing repositories: #{skipped_repos.join(', ')}" unless skipped_repos.empty?
    message << "❌ Failed to process: #{failed_repos.join(', ')}" unless failed_repos.empty?
  
    redirect_to products_path, alert: message.join(' ')
  end

  def show_file_content
    @product = Product.friendly.find(params[:id])
    file_name = params[:file_name]
    file_extension = file_name.split('.').last
    @file_content = extract_file_content(@product, file_name)
    if %w[jpg jpeg png gif].include?(file_extension)
      send_data @file_content, type: "image/#{file_extension}", disposition: "inline", filename: "#{file_name}"
    else
      render "show_file_content", locals: { file_content: @file_content || 'File not found' }
    end
  end

  def replace_file
    @product = Product.friendly.find(params[:id])
    @file_name = params[:file_name]
    @new_content = params[:file_content]
    old_content = params[:old_content]
    commit_message = params[:commit_message]
    begin
      replace_file_content(@product, @file_name, @new_content)
      Commit.create!(
        product: @product,
        user: current_user,
        file_path: @file_name,
        old_content: old_content,
        new_content: @new_content,
        commit_message: commit_message
      )
      render json: { success: true, message: 'File content replaced successfully' }
    rescue => e
      render json: { success: false, error: e.message }, status: :unprocessable_entity
    end
  end
  
  def update_file_content
    product = Product.friendly.find(params[:id])
    file_name = params[:file_name]
    new_content = params[:content]

    if file_name.present? && new_content.present?
      replace_file_content(product, file_name, new_content)
      redirect_to marketplace_library_path(product), notice: 'File content updated successfully.'
    else
      redirect_to marketplace_library_path(product), notice: "Something went wrong in updating file content." 
    end
  end

  def new
    if params[:template_id].present?
      template = Template.find(params[:template_id])
      @product = Product.unscoped.new(template_id: params[:template_id], name: template.name, description: template.description, demo_url: template.default_url)
      if template.folder.attached?
        @product.folder.attach(template.folder.blob)
      end
    else
      @product = Product.unscoped.new
    end
    
    @filtered_repos = import_table
  end

  def create
    # boost_price = product_params[:boost_price].to_d
    # unit_amount = (boost_price * 100).to_i
    
    # line_items = [{
    #   price_data: {
    #     currency: 'usd',
    #     product_data: {
    #       name: 'Boost Price',
    #     },
    #     unit_amount: unit_amount,
    #   },
    #   quantity: 1,
    # }]

    # session = Stripe::Checkout::Session.create(
    #   payment_method_types: ['card'],
    #   line_items: line_items,
    #   mode: 'payment',
    #   automatic_tax: { enabled: true },
    #   success_url: marketplace_product_boost_success_payment_url(product_id:  current_user.id),
    #   cancel_url: marketplace_cancel_payment_url,
    # )

    # payment = Payment.create!(user: current_user, total_cents: 5000, stripe_session_id: session.id)
    # redirect_to session.url, allow_other_host: true

    uploaded_file = product_params[:upload_file]
    file_path = ""
  
    product_params_without_file = product_params.dup

    product_params_without_file.delete(:upload_file)
    product_params_with_user = product_params_without_file.merge(user_id: current_user.id)

    @product = Product.unscoped.new(product_params_with_user)
    featured = @product.featured
    @product.featured = false
    @template = @product.template
    if @template.present? && @template.folder.attached?
      @product.folder.attach(@template.folder.blob)
    end
    if @product.save
      if @template.present?
        @template.update(cloned_count: @product.template.cloned_count + 1)
        uploaded_file = @template.folder.blob
        filename = uploaded_file.filename.to_s if uploaded_file
      else
        uploaded_file = product_params[:upload_file]
        filename = uploaded_file.original_filename if uploaded_file
      end
      if uploaded_file

      Tempfile.open(['uploaded_file', File.extname(filename)], binmode: true) do |temp_file|
        if @template.present?
          temp_file.write(uploaded_file.download)
        else
          temp_file.write(uploaded_file.read)
        end
        temp_file.flush
        temp_file.close
        directory_tree_str = zip_structure_for_js_tree(temp_file.path).to_s
        @product.update_attribute(:directory_tree, directory_tree_str)
        @product.folder.attach(
          io: File.open(temp_file.path), 
          filename: "#{@product.name.gsub(' ', '_')}.zip",
          content_type: 'application/zip'
        )
      end
    end

      params[:user_id]=current_user.id
      params[:product_id] = @product.id
      params[:file_path] = file_path

      AddGitRepoWorkerJob.perform_async(params.to_json)
    
      if featured
        session = featured_stripe_session(@product)
        render json: { url: session.url, status: :ok}
      else
        render json: { message: 'Your file was large so we are finishing uploading it in the background. You will be notified when it is on the market.' }, status: :ok
      end 

    else
      if @product.errors.details[:base].any? { |error| error[:code] == 402 }
        render json: { message: 'Limit exceeded. Please upgrade your plan.'}, status: :unprocessable_entity
      else
        render json: { message: 'Failed to create product. Repository Aleady Exist.' }, status: :unprocessable_entity
      end
    end
    
  rescue => e
    render json: { message: e.message }, status: :unprocessable_entity
  end

  def destroy
    @product = current_user.products.friendly.find(params[:id])
    @product.template.update(cloned_count: @product.template.cloned_count - 1) if @product.template.present?
    @product.destroy
    redirect_to products_path, notice: 'Product was successfully deleted.'
  end

  def search_repositories
    if params[:query].present?
      search_query = "#{params[:query]}"
      @user_repos = octokit_client.search_repositories(search_query, {per_page: repositories_count, type: 'private'})[:items]
    else
      @user_repos ||= octokit_client.repositories(nil, type: 'private', per_page: repositories_count)
    end
    import_table
    respond_to do |format|
      format.js
    end
  end 
  
  def search 
    query = params[:q]
    if query.present?
      
      @products = current_user.products.where('name ILIKE ?', "%#{query}%").page(params[:page]).per(50)  
    else
      @products = current_user.products.page(params[:page]).per(50)
    end
    
    respond_to do |format|
      if @products.empty?
        format.html { render plain: "No Data Found", status: :not_found }
      else
      format.html { render partial: 'products/product', collection: @products, as: :product }
      end
    end
  end

  def build_product_from_ai
    begin
      user_input = params[:prompt]
      @response = send_request(user_input)
      @response = @response.with_indifferent_access if @response.present? && @response.is_a?(Hash)
      @product = create_zip_file_structure(@response) if @response.present? && @response[:create_product]
    rescue Exception => e
      @response = { error: e.message, backtrace: e.backtrace }.with_indifferent_access
    end
    respond_to do |format|
      format.js
    end
  end

  def build_product_file_from_ai
    begin
      user_input = params[:prompt]
      @old_content = params[:file_content]
      @file_name = params[:file_name]
      @response = send_request_data(user_input, @old_content)
      puts "@response = #{@response}"
      @response = @response.with_indifferent_access if @response.present? && @response.is_a?(Hash)
      @product = Product.friendly.find(params[:product_id]) 
    rescue Exception => e
      @response = { error: e.message, backtrace: e.backtrace }.with_indifferent_access
    end
    respond_to do |format|
      format.js
    end
  end

  private

  def import_table
    return unless current_user.token.present?

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
      :name, :featured, :description, :price, :boost_price, :active, :published, :preview_video_url, 
      :video_file, :upload_file, :features, :instructions, :requirements, :demo_url, :url, :template_id,
      :category_ids, :language_ids,
      category_ids: [],            
      language_ids: [],            
      covers: [],
      product_categories_attributes: [:id, :active],
      covers_attributes: [:id, :image]
    )
  end

  def extract_owner_and_repo_name(repo_url)
    parts = URI.parse(repo_url).path.split('/')
    [parts[1], parts[2]]
  end

  def gitlab_client
    @gitlab_client ||= Gitlab.client(endpoint: 'https://gitlab.com/api/v4', private_token: current_user.gitlab_token)
  end

  def octokit_client
    @octokit_client ||= Octokit::Client.new(access_token: current_user.token)
  end

  def bitbucket_client
    @bitbucket_client ||= Faraday.new(
      url: 'https://api.bitbucket.org/2.0',
      headers: {
        'Authorization' => "Bearer #{current_user.bitbucket_token}",
        'Content-Type' => 'application/json'
      }
    )
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
    octokit_client.user.public_repos + octokit_client.user.total_private_repos.to_i
  end

  def set_product
    @product = Product.friendly.find(params[:id])
  end

  def set_user_repos
    @github_page = params[:page]&.to_i || 1
    @total_repos_count = repositories_count
    @display_next_page_link = @total_repos_count > (Product::PER_PAGE_REPOS * @github_page)
    @user_repos ||= octokit_client.repositories(nil, per_page: Product::PER_PAGE_REPOS, page: @github_page)
  end

  def set_gitlab_repos
    begin
      @gitlab_page = params[:page]&.to_i || 1
      @gitlab_total_repos_count = gitlab_client.projects(membership: true).size
      @display_next_page_link_gitlab = @gitlab_total_repos_count > (Product::PER_PAGE_REPOS * @gitlab_page)
      @gitlab_repos = gitlab_client.projects(membership: true, per_page: Product::PER_PAGE_REPOS, page: @gitlab_page)
    rescue Gitlab::Error::Unauthorized
      current_user.update(gitlab_token: nil)
      redirect_to new_product_products_path, alert: 'Your GitLab token has expired. Please re-authorize.'
    end
  end

  def set_bitbucket_repos
    begin
      @bitbucket_page = params[:page]&.to_i || 1
      workspace_response = bitbucket_client.get('workspaces')
      if workspace_response.status == 401
        raise StandardError, "Bitbucket token expired"
      end  
      unless workspace_response.success?
        puts "❌ Failed to fetch workspaces: #{workspace_response.status} - #{workspace_response.body}"
        return
      end
      workspaces = JSON.parse(workspace_response.body)
      @bitbucket_repos = []
      workspaces["values"].each do |workspace|
        workspace_slug = workspace["slug"]
        repos_response = @bitbucket_client.get("repositories/#{workspace_slug}")  
        if repos_response.status == 401
          raise StandardError, "Bitbucket token expired"
        end
        unless repos_response.success?
          puts "❌ Failed to fetch repositories for workspace '#{workspace_slug}': #{repos_response.status} - #{repos_response.body}"
          next
        end
        repos = JSON.parse(repos_response.body)
        if repos["values"]
          repos["values"].each do |repo|
            repo["uuid"] = repo["uuid"].gsub(/[{}]/, '') # Remove curly braces from UUID
            repo["id"] = repo.dig('workspace', 'slug')
          end
          @bitbucket_repos.concat(repos["values"])
        end
      end
      @bitbucket_total_repos_count = @bitbucket_repos.size
      @display_next_page_link_bitbucket = @bitbucket_total_repos_count > (Product::PER_PAGE_REPOS * @bitbucket_page)
    rescue StandardError => e
      if e.message == "Bitbucket token expired"
        current_user.update(bitbucket_token: nil)
        redirect_to new_product_products_path, alert: 'Your Bitbucket token has expired. Please re-authorize.' and return
      else
        puts "❌ Unexpected error: #{e.message}"
      end
    end
  end

  def download_gitlab_repo(project_id, token)
    zip_link = "https://gitlab.com/api/v4/projects/#{project_id}/repository/archive.zip"
    system("curl -H 'Private-Token: #{token}' -o repo.zip #{zip_link}")
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

  def featured_stripe_session(product)
    line_items = [{
      price_data: {
        currency: 'usd',
        product_data: {
          name: 'Featured',
        },
        unit_amount: 1000,
      },
      quantity: 1,
    }]

      session = Stripe::Checkout::Session.create(
        payment_method_types: ['card'],
        line_items: line_items,
        metadata: { product_id: product.id},
        mode: 'payment',
        automatic_tax: { enabled: true },
        success_url: marketplace_library_url(product) + "?session_id={CHECKOUT_SESSION_ID}",
        cancel_url: marketplace_cancel_payment_url,
      )
      
      payment_intent = Stripe::PaymentIntent.retrieve(session.payment_intent)

      product.create_featured_payment_intent(intent_id: payment_intent.id, intent_object: payment_intent)

      session 
  end
  
end
