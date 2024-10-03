class WorkflowsController < ApplicationController
  before_action :authenticate_user!
  include ProductConcern

  def index
    folder_path = Rails.root.join('workflows', current_user.friendly_id)
    if Dir.exist?(folder_path)
      @folders = Dir.glob("#{folder_path}/*").select { |f| File.directory?(f) }.map { |f| File.basename(f) }
    else
      @folders = []
      FileUtils.mkdir_p(folder_path)
    end
    @directory_tree_json = "{}"
    if folder_name_params[:folder_name]
      path = "#{folder_path}/#{folder_name_params[:folder_name]}"
      @directory_tree_json = [folder_structure_for_js_tree(path)].to_json.html_safe
    end
  end

  def open_file
    if request.format.html?
      head :ok
      return
    end

    path = Rails.root.join("workflows", params[:id], params[:file_path])
    if File.exist?(path)
      file_data = File.file?(path) ? File.read(path) : nil
      respond_to do |format|
        format.json { render json: { file_data: file_data }, status: :ok }
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
    path = Rails.root.join("workflows", params[:id], params[:file_path])
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
          Zip::File.open(temp_file.path) do |zip_file|
            zip_file.each do |entry|
              target_file_path = File.join(workflow_folder, entry.name)
              FileUtils.mkdir_p(workflow_folder) unless Dir.exist?(workflow_folder)
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
          redirect_to workflows_path(current_user, folder_name: folder_name), notice: "Zip Uploaded successfully."
          return
        rescue
          redirect_to workflows_path(current_user), alert: "File upload failed. Please try again!"
        end
      end
    end
  end

  def open_workflow
  end

  def download_zip
  end

  private

  def folder_name_params
    params.permit(:folder_name)
  end
end
