#!/usr/bin/ruby
# frozen_string_literal: true

require 'discordrb'
require 'slop'
require 'uri'
require_relative 'helpers/webhelper'
require_relative 'classes/modlistmanager'
require_relative 'classes/servermanager'

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
  token: @settings['token'],
  client_id: @settings['client_id'],
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
  
  error(event, 'Not implemented yet, spam trawzified about this')
end

@bot.command(
  :release,
  description: 'Put out a new release of your list',
  usage: "#{opts[:prefix]}release <modlist_id> <message>",
  min_args: 1
) do |event, modlist_id|
  modlistmanager_json = uri_to_json(@settings['modlists_url'])

  modlist = @modlistmanager.get_by_id(modlist_id)
  error(event, "Modlist with id #{modlist_id} not found") if modlist.nil?
  error(event, 'You\'re not managing this list') if modlist.user != event.author.id

  modlist_json = modlistmanager_json.find { |m| m['links']['machineURL'] == modlist_id }
  version = modlist_json['version']
  modlist_image = value_of(value_of(modlist_json, 'links'), 'image')

  message = event.message.content.delete_prefix("#{opts[:prefix]}release #{modlist_id}")

  listening_servers = @servermanager.get_servers_listening_to_id(modlist_id)
  channel_count = 0
  listening_server_count = 0
  error(event, 'There are no servers listening to these modlist releases') if listening_servers.empty?
  listening_servers.each do |listening_server|
    server = @bot.servers[listening_server.id]
    listening_server_count += 1
    listening_server.listening_channels.each do |channel|
      channel_to_post_in = server.channels.find { |c| c.id == channel.id.to_i }
      channel_count += 1
      channel_to_post_in.send_embed do |embed|
        embed.title = "#{event.author.username} just released #{modlist.name} #{version}!"
        embed.colour = 0xbb86fc
        embed.timestamp = Time.now
        embed.description = message
        # embed.url = modlist_json['links']['readme']
        embed.image = Discordrb::Webhooks::EmbedImage.new(url: modlist_image)
        embed.footer = Discordrb::Webhooks::EmbedFooter.new(text: 'WabbaBot')
      end
    end
  end
  success ? "Modlist was released in #{channel_count} channels in #{listening_servers_count} servers!" : error(event, 'Failed to release modlist in any servers')
end

@bot.command(
  :addmodlist,
  description: 'Adds a new modlist',
  usage: "#{opts[:prefix]}addmodlist <user> <role> <modlist id>",
  min_args: 2
) do |event, user, role, id|
  admins_only(event)

  error(event, 'Modlist does not exist in external modlists JSON') if modlist_json.nil?

  user = get_user_id(user)
  # Confirm the id exists on the event server

  begin
    modlist = Modlist.new(id, name, user, username, role.id)
  rescue ModlistNotFoundException => e
    error(event, e.message)
  end

  return "Modlist #{name} with ID `#{id}` was added to the database." if @modlistmanager.add(modlist)
end

@bot.command(
  :delmodlist,
  description: 'Deletes a modlist',
  usage: "#{opts[:prefix]}delmodlist <modlist_id>",
  min_args: 1
) do |event, id|
  admins_only(event)

  modlist = @modlistmanager.get_by_id(id)
  role = event.server.roles.find { |role| role.id == modlist.role_id }
  begin
    role.delete
  rescue Discordrb::Errors::NoPermission => e
    error(event, 'This bot requires the manage roles permission')
  end
  return "Modlist with ID `#{id}` was deleted." if @modlistmanager.del(modlist)
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
end

def log(message)
  log_msg = "[#{Time.now}] - #{message}"
  puts log_msg
end

# Error out when someone calls this method and isn't a bot administrator
def admins_only(event)
  author = event.author
  error_msg = 'You don\'t have privileges for this action'
  error(event, error_msg) unless @settings['admins'].include? author.id
end

# Error out when someone calls this method and isn't a bot administrator or a person that can manage roles
def manage_roles_only(event)
  author = event.author
  error_msg = 'You don\'t have privileges for this action'
  error(event, error_msg) unless author.permission?(:manage_roles) || @settings['admins'].include?(author.id)
end

def get_channel_id(event, channel)
  # Format of channel: <#717201910364635147>
  error(event, 'Invalid channel provided') unless (match = channel.match(/<#([0-9]+)>/))
  return match.captures[0]
end

def get_user_id(event, user)
  # Format of user id: @<185807760590372874>
  match = user.match(/<@!?([0-9]+)>/)
  user = match.nil? ? user.to_i : match.captures[0].to_i
  member = event.server.members.find { |m| m.id == user }
  error(event, 'Invalid user provided') if member.nil?
end
@bot.run
