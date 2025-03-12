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

  def extract_file_content(product, file_name, lines = nil, char_limit = nil)
    return nil unless product.folder.attached?

    if policy(product).viewable?
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
      else
        owner, repo, ref = parse_github_url(source)
        zip_link = "https://github.com/#{owner}/#{repo}/archive/refs/heads/#{ref}.zip"
      end
      temp_file = Tempfile.new([repo, '.zip'])
  
      curl_command = "curl -L #{header} -o #{temp_file.path} #{zip_link}"
      stdout, stderr, status = Open3.capture3(curl_command)
  
      unless status.success?
        Rails.logger.error "Failed to download ZIP: #{stderr}"
        return nil
      end
  
      Rails.logger.info "Successfully downloaded #{temp_file.path}"
  
      # Ensure file exists before attaching
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
