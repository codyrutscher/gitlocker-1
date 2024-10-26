require 'octokit'
require 'open-uri'
require 'zip'

class WorkflowsController < ApplicationController
  before_action :retreive_github_repo_info, only: :index
  before_action :authenticate_user!
  include ProductConcern

  def index
    folder_path = Rails.root.join('workflows', current_user.friendly_id)
    if !(Dir.exist?(folder_path))
      FileUtils.mkdir_p(folder_path)
    end
    @directory_tree_json = "{}"
    @folders = current_user.projects.flat_map { |project| project.filename.to_s.sub(".zip", "") }
    open_projects = Dir.glob("#{folder_path}/*").select { |f| File.directory?(f) }.map { |f| File.basename(f) }
    if open_projects.size == 0
      @open_project = nil  
    elsif open_projects.size == 1
      @open_projects = check_for_unnecessary_folders(folder_path, @folders, open_projects)  
      @open_project = @open_projects.first
    else
      @open_projects = check_for_unnecessary_folders(folder_path, @folders, open_projects)
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

  def push_to_git
    if git_file_params
      @octokit_client = Octokit::Client.new(access_token: current_user.token)
      workflow_folder_path = Rails.root.join("workflows", current_user.friendly_id, git_file_params[:folder_name].to_s)
      folder_name = git_file_params[:folder_name].gsub("-main","")
      file_path = git_file_params[:file_path].gsub("#{git_file_params[:folder_name]}/","")

      repos_name = @octokit_client.repos.pluck(:name)
      local_file_path = workflow_folder_path + file_path
      if File.exist?(local_file_path) && repos_name&.include?(folder_name)
        if File.file?(local_file_path)
          begin
            file_content = File.read(local_file_path)
            repo = @octokit_client.login + "/" + folder_name
            blob = @octokit_client.create_blob(repo, file_content)
            latest_commit = @octokit_client.commits(repo).first
            latest_tree_sha = latest_commit.commit.tree.sha
            new_tree = @octokit_client.create_tree(repo, [
              {
                path: "#{file_path}",
                mode: '100644',
                type: 'blob',
                sha: blob
              }
            ], base_tree: latest_tree_sha)
            commit_message = "Changed #{file_path}"
            new_commit = @octokit_client.create_commit(repo, commit_message, new_tree.sha, [latest_commit.sha])
            ref = "heads/main"
            @octokit_client.update_ref(repo, ref, new_commit.sha)
            redirect_to workflows_path(current_user, folder_name: git_file_params[:folder_name].to_s), notice: "Pushed updated file to Github Successfully!!"
          rescue
            redirect_to workflows_path(current_user), alert: "Failed to export to Github! Please try again!"
          end
        else
          redirect_to workflows_path(current_user), alert: "Folder cannot be imported!"
        end
      else
        redirect_to workflows_path(current_user), alert: "Failed to export to Github! Please try again!"
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
    workflow_folder = Rails.root.join('workflows', "#{current_user.friendly_id}").to_s
    begin
      tmp_directory = Rails.root.join('tmp')
      zip_link = "https://github.com/#{repo_params[:username]}/#{repo_params[:repo_name]}/archive/refs/heads/main.zip"
      file = Tempfile.new(["#{repo_params[:username]}-#{repo_params[:repo_name]}", '.zip'], tmp_directory)
      curl_command = "curl -L -H 'Authorization: token #{current_user.token}' -o #{file.path} #{zip_link}"
      stdout, stderr, status = Open3.capture3(curl_command)
      
      if status.success?
        if File.exist?(file.path)
          new_project_name = "#{repo_params[:repo_name]}.zip"
          delete_project_from_s3(new_project_name)
          extract_zip(file.path, workflow_folder)
          old_folder_path = File.join(workflow_folder, "#{repo_params[:repo_name]}-main")
          new_folder_path = File.join(workflow_folder, "#{repo_params[:repo_name]}")
          FileUtils.mv old_folder_path, new_folder_path
          File.delete(file.path) if File.exist?(file.path)
          temp_zip_name = "#{repo_params[:repo_name]}.zip"
          temp_zip_path = download_temp_zip(temp_zip_name, zip_url = nil, new_folder_path)
          current_user.projects.attach(
            io: File.open(temp_zip_path),
            filename: new_project_name,
            content_type: 'application/zip'
          )
          File.delete(temp_zip_path) if File.exist?(temp_zip_path)
          redirect_to workflows_path(current_user, folder_name: repo_params[:repo_name]), notice: "Successfully Imported From Git."
        else
          puts "Failed to Import From Git : #{stderr}"
          redirect_to workflows_path(current_user), alert: "Failed to import from Git. Please try again!"
        end
      else
        puts "Failed to Import From Git : #{stderr}"
        redirect_to workflows_path(current_user), alert: "Failed to import from Git. Please try again!"
      end
    rescue => e
      puts "Exception occurred: #{e.message}"
      redirect_to workflows_path(current_user), alert: "Exception Occured. Please try again!"
    ensure
      file.close if file
      file.unlink if file
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
    params.permit(:id, :username, :repo_name)
  end

  def git_file_params
    params.permit(:id, :folder_name, :file_path)
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

  def retreive_github_repo_info
    begin
      @octokit_client = Octokit::Client.new(access_token: current_user.token)
      @username = @octokit_client.user.login
      @repos = @octokit_client.repos.pluck(:name)
      repos = @octokit_client.repos
      repo_branch_hash = {}
      repos.each do |repo|
        repo_name = repo.name
        repo_full_name = repo.full_name
        branches = @octokit_client.branches(repo_full_name)
        branch_hash = {}
        branches.each do |branch|
          branch_hash[branch.name] = { sha: branch.commit.sha }
        end
        if branch_hash.key?('main')
          repo_branch_hash[repo_name] = branch_hash
        end
      end
      @repo_branch_hash = repo_branch_hash
    rescue Octokit::NotFound
      puts "User or repository not found."
      @repo_branch_hash = {}
    rescue Octokit::Unauthorized
      puts "Unauthorized access. Please check your access token."
      @repo_branch_hash = {}
    rescue => e
      puts "Error fetching repositories or branches: #{e.message}"
      @repo_branch_hash = {}
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
        Dir[File.join(folder_path, '**', '**')].each do |file|
          zipfile.add(File.join(main_folder_name,file.sub(folder_path.to_s + '/', '')), file)
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
