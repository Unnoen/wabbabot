require_relative 'ModlistAuthor'
require 'json'
require 'active_support/all'

class Modlists
  def initialize
    @modlists = []
    @modlist_path = "#{$root_dir}/db/modlists.json"
    initialize_json
    read_existing_lists
  end

  def add(id, name)
    modlist = Modlist.new(id, name)
    return if @modlists.include? modlist

    @modlists.push(modlist)
    save
  end

  def del(modlist_to_del)
    @modlists.delete(modlist_to_del)
    save
  end

  def get(modlist_to_get)
    @modlists.detect { |modlist| modlist == modlist_to_get }
  end

  def save

    # .positive? Makes it return a bool if succesful instead of the number of chars written
    File.write(@modlist_path, @modlists.to_json).positive?
  end

  def show
    modlists_str = "There are #{@modlists.count} modlists.\n"
    @modlists.each_with_index do |modlist, index|
      modlists_str << "#{index}: #{modlist.name} (`#{modlist.id}`)\n"
    end
    return modlists_str
  end

  private

  def read_existing_lists
    return unless File.exist? @modlist_path

    json = JSON.parse(File.open(@modlist_path).read)
    json.each do |child|
      @modlists.push(Modlist.new(child['id'], child['name']))
    end
    puts @modlists
  end

  # Create directories and files if they do not exist
  def initialize_json
    modlist_dir = File.dirname(@modlist_path)
    Dir.mkdir(modlist_dir) unless Dir.exist?(modlist_dir)
    File.open(@modlist_path, 'w') { |f| f.write('{}') } unless File.exist?(@modlist_path)
  end
end

class Modlist
  attr_reader :id, :name
  def initialize(id, name)
    @id = id
    @name = name
  end

  def to_hash
    Hash[instance_variables.map { |var| [var.to_s[1..-1], instance_variable_get(var)] }]
  end

  def ==(other)
    self.class === other && other.id == @id
  end

end
