require 'linguist'
require 'fileutils'
module ApplicationHelper

  def get_color_code(language)
    Linguist::Language.find_by_name(language)&.color 
  end
end
