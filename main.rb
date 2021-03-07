#!/usr/bin/ruby
# frozen_string_literal: true

require 'discordrb'
require 'slop'
require 'uri'
require_relative 'helpers/webhelper'
require_relative 'classes/modlistmanager'
require_relative 'classes/servermanager'
require_relative 'errors/modlistnotfoundexception.rb'
require_relative 'errors/duplicatemodlistexception.rb'

$root_dir = __dir__.freeze

opts = Slop.parse do |arg|
  arg.string '-p', '--prefix', 'prefix to use for @bot commands', default: '!'
  arg.on '-h', '--help' do
    puts arg
    exit
  end
  arg.on '--version', 'print the version' do
    puts Slop::VERSION
    exit
  end
end

prefix = proc do |message|
  p = opts[:prefix]
  message.content[p.size..-1] if message.content.start_with? p
end

settings_path = "#{$root_dir}/db/settings.json"
$settings = JSON.parse(File.open(settings_path).read).freeze
@modlistmanager = ModlistManager.new
@servermanager = ServerManager.new

@bot = Discordrb::Commands::CommandBot.new(
  token: $settings['token'],
  client_id: $settings['client_id'],
  prefix: prefix
)

puts "Running WabbaBot with invite URL: #{@bot.invite_url}."

@bot.command(
  :listen,
  description: 'Listen to new modlist releases from the specified list in the specified channel',
  usage: "#{opts[:prefix]}listen <modlist id> <channel>",
  min_args: 1
) do |event, modlist_id, channel|
  manage_roles_only(event)

  server = @servermanager.spawn(event.server.id, event.server.name)
  channel_id = get_channel_id(event, channel)
  @servermanager.add_channel_to_server(event.server.id, Channel.new(channel_id))
  return "Now listening to `#{modlist_id}` in #{channel_id}" if @servermanager.add_listener_to_channel(server, channel_id, modlist_id)
end

@bot.command(
  :unlisten,
  description: 'Stop listening to new modlist releases from the specified list in the specified channel',
  usage: "#{opts[:prefix]}unlisten <modlist id> <channel>",
  min_args: 1
) do |event, modlist_id, channel|
  server = @servermanager.spawn(event.server.id, event.server.name)
  channel_id = get_channel_id(event, channel)
  
  error(event, 'Not implemented yet, spam me (trawzified) about this')
end

@bot.command(
  :release,
  description: 'Put out a new release of your list',
  usage: "#{opts[:prefix]}release <modlist_id> <message>",
  min_args: 1
) do |event, modlist_id|
  modlistmanager_json = uri_to_json($settings['modlists_url'])

  modlist = @modlistmanager.get_by_id(modlist_id)
  error(event, "Modlist with id #{modlist_id} not found") if modlist.nil?
  error(event, 'You\'re not managing this list') if modlist.author_id != event.author.id

  message = event.message.content.delete_prefix("#{opts[:prefix]}release #{modlist_id}")

  listening_servers = @servermanager.get_servers_listening_to_id(modlist_id)
  channel_count = 0
  server_count = 0
  error(event, 'There are no servers listening to these modlist releases') if listening_servers.empty?
  listening_servers.each do |listening_server|
    server = @bot.servers[listening_server.id]
    server_count += 1
    listening_server.listening_channels.each do |channel|
      channel_to_post_in = server.channels.find { |c| c.id == channel.id.to_i }
      channel_count += 1
      channel_to_post_in.send_embed do |embed|
        embed.title = "#{event.author.username} just released #{modlist.title} #{modlist.version}!"
        embed.colour = 0xbb86fc
        embed.timestamp = Time.now
        embed.description = message
        # embed.url = modlist_json['links']['readme']
        embed.image = Discordrb::Webhooks::EmbedImage.new(url: modlist.image_link)
        embed.footer = Discordrb::Webhooks::EmbedFooter.new(text: 'WabbaBot')
      end
    end
  end
  channel_count > 0 ? "Modlist was released in #{channel_count} channels in #{server_count} servers!"
                    : error(event, 'Failed to release modlist in any servers')
end

@bot.command(
  :addmodlist,
  description: 'Adds a new modlist',
  usage: "#{opts[:prefix]}addmodlist <user> <role> <modlist id>",
  min_args: 2
) do |event, user, role, id|
  admins_only(event)

  member = get_member_for_user(event, user)
  begin
    modlist = Modlist.new(id, member.id)
  rescue ModlistNotFoundException => e
    error(event, e.message)
  end

  begin
    return @modlistmanager.add(modlist) ? "Modlist #{modlist.title} managed by #{member.username} was added to the database."
                                        : error(event, "Failed to add modlist #{id} to the database")
  rescue DuplicateModlistException => e
    error(event, e.message)
  end
end

@bot.command(
  :delmodlist,
  description: 'Deletes a modlist',
  usage: "#{opts[:prefix]}delmodlist <modlist_id>",
  min_args: 1
) do |event, id|
  admins_only(event)

  modlist = @modlistmanager.get_by_id(id)
  return "Modlist with ID `#{id}` was deleted." if @servermanager.del_listeners_to_id(id) && @modlistmanager.del(modlist)
end

@bot.command(
  :modlists,
  description: 'Presents a list of all modlists',
  usage: "#{opts[:prefix]}modlists"
) do |event|
  admins_only(event)

  @modlistmanager.show
end

def error(event, message)
  error_msg = "An error occurred! **#{message}.**"
  @bot.send_message(event.channel, error_msg)
  raise error_msg
  puts '-------------------'
end

def log(message)
  log_msg = "[#{Time.now}] - #{message}"
  puts log_msg
end

# Error out when someone calls this method and isn't a bot administrator
def admins_only(event)
  author = event.author
  error_msg = 'You don\'t have privileges for this action'
  error(event, error_msg) unless $settings['admins'].include? author.id
end

# Error out when someone calls this method and isn't a bot administrator or a person that can manage roles
def manage_roles_only(event)
  author = event.author
  error_msg = 'You don\'t have privileges for this action'
  error(event, error_msg) unless author.permission?(:manage_roles) || $settings['admins'].include?(author.id)
end

def get_channel_id(event, channel)
  # Format of channel: <#717201910364635147>
  error(event, 'Invalid channel provided') unless (match = channel.match(/<#([0-9]+)>/))
  return match.captures[0]
end

def get_member_for_user(event, user)
  # Format of user id: @<185807760590372874>
  match = user.match(/<@!?([0-9]+)>/)
  user = match.nil? ? user.to_i : match.captures[0].to_i
  # Confirm the id exists on the event server
  member = event.server.members.find { |m| m.id == user }
  error(event, 'Invalid user provided') if member.nil?
  return member
end
@bot.run
