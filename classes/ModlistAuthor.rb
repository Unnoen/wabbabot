require 'discordrb'
require_relative '../helpers/typehelper.rb'
class ModlistAuthor
  def initialize(username, discord_id)
    raise TypeError, 'modlist_author.initialize requires a Discord ID' unless only_digits? discord_id
    @username = username
    @id = discord_id
  end
end
