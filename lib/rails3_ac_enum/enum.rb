module ActiveRecord
  # This is a work around to make ActiveRecord::Base#enum in Rails master works for Rails3
  #
  # Declare an enum attribute where the values map to integers in the database, but can be queried by name. Example:
  #
  #   class Conversation < ActiveRecord::Base
  #     enum status: [ :active, :archived ]
  #   end
  #
  #   Conversation::STATUS # => { active: 0, archived: 1 }
  #
  #   # conversation.update! status: 0
  #   conversation.active!
  #   conversation.active? # => true
  #   conversation.status  # => :active
  #
  #   # conversation.update! status: 1
  #   conversation.archived!
  #   conversation.archived? # => true
  #   conversation.status    # => :archived
  #
  #   # conversation.update! status: 1
  #   conversation.status = :archived
  #
  # You can set the default value from the database declaration, like:
  #
  #   create_table :conversations do |t|
  #     t.column :status, :integer, default: 0
  #   end
  #
  # Good practice is to let the first declared status be the default.
  #
  # Finally, it's also possible to explicitly map the relation between attribute and database integer:
  #
  #   class Conversation < ActiveRecord::Base
  #     enum status: { active: 0, archived: 1 }
  #   end
  module Enum
    def enum(definitions, translates = {})
      klass = self
      definitions.each do |name, values|
        enum_values = {}
        enum_trans = {}
        name        = name.to_sym
        trans = translates[name] || {}

        _enum_methods_module.module_eval do
          # def direction=(value) self[:direction] = DIRECTION[value] end
          define_method("#{name}=") { |value|
            value = value.to_s
            #if enum_values.has_key?(value) 
            #  self[name] = enum_values[value]
            #elsif enum_values.key(value.to_i)
            #  self[name] = value
            #else
            #  raise ArgumentError, "'#{value}' is not a valid #{name}"
            #end
            
            unless enum_values.has_key?(value) 
              raise ArgumentError, "'#{value}' is not a valid #{name}"
            end

            self[name] = enum_values[value]
          }

          # def direction() DIRECTION.key self[:direction] end
          #define_method(name) { enum_values.key self[name] }
          define_method(name) { enum_trans[self[name]] || enum_values.key(self[name]) }

          pairs = values.respond_to?(:each_pair) ? values.each_pair : values.each_with_index
          pairs.each do |value, i|
            enum_values[value.to_s] = i
            if trans.is_a? Array
              enum_trans[value] = trans[i] 
            else
              enum_trans[value] = trans.key i
            end

            # scope :incoming, -> { where direction: 0 }
            klass.scope value, -> { klass.where name => i }

            # def incoming?() direction == 0 end
            define_method("#{value}?") { self[name] == i }

            # def incoming! update! direction: :incoming end
            define_method("#{value}!") { update_attributes! name => value.to_sym }
          end

          self.const_set(name.upcase, enum_values)
          self.const_set("#{name.upcase}_T", enum_trans)
        end
      end
    end

    def _enum_methods_module
      @_enum_methods_module ||= begin
        mod = Module.new
        include mod
        mod
      end
    end
  end
end
