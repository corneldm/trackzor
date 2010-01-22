module Trackzor
  def self.included(base)
    base.extend ClassMethods
  end

  module ClassMethods
    def trackzored(options = {})
      class_inheritable_reader :trackzor_exempt_columns

      if options[:only]
        except = self.column_names - options[:only].flatten.map(&:to_s)
      else
        except = [self.primary_key, inheritance_column, 'lock_version', 'created_at', 'updated_at']
        except |= Array(options[:except]).collect(&:to_s) if options[:except]
      end
      write_inheritable_attribute :trackzor_exempt_columns, except
      aaa_present = self.respond_to?(:non_audited_columns)

      # create ATTR_source associations
      (self.column_names - self.trackzor_exempt_columns).select{|column| column =~ /(_updated_by|_updated_at)$/ }.each do |col|
        if col =~ /_updated_by$/
          belongs_to col.sub(/_updated_by$/, '_source').to_sym, :class_name => 'User', :foreign_key => col
        end
        self.non_audited_columns << col if aaa_present
      end

      validate :trackzor_assign_and_validate

      include Trackzor::InstanceMethods
    end
  end # ClassMethods

  module InstanceMethods
    def trackzor_assign_and_validate
      user = Thread.current[:trackzor_user] || Thread.current[:acts_as_audited_user]

      self.changes.keys.each do |attr|
        unless self.trackzor_exempt_columns.include?(attr)
          time_column = "#{attr}_updated_at"
          user_association = "#{attr}_source"

          if self.respond_to?(time_column.to_sym)
            self.send("#{time_column}=".to_sym, Time.now)
          end

          if self.respond_to?(user_association.to_sym)
            if user
              self.send("#{user_association}=".to_sym, user)
            else
              self.errors.add("#{attr}_updated_by", "requires Trackzor user to be set")
            end
          end
        end
      end
    end

    # force update of multiple attributes
    def will_update_attributes!(new_attributes, guard_protected_attributes = true)
      return if new_attributes.nil?
      attributes = new_attributes.dup
      attributes.stringify_keys!

      multi_parameter_attributes = []
      attributes = remove_attributes_protected_from_mass_assignment(attributes) if guard_protected_attributes

      attributes.each do |k, v|
        if k.include?("(")
          multi_parameter_attributes << [ k, v ]
        else
          if respond_to?("#{k}=")
            send("#{k}=", v)
            send("#{k}_will_change!")
          else
            raise "unknown attribute: #{k}"
          end
        end
      end

      assign_multiparameter_attributes(multi_parameter_attributes)
      save!
    end
  end # InstanceMethods

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
