require 'zip'
require 'json'

module ProductConcern
  extend ActiveSupport::Concern

  def fetch_product_directory_tree(product)
    if product.directory_tree.present? 
      directory_tree = begin 
        eval(product.directory_tree) 
      rescue 
        []
      end
    else
      directory_tree = []
    end
    directory_tree.to_json.html_safe
  end

  def zip_structure_for_js_tree(file_path)
    structure = {}
    # return nil unless File.exist?(file_path) && `file --mime-type -b #{file_path}`.strip == "application/zip"
    begin
      Zip::File.open(file_path) do |zip_file|
        sorted_entries = zip_file.sort_by { |entry| [entry.directory? ? 0 : 1, entry.name] }
        sorted_entries.each do |entry|
          parts = entry.name.split('/')
          current_level = structure
          parts.each_with_index do |part, index|
            if index == parts.size - 1
              if entry.directory?
                current_level[part] ||= {}
              else
                current_level[part] = 'file'
              end
            else
              current_level[part] ||= {}
              current_level = current_level[part]
            end
          end
        end
      end
    rescue Zip::Error => e
      return nil
    end
    convert_to_js_tree_format(structure)
  end

  def folder_structure_for_js_tree(folder_path)
    structure = {}
    Dir.glob(File.join(folder_path, '**', '*')).each do |path|
      relative_path = path.sub("#{folder_path}/", '')
      parts = relative_path.split('/')
      current_level = structure
  
      parts.each_with_index do |part, index|
        if index == parts.size - 1
          if File.directory?(path)
            current_level[part] ||= {}
          else
            current_level[part] = 'file'
          end
        else
          current_level[part] ||= {}
          current_level = current_level[part]
        end
      end
    end
    sorted_structure = sort_structure(structure)
    { text: File.basename(folder_path), children: convert_to_js_tree_format(sorted_structure), icon: 'jstree-folder', type: 'root_folder' }
  end

  def sort_structure(structure)
    structure.sort_by { |key, value| [value.is_a?(Hash) ? 0 : 1, key] }.to_h
  end
  
  def convert_to_js_tree_format(structure)
    structure.map do |key, value|
      if value.is_a?(Hash)
        { text: key, children: convert_to_js_tree_format(value), type: 'folder' }
      else
        { text: key, icon: 'jstree-file', type: 'file' }
      end
    end
  end

  def replace_file_content(product, file_name, new_content)
    return nil unless product.folder.attached?
  
    temp_zip_path = Rails.root.join("tmp", "temp_zip_#{SecureRandom.hex}.zip")
    updated_zip_path = Rails.root.join("tmp", "updated_zip_#{SecureRandom.hex}.zip")
  
    File.open(temp_zip_path, 'wb') { |file| file.write(product.folder.download) }
  
    begin

      Zip::File.open(temp_zip_path) do |zip_file|
        Zip::File.open(updated_zip_path, Zip::File::CREATE) do |new_zip|
          zip_file.each do |entry|
            entry_relative_path = entry.name.split('/', 2).last # Remove top-level project folder
            if entry.directory?
              new_zip.mkdir(entry.name)
            elsif entry_relative_path == file_name
              new_zip.get_output_stream(entry.name) { |f| f.write(new_content) }
            else
              new_zip.get_output_stream(entry.name) { |f| f.write(entry.get_input_stream.read) }
            end
          end
        end
      end
  
      product.folder.attach(
        io: File.open(updated_zip_path),
        filename: "#{product.id}-updated.zip",
        content_type: 'application/zip'
      )
    ensure
      File.delete(temp_zip_path) if File.exist?(temp_zip_path)
      File.delete(updated_zip_path) if File.exist?(updated_zip_path)
    end
  end
  
  def add_file_to_zip(product, file_path, new_file_name, new_file_content = "")
    return nil unless product.folder.attached?
  
    temp_zip_path = Rails.root.join("tmp", "temp_zip_#{SecureRandom.hex}.zip")
    updated_zip_path = Rails.root.join("tmp", "updated_zip_#{SecureRandom.hex}.zip")
  
    Rails.logger.info "Params - File Path: #{file_path}, File Name: #{new_file_name}, Content: #{new_file_content.inspect}"
  
    # Step 1: Download the existing zip file
    File.open(temp_zip_path, 'wb') { |file| file.write(product.folder.download) }
    Rails.logger.info "Temporary Zip Path: #{temp_zip_path}"
  
    begin
      # Step 2: Open the existing zip file and create a modified version
      Zip::File.open(temp_zip_path) do |zip_file|
        Zip::File.open(updated_zip_path, Zip::File::CREATE) do |new_zip|
          # Extract the top-level folder name (e.g., "CrudMaster/")
          top_level_folder = zip_file.first.name.split('/').first
          Rails.logger.info "Top-level folder: #{top_level_folder}"
  
          # Copy all existing entries from the original zip to the new zip
          zip_file.each do |entry|
            if entry.directory?
              new_zip.mkdir(entry.name) unless new_zip.find_entry(entry.name)
            else
              new_zip.get_output_stream(entry.name) { |f| f.write(entry.get_input_stream.read) }
            end
          end
  
          # Step 3: Determine the path for the new file inside the product folder
          relative_path = file_path.blank? ? new_file_name : File.join(file_path, new_file_name)
          zip_entry_path = File.join(top_level_folder, relative_path)
          Rails.logger.info "Calculated zip entry path: #{zip_entry_path}"
  
          # Step 4: Add the new file to the zip
          Rails.logger.info "Adding new file to zip at #{zip_entry_path}"
          new_zip.get_output_stream(zip_entry_path) { |f| f.write(new_file_content) }
          Rails.logger.info "File added successfully to zip at #{zip_entry_path}"
        end
      end
  
      # Step 5: Attach the modified zip file back to the product
      product.folder.purge
      product.folder.attach(
        io: File.open(updated_zip_path),
        filename: "#{product.id}-updated.zip",
        content_type: 'application/zip'
      )

      directory_tree_str = zip_structure_for_js_tree(updated_zip_path).to_s
      if directory_tree_str.present? && product.update(directory_tree: directory_tree_str)
        Rails.logger.info "Successfully updated directory tree for product #{product.id}"
      else
        Rails.logger.error "Failed to update directory tree for product #{product.id}"
      end

      Rails.logger.info "Successfully added file to zip and updated product folder."
    rescue => e
      Rails.logger.error "Exception occurred: #{e.message}"
      raise
    ensure
      # Step 6: Clean up temporary files
      File.delete(temp_zip_path) if File.exist?(temp_zip_path)
      File.delete(updated_zip_path) if File.exist?(updated_zip_path)
    end
  end
  
  def extract_file_content(product, file_name, lines = nil, char_limit = nil)
    return nil unless product.folder.attached?

    unless policy(product).viewable?
      lines = 10
      char_limit = 1000
    end
    temp_zip_path = Rails.root.join("tmp", "temp_zip_#{SecureRandom.hex}.zip")
    File.open(temp_zip_path, 'wb') { |file| file.write(product.folder.download) }
  
    file_content = nil

    begin
      Zip::File.open(temp_zip_path) do |zip_file|
        zip_file.each do |entry|
          if entry.name.include?(file_name)
            file_content = entry.get_input_stream.read.lines
            if lines
              file_content = file_content.first(lines).join
              file_content = file_content[0, char_limit] if char_limit && file_content.length > char_limit
            else
              file_content = file_content.join
            end
            break
          end
        end
      end
    ensure
      File.delete(temp_zip_path) if File.exist?(temp_zip_path)
    end
    file_content
  end

  def load_repo_and_link_tree(owner, repo, ref, token, product, source = 'github')
    begin
      header = " -H 'Authorization: token #{token}' " if token.present?
      if source == 'github'
        zip_link = "https://github.com/#{owner}/#{repo}/archive/refs/heads/#{ref}.zip"
      elsif source == 'gitlab'
        zip_link = "https://gitlab.com/#{owner}/#{repo}/-/archive/#{ref}/#{repo}-#{ref}.zip"
      elsif source == 'bitbucket'
        header = " -H 'Authorization: Bearer #{token}' "
        zip_link = "https://bitbucket.org/#{owner}/#{repo}/get/#{ref}.zip"
      else
        return nil
      end
      temp_file = Tempfile.new([repo, '.zip'])
  
      curl_command = "curl -L #{header} -o #{temp_file.path} #{zip_link}"
      stdout, stderr, status = Open3.capture3(curl_command)
  
      unless status.success?
        Rails.logger.error "Failed to download ZIP: #{stderr}"
        return nil
      end
  
      Rails.logger.info "Successfully downloaded #{temp_file.path}"
      if File.exist?(temp_file.path) && File.size(temp_file.path) > 0
        product.folder.attach(
          io: File.open(temp_file.path),
          filename: "#{repo}-#{ref}.zip",
          content_type: 'application/zip'
        )
        directory_tree_str = zip_structure_for_js_tree(temp_file.path).to_s
        if directory_tree_str.present? && product.update(directory_tree: directory_tree_str)
          Rails.logger.info "Successfully attached #{repo}-#{ref}.zip to the product"
          return temp_file.path
        else
          Rails.logger.error "Failed to update directory_tree for product #{product.id}"
          return nil
        end
      else
        Rails.logger.error "Downloaded file is empty or missing."
        return nil
      end
    rescue => e
      Rails.logger.error "Exception occurred: #{e.message}"
      return nil
    ensure
      temp_file.close
      temp_file.unlink if File.exist?(temp_file.path)
    end
  end

  def parse_github_url(url)
    match = url.match(%r{https://github.com/(?<owner>[^/]+)/(?<repo>[^/]+)(/tree/(?<ref>[^/]+))?})
    owner = match[:owner]
    repo = match[:repo]
    ref = match[:ref] || 'main'
    [owner, repo, ref]
  end
end
