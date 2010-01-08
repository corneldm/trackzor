module Trackzor
  def self.included(base)
    base.extend ClassMethods
  end

  module ClassMethods
    def trackzored
      self.columns.select{|column| column.name =~ /_updated_by/ }.each do |col|
        belongs_to "#{col.name.split('_updated_by')[0]}_source".to_sym, :class_name => 'User', :foreign_key => col.name
      end

      validate do |record|
        user = Thread.current[:trackzor_user] || Thread.current[:acts_as_audited_user]

        record.changes.keys.each do |attr|
          time_column = "#{attr}_updated_at"
          user_association = "#{attr}_source"

          if record.respond_to?(time_column.to_sym)
            record.send("#{time_column}=".to_sym, Time.now)
          end

          if record.respond_to?(user_association.to_sym)
            if user
              record.send("#{user_association}=".to_sym, user)
            else
              record.errors.add("#{attr}_updated_by", "requires Trackzor.user or Audit.user to be set")
            end
          end
        end
      end
    end
  end

  # All X attribute changes where X_updated_by exists will be recorded as made by +user+.
  def self.as_user(user, &block)
    Thread.current[:trackzor_user] = user

    yield

    Thread.current[:trackzor_user] = nil
  end
end

class ActiveRecord::Base
  include Trackzor
end
