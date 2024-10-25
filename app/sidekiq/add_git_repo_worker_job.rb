class AddGitRepoWorkerJob
  include Sidekiq::Job
  sidekiq_options :retry => 5, :dead => false

  def perform(params, action=nil)
    params = JSON.parse(params).deep_symbolize_keys
    @product = Product.unscoped.find(params[:product_id])
    @product_url = "#{ENV["BASE_URL"]}/marketplace/l/#{@product&.slug}"
    @current_user = User.find(params[:user_id])
    @file_path = params[:file_path] || ""

    @octokit_client ||= Octokit::Client.new(access_token: @current_user.token)
    if action=="update"
      update params
    else
      create params
    end
  rescue => e
    puts "Error:- #{e}"
  end
  private
  def create params
    repositories_count = @octokit_client.user.public_repos + @octokit_client.user.total_private_repos
    if params[:product][:product_url].present?
      repo_url = params[:product][:product_url]
      owner, repo_name = extract_owner_and_repo_name(repo_url)
      user_repos = @octokit_client.repositories(nil, per_page: repositories_count)
      matching_repo = user_repos.find { |repo| repo.owner.login == owner && repo.name == repo_name }
      
      if matching_repo
        @product.url = matching_repo.html_url
        @product.repo_id = matching_repo.id
        @archive_path = DownloadRepoAsZip.new.start(owner, repo_name, 'main', @current_user.token, @product)
      else
       
        # UserMailer.repo_added(@product, @product.user, "created", @product_url, "Failed to create product. Repository not found or does not belong to you. Github:- #{ params[:product][:product_url] }").deliver_now
        puts 'Failed to create product. Repository not found or does not belong to you.'
        return
      end

    else
      # if @file_path.present?

      #   @product.folder.attach(
      #         io: File.open(@file_path), 
      #         filename: "#{@product.name.gsub(' ', '_')}.zip", 
      #         content_type: 'application/zip'
      #     )
      # end
    end
    
    if params[:product][:category_ids].present?
      # category_ids = params[:product][:category_ids][0].split(",").map(&:to_i)
      category_ids, category_names = differentiate_id_name(params[:product][:category_ids][0])

      if category_ids.present?
        categories = Category.where(id: category_ids)
        @product.categories << categories
      end 
      if category_names.present? 
        @product.more_categories_from_createor = category_names
      end 
    end

    if params[:product][:language_ids].present?
      # language_ids = params[:product][:language_ids][0].split(",").map(&:to_i)

      language_ids, language_names = differentiate_id_name(params[:product][:language_ids][0])

      if language_ids.present?
        languages = Language.where(id: language_ids)
        @product.languages << languages
      end 
      if language_names.present? 
        @product.more_languages_from_createor = language_names
      end 
    else
      selected_language = Language.find_or_create_by(name: 'not_specified', image_name: 'html.png')
      @product.languages << selected_language
    end
    @product.published = true
    @product.active = true
    begin      
      @product.upload_complete = true
      if @product.save
        notification_params = {
          recipient: @product.user,
          params: {
            message: "Your product '#{@product.name}' has been uploaded.",
            # reason: "Product deletion by admin"
          }
        }

        # UserMailer.repo_added(@product, @product.user, "created", @product_url).deliver_now
      else
        notification_params = {
          recipient: @product.user,
          params: {
            message: "Your product '#{@product.name}' uploading has been failed.",
            # reason: "Product deletion by admin"
          }
        }
        # UserMailer.repo_added(@product, @product.user, "created", @product_url, "Failed to create product for github:- #{params[:product][:product_url]}").deliver_now
        @product.destroy
      end
      notification = Notification.create!(notification_params)

    rescue ActiveRecord::RecordNotUnique => e
      @product.destroy
      puts 'Failed to create product. Repositry Aleady Exist.'
    end
  end

  def update params
    repositories_count = @octokit_client.user.public_repos + @octokit_client.user.total_private_repos
    
    if params[:product][:product_url].present?
      repo_url = params[:product][:product_url]
      owner, repo_name = extract_owner_and_repo_name(repo_url)
      user_repos = @octokit_client.repositories(nil, per_page: repositories_count)
      @archive_path = DownloadRepoAsZip.new.start(owner, repo_name, 'main', @current_user.token, @product)
      
    else

      # if @file_path.present?
      #   @product.folder.attach(
      #         io: File.open(@file_path), 
      #         filename: "#{@product.name.gsub(' ', '_')}.zip", 
      #         content_type: 'application/zip'
      #     )
      # end

    end

    
    @product.published = true
    @product.active = true

    @product.categories.destroy_all
    
    if params[:product][:category_ids].present?
      # category_ids = params[:product][:category_ids][0].split(",").map(&:to_i)
      category_ids, category_names = differentiate_id_name(params[:product][:category_ids][0])
      
      if category_ids.present?
        categories = Category.where(id: category_ids)
        @product.categories << categories
      end 
      if category_names.present? 
        @product.more_categories_from_createor = category_names
      else 
        @product.more_categories_from_createor = []
      end 
    else 
      @product.more_categories_from_createor = []
    end

    @product.languages.destroy_all
    if params[:product][:language_ids].present?
      # language_ids = params[:product][:language_ids][0].split(",").map(&:to_i)
      language_ids, language_names = differentiate_id_name(params[:product][:language_ids][0])

      if language_ids.present?
        languages = Language.where(id: language_ids)
        @product.languages << languages
      end 
      if language_names.present? 
        @product.more_languages_from_createor = language_names
      else  
        @product.more_languages_from_createor = []
      end 
    else
      selected_language = Language.find_or_create_by(name: 'not_specified', image_name: 'html.png')
      @product.languages << selected_language
      @product.more_languages_from_createor = []
    end
    
    if @product.save
      notification_params = {
        recipient: @product.user,
        params: {
          message: "Your product '#{@product.name}' has been updated.",
          # reason: "Product deletion by admin"
        }
      }

      # UserMailer.repo_added(@product, @product.user, "updated", @product_url).deliver_now
      
      # Notify All Product Buyers 
      @product.purchases.includes(:user).each do |purchase|
        notification_user = {
        recipient: purchase.user,
        params: {
          message: "Product Owner '#{@product.user.username}' has updated the '#{@product.name}'.",
          # reason: "Product deletion by admin"
        }
      }
      Notification.create!(notification_user)
      end
      
    else
      notification_params = {
          recipient: @product.user,
          params: {
            message: "Your product '#{@product.name}' is not updated.",
          }
      }
    end
    notification = Notification.create!(notification_params)
  end

  def extract_owner_and_repo_name(repo_url)
    parts = URI.parse(repo_url).path.split('/')
    [parts[1], parts[2].sub(/\.git$/, "")]
  end

  def differentiate_id_name(inputs)
    elements = inputs.split(',')
    ids = elements.select { |e| e =~ /^\d+$/ }
    names = elements.reject { |e| e =~ /^\d+$/ }

    return ids, names 
  end 
end