module VCAP::CloudController
  class StagingEnvironmentBuilder
    def build(app, space, lifecycle, memory_limit, disk_limit, vars_from_message=nil)
      app_env           = app.environment_variables || {}
      vars_from_message ||= {}
      staging_var_group = EnvironmentVariableGroup.staging.environment_json

      staging_var_group.
        merge(app_env).
        merge(vars_from_message.try(:stringify_keys)).
        merge(lifecycle.staging_environment_variables).
        merge(
          {
            'VCAP_APPLICATION' => vcap_application(app, space, memory_limit, disk_limit),
            'MEMORY_LIMIT'     => memory_limit
          }).
        merge(SystemEnvPresenter.new(app.service_bindings).system_env.stringify_keys)
    end

    private

    def vcap_application(app, space, memory_limit, disk_limit)
      version = SecureRandom.uuid
      uris    = app.routes.map(&:fqdn)
      {
        'limits' => {
          'mem'  => memory_limit,
          'disk' => disk_limit,
          'fds'  => Config.config[:instance_file_descriptor_limit] || 16384,
        },
        'application_id'      => app.guid,
        'application_version' => version,
        'application_name'    => app.name,
        'application_uris'    => uris,
        'version'             => version,
        'name'                => app.name,
        'space_name'          => space.name,
        'space_id'            => space.guid,
        'uris'                => uris,
        'users'               => nil
      }
    end
  end
end
