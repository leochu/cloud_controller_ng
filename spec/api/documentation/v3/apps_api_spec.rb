require 'rails_helper'
require 'awesome_print'
require 'rspec_api_documentation/dsl'

resource 'Apps (Experimental)', type: :api do
  let(:user) { VCAP::CloudController::User.make }
  let(:user_header) { headers_for(user)['HTTP_AUTHORIZATION'] }
  header 'AUTHORIZATION', :user_header

  def do_request_with_error_handling
    do_request
    if response_status > 299
      error = MultiJson.load(response_body)
      ap error
      raise error['description']
    end
  end

  get '/v3/apps' do
    parameter :names, 'Names of apps to filter by', valid_values: 'array of strings', example_values: 'names=name1,name2'
    parameter :space_guids, 'Spaces to filter by', valid_values: 'array of strings', example_values: 'space_guids=space_guid1,space_guid2'
    parameter :organization_guids, 'Organizations to filter by', valid_values: 'array of strings', example_values: 'organization_guids=org_guid1,org_guid2'
    parameter :guids, 'App guids to filter by', valid_values: 'array of strings', example_values: 'guid=guid1,guid2'
    parameter :page, 'Page to display', valid_values: '>= 1'
    parameter :per_page, 'Number of results per page', valid_values: '1 - 5000'
    parameter :order_by, 'Value to sort by. Prepend with "+" or "-" to change sort direction to ascending or descending, respectively.',
      valid_values: 'created_at, updated_at', example_value: 'order_by=-created_at'

    let(:name1) { 'my_app1' }
    let(:name2) { 'my_app2' }
    let(:name3) { 'my_app3' }
    let(:environment_variables) { { 'magic' => 'beautiful' } }
    let(:buildpack) { VCAP::CloudController::Buildpack.make }
    let(:lifecycle) { { 'type' => 'buildpack', 'data' => { 'buildpack' => buildpack.name } } }
    let!(:app_model1) { VCAP::CloudController::AppModel.make(name: name1, space_guid: space.guid, created_at: Time.at(1)) }
    let!(:app_model2) { VCAP::CloudController::AppModel.make(name: name2, space_guid: space.guid, created_at: Time.at(2)) }
    let!(:app_model3) { VCAP::CloudController::AppModel.make(
      name:                  name3,
      space_guid:            space.guid,
      environment_variables: environment_variables,
      created_at:            Time.at(3),
    )
    }
    let!(:app_model4) { VCAP::CloudController::AppModel.make(space_guid: VCAP::CloudController::Space.make.guid) }
    let(:space) { VCAP::CloudController::Space.make }
    let(:page) { 1 }
    let(:per_page) { 2 }
    let(:order_by) { '-created_at' }

    before do
      space.organization.add_user user
      space.add_developer user

      VCAP::CloudController::BuildpackLifecycleDataModel.make(app: app_model1)
      VCAP::CloudController::BuildpackLifecycleDataModel.make(app: app_model2)
      VCAP::CloudController::BuildpackLifecycleDataModel.make(app: app_model3)
      VCAP::CloudController::BuildpackLifecycleDataModel.make(app: app_model4)
    end

    example 'List all Apps' do
      do_request_with_error_handling

      expected_response = {
        'pagination' => {
          'total_results' => 3,
          'first'         => { 'href' => "/v3/apps?order_by=#{order_by}&page=1&per_page=2" },
          'last'          => { 'href' => "/v3/apps?order_by=#{order_by}&page=2&per_page=2" },
          'next'          => { 'href' => "/v3/apps?order_by=#{order_by}&page=2&per_page=2" },
          'previous'      => nil,
        },
        'resources'  => [
          {
            'name'                    => name3,
            'guid'                    => app_model3.guid,
            'desired_state'           => app_model3.desired_state,
            'total_desired_instances' => 0,
            'lifecycle'               => {
              'type' => 'buildpack',
              'data' => {
                'buildpack' => app_model3.lifecycle_data.buildpack,
                'stack'     => app_model3.lifecycle_data.stack,
              }
            },
            'created_at'              => iso8601,
            'updated_at'              => nil,
            'environment_variables'   => environment_variables,
            'links'                   => {
              'self'                   => { 'href' => "/v3/apps/#{app_model3.guid}" },
              'processes'              => { 'href' => "/v3/apps/#{app_model3.guid}/processes" },
              'packages'               => { 'href' => "/v3/apps/#{app_model3.guid}/packages" },
              'space'                  => { 'href' => "/v2/spaces/#{space.guid}" },
              'droplets'               => { 'href' => "/v3/apps/#{app_model3.guid}/droplets" },
              'tasks'                  => { 'href' => "/v3/apps/#{app_model3.guid}/tasks" },
              'route_mappings'         => { 'href' => "/v3/apps/#{app_model3.guid}/route_mappings" },
              'start'                  => { 'href' => "/v3/apps/#{app_model3.guid}/start", 'method' => 'PUT' },
              'stop'                   => { 'href' => "/v3/apps/#{app_model3.guid}/stop", 'method' => 'PUT' },
              'assign_current_droplet' => { 'href' => "/v3/apps/#{app_model3.guid}/current_droplet", 'method' => 'PUT' }
            }
          },
          {
            'name'                    => name2,
            'guid'                    => app_model2.guid,
            'desired_state'           => app_model2.desired_state,
            'total_desired_instances' => 0,
            'lifecycle'               => {
              'type' => 'buildpack',
              'data' => {
                'buildpack' => app_model2.lifecycle_data.buildpack,
                'stack'     => app_model2.lifecycle_data.stack,
              }
            },
            'created_at'              => iso8601,
            'updated_at'              => nil,
            'environment_variables'   => {},
            'links'                   => {
              'self'                   => { 'href' => "/v3/apps/#{app_model2.guid}" },
              'processes'              => { 'href' => "/v3/apps/#{app_model2.guid}/processes" },
              'packages'               => { 'href' => "/v3/apps/#{app_model2.guid}/packages" },
              'space'                  => { 'href' => "/v2/spaces/#{space.guid}" },
              'droplets'               => { 'href' => "/v3/apps/#{app_model2.guid}/droplets" },
              'tasks'                  => { 'href' => "/v3/apps/#{app_model2.guid}/tasks" },
              'route_mappings'         => { 'href' => "/v3/apps/#{app_model2.guid}/route_mappings" },
              'start'                  => { 'href' => "/v3/apps/#{app_model2.guid}/start", 'method' => 'PUT' },
              'stop'                   => { 'href' => "/v3/apps/#{app_model2.guid}/stop", 'method' => 'PUT' },
              'assign_current_droplet' => { 'href' => "/v3/apps/#{app_model2.guid}/current_droplet", 'method' => 'PUT' }
            }
          }
        ]
      }

      parsed_response = MultiJson.load(response_body)

      expect(response_status).to eq(200)
      expect(parsed_response).to be_a_response_like(expected_response)
    end

    context 'faceted search' do
      let(:app_model5) { VCAP::CloudController::AppModel.make(name: name1, space_guid: VCAP::CloudController::Space.make.guid) }
      let!(:app_model6) { VCAP::CloudController::AppModel.make(name: name1, space_guid: VCAP::CloudController::Space.make.guid) }
      let(:per_page) { 2 }
      let(:space_guids) { [app_model5.space_guid, space.guid, app_model6.space_guid].join(',') }
      let(:names) { [name1].join(',') }
      let(:user_header) { admin_headers['HTTP_AUTHORIZATION'] }

      before do
        VCAP::CloudController::BuildpackLifecycleDataModel.make(app: app_model5)
        VCAP::CloudController::BuildpackLifecycleDataModel.make(app: app_model6)
      end

      it 'Filters Apps by guids, names, spaces, and organizations' do
        expected_pagination = {
          'total_results' => 3,
          'first'         => { 'href' => "/v3/apps?names=#{name1}&order_by=#{order_by}&page=1&per_page=2&space_guids=#{CGI.escape(space_guids)}" },
          'last'          => { 'href' => "/v3/apps?names=#{name1}&order_by=#{order_by}&page=2&per_page=2&space_guids=#{CGI.escape(space_guids)}" },
          'next'          => { 'href' => "/v3/apps?names=#{name1}&order_by=#{order_by}&page=2&per_page=2&space_guids=#{CGI.escape(space_guids)}" },
          'previous'      => nil
        }

        do_request_with_error_handling

        parsed_response = MultiJson.load(response_body)
        expect(response_status).to eq(200)
        expect(parsed_response['resources'].map { |r| r['name'] }).to eq(['my_app1', 'my_app1'])
        expect(parsed_response['pagination']).to eq(expected_pagination)
      end
    end
  end

  get '/v3/apps/:guid' do
    let(:droplet_guid) { 'a-droplet-guid' }
    let(:environment_variables) { { 'unicorn' => 'horn' } }
    let(:buildpack) { VCAP::CloudController::Buildpack.make }
    let(:app_model) { VCAP::CloudController::AppModel.make(
      name:                  name,
      droplet_guid:          droplet_guid,
      environment_variables: environment_variables
    )
    }
    let(:process1) { VCAP::CloudController::App.make(space: space, instances: 1) }
    let(:process2) { VCAP::CloudController::App.make(space: space, instances: 2) }
    let(:guid) { app_model.guid }
    let(:space_guid) { app_model.space_guid }
    let(:space) { VCAP::CloudController::Space.find(guid: space_guid) }
    let(:name) { 'my_app' }

    before do
      space.organization.add_user user
      space.add_developer user

      app_model.add_process(process1)
      app_model.add_process(process2)

      VCAP::CloudController::BuildpackLifecycleDataModel.make(app: app_model)
    end

    example 'Get an App' do
      do_request_with_error_handling

      expected_response = {
        'name'                    => name,
        'guid'                    => guid,
        'desired_state'           => app_model.desired_state,
        'total_desired_instances' => 3,
        'created_at'              => iso8601,
        'updated_at'              => nil,
        'environment_variables'   => environment_variables,
        'lifecycle'               => {
          'type' => 'buildpack',
          'data' => {
            'buildpack' => app_model.lifecycle_data.buildpack,
            'stack'     => app_model.lifecycle_data.stack,
          }
        },
        'links'                   => {
          'self'                   => { 'href' => "/v3/apps/#{guid}" },
          'processes'              => { 'href' => "/v3/apps/#{guid}/processes" },
          'packages'               => { 'href' => "/v3/apps/#{guid}/packages" },
          'space'                  => { 'href' => "/v2/spaces/#{space_guid}" },
          'droplet'                => { 'href' => "/v3/droplets/#{droplet_guid}" },
          'droplets'               => { 'href' => "/v3/apps/#{guid}/droplets" },
          'tasks'                  => { 'href' => "/v3/apps/#{guid}/tasks" },
          'route_mappings'         => { 'href' => "/v3/apps/#{guid}/route_mappings" },
          'start'                  => { 'href' => "/v3/apps/#{guid}/start", 'method' => 'PUT' },
          'stop'                   => { 'href' => "/v3/apps/#{guid}/stop", 'method' => 'PUT' },
          'assign_current_droplet' => { 'href' => "/v3/apps/#{app_model.guid}/current_droplet", 'method' => 'PUT' }
        }
      }

      parsed_response = MultiJson.load(response_body)
      expect(response_status).to eq(200)
      expect(parsed_response).to be_a_response_like(expected_response)
    end
  end

  post '/v3/apps' do
    let(:space) { VCAP::CloudController::Space.make }
    let(:space_guid) { space.guid }
    let(:name) { 'my_app' }
    let(:buildpack) { VCAP::CloudController::Buildpack.make.name }
    let(:environment_variables) { { 'open' => 'source' } }
    let(:lifecycle) { { 'type' => 'buildpack', 'data' => { 'stack' => nil, 'buildpack' => buildpack } } }

    before do
      space.organization.add_user(user)
      space.add_developer(user)
    end

    body_parameter :name, 'Name of the App', required: true
    body_parameter :"relationships[space][guid]", 'Guid for a particular space', scope: [:relationships, :space], required: true

    body_parameter :environment_variables, 'Environment variables to be used for the App when running', required: false
    body_parameter :lifecycle, 'Lifecycle to be used when creating the app.
    Note: If no lifecycle is provided, lifecycle type defaults to buildpack.
    Data is a required field in lifecycle',
      required: false

    let(:raw_post) do
      MultiJson.load(body_parameters).
        merge(
          {
            relationships: {
              space: { guid: space_guid }
            }
          }).to_json
    end
    header 'Content-Type', 'application/json'
    example 'Create an App' do
      explanation <<-eos
        Creates an app in v3 of the Cloud Controller API.
        Apps must have a valid space guid for creation, which is namespaced under {"relationships": {"space": "your-space-guid"} }.
        See the example below for more information.
      eos

      expect {
        do_request_with_error_handling
      }.to change { VCAP::CloudController::AppModel.count }.by(1)

      created_app       = VCAP::CloudController::AppModel.last
      expected_guid     = created_app.guid
      expected_response = {
        'name'                    => name,
        'guid'                    => expected_guid,
        'desired_state'           => 'STOPPED',
        'total_desired_instances' => 0,
        'lifecycle'               => {
          'type' => 'buildpack',
          'data' => {
            'buildpack' => created_app.lifecycle_data.buildpack,
            'stack'     => created_app.lifecycle_data.stack,
          }
        },
        'created_at'              => iso8601,
        'updated_at'              => nil,
        'environment_variables'   => environment_variables,
        'links'                   => {
          'self'                   => { 'href' => "/v3/apps/#{expected_guid}" },
          'processes'              => { 'href' => "/v3/apps/#{expected_guid}/processes" },
          'packages'               => { 'href' => "/v3/apps/#{expected_guid}/packages" },
          'space'                  => { 'href' => "/v2/spaces/#{space_guid}" },
          'droplets'               => { 'href' => "/v3/apps/#{expected_guid}/droplets" },
          'tasks'                  => { 'href' => "/v3/apps/#{expected_guid}/tasks" },
          'route_mappings'         => { 'href' => "/v3/apps/#{expected_guid}/route_mappings" },
          'start'                  => { 'href' => "/v3/apps/#{expected_guid}/start", 'method' => 'PUT' },
          'stop'                   => { 'href' => "/v3/apps/#{expected_guid}/stop", 'method' => 'PUT' },
          'assign_current_droplet' => { 'href' => "/v3/apps/#{expected_guid}/current_droplet", 'method' => 'PUT' }
        }
      }

      parsed_response = MultiJson.load(response_body)
      expect(response_status).to eq(201)
      expect(parsed_response).to be_a_response_like(expected_response)
      event = VCAP::CloudController::Event.last
      expect(event.values).to include({
            type:              'audit.app.create',
            actee:             expected_guid,
            actee_type:        'v3-app',
            actee_name:        name,
            actor:             user.guid,
            actor_type:        'user',
            space_guid:        space_guid,
            organization_guid: space.organization.guid,
          })
    end

    describe 'docker app' do
      let(:lifecycle) { { 'type' => 'docker', 'data' => {} } }

      before do
        VCAP::CloudController::FeatureFlag.make(name: 'diego_docker', enabled: true, error_message: nil)
      end

      example 'Create a docker app' do
        explanation <<-eos
          Creates an app in v3 of the Cloud Controller API.
          Apps must have a valid space guid for creation, which is namespaced under {"relationships": {"space": "your-space-guid"} }.
          See the example below for more information.
        eos

        expect {
          do_request_with_error_handling
        }.to change { VCAP::CloudController::AppModel.count }.by(1)

        created_app       = VCAP::CloudController::AppModel.last
        expected_guid     = created_app.guid
        expected_response = {
          'name'                    => name,
          'guid'                    => expected_guid,
          'desired_state'           => 'STOPPED',
          'total_desired_instances' => 0,
          'lifecycle'               => {
            'type' => 'docker',
            'data' => {}
          },
          'created_at'              => iso8601,
          'updated_at'              => nil,
          'environment_variables'   => environment_variables,
          'links'                   => {
            'self'                   => { 'href' => "/v3/apps/#{expected_guid}" },
            'processes'              => { 'href' => "/v3/apps/#{expected_guid}/processes" },
            'packages'               => { 'href' => "/v3/apps/#{expected_guid}/packages" },
            'space'                  => { 'href' => "/v2/spaces/#{space_guid}" },
            'droplets'               => { 'href' => "/v3/apps/#{expected_guid}/droplets" },
            'tasks'                  => { 'href' => "/v3/apps/#{expected_guid}/tasks" },
            'route_mappings'         => { 'href' => "/v3/apps/#{expected_guid}/route_mappings" },
            'start'                  => { 'href' => "/v3/apps/#{expected_guid}/start", 'method' => 'PUT' },
            'stop'                   => { 'href' => "/v3/apps/#{expected_guid}/stop", 'method' => 'PUT' },
            'assign_current_droplet' => { 'href' => "/v3/apps/#{expected_guid}/current_droplet", 'method' => 'PUT' }
          }
        }

        parsed_response = MultiJson.load(response_body)
        expect(response_status).to eq(201)
        expect(parsed_response).to be_a_response_like(expected_response)
        event = VCAP::CloudController::Event.last
        expect(event.values).to include({
              type:              'audit.app.create',
              actee:             expected_guid,
              actee_type:        'v3-app',
              actee_name:        name,
              actor:             user.guid,
              actor_type:        'user',
              space_guid:        space_guid,
              organization_guid: space.organization.guid,
            })
      end
    end
  end

  patch '/v3/apps/:guid' do
    let(:space) { VCAP::CloudController::Space.make }
    let(:space_guid) { space.guid }
    let(:droplet) { VCAP::CloudController::DropletModel.make(app_guid: guid) }
    let(:buildpack) { 'http://gitwheel.org/my-app' }
    let(:app_model) { VCAP::CloudController::AppModel.make(name: 'original_name', space_guid: space_guid) }

    let(:stack) { VCAP::CloudController::Stack.make(name: 'redhat') }
    let(:lifecycle) { { 'type' => 'buildpack', 'data' => { 'buildpack' => buildpack, 'stack' => stack.name } } }

    before do
      space.organization.add_user(user)
      space.add_developer(user)
      VCAP::CloudController::BuildpackLifecycleDataModel.make(app: app_model, stack: VCAP::CloudController::Stack.default.name, buildpack: 'og-buildpack')
    end

    body_parameter :name, 'Name of the App'
    body_parameter :environment_variables, 'Environment variables to be used for the App when running'
    body_parameter :lifecycle, 'Lifecycle to be used when updating the app.
    Note: lifecycle type cannot be changed.
    Buildpack can be set to null to allow the backend to auto-detect the appropriate buildpack.
    Stack can be updated, but cannot be null.
    Type and Data are required fields in lifecycle, but lifecycle itself is not required.',
      required: false

    let(:name) { 'new_name' }
    let(:environment_variables) do
      {
        'MY_ENV_VAR' => 'foobar',
        'FOOBAR'     => 'MY_ENV_VAR'
      }
    end
    let(:guid) { app_model.guid }

    let(:raw_post) { body_parameters }
    header 'Content-Type', 'application/json'

    example 'Updating an App' do
      do_request_with_error_handling

      app_model.reload
      expected_response = {
        'name'                    => name,
        'guid'                    => app_model.guid,
        'desired_state'           => app_model.desired_state,
        'total_desired_instances' => 0,
        'lifecycle'               => {
          'type' => 'buildpack',
          'data' => {
            'buildpack' => buildpack,
            'stack'     => stack.name,
          }
        },
        'created_at'              => iso8601,
        'updated_at'              => iso8601,
        'environment_variables'   => environment_variables,
        'links'                   => {
          'self'                   => { 'href' => "/v3/apps/#{app_model.guid}" },
          'processes'              => { 'href' => "/v3/apps/#{app_model.guid}/processes" },
          'packages'               => { 'href' => "/v3/apps/#{app_model.guid}/packages" },
          'space'                  => { 'href' => "/v2/spaces/#{space_guid}" },
          'droplets'               => { 'href' => "/v3/apps/#{app_model.guid}/droplets" },
          'tasks'                  => { 'href' => "/v3/apps/#{app_model.guid}/tasks" },
          'route_mappings'         => { 'href' => "/v3/apps/#{app_model.guid}/route_mappings" },
          'start'                  => { 'href' => "/v3/apps/#{app_model.guid}/start", 'method' => 'PUT' },
          'stop'                   => { 'href' => "/v3/apps/#{app_model.guid}/stop", 'method' => 'PUT' },
          'assign_current_droplet' => { 'href' => "/v3/apps/#{app_model.guid}/current_droplet", 'method' => 'PUT' }
        }
      }

      parsed_response = MultiJson.load(response_body)
      expect(response_status).to eq(200)
      expect(parsed_response).to be_a_response_like(expected_response)
      event = VCAP::CloudController::Event.last
      expect(event.values).to include({
            type:              'audit.app.update',
            actee:             app_model.guid,
            actee_type:        'v3-app',
            actee_name:        name,
            actor:             user.guid,
            actor_type:        'user',
            space_guid:        space_guid,
            organization_guid: space.organization.guid
          })

      metadata_request = { 'name' => 'new_name', 'environment_variables' => 'PRIVATE DATA HIDDEN',
                           'lifecycle'               => { 'type' => 'buildpack', 'data' => { 'buildpack' => buildpack, 'stack' => stack.name } } }
      expect(event.metadata['request']).to eq(metadata_request)
    end
  end

  delete '/v3/apps/:guid' do
    let!(:app_model) { VCAP::CloudController::AppModel.make }
    let!(:package) { VCAP::CloudController::PackageModel.make(app_guid: guid) }
    let!(:droplet) { VCAP::CloudController::DropletModel.make(package_guid: package.guid, app_guid: guid) }
    let!(:process) { VCAP::CloudController::AppFactory.make(app_guid: guid, space_guid: space_guid) }
    let(:guid) { app_model.guid }
    let(:space_guid) { app_model.space_guid }
    let(:space) { VCAP::CloudController::Space.find(guid: space_guid) }

    before do
      space.organization.add_user(user)
      space.add_developer(user)
    end

    example 'Delete an App' do
      do_request_with_error_handling
      expect(response_status).to eq(204)
      expect { app_model.refresh }.to raise_error Sequel::Error, 'Record not found'
      expect { package.refresh }.to raise_error Sequel::Error, 'Record not found'
      expect { droplet.refresh }.to raise_error Sequel::Error, 'Record not found'
      expect { process.refresh }.to raise_error Sequel::Error, 'Record not found'
      event = VCAP::CloudController::Event.last(2).first
      expect(event.values).to include({
            type:              'audit.app.delete-request',
            actee:             app_model.guid,
            actee_type:        'v3-app',
            actee_name:        app_model.name,
            actor:             user.guid,
            actor_type:        'user',
            space_guid:        space_guid,
            organization_guid: space.organization.guid
          })
    end
  end

  put '/v3/apps/:guid/start' do
    let(:space) { VCAP::CloudController::Space.make }
    let(:space_guid) { space.guid }
    let(:droplet) { VCAP::CloudController::DropletModel.make(:buildpack, app_guid: guid, state: VCAP::CloudController::DropletModel::STAGED_STATE) }
    let(:droplet_guid) { droplet.guid }

    let(:app_model) do
      VCAP::CloudController::AppModel.make(name: 'original_name', space_guid: space_guid, desired_state: 'STOPPED')
    end

    before do
      space.organization.add_user(user)
      space.add_developer(user)
      app_model.update(droplet_guid: droplet_guid)
      VCAP::CloudController::BuildpackLifecycleDataModel.make(app: app_model)
    end

    let(:guid) { app_model.guid }

    example 'Starting an App' do
      do_request_with_error_handling

      expected_response = {
        'name'                    => app_model.name,
        'guid'                    => app_model.guid,
        'desired_state'           => 'STARTED',
        'total_desired_instances' => 0,
        'created_at'              => iso8601,
        'updated_at'              => iso8601,
        'environment_variables'   => {},
        'lifecycle'               => {
          'type' => 'buildpack',
          'data' => {
            'buildpack' => app_model.lifecycle_data.buildpack,
            'stack'     => app_model.lifecycle_data.stack,
          }
        },
        'links'                   => {
          'self'                   => { 'href' => "/v3/apps/#{app_model.guid}" },
          'processes'              => { 'href' => "/v3/apps/#{app_model.guid}/processes" },
          'packages'               => { 'href' => "/v3/apps/#{app_model.guid}/packages" },
          'space'                  => { 'href' => "/v2/spaces/#{space_guid}" },
          'droplet'                => { 'href' => "/v3/droplets/#{droplet_guid}" },
          'droplets'               => { 'href' => "/v3/apps/#{guid}/droplets" },
          'tasks'                  => { 'href' => "/v3/apps/#{guid}/tasks" },
          'route_mappings'         => { 'href' => "/v3/apps/#{app_model.guid}/route_mappings" },
          'start'                  => { 'href' => "/v3/apps/#{app_model.guid}/start", 'method' => 'PUT' },
          'stop'                   => { 'href' => "/v3/apps/#{app_model.guid}/stop", 'method' => 'PUT' },
          'assign_current_droplet' => { 'href' => "/v3/apps/#{app_model.guid}/current_droplet", 'method' => 'PUT' }
        }
      }

      parsed_response = MultiJson.load(response_body)
      expect(response_status).to eq(200)
      expect(parsed_response).to be_a_response_like(expected_response)
      event = VCAP::CloudController::Event.last
      expect(event.values).to include({
            type:              'audit.app.start',
            actee:             guid,
            actee_type:        'v3-app',
            actee_name:        app_model.name,
            actor:             user.guid,
            actor_type:        'user',
            space_guid:        space_guid,
            organization_guid: space.organization.guid,
          })
    end
  end

  put '/v3/apps/:guid/stop' do
    let(:space) { VCAP::CloudController::Space.make }
    let(:space_guid) { space.guid }
    let(:droplet) { VCAP::CloudController::DropletModel.make(app_guid: guid, state: VCAP::CloudController::DropletModel::STAGED_STATE) }
    let(:droplet_guid) { droplet.guid }

    let(:app_model) do
      VCAP::CloudController::AppModel.make(name: 'original_name', space_guid: space_guid, desired_state: 'STARTED')
    end

    before do
      space.organization.add_user(user)
      space.add_developer(user)
      app_model.update(droplet_guid: droplet_guid)
      VCAP::CloudController::BuildpackLifecycleDataModel.make(app: app_model)
    end

    let(:guid) { app_model.guid }

    example 'Stopping an App' do
      do_request_with_error_handling

      expected_response = {
        'name'                    => app_model.name,
        'guid'                    => app_model.guid,
        'desired_state'           => 'STOPPED',
        'total_desired_instances' => 0,
        'created_at'              => iso8601,
        'updated_at'              => iso8601,
        'environment_variables'   => {},
        'lifecycle'               => {
          'type' => 'buildpack',
          'data' => {
            'buildpack' => app_model.lifecycle_data.buildpack,
            'stack'     => app_model.lifecycle_data.stack,
          }
        },
        'links'                   => {
          'self'                   => { 'href' => "/v3/apps/#{app_model.guid}" },
          'processes'              => { 'href' => "/v3/apps/#{app_model.guid}/processes" },
          'packages'               => { 'href' => "/v3/apps/#{app_model.guid}/packages" },
          'space'                  => { 'href' => "/v2/spaces/#{space_guid}" },
          'droplet'                => { 'href' => "/v3/droplets/#{droplet_guid}" },
          'droplets'               => { 'href' => "/v3/apps/#{guid}/droplets" },
          'tasks'                  => { 'href' => "/v3/apps/#{guid}/tasks" },
          'route_mappings'         => { 'href' => "/v3/apps/#{app_model.guid}/route_mappings" },
          'start'                  => { 'href' => "/v3/apps/#{app_model.guid}/start", 'method' => 'PUT' },
          'stop'                   => { 'href' => "/v3/apps/#{app_model.guid}/stop", 'method' => 'PUT' },
          'assign_current_droplet' => { 'href' => "/v3/apps/#{app_model.guid}/current_droplet", 'method' => 'PUT' }
        }
      }

      parsed_response = MultiJson.load(response_body)
      expect(response_status).to eq(200)
      expect(parsed_response).to be_a_response_like(expected_response)
      event = VCAP::CloudController::Event.last
      expect(event.values).to include({
            type:              'audit.app.stop',
            actee:             guid,
            actee_type:        'v3-app',
            actee_name:        app_model.name,
            actor:             user.guid,
            actor_type:        'user',
            space_guid:        space_guid,
            organization_guid: space.organization.guid,
          })
    end
  end

  get '/v3/apps/:guid/env' do
    let(:space_name) { 'some_space' }
    let(:space) { VCAP::CloudController::Space.make(name: space_name) }
    let(:space_guid) { space.guid }
    let(:service_instance) { VCAP::CloudController::ManagedServiceInstance.make space: space, tags: ['50% off'] }
    let(:app_model) do
      VCAP::CloudController::AppModel.make(
        name:                  'app_name',
        space_guid:            space_guid,
        environment_variables: {
          'SOME_KEY' => 'some_val'
        }
      )
    end
    let!(:service_binding) do
      VCAP::CloudController::ServiceBindingModel.make service_instance: service_instance, app: app_model, syslog_drain_url: 'https://syslog.example.com/drain'
    end

    before do
      space.organization.add_user(user)
      space.add_developer(user)

      group                  = VCAP::CloudController::EnvironmentVariableGroup.staging
      group.environment_json = { STAGING_ENV: 'staging_value' }
      group.save

      group                  = VCAP::CloudController::EnvironmentVariableGroup.running
      group.environment_json = { RUNNING_ENV: 'running_value' }
      group.save
    end

    let(:guid) { app_model.guid }

    example 'Get the env for an App' do
      do_request_with_error_handling

      expected_response = {
        'staging_env_json'      => {
          'STAGING_ENV' => 'staging_value'
        },
        'running_env_json'      => {
          'RUNNING_ENV' => 'running_value'
        },
        'environment_variables' => {
          'SOME_KEY' => 'some_val'
        },
        'system_env_json'       => {
          'VCAP_SERVICES' => {
            service_instance.service.label => [
              {
                'name'             => service_instance.name,
                'label'            => service_instance.service.label,
                'tags'             => ['50% off'],
                'plan'             => service_instance.service_plan.name,
                'credentials'      => service_binding.credentials,
                'syslog_drain_url' => 'https://syslog.example.com/drain',
                'provider'         => nil
              }
            ]
          }
        },
        'application_env_json'  => {
          'VCAP_APPLICATION' => {
            'limits'           => {
              # 'mem' => 1024,
              # 'disk' => 1024,
              'fds' => 16384
            },
            # 'application_version' => 'a4340b70-5fe6-425f-a319-f6af377ea26b',
            'application_name' => 'app_name',
            'application_uris' => [],
            # 'version' => 'a4340b70-5fe6-425f-a319-f6af377ea26b',
            'name'             => 'app_name',
            'space_name'       => space_name,
            'space_id'         => space_guid,
            'uris'             => [],
            'users'            => nil
          }
        }
      }

      parsed_response = MultiJson.load(response_body)
      expect(response_status).to eq(200)
      expect(parsed_response).to match(expected_response)
    end
  end

  put '/v3/apps/:guid/current_droplet' do
    let(:space) { VCAP::CloudController::Space.make }
    let(:space_guid) { space.guid }
    let(:process_types) { { web: 'start the app' } }
    let(:droplet) { VCAP::CloudController::DropletModel.make(app_guid: guid, process_types: process_types, state: VCAP::CloudController::DropletModel::STAGED_STATE) }
    let(:app_model) { VCAP::CloudController::AppModel.make(name: 'name1', space_guid: space_guid) }

    before do
      space.organization.add_user(user)
      space.add_developer(user)
      VCAP::CloudController::BuildpackLifecycleDataModel.make(app: app_model)
    end

    body_parameter :droplet_guid, 'GUID of the Staged Droplet to be used for the App'

    let(:droplet_guid) { droplet.guid }
    let(:guid) { app_model.guid }

    let(:raw_post) { body_parameters }
    header 'Content-Type', 'application/json'

    example 'Assigning a droplet as an App\'s current droplet' do
      do_request_with_error_handling

      expected_response = {
        'name'                    => app_model.name,
        'guid'                    => app_model.guid,
        'desired_state'           => app_model.desired_state,
        'total_desired_instances' => 1,
        'environment_variables'   => {},
        'created_at'              => iso8601,
        'updated_at'              => iso8601,
        'lifecycle'               => {
          'type' => 'buildpack',
          'data' => {
            'buildpack' => app_model.lifecycle_data.buildpack,
            'stack'     => app_model.lifecycle_data.stack,
          }
        },
        'links'                   => {
          'self'                   => { 'href' => "/v3/apps/#{app_model.guid}" },
          'processes'              => { 'href' => "/v3/apps/#{app_model.guid}/processes" },
          'packages'               => { 'href' => "/v3/apps/#{app_model.guid}/packages" },
          'space'                  => { 'href' => "/v2/spaces/#{space_guid}" },
          'droplet'                => { 'href' => "/v3/droplets/#{droplet_guid}" },
          'droplets'               => { 'href' => "/v3/apps/#{guid}/droplets" },
          'tasks'                  => { 'href' => "/v3/apps/#{guid}/tasks" },
          'route_mappings'         => { 'href' => "/v3/apps/#{app_model.guid}/route_mappings" },
          'start'                  => { 'href' => "/v3/apps/#{app_model.guid}/start", 'method' => 'PUT' },
          'stop'                   => { 'href' => "/v3/apps/#{app_model.guid}/stop", 'method' => 'PUT' },
          'assign_current_droplet' => { 'href' => "/v3/apps/#{app_model.guid}/current_droplet", 'method' => 'PUT' }
        }
      }

      parsed_response = MultiJson.load(response_body)
      expect(response_status).to eq(200)
      expect(parsed_response).to match(expected_response)
      event = VCAP::CloudController::Event.where(actor: user.guid).first
      expect(event.values).to include({
            type:              'audit.app.droplet_mapped',
            actee:             app_model.guid,
            actee_type:        'v3-app',
            actee_name:        app_model.name,
            actor:             user.guid,
            actor_type:        'user',
            space_guid:        space_guid,
            organization_guid: space.organization.guid
          })
      expect(event.metadata).to eq({ 'request' => { 'droplet_guid' => droplet.guid } })
      expect(app_model.reload.processes).not_to be_empty
    end
  end

  get '/v3/apps/:guid/stats' do
    header 'Content-Type', 'application/json'

    let(:app_model) { VCAP::CloudController::AppModel.make }
    let(:process1) { VCAP::CloudController::AppFactory.make(state: 'STARTED', diego: true, type: 'web', instances: 2, app_guid: app_model.guid) }
    let(:guid) { app_model.guid }

    let(:usage_time1) { Time.now.utc.to_s }
    let(:tps_response1) do
      [
        {
          process_guid:  process1.guid,
          instance_guid: 'instance-1-A',
          index:         0,
          state:         'RUNNING',
          details:       'some-details',
          uptime:        1,
          since:         101,
          host:          'toast',
          port:          8080,
          stats:         { time: usage_time1, cpu: 80, mem: 128, disk: 1024 }
        },
        {
          process_guid:  process1.guid,
          instance_guid: 'instance-1-B',
          index:         1,
          state:         'RUNNING',
          details:       'some-details',
          uptime:        1,
          since:         101,
          host:          'toast',
          port:          8080,
          stats:         { time: usage_time1, cpu: 80, mem: 128, disk: 1024 }
        }
      ].to_json
    end

    before do
      process1_guid = VCAP::CloudController::Diego::ProcessGuid.from_app(process1)
      stub_request(:get, "http://tps.service.cf.internal:1518/v1/actual_lrps/#{process1_guid}/stats").to_return(status: 200, body: tps_response1)

      app_model.space.organization.add_user user
      app_model.space.add_developer user
    end

    example 'Get Detailed Stats for an App' do
      do_request_with_error_handling

      expected_response = {
        'processes' => [
          {
            'type'       => process1.type,
            'index'      => 0,
            'state'      => 'RUNNING',
            'usage'      => {
              'time' => usage_time1,
              'cpu'  => 80,
              'mem'  => 128,
              'disk' => 1024,
            },
            'host'       => 'toast',
            'port'       => 8080,
            'uptime'     => 1,
            'mem_quota'  => 1073741824,
            'disk_quota' => 1073741824,
            'fds_quota'  => 16384
          },
          {
            'type'       => process1.type,
            'index'      => 1,
            'state'      => 'RUNNING',
            'usage'      => {
              'time' => usage_time1,
              'cpu'  => 80,
              'mem'  => 128,
              'disk' => 1024,
            },
            'host'       => 'toast',
            'port'       => 8080,
            'uptime'     => 1,
            'mem_quota'  => 1073741824,
            'disk_quota' => 1073741824,
            'fds_quota'  => 16384
          }
        ]
      }

      parsed_response = JSON.parse(response_body)
      expect(response_status).to eq(200)
      expect(parsed_response).to be_a_response_like(expected_response)
    end
  end
end
