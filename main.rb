#!/usr/bin/ruby
# frozen_string_literal: true

require 'discordrb'
require 'slop'
require_relative 'classes/Modlist'

$root_dir = __dir__

opts = Slop.parse do |arg|
  arg.string '-p', '--prefix', 'prefix to use for bot commands', default: '$'
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
settings = JSON.parse(File.open(settings_path).read)
modlists = Modlists.new

bot = Discordrb::Commands::CommandBot.new(token: settings['token'], client_id: settings['client_id'], prefix: prefix)

bot.command(:release, description: 'Put out a new release of your list', usage: "#{opts[:prefix]}release <semantic version> <message>", min_args: 2) do |event, version, message|
  event.channel.send_embed do |embed|
    embed.title = "#{event.author.username} just released Skyrimified #{version}!"
    embed.colour = 0xd5cb2a
    embed.timestamp = Time.now
    embed.description = message

    # embed.thumbnail = Discordrb::Webhooks::EmbedThumbnail.new(url: player.avatar)
    embed.footer = Discordrb::Webhooks::EmbedFooter.new(text: "WabbaBot")
  end
end

bot.command(:add_modlist, description: 'Adds a new modlist', usage: "#{opts[:prefix]}add_modlist <modlist_id> <modlist_name> <user>", min_args: 3) do |event, id, name, user|
  "Modlist #{name} with ID `#{id}` owned by #{user.username} was added to the database." if modlists.add(id, name, user)
end

bot.command(:modlists, description: 'Presents a list of all modlists', usage: "#{opts[:prefix]}modlists") do |event|
  modlists.show
end

bot.run
