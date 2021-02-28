# frozen_string_literal: true
require 'json'

class Modlist
  attr_reader :id, :name, :user, :username, :role_id

  def initialize(id, name, user, username, role_id)
    @id = id
    @name = name
    @user = user
    @username = username
    @role_id = role_id
  end

  def to_hash
    Hash[instance_variables.map { |var| [var.to_s[1..-1], instance_variable_get(var)] }]
  end

  def ==(other)
    self.class === other && other.id == @id
  end

end
