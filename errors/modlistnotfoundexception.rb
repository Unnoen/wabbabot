class ModlistNotFoundException < StandardError
  def message
    'The modlist was not found in the external modlists JSON file'
  end
end
