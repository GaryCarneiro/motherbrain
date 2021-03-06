module MotherBrain
  module Gear
    class Service < Gear::Base
      register_gear :service

      class << self
        # Finds a gear identified by name in the list of gears supplied.
        #
        # @param [Array<MB::Gear::Service>] gears
        #   the list of gears to search in
        # @param [#to_s] name
        #   the name of the gear to search for
        #
        # @return [MB::Gear::Service]
        def find(gears, name)
          gears.find { |obj| obj.name == name.to_s }
        end
      end

      # @return [String]
      attr_reader :name
      # @return [Set<Action>]
      attr_reader :actions
      # @return [MB::Component]
      attr_reader :component

      attr_reader :service_group
      attr_reader :service_recipe
      attr_reader :service_attribute

      # @param [MB::Component] component
      # @param [#to_s] name
      def initialize(component, name, &block)
        @name      = name.to_s
        @component = component
        @actions   = Set.new

        if block_given?
          dsl_eval(&block)
        end
      end

      # Find and return the given action
      #
      # @param [String] name
      #
      # @raise [ActionNotFound] if there is no action of the given name defined
      #
      # @return [Gear::Action]
      def action!(name)
        action = action(name)

        unless action
          raise ActionNotFound, "#{self.class.keyword} '#{_attributes_[:name]}' does not have the action '#{name}'"
        end

        action
      end

      # Find and return the given action
      #
      # @param [String] name
      #
      # @raise [ActionNotFound] if there is no action of the given name defined
      #
      # @return [Gear::Action]
      def action(name)
        actions.find { |action| action.name == name }
      end

      # Find and return the stop action
      #
      # @return [Gear::Action]
      def stop_action
        action(:stop)
      end

      # Add a new action to this Service
      #
      # @param [Service::Action] new_action
      #
      # @return [Set<Action>]
      def add_action(new_action)
        if action(new_action.name)
          raise DuplicateAction, "Action '#{new_action.name}' already defined on service '#{_attributes_[:name]}'"
        end

        actions << new_action
      end

      def set_service_group(group)
        @service_group = group
      end

      def set_service_recipe(recipe)
        @service_recipe = recipe
      end

      def set_service_attribute(attribute)
        @service_attribute = attribute
      end

      # Convert a Service to a DynamicService
      #
      # @return [MB::Gears::DynamicService]
      def to_dynamic_service
        log {
          "Service '#{self.name}' does not appear to by a dynamic service. It does not define the following fields which are required for dynamic services: #{self.missing_fields_for_dynamic_service.join(",")}"
        } unless dynamic_service?

        MotherBrain::Gear::DynamicService.new(component.name, name)
      end

      # Indicates whether this service conforms to the dyanamic service pattern
      # 
      # @return TrueClass, FalseClass
      def dynamic_service?
        missing_fields_for_dynamic_service.empty?
      end

      private

        def dsl_eval(&block)
          CleanRoom.new(self).instance_eval do
            instance_eval(&block)
          end
        end

        def missing_fields_for_dynamic_service
          %w[service_group service_recipe service_attribute].collect do |field|
            field if self.instance_variable_get("@#{field}").nil?
          end.compact
        end

        # @api private
        class CleanRoom < CleanRoomBase
          # @param [String] name
          def action(name, &block)
            real_model.add_action Service::Action.new(name, real_model.component, &block)
          end

          def service_group(group)
            real_model.set_service_group(group)
          end

          def service_recipe(recipe)
            real_model.set_service_recipe([recipe].flatten)
          end

          def service_attribute(attribute)
            real_model.set_service_attribute([attribute].flatten)
          end

          private

            attr_reader :component
        end
    end

    require_relative 'service/action'
    require_relative 'service/action_runner'
  end
end
