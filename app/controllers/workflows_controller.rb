require 'octokit'
require 'open-uri'
require 'zip'
require 'git'

class WorkflowsController < ApplicationController
  before_action :authenticate_user!
  include ProductConcern

  def index
    if request.format.turbo_stream? && request.format.symbol == :turbo_stream
      @github_list_open = false
      @saved_projects_open = false
      if github_list_params && github_list_params[:github_page]
        @github_list_open = true
        begin
          if github_list_params[:data]
            @repo_branch_array = eval(github_list_params[:data])
          else
            retreive_github_repo_info  
          end
        rescue 
          retreive_github_repo_info
        end
        @paginated_repositories = Kaminari.paginate_array(@repo_branch_array).page(github_list_params[:github_page]).per(10)
      end
      if saved_projects_params && saved_projects_params[:project_page]
        @saved_projects_open = true
        begin 
          if saved_projects_params[:data]
            @saved_projects = eval(saved_projects_params[:data])
          else 
            @saved_projects = current_user.projects.flat_map { |project| project.filename.to_s.sub(".zip", "") }
          end            
        rescue 
          @saved_projects = current_user.projects.flat_map { |project| project.filename.to_s.sub(".zip", "") }
        end
        @paginated_saved_projects = Kaminari.paginate_array(@saved_projects).page(saved_projects_params[:project_page]).per(5)
      end
      respond_to do |format|
        format.turbo_stream
      end
      return
    end
    retreive_github_repo_info
    @paginated_repositories = Kaminari.paginate_array(@repo_branch_array).page(1).per(10)
    folder_path = Rails.root.join('workflows', current_user.friendly_id)
    if !(Dir.exist?(folder_path))
      FileUtils.mkdir_p(folder_path)
    end
    @directory_tree_json = "{}"
    @saved_projects = current_user.projects.flat_map { |project| project.filename.to_s.sub(".zip", "") }
    @paginated_saved_projects = Kaminari.paginate_array(@saved_projects).page(1).per(5)
    open_projects = Dir.glob("#{folder_path}/*").select { |f| File.directory?(f) }.map { |f| File.basename(f) }
    if open_projects.size == 0
      @open_project = nil  
    elsif open_projects.size == 1
      @open_projects = check_for_unnecessary_folders(folder_path, @saved_projects, open_projects)  
      @open_project = @open_projects.first
    else
      @open_projects = check_for_unnecessary_folders(folder_path, @saved_projects, open_projects)
      @open_project = @open_projects.first
    end
    if folder_name_params && folder_name_params[:folder_name]
      path = File.join(folder_path,folder_name_params[:folder_name])
      if !(Dir.exist?(path))
        redirect_to workflows_path(current_user)
        return
      end
      @directory_tree_json = [folder_structure_for_js_tree(path)].to_json.html_safe
      @folder_name = folder_name_params[:folder_name]
    end
  end

  def open_file
    if request.format.html?
      head :ok
      return
    end
    path = Rails.root.join("workflows", current_user.friendly_id, params[:file_path])
    if File.exist?(path)
      if File.file?(path)
        file_data = File.read(path)
        file_ext = File.extname(path).downcase
      else
        file_data = nil
        file_ext = nil
      end
      respond_to do |format|
        format.json { render json: { file_data: file_data, file_ext: file_ext }, status: :ok }
      end
    else
      respond_to do |format|
        format.json { render json: { error: "File / Folder not found." }, status: :not_found }
      end
    end
  end

  def save_file
    if request.format.html?
      head :ok
      return
    end
    path = Rails.root.join("workflows", current_user.friendly_id, params[:file_path])
    updated_file_data = params[:updated_file_data]
    if File.file?(path)
      File.open(path, 'w') do |file|
        file.puts updated_file_data
      end     
      respond_to do |format|
        format.json { render json: { message: "File Saved Successfully" }, status: :ok }
      end 
    else
      respond_to do |format|
        format.json { render json: { error: "File not found." }, status: :not_found }
      end
    end
  end
  
  def upload_zip
    uploaded_file = params[:upload_file]
    if uploaded_file
      folder_name = File.basename(uploaded_file.original_filename, File.extname(uploaded_file.original_filename))
      workflow_folder = Rails.root.join('workflows', "#{current_user.friendly_id}").to_s
      Tempfile.open(["#{current_user.friendly_id}", File.extname(uploaded_file.original_filename)], binmode: true) do |temp_file|
        temp_file.write(uploaded_file.read)
        temp_file.flush
        temp_file.close
        begin
          extract_zip(temp_file.path, workflow_folder)
          new_project_name = "#{folder_name}.zip"
          delete_project_from_s3(new_project_name)
          current_user.projects.attach(
            io: File.open(temp_file.path),
            filename: new_project_name,
            content_type: 'application/zip'
          )
          redirect_to workflows_path(current_user, folder_name: folder_name), notice: "Zip Uploaded successfully."
          return
        rescue
          redirect_to workflows_path(current_user), alert: "File upload failed. Please try again!"
        ensure
          File.delete(temp_file.path) if File.exist?(temp_file.path)
        end
      end
    end
  end

  def git
    if folder_name_params && folder_name_params[:folder_name]
      folder_path = Rails.root.join('workflows', "#{current_user.friendly_id}", folder_name_params[:folder_name])
      if File.exist?(folder_path) && File.directory?(folder_path)
        begin 
          git = Git.open(folder_path)
          git_repo_name = File.basename(git.dir.path)
          @repo_name = folder_name_params[:folder_name].to_s
          if git_repo_name == @repo_name
            respond_to do |format|
              format.turbo_stream
            end
            return
          else
            flash[:alert] = 'Repository not initialized for this project.'
          end
        rescue => e
          puts "Error : #{e.message}"
          flash[:alert] = 'Project not found. Please try again.'
        end
      else 
        flash[:alert] = 'Project not found. Please try again.'
      end
    else 
      flash[:alert] = 'Repository not found. Please try again.'
    end
    flash_content = render_to_string(partial: '/shared/flash_messages')
    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.replace('flash_wrapper', "<div id='flash_wrapper'>#{flash_content}</div>")
      end
    end
  end

  def git_pull
    if folder_name_params && folder_name_params[:folder_name]
      folder_path = Rails.root.join('workflows', "#{current_user.friendly_id}", folder_name_params[:folder_name])
      if File.exist?(folder_path) && File.directory?(folder_path)
        begin
          octokit_client = Octokit::Client.new(access_token: current_user.token)
          username = octokit_client.user.login
          @repo_name = folder_name_params[:folder_name].to_s
          repository = octokit_client.repository("#{username}/#{@repo_name}")
          branch = repository.default_branch
          git = Git.open(folder_path)
          git_repo_name = File.basename(git.dir.path)
          if git_repo_name == @repo_name
            git.pull('origin',"#{branch}")
            status = git.status
            deleted = status.deleted.keys
            changed = status.changed.keys
            untracked = status.untracked.keys
            @changes = {'Deleted:'=>deleted, 'Modified:'=>changed, 'Untracked:'=>untracked }
            flash[:notice] = 'Local branch updated successfully!'
            flash_content = render_to_string(partial: '/shared/flash_messages')
            respond_to do |format|
              format.turbo_stream do
                render turbo_stream: [
                  turbo_stream.replace('flash_wrapper', "<div id='flash_wrapper'>#{flash_content}</div>"),
                  turbo_stream.replace('git-pull', "<div id='git-pull'></div>"),
                  turbo_stream.replace('git-diff', partial: 'workflows/git_diff')
                ]
              end
            end
            return
          else
            flash[:alert] = 'Repository not initialized for this project.'
          end
        rescue Git::FailedError => e
          puts "Error : #{e.message}"
          stderr_content = e.message.match(/stderr: "(.*)"/m)[1]
          @filenames = stderr_content.scan(/\\t(.*?)\\n/).flatten
          @message = "Changes of the following files will be removed to update the local branch : "
          flash[:alert] = 'Remove un-commited changes.'
          flash.delete(:notice)
          flash_content = render_to_string(partial: '/shared/flash_messages')
          respond_to do |format|
            format.turbo_stream do
              render turbo_stream: [
                turbo_stream.replace('flash_wrapper', "<div id='flash_wrapper'>#{flash_content}</div>"),
                turbo_stream.replace('git-pull', "<div id='git-pull'></div>"),
                turbo_stream.replace('git-checkout', partial: '/workflows/git_checkout')
              ]
            end
          end
          return
        end
      else 
        flash[:alert] = 'Project not found. Please try again.'
      end
    else 
      flash[:alert] = 'Repository not found. Please try again.'
    end
    flash_content = render_to_string(partial: '/shared/flash_messages')
    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: [
          turbo_stream.replace('flash_wrapper', "<div id='flash_wrapper'>#{flash_content}</div>"),
          turbo_stream.replace('github-modal', "<div id='github-modal'></div>"),
        ]
      end
    end
  end

  def git_checkout
    if git_file_params && git_file_params[:repo_name]
      repo_name = git_file_params[:repo_name].to_s
      files = git_file_params[:files]
      folder_path = Rails.root.join('workflows',"#{current_user.friendly_id}","#{git_file_params[:repo_name].to_s}")
      if File.exist?(folder_path) && File.directory?(folder_path)
        begin 
          octokit_client = Octokit::Client.new(access_token: current_user.token)
          username = octokit_client.user.login
          @repo_name = git_file_params[:repo_name].to_s
          repository = octokit_client.repository("#{username}/#{@repo_name}")
          branch = repository.default_branch
          git = Git.open(folder_path)
          files.each do |file, check|
            git.checkout_file('HEAD', file)
          end
          git.pull('origin',"#{branch}")
          status = git.status
          deleted = status.deleted.keys
          changed = status.changed.keys
          untracked = status.untracked.keys
          @changes = {'Deleted:'=>deleted, 'Modified:'=>changed, 'Untracked:'=>untracked }
          flash[:notice] = 'Un-commited changes removed successfully.'
          flash_content = render_to_string(partial: '/shared/flash_messages')
          respond_to do |format|
            format.turbo_stream do
              render turbo_stream: [
                turbo_stream.replace('flash_wrapper', "<div id='flash_wrapper'>#{flash_content}</div> "),
                turbo_stream.replace('git-checkout', "<div id='git-checkout'></div>"),
                turbo_stream.replace('git-diff', partial: 'workflows/git_diff')
              ]
            end
          end
          return
        rescue => e
          puts "Error : #{e.message}"
          flash[:alert] = 'Not able to push the changes, please try again.'
        end
      else
        flash[:alert] = 'Project does not exist. Please try again.'
      end
    else 
      flash[:alert] = 'Project does not exist. Please try again.'
    end
    return
    flash_content = render_to_string(partial: '/shared/flash_messages')
    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: [
          turbo_stream.replace('flash_wrapper', "<div id='flash_wrapper'>#{flash_content}</div> "),
          turbo_stream.replace('github-modal', "<div id='github-modal'></div>")
        ]
      end
    end
  end

  def git_push
    if git_file_params && git_file_params[:repo_name]
      repo_name = git_file_params[:repo_name].to_s
      files = git_file_params[:files]
      folder_path = Rails.root.join('workflows',"#{current_user.friendly_id}","#{git_file_params[:repo_name].to_s}")
      if File.exist?(folder_path) && File.directory?(folder_path)
        begin 
          octokit_client = Octokit::Client.new(access_token: current_user.token)
          username = octokit_client.user.login
          name = octokit_client&.user&.name
          email = octokit_client&.user&.email
          @repo_name = git_file_params[:repo_name].to_s
          repository = octokit_client.repository("#{username}/#{@repo_name}")
          branch = repository.default_branch
          git = Git.open(folder_path)
          status = git.status
          remote_url = "https://#{current_user.token}@github.com/#{username}/#{@repo_name}.git"
          if git.remotes.any? { |r| r.name == 'origin' }
            git.remote('origin').remove
          end
          git.add_remote('origin', remote_url)
          git.config('user.name', "#{name}")
          git.config('user.email', "#{email}")
          files.each do |file, check|
            if check == "1"
              git.add(file)
            end
          end
          git.commit(git_file_params[:commit_message].to_s)
          git.push('origin',"#{branch}")
          temp_zip_name = "#{current_user.friendly_id}-#{git_file_params[:repo_name]}.zip"
          temp_zip_path = download_temp_zip(temp_zip_name, zip_url = nil, folder_path)
          new_project_name = "#{git_file_params[:repo_name]}.zip"
          delete_project_from_s3(new_project_name)
          current_user.projects.attach(
            io: File.open(temp_zip_path),
            filename: new_project_name,
            content_type: 'application/zip'
          )
          flash[:notice] = 'Changes commited and pushed successfully.'
        rescue => e
          puts "Error : #{e.message}"
          flash[:alert] = 'Not able to push the changes, please try again.'
        end
      else
        flash[:alert] = 'Project does not exist. Please try again.'
      end
    else 
      flash[:alert] = 'Project does not exist. Please try again.'
    end
    flash_content = render_to_string(partial: '/shared/flash_messages')
    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: [
          turbo_stream.replace('flash_wrapper', "<div id='flash_wrapper'>#{flash_content}</div> "),
          turbo_stream.replace('github-modal', "<div id='github-modal'></div>")
        ]
      end
    end
  end

  def download_zip
    if folder_name_params && folder_name_params[:folder_name]
      folder_path = Rails.root.join("workflows", current_user.friendly_id, folder_name_params[:folder_name].to_s)
      begin
        temp_zip_name = "#{current_user.friendly_id}-#{folder_name_params[:folder_name]}.zip"
        temp_zip_path = download_temp_zip(temp_zip_name, zip_url = nil, folder_path)
        new_project_name = "#{folder_name_params[:folder_name]}.zip"
        delete_project_from_s3(new_project_name)
        current_user.projects.attach(
          io: File.open(temp_zip_path),
          filename: new_project_name,
          content_type: 'application/zip'
        )
        send_file temp_zip_path, type: 'application/zip', disposition: 'attachment'
        return
      end
    else
      render plain: "Project not found. Please try again.", status: :not_found
    end
  end

  def download_repo
    workflow_folder = Rails.root.join('workflows', "#{current_user.friendly_id}")
    if repo_params && repo_params[:username] && repo_params[:repo_name] && repo_params[:branch_name]
      repo_url = "https://#{current_user.token}@github.com/#{repo_params[:username]}/#{repo_params[:repo_name]}.git"
      folder_path = workflow_folder.join("#{repo_params[:repo_name]}")
      if File.exist?(folder_path) && File.directory?(folder_path)
        FileUtils.remove_dir(folder_path, true)
      end
      begin
        Git.clone(repo_url, folder_path, branch: repo_params[:branch_name])
        new_project_name = "#{repo_params[:repo_name]}.zip"
        delete_project_from_s3(new_project_name)
        temp_zip_name = "#{repo_params[:repo_name]}.zip"
        temp_zip_path = download_temp_zip(temp_zip_name, zip_url = nil, folder_path)
        current_user.projects.attach(
          io: File.open(temp_zip_path),
          filename: new_project_name,
          content_type: 'application/zip'
        )
        File.delete(temp_zip_path) if File.exist?(temp_zip_path)
        redirect_to workflows_path(current_user, folder_name: repo_params[:repo_name]), notice: "Successfully Imported From Git."
      rescue => e
        puts "Exception occurred: #{e.message}"
        redirect_to workflows_path(current_user), alert: "Failed to import from Git. Please try again!"
      end
    else 
      redirect_to workflows_path(current_user), alert: "Failed to import from Git. Please try again!"
    end
  end

  def create_file
    if request.format.html?
      head :ok
      return
    end
    if create_file_params
      begin
        create_file_path = Rails.root.join("workflows", current_user.friendly_id, create_file_params[:file_path])
        directory_path = create_file_path.dirname
        if create_file_params[:type] == 'file'
          Dir.mkdir(directory_path) unless Dir.exist?(directory_path)
          unless File.exist?(create_file_path)
            File.open(create_file_path,'w') do |file|
              file.puts "# New File Created"
            end
          end
          respond_to do |format|
            format.json { render json: { message: "File created successfully!" }, status: :ok }
          end 
        else
          Dir.mkdir(create_file_path) unless Dir.exist?(create_file_path)
          respond_to do |format|
            format.json { render json: { message: "Folder created successfully" }, status: :ok }
          end 
        end
      rescue 
        respond_to do |format|
          format.json { render json: { error: "File / Folder not created." }, status: :not_found }
        end
      end
    end
  end

  def rename_folder
    if request.format.html?
      head :ok
      return
    end
    if rename_file_params
      workflow_path = Rails.root.join("workflows", current_user.friendly_id)
      dir_path = File.dirname(rename_file_params[:old_file_path])
      folder_name = dir_path.split('/')[0]
      old_file_path = Rails.root.join("workflows", current_user.friendly_id, dir_path, rename_file_params[:old_file_name])
      new_file_path = Rails.root.join("workflows", current_user.friendly_id, dir_path, rename_file_params[:new_file_name])
      path = "#{workflow_path}/#{folder_name}"
      begin
        if old_file_path == new_file_path
          respond_to do |format|
            format.json { render json: { file_href: open_file_path(current_user, file_path: new_file_path), success: "File Renamed" }, status: :ok }
          end
          return
        end
        if File.exist?(old_file_path)
          FileUtils.mv(old_file_path, new_file_path)
          directory_tree_json = [folder_structure_for_js_tree(path)].to_json.html_safe
          respond_to do |format|
            format.json { render json: { directory_tree_json: directory_tree_json, success: "Folder Renamed" }, status: :ok }
          end
          return
        else
          directory_tree_json = [folder_structure_for_js_tree(path)].to_json
          respond_to do |format|
            format.json { render json: { directory_tree_json: directory_tree_json, error: "Folder does not exist. Please try again!" }, status: :not_found }
          end
        end
      rescue
        directory_tree_json = [folder_structure_for_js_tree(path)].to_json
        respond_to do |format|
          format.json { render json: { directory_tree_json: directory_tree_json, error: "Not able to rename. Please try again!" }, status: :not_found }
        end
      end
    end
  end

  def rename_file
    if request.format.html?
      head :ok
      return
    end
    if rename_file_params
      workflow_path = Rails.root.join("workflows", current_user.friendly_id)
      dir_path = File.dirname(rename_file_params[:old_file_path])
      folder_name = dir_path.split('/')[0]
      old_file_path = workflow_path.join(dir_path, rename_file_params[:old_file_name])
      new_file_path = workflow_path.join(dir_path, rename_file_params[:new_file_name])
      path_to_share = dir_path + "/" + rename_file_params[:new_file_name]
      begin
        if old_file_path == new_file_path
          respond_to do |format|
            format.json { render json: { file_href: open_file_path(current_user, file_path: path_to_share), success: "File Renamed" }, status: :ok }
          end
          return
        end
        if File.exist?(old_file_path)
          FileUtils.mv(old_file_path, new_file_path)
          respond_to do |format|
            format.json { render json: { file_href: open_file_path(current_user, file_path: path_to_share), success: "File Renamed" }, status: :ok }
          end
          return
        else
          respond_to do |format|
            format.json { render json: { file_href: open_file_path(current_user, file_path: old_file_path), error: "File / Folder does not exist. Please try again!" }, status: :not_found }
          end
        end
      rescue
        respond_to do |format|
          format.json { render json: { file_href: open_file_path(current_user, file_path: old_file_path), error: "Not able to rename. Please try again!" }, status: :not_found }
        end
      end
    end
  end

  def delete_file
    if request.format.html?
      head :ok
      return
    end
    if removed_file_params
      workflow_path = Rails.root.join("workflows", current_user.friendly_id)
      removed_file_path = removed_file_params[:removed_file_path]
      folder_name = removed_file_path.split('/')[0]
      final_path = workflow_path.join(removed_file_path)
      begin
        if File.exist?(final_path)
          if File.directory?(final_path)
            FileUtils.remove_dir(final_path, true)
          else
            File.delete(final_path)
          end
          respond_to do |format|
            format.json { render json: { success: "File / Folder Deleted" }, status: :ok }
          end
        else
          raise "File or directory does not exist. Please try again!"
        end
      rescue => e
        path = workflow_path.join(folder_name)
        directory_tree_json = [folder_structure_for_js_tree(path)].to_json
        respond_to do |format|
          format.json { render json: { directory_tree_json: directory_tree_json , error: "#{e}" }, status: :not_found }
        end
      end
    end
  end

  def new_project
    begin
      workflows_path = Rails.root.join('workflows', current_user.friendly_id)
      if Dir.exist?(workflows_path)
        folders = Dir.glob("#{workflows_path}/*").select { |f| File.directory?(f) }.map { |f| File.basename(f) }
      else
        folders = []
        FileUtils.mkdir_p(workflows_path)
      end
      if folder_name_params[:folder_name]
        counter = 1
        unique_name = folder_name_params[:folder_name]
        siblings = folders

        while siblings.include?(unique_name)
          unique_name = "#{base_name}_#{counter}"
          counter += 1
        end
        new_folder_path = workflows_path.join(unique_name)
      end
      FileUtils.mkdir_p(new_folder_path)
      new_project_name = "#{unique_name}.zip"
      delete_project_from_s3(new_project_name)
      temp_zip_name = "#{unique_name}.zip"
      temp_zip_path = download_temp_zip(temp_zip_name, zip_url = nil, new_folder_path)
      current_user.projects.attach(
        io: File.open(temp_zip_path),
        filename: new_project_name,
        content_type: 'application/zip'
      )
      File.delete(temp_zip_path) if File.exist?(temp_zip_path)
      redirect_to workflows_path(current_user, folder_name: unique_name), notice: "Created new project successfully!"
    rescue
      redirect_to workflows_path(current_user), alert: "Not able to create project! Please try again."
    end
  end

  def delete_project
    begin
      if folder_name_params && folder_name_params[:folder_name]
        workflow_path = Rails.root.join("workflows", current_user.friendly_id)
        folder_path = workflow_path.join(folder_name_params[:folder_name])
        folder_name = folder_name_params[:folder_name]
        new_project_name = "#{folder_name}.zip"
        delete_project_from_s3(new_project_name)
        if Dir.exist?(folder_path)
          FileUtils.remove_dir(folder_path, true)
        end
        respond_to do |format|
          format.html { redirect_to workflows_path(current_user), notice: "Project deleted successfully!" }
        end
      else
        respond_to do |format|
          redirect_to workflows_path(current_user), alert: "Not able to delete project. Please try again!"
        end
      end
    rescue
      respond_to do |format|
        redirect_to workflows_path(current_user), alert: "Not able to delete project. Please try again!"
      end
    end
  end

  def save_project
    if folder_name_params && folder_name_params[:folder_name]
      folder_path = Rails.root.join("workflows", current_user.friendly_id, folder_name_params[:folder_name].to_s)
      begin
        temp_zip_name = "#{current_user.friendly_id}-#{folder_name_params[:folder_name]}.zip"
        temp_zip_path = download_temp_zip(temp_zip_name, zip_url = nil, folder_path)
        new_project_name = "#{folder_name_params[:folder_name]}.zip"
        delete_project_from_s3(new_project_name)
        current_user.projects.attach(
          io: File.open(temp_zip_path),
          filename: new_project_name,
          content_type: 'application/zip'
        )
      ensure
        File.delete(temp_zip_path) if File.exist?(temp_zip_path)
        FileUtils.remove_dir(folder_path, true)
      end
      redirect_to workflows_path(current_user), notice: 'Project Saved!'
    else
      redirect_to workflows_path(current_user), alert: 'Not able to find project to save! Please try again!'
    end
  end

  def project_from_s3
    if folder_name_params && folder_name_params[:folder_name]
      begin
        folder_name = "#{folder_name_params[:folder_name]}.zip"
        workflow_folder = Rails.root.join('workflows', "#{current_user.friendly_id}").to_s
        zip_url = nil
        current_user.projects.each do |project| 
          if project.filename.to_s == folder_name
            zip_url = project.url
            break
          end
        end
        temp_zip_path = download_temp_zip(folder_name, zip_url, nil)
        if temp_zip_path != ""
          extract_zip(temp_zip_path, workflow_folder)
          File.delete(temp_zip_path) if File.exist?(temp_zip_path)
          redirect_to workflows_path(current_user, folder_name: folder_name_params[:folder_name]), notice: "Project loaded successfully!"
        else
          redirect_to workflows_path(current_user), alert: "Not able to load project! Please try again!"
        end
      rescue
        redirect_to workflows_path(current_user), alert: 'Not able to find saved project! Please try again!'
      end
    else
      redirect_to workflows_path(current_user), alert: 'Not able to find saved project! Please try again!'
    end
  end

  def remove_existing_project
    if folder_name_params && folder_name_params[:folder_name]
      begin
        path = Rails.root.join('workflows', current_user.friendly_id, folder_name_params[:folder_name].to_s)
        FileUtils.remove_dir(path, true) if File.exist?(path) && File.directory?(path)
        redirect_to workflows_path, notice: 'Changes removed successfully!'
      rescue
        redirect_to request.referrer, alert: 'Project not found. Please try again!'  
      end
    else
      redirect_to request.referrer, alert: 'Project not found. Please try again!'
    end
  end

  private

  def folder_name_params
    params.permit(:id, :folder_name)
  end

  def repo_params
    params.permit(:id, :username, :repo_name, :branch_name)
  end

  def git_file_params
    params.permit(:id, :repo_name, :commit_message, files: {})
  end

  def create_file_params
    params.permit(:id, :file_path, :type)
  end

  def rename_file_params
    params.permit(:id, :old_file_name, :new_file_name, :old_file_path, :type)
  end

  def removed_file_params
    params.permit(:id, :removed_file_path);
  end

  def download_zip_params
    params.permit(:download_zip);
  end

  def github_list_params
    params.permit(:id, :github_page, :data)
  end

  def saved_projects_params
    params.permit(:id, :project_page, :data)
  end

  def retreive_github_repo_info
    begin
      @octokit_client = Octokit::Client.new(access_token: current_user.token)
      @username = @octokit_client.user.login
      page = 1
      per_page = 30
      @repo_branch_array = []
      loop do
        repos = @octokit_client.repositories(nil, page: page, per_page: per_page)
        break if repos.empty?
        repos.each do |repo|
          repo_hash = {}
          repo_hash[:name] = repo.name
          repo_hash[:type] = repo.private ? 'Private' : 'Public'
          repo_hash[:branch] = repo.default_branch
          @repo_branch_array.push(repo_hash)
        end
        page += 1
      end
      @repo_branch_array
    rescue Octokit::NotFound
      puts "User or repository not found."
      @repo_branch_array = []
    rescue Octokit::Unauthorized
      puts "Unauthorized access. Please check your access token."
      @repo_branch_array = []
    rescue => e
      puts "Error fetching repositories or branches: #{e.message}"
      @repo_branch_array = []
    end
  end

  def download_temp_zip(temp_zip_name, zip_url = nil, folder_path = nil)
    temp_zip_path = Rails.root.join('tmp', "#{temp_zip_name}")
    File.delete(temp_zip_path) if File.exist?(temp_zip_path)
    if zip_url 
      File.open(temp_zip_path, 'wb') do |file|
        file.write(URI.open(zip_url).read)
      end
      temp_zip_path
    elsif folder_path
      main_folder_name = File.basename(folder_path)
      Zip::File.open(temp_zip_path, Zip::File::CREATE) do |zipfile|
        zipfile.mkdir(main_folder_name)
        Dir.glob(File.join(folder_path, '**', '*'), File::FNM_DOTMATCH).each do |file|
          next if File.basename(file) == '.' || File.basename(file) == '..'
          zipfile.add(File.join(main_folder_name, file.sub(folder_path.to_s + '/', '')), file)
        end
      end
      temp_zip_path
    else
      ""    
    end
  end

  def extract_zip(zip_path, destination_folder)
    FileUtils.mkdir_p(destination_folder) unless Dir.exist?(destination_folder)
    Zip::File.open(zip_path) do |zip_file|
      zip_file.each do |entry|
        target_file_path = File.join(destination_folder, entry.name)
        if File.exist?(target_file_path)
          if File.directory?(target_file_path)
            FileUtils.remove_dir(target_file_path, true)
          else
            FileUtils.rm(target_file_path)
          end
        end
        entry.extract(target_file_path)
      end
    end
  end

  def delete_project_from_s3(project_name)
    projects = current_user.projects.map { |project| project.filename.to_s }
    if projects.include?(project_name)
      project_to_delete = current_user.projects.select { |project| project.filename.to_s == project_name }
      project_to_delete.each(&:purge)
    end
  end

  def check_for_unnecessary_folders(workflow_path, folders, open_projects)
    begin
      projects = []
      open_projects&.each do |open_project|
        if folders.include?(open_project)
          projects.push(open_project)
        else
          delete_folder_path = File.join(workflow_path, open_project)
          FileUtils.remove_dir(delete_folder_path, true) if File.exist?(delete_folder_path) && File.directory?(delete_folder_path)
        end
      end
      projects
    rescue
      []
    end
  end
end
