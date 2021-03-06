module VCAP::CloudController
  class RouteMappingsController < RestController::ModelController
    class ValidationError < StandardError
    end
    class RouteMappingTaken < ValidationError
    end

    define_attributes do
      to_one :app, exclude_in: [:update]
      to_one :route, exclude_in: [:update]
      attribute :app_port, Integer, default: nil
    end

    query_parameters :app_guid, :route_guid

    def self.translate_validation_exception(e, attributes)
      port_errors = e.errors.on(:app_port)
      if port_errors && port_errors.include?(:diego_only)
        Errors::ApiError.new_from_details('AppPortMappingRequiresDiego')
      elsif port_errors && port_errors.include?(:not_bound_to_app)
        Errors::ApiError.new_from_details('RoutePortNotEnabledOnApp')
      end
    end

    def before_create
      super
      app_guid = request_attrs['app_guid']
      route_guid = request_attrs['route_guid']
      app_port = get_app_port(app_guid)
      validate_route_mapping(app_guid, app_port, route_guid)
    rescue RouteMappingsController::ValidationError => e
      raise Errors::ApiError.new_from_details(e.class.name.demodulize, e.message)
    end

    def after_create(route_mapping)
      super
      app_guid = request_attrs['app_guid']
      app_port = request_attrs['app_port']
      if app_port.blank?
        app = App.find(guid: app_guid)
        if !app.nil? && !app.ports.blank?
          port = app.ports[0]
          add_warning("Route has been mapped to app port #{port}.")
        end
      end
    end

    def get_app_port(app_guid)
      app_port = request_attrs['app_port']
      if app_port.blank?
        app = App.find(guid: app_guid)
        if !app.nil?
          return app.ports[0] unless app.ports.blank?
        end
      end

      app_port
    end

    def validate_route_mapping(app_guid, app_port, route_guid)
      mappings = RouteMapping.dataset.select_all(RouteMapping.table_name).
        join(App.table_name, id: :app_id).
        join(Route.table_name, id: :"#{RouteMapping.table_name}__route_id").
        where(:"#{RouteMapping.table_name}__app_port" => app_port,
              :"#{App.table_name}__guid" => app_guid,
              :"#{Route.table_name}__guid" => route_guid)
      unless mappings.count == 0
        error_message =  "Route #{route_guid} is mapped to "
        error_message += "port #{app_port} of " unless app_port.blank?
        error_message += "app #{app_guid}"

        raise RouteMappingTaken.new(error_message)
      end
    end

    def delete(guid)
      route_mapping = find_guid_and_validate_access(:delete, guid)

      do_delete(route_mapping)
    end

    define_messages
    define_routes
  end
end
