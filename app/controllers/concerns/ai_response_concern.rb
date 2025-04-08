require 'httparty'
require 'json'
require 'zip'

module AiResponseConcern
  extend ActiveSupport::Concern

  API_URL = 'https://api.openai.com/v1/chat/completions' # Replace with actual endpoint

  def context_of_product_prompt(user_query)
    "Hi
    I will forward you the query of a user and you will return response according to that.
    If the query is general then return response in general string format and make create_product false.
    If the query is to create a product then return response in json format and make create_product true.
    For example, if someone asks you to create a product then you will return response in json format as given below.
    The json response will indicate zipfile structure and code attached,
    so that i can convert it to my product if someone ask you to create a product. JSON Format is here #{sample_json_structure}
    And here is the query of user: #{user_query}"
  end

  def sample_json_structure
    "{
      # If true then zipfile structure, name and description will be attached by you as User have asked you to create a product.
      # If false then simple response will be returned by you in string format
      create_product: 'boolean',
      # It will be emptyt string if user's query is general and not asked you to create the product
      response: \"string\",
      # This will contain the name of the product given by user or either sugested by you.
      name: \"string\",
      # This will contain the description of the product given by user or either sugested by you.
      description: \"string\",
      # This will contain the folder structure of the product and the code to be put in the files
      zipfile: {}
    }"
  end

  def send_request(user_query)
    begin
        prompt = context_of_product_prompt(user_query)
        response = HTTParty.post(
            API_URL,
            headers: {
                "Content-Type" => "application/json",
                "Authorization" => "Bearer #{ENV['MINI_SECRET_KEY']}"
            },
            body: {
                model: "gpt-4o-mini", # gpt-4o-mini
                messages: [{ role: "user", content: prompt }],
                temperature: 0.7
            }.to_json
        )
        parsed_response = JSON.parse(response.body)
        if parsed_response.present? && parsed_response["error"]
            Rails.logger.error "Request failed with response: #{parsed_response['error']}"
            return parsed_response
        end
        ai_text = parsed_response.dig("choices", 0, "message", "content") || nil
        return { error: "No response received from AI model" } if ai_text.blank?

        cleaned_text = ai_text.gsub(/\A```json\n|\n```\z/, '')
        cleaned_text = JSON.parse(cleaned_text) if cleaned_text.is_a?(String) && cleaned_text.start_with?('{')
        cleaned_text
    rescue RestClient::ExceptionWithResponse => e
      Rails.logger.error "Request failed with response: #{e.response}"
      { error: "Request failed with response: #{e.response}" }
    rescue JSON::ParserError => e
      Rails.logger.error "Failed to parse JSON response: #{e.message}"
      { error: "Failed to parse JSON response: #{e.message} and #{e.backtrace}" }
    rescue StandardError => e
      Rails.logger.error "An unexpected error occurred: #{e.message}"
      { error: "An unexpected error occurred: #{e.message}" }
    end
  end

  def add_to_zip(zipfile, current_path, structure)
    structure.each do |name, content|
      full_path = [current_path, name].reject(&:empty?).join('/')      
      if content.is_a?(Hash)
        zipfile.mkdir(full_path) unless zipfile.find_entry(full_path)
        add_to_zip(zipfile, full_path, content)
      else
        zipfile.get_output_stream(full_path) { |f| f.write(content) }
      end
    end
  end

  def create_zip_file_structure(zip_structure)
    zip_structure = @response[:zipfile]
    name = @response[:name]
    description = @response[:description]
    create_product = @response[:create_product]
    return nil if create_product == false

    return nil if zip_structure.blank? || !zip_structure.is_a?(Hash)

    begin
      temp_zip = Tempfile.new(['ai_response', '.zip'], binmode: true)
      Zip::File.open(temp_zip.path, Zip::File::CREATE) do |zipfile|
        add_to_zip(zipfile, '', zip_structure)  # Start at root
      end
      temp_zip.flush
      temp_zip.close

      @product = Product.new(name: name || 'AI Generated App', description: description || 'AI Generated App', published: true, active: true)
      @product.user = current_user

      if @product.save
        directory_tree_str = zip_structure_for_js_tree(temp_zip.path).to_s
        @product.update_attribute(:directory_tree, directory_tree_str)

        @product.folder.attach(
          io: File.open(temp_zip.path), 
          filename: "#{@product.name.gsub(' ', '_')}.zip",
          content_type: 'application/zip'
        )
      end
      temp_zip.unlink
      @product
    rescue Exception => e
      Rails.logger.error "Failed to create ZIP file: #{e.message}"
      nil
    end
  end
end
