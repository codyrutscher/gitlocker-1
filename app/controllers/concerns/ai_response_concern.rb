require 'httparty'
require 'json'

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
    {
      # If true then zipfile structure, name and description will be attached by you as User have asked you to create a product.
      # If false then simple response will be returned by you in string format
      create_product: 'boolean',
      # It will be emptyt string if user's query is general and not asked you to create the product
      response: 'string',
      # This will contain the name of the product given by user or either sugested by you.
      name: "string",
      # This will contain the description of the product given by user or either sugested by you.
      description: "string",
      # This will contain the folder structure of the product and the code to be put in the files
      zipfile: {}
    }
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
        cleaned_text = JSON.parse(cleaned_text)
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
end
