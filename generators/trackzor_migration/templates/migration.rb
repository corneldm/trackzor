class Trackzorify<%= class_name.pluralize %> < ActiveRecord::Migration
  def self.up<% args.each do |arg| %>
    add_column :<%= table_name %>, :<%= "#{arg}_updated_at" %>, :datetime
    add_column :<%= table_name %>, :<%= "#{arg}_updated_by" %>, :string<% end %>
  end

  def self.down<% args.each do |arg| %>
    remove_column :<%= table_name %>, :<%= "#{arg}_updated_at" %>
    remove_column :<%= table_name %>, :<%= "#{arg}_updated_by" %><% end %>
  end
end
