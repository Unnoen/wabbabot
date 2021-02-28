# frozen_string_literal: true

class Channel
  attr_reader :id, :listening_to, :auto_listen_to_new_lists

  def initialize(id, listening_to = [], auto_listen_to_new_lists = false)
    @id = id
    @listening_to = listening_to
    @auto_listen_to_new_lists = auto_listen_to_new_lists
  end

  def listen_to(modlist_id)
    @listening_to.push(modlist_id) unless @listening_to.include?(modlist_id)
  end

  def to_hash
    Hash[instance_variables.map { |var| [var.to_s[1..-1], instance_variable_get(var)] }]
  end

  def ==(other)
    self.class === other && other.id == @id
  end
end
