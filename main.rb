#!/usr/bin/ruby
# frozen_string_literal: true

require 'discordrb'
require 'slop'
require 'uri'
require_relative 'helpers/webhelper'
require_relative 'classes/Modlist'

$root_dir = __dir__

opts = Slop.parse do |arg|
  arg.string '-p', '--prefix', 'prefix to use for @bot commands', default: '$'
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
@settings = JSON.parse(File.open(settings_path).read)
@modlists = Modlists.new

@bot = Discordrb::Commands::CommandBot.new(token: @settings['token'], client_id: @settings['client_id'], prefix: prefix)

puts "Running WabbaBot with invite URL: #{@bot.invite_url}."

@bot.command(:set_release_channel, description: 'Sets the channel to release modlist release notifications to', usage: "#{opts[:prefix]}set_up_release_channel <channel>", min_args: 1) do |event, channel|
  # format of channel <#804803296669466707>
  error(event, 'Invalid channel provided') unless (match = user.match(/<#([0-9]+)>/))
  channel_id = match.captures[0]

end

@bot.command(:release, description: 'Put out a new release of your list', usage: "#{opts[:prefix]}release <semantic version> <message>", min_args: 2) do |event, version, *args|
  modlist = @modlists.get_by_user_id(event.author.id)

  wabbajack_modlists = uri_to_json(@settings['modlists_url'])
  modlist_json = wabbajack_modlists.detect { |m| m['links']['machineURL'] == modlist.id }

  error 'Version doesn\'t match modlists json!' if version != modlist_json['version']

  modlist_image = value_of(value_of(modlist_json, 'links'), 'image')

  message = event.message.content.delete_prefix("#{opts[:prefix]}release #{version} ")
  puts message
  event.channel.send_embed do |embed|
    embed.title = "#{event.author.username} just released #{modlist.name} #{version}!"
    embed.colour = 0xd5cb2a
    embed.timestamp = Time.now
    embed.description = message
    embed.image = Discordrb::Webhooks::EmbedImage.new(url: modlist_image)
    embed.footer = Discordrb::Webhooks::EmbedFooter.new(text: 'WabbaBot')
  end
end

@bot.command(:add_modlist, description: 'Adds a new modlist', usage: "#{opts[:prefix]}add_modlist <user> <modlist id> <modlist name>", min_args: 3) do |event, user, id, *args|
  admins_only(event)

  name = args.join(' ')
  # format of user id @<185807760590372874>
  error(event, 'Invalid user provided') unless (match = user.match(/<@!([0-9]+)>/))
  user_id = match.captures[0]

  begin
    role = event.server.create_role(name: name, colour: 0)
  rescue Discordrb::Errors::NoPermission
    return 'I don\'t have permission to manage roles!'
  end

  "Modlist #{name} with ID `#{id}` was added to the database." if @modlists.add(id, name, user_id, role.id)
end

@bot.command(:del_modlist, description: 'Deletes a modlist', usage: "#{opts[:prefix]}del_modlist <modlist_id>", min_args: 1) do |event, id|
  admins_only(event)

  modlist = @modlists.get_by_id(id)
  role = event.server.roles.detect {|role| role.id == modlist.role_id}
  puts role
  role.delete
  "Modlist with ID `#{id}` was deleted." if @modlists.del(modlist)
end

@bot.command(:modlists, description: 'Presents a list of all modlists', usage: "#{opts[:prefix]}modlists") do |event|
  admins_only(event)

  @modlists.show
end

def error(event, message)
  error_msg = "Error: **#{message}.**"
  @bot.send_message(event.channel, error_msg)
  raise error_msg
end

def log(message)
  log_msg = "[#{Time.now}] - #{message}"
  puts log_msg
end

def admins_only(event)
  error(event, "User #{event.author.username} has no privileges for this action") unless @settings['admins'].include? event.author.id
end

@bot.run
