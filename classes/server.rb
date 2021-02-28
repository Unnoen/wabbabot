# frozen_string_literal: true
require_relative 'channel'
class Server
  attr_reader :id, :name, :listening_channels

  def initialize(id, name, listening_channels = [])
    @id = id
    @name = name
    @listening_channels = listening_channels
  end

  def add_channel(channel)
    @listening_channels.push(channel) unless @listening_channels.include?(channel)
  end

  def listen_to_list_in_channel(channel_id, modlist_id, auto_listen_to_new_lists = false)
    channel = @listening_channels.find { |listening_channel| listening_channel.id == channel_id }
    if channel.nil?
      channel = Channel.new(channel_id, [modlist_id], auto_listen_to_new_lists)
      listening_channels.push(channel)
    else
      channel.listen_to(modlist_id)
    end
  end

  def to_hash
    Hash[instance_variables.map { |var| [var.to_s[1..-1], instance_variable_get(var)] }]
  end

  def ==(other)
    self.class === other && other.id == @id
  end
end
