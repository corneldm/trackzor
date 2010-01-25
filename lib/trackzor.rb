module Trackzor
  def self.included(base)
    base.extend ClassMethods
  end

  module ClassMethods
    def trackzored(options = {})
      class_inheritable_reader :trackzor_exempt_columns
      class_inheritable_reader :trackzor_maintained_columns
      class_inheritable_reader :trackzored_columns

      if options[:only]
        except = self.column_names - options[:only].flatten.map(&:to_s)
      else
        except = [self.primary_key, inheritance_column, 'lock_version', 'created_at', 'updated_at']
        except |= Array(options[:except]).collect(&:to_s) if options[:except]
      end
      write_inheritable_attribute :trackzor_exempt_columns, except

      the_trackzored_columns = []
      the_trackzor_maintained_columns = []

      # create ATTR_source associations
      (self.column_names - self.trackzor_exempt_columns).each do |column|
        has_updated_by_col = self.column_names.include?("#{column}_updated_by")
        has_updated_at_col = self.column_names.include?("#{column}_updated_at")

        if has_updated_by_col || has_updated_at_col
          the_trackzored_columns << column
          
          if has_updated_by_col
            belongs_to "#{column}_source".to_sym, :class_name => 'User', :foreign_key => "#{column}_updated_by"
            the_trackzor_maintained_columns << "#{column}_updated_by"
          end

          if has_updated_at_col
            the_trackzor_maintained_columns << "#{column}_updated_at"
          end
        end
      end
      write_inheritable_attribute :trackzored_columns, the_trackzored_columns
      write_inheritable_attribute :trackzor_maintained_columns, the_trackzor_maintained_columns

      if self.respond_to?(:non_audited_columns)
        nac = self.non_audited_columns + the_trackzor_maintained_columns
        write_inheritable_attribute :non_audited_columns, nac
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

    # update multiple attributes and force update of trackzored attributes
    def update_or_touch_attributes!(new_attributes, guard_protected_attributes = true)
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
            send("#{k}_will_change!") if self.trackzored_columns.include?(k)
          else
            raise "unknown attribute: #{k}"
          end
        end
      end

      assign_multiparameter_attributes(multi_parameter_attributes)
      save!
    end

    # merge record with another, accepting the latest values available
    def merge_with(other, unique_id_col = 'id')
      raise "unmergable objects" if other.class.column_names != self.class.column_names || self.send(unique_id_col.to_sym) != other.send(unique_id_col.to_sym)

      column_names = self.class.column_names

      self.trackzored_columns.each do |tc|
        has_updated_by_col = column_names.include?("#{tc}_updated_by")
        has_updated_at_col = column_names.include?("#{tc}_updated_at")
        
        if has_updated_at_col
          self_time = self.send("#{tc}_updated_at".to_sym)
          other_time = other.send("#{tc}_updated_at".to_sym)
        else
          self_time = self.updated_at
          other_time = other.updated_at
        end

        if self_time.nil? || other_time > self_time
          self.send("#{tc}_updated_at=".to_sym, other_time) if has_updated_at_col
          self.send("#{tc}_updated_by=".to_sym, other.send("#{tc}_updated_by".to_sym)) if has_updated_by_col
          self.send("#{tc}=".to_sym, other.send(tc.to_sym))
        end
      end

      if other.updated_at > self.updated_at
        (column_names - self.trackzored_columns - self.trackzor_maintained_columns).each do |c|
          self.send("#{c}=".to_sym, other.send(c.to_sym))
        end
      end

      puts "Merged #{self.send(unique_id_col.to_sym)}: #{self.changes.inspect}" unless self.changes.empty?
      self.send(:update_without_callbacks)
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
