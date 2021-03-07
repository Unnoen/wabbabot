class DuplicateModlistException < StandardError
  def message
    'The modlist was already present in the database'
  end
end
