require 'rails_helper'
require 'queries/task_list_fetcher'

describe TasksController, type: :controller do
  let(:tasks_enabled) { true }
  let(:membership) { instance_double(VCAP::CloudController::Membership) }
  let(:app_model) { VCAP::CloudController::AppModel.make }
  let(:space) { app_model.space }
  let(:org) { space.organization }

  before do
    VCAP::CloudController::FeatureFlag.make(name: 'task_creation', enabled: tasks_enabled, error_message: nil)

    @request.env.merge!(headers_for(VCAP::CloudController::User.make))

    allow_any_instance_of(TasksController).to receive(:membership).and_return(membership)
    allow(membership).to receive(:has_any_roles?).with(
      [VCAP::CloudController::Membership::SPACE_DEVELOPER], space.guid).and_return(true)
    allow(membership).to receive(:has_any_roles?).with(
      [VCAP::CloudController::Membership::SPACE_DEVELOPER,
       VCAP::CloudController::Membership::SPACE_MANAGER,
       VCAP::CloudController::Membership::SPACE_AUDITOR,
       VCAP::CloudController::Membership::ORG_MANAGER], space.guid, org.guid).and_return(true)
  end

  describe '#create' do
    let(:droplet) do
      VCAP::CloudController::DropletModel.make(
        app_guid: app_model.guid,
        state: VCAP::CloudController::DropletModel::STAGED_STATE)
    end
    let(:req_body) do
      {
        "name": 'mytask',
        "command": 'rake db:migrate && true',
        "memory_in_mb": 2048,
        "environment_variables": {
          "unicorn": 'magic'
        }
      }
    end
    let(:client) { instance_double(VCAP::CloudController::Diego::NsyncClient) }
    let(:task) { Task.make }

    before do
      app_model.droplet = droplet
      app_model.save

      locator = CloudController::DependencyLocator.instance
      allow(locator).to receive(:nsync_client).and_return(client)
      allow(client).to receive(:desire_task).and_return(nil)
    end

    it 'returns a 202 and the task' do
      post :create, guid: app_model.guid, body: req_body

      expect(response.status).to eq 202
      expect(parsed_body['name']).to eq('mytask')
      expect(parsed_body['state']).to eq('RUNNING')
      expect(parsed_body['memory_in_mb']).to eq(2048)
    end

    it 'creates a task for the app' do
      expect(app_model.tasks.count).to eq(0)

      post :create, guid: app_model.guid, body: req_body

      expect(app_model.reload.tasks.count).to eq(1)
      expect(app_model.tasks.first).to eq(VCAP::CloudController::TaskModel.last)
    end

    describe 'access permissions' do
      context 'when the task_creation feature flag is disabled' do
        let(:tasks_enabled) { false }

        it 'raises 403 for non-admins' do
          post :create, guid: app_model.guid, body: req_body

          expect(response.status).to eq(403)
          expect(response.body).to include('FeatureDisabled')
          expect(response.body).to include('task_creation')
        end

        it 'succeeds for admins' do
          @request.env.merge!(admin_headers)
          post :create, guid: app_model.guid, body: req_body

          expect(response.status).to eq(202)
        end
      end

      context 'when the user does not have write scope' do
        before do
          @request.env.merge!(json_headers(headers_for(VCAP::CloudController::User.make, scopes: ['cloud_controller.read'])))
        end

        it 'raises 403' do
          post :create, guid: app_model.guid, body: req_body

          expect(response.status).to eq(403)
          expect(response.body).to include 'NotAuthorized'
        end
      end

      context 'when the user does not have write permissions on the app space' do
        before do
          allow(membership).to receive(:has_any_roles?).with(
            [VCAP::CloudController::Membership::SPACE_DEVELOPER], space.guid).and_return(false)
          allow(membership).to receive(:has_any_roles?).with(
            [VCAP::CloudController::Membership::SPACE_DEVELOPER,
             VCAP::CloudController::Membership::SPACE_MANAGER,
             VCAP::CloudController::Membership::SPACE_AUDITOR,
             VCAP::CloudController::Membership::ORG_MANAGER], space.guid, org.guid).and_return(true)
        end

        it 'returns a 403 unauthorized' do
          post :create, guid: app_model.guid, body: req_body

          expect(response.status).to eq 403
          expect(response.body).to include 'NotAuthorized'
        end
      end

      context 'when the user does not have read permissions on the app space' do
        before do
          allow(membership).to receive(:has_any_roles?).with(
            [VCAP::CloudController::Membership::SPACE_DEVELOPER,
             VCAP::CloudController::Membership::SPACE_MANAGER,
             VCAP::CloudController::Membership::SPACE_AUDITOR,
             VCAP::CloudController::Membership::ORG_MANAGER], space.guid, org.guid).and_return(false)
        end

        it 'returns a 404 ResourceNotFound' do
          post :create, guid: app_model.guid, body: req_body

          expect(response.status).to eq 404
          expect(response.body).to include 'ResourceNotFound'
        end
      end
    end

    context 'when the app does not exist' do
      it 'returns a 404 ResourceNotFound' do
        post :create, guid: 'bogus', body: req_body

        expect(response.status).to eq 404
        expect(response.body).to include 'ResourceNotFound'
        expect(response.body).to include 'App not found'
      end
    end

    context 'when the app does not have an assigned droplet' do
      let(:droplet) { nil }

      it 'returns a 422 and a helpful error' do
        post :create, guid: app_model.guid, body: req_body

        expect(response.status).to eq 422
        expect(response.body).to include 'UnprocessableEntity'
        expect(response.body).to include 'Task must have a droplet. Specify droplet or assign current droplet to app.'
      end
    end

    context 'when the user has requested an invalid field' do
      it 'returns a 400 and a helpful error' do
        req_body.merge! invalid: 'field'

        post :create, guid: app_model.guid, body: req_body

        expect(response.status).to eq 422
        expect(response.body).to include 'UnprocessableEntity'
        expect(response.body).to include "Unknown field(s): 'invalid'"
      end
    end

    context 'when there is a validation failure' do
      it 'returns a 422 and a helpful error' do
        stub_const('VCAP::CloudController::TaskModel::COMMAND_MAX_LENGTH', 6)
        req_body.merge! command: 'a' * 7

        post :create, guid: app_model.guid, body: req_body

        expect(response.status).to eq 422
        expect(response.body).to include 'UnprocessableEntity'
        expect(response.body).to include 'The request is semantically invalid: command must be shorter than 7 characters'
      end
    end

    context 'invalid task' do
      it 'returns a useful error message' do
        post :create, guid: app_model.guid, body: {}

        expect(response.status).to eq 422
        expect(response.body).to include 'UnprocessableEntity'
      end
    end
  end

  describe '#show' do
    let!(:task) { VCAP::CloudController::TaskModel.make name: 'mytask', app_guid: app_model.guid, memory_in_mb: 2048 }

    it 'returns a 200 and the task' do
      get :show, task_guid: task.guid

      expect(response.status).to eq 200
      expect(parsed_body['name']).to eq('mytask')
      expect(parsed_body['memory_in_mb']).to eq(2048)
    end

    context 'when providing an app guid' do
      it 'returns a 200 and the task' do
        get :show, task_guid: task.guid, app_guid: app_model.guid

        expect(response.status).to eq 200
        expect(parsed_body).to include('name' => 'mytask')
      end

      context 'when the requested task does not belong to the provided app guid' do
        it 'returns a 404' do
          other_app = VCAP::CloudController::AppModel.make space_guid: space.guid
          other_task = VCAP::CloudController::TaskModel.make name: 'other_task', app_guid: other_app.guid
          get :show, task_guid: other_task.guid, app_guid: app_model.guid

          expect(response.status).to eq 404
          expect(response.body).to include 'ResourceNotFound'
          expect(response.body).to include 'Task not found'
        end
      end
    end

    describe 'access permissions' do
      context 'when the user does not have read scope' do
        before do
          @request.env.merge!(json_headers(headers_for(VCAP::CloudController::User.make, scopes: [])))
        end

        it 'raises 403' do
          get :show, task_guid: task.guid

          expect(response.status).to eq(403)
          expect(response.body).to include 'NotAuthorized'
        end
      end

      context 'when the user does not have read permissions on the app space' do
        before do
          allow(membership).to receive(:has_any_roles?).with(
            [VCAP::CloudController::Membership::SPACE_DEVELOPER,
             VCAP::CloudController::Membership::SPACE_MANAGER,
             VCAP::CloudController::Membership::SPACE_AUDITOR,
             VCAP::CloudController::Membership::ORG_MANAGER], space.guid, org.guid).and_return(false)
        end

        it 'returns a 404 ResourceNotFound' do
          get :show, task_guid: task.guid

          expect(response.status).to eq 404
          expect(response.body).to include 'ResourceNotFound'
          expect(response.body).to include 'Task not found'
        end
      end
    end

    it 'returns a 404 if the task does not exist' do
      get :show, task_guid: 'bogus'

      expect(response.status).to eq 404
      expect(response.body).to include 'ResourceNotFound'
      expect(response.body).to include 'Task not found'
    end
  end

  describe '#index' do
    before do
      allow(membership).to receive(:space_guids_for_roles).with(
        [VCAP::CloudController::Membership::SPACE_DEVELOPER,
         VCAP::CloudController::Membership::SPACE_MANAGER,
         VCAP::CloudController::Membership::SPACE_AUDITOR]).and_return([space.guid])

      @request.env.merge!(headers_for(VCAP::CloudController::User.make))
      allow(VCAP::CloudController::Membership).to receive(:new).and_return(membership)
      allow(membership).to receive(:has_any_roles?).and_return(true)
    end

    it 'returns tasks the user has roles to see' do
      task_1 = VCAP::CloudController::TaskModel.make(app_guid: app_model.guid)
      task_2 = VCAP::CloudController::TaskModel.make(app_guid: app_model.guid)
      VCAP::CloudController::TaskModel.make

      get :index

      response_guids = parsed_body['resources'].map { |r| r['guid'] }
      expect(response.status).to eq(200)
      expect(response_guids).to match_array([task_1.guid, task_2.guid])
    end

    it 'provides the correct base url in the pagination links' do
      get :index

      expect(parsed_body['pagination']['first']['href']).to include('/v3/tasks')
    end

    context 'when an app is specified' do
      it 'uses the app as a filter' do
        task_list_fetcher = VCAP::CloudController::TaskListFetcher.new
        allow(VCAP::CloudController::TaskListFetcher).to receive(:new).and_return(task_list_fetcher)
        allow(task_list_fetcher).to receive(:fetch).and_call_original

        get :index, app_guid: app_model.guid

        expect(task_list_fetcher).to have_received(:fetch) do |_, _, app_guid|
          expect(app_guid).to eq(app_model.guid)
        end
        expect(response.status).to eq(200)
      end

      it 'provides the correct base url in the pagination links' do
        get :index, app_guid: app_model.guid

        expect(parsed_body['pagination']['first']['href']).to include("/v3/apps/#{app_model.guid}/tasks")
      end

      context 'the app does not exist' do
        it 'returns a 404 Resource Not Found' do
          get :index, app_guid: 'hello-i-do-not-exist'

          expect(response.status).to eq 404
          expect(response.body).to include 'ResourceNotFound'
        end
      end

      context 'when the user does not have permissions to read the app' do
        before do
          allow(membership).to receive(:has_any_roles?).with(
            [VCAP::CloudController::Membership::SPACE_DEVELOPER,
             VCAP::CloudController::Membership::SPACE_MANAGER,
             VCAP::CloudController::Membership::SPACE_AUDITOR,
             VCAP::CloudController::Membership::ORG_MANAGER], space.guid, org.guid).and_return(false)
        end

        it 'returns a 404 Resource Not Found error' do
          get :index, app_guid: app_model.guid

          expect(response.body).to include 'ResourceNotFound'
          expect(response.status).to eq 404
        end
      end
    end

    context 'admin' do
      before do
        @request.env.merge!(admin_headers)
      end

      it 'returns a 200 and all tasks belonging to the app' do
        task_1 = VCAP::CloudController::TaskModel.make(app_guid: app_model.guid)
        task_2 = VCAP::CloudController::TaskModel.make(app_guid: app_model.guid)
        task_3 = VCAP::CloudController::TaskModel.make

        get :index

        response_guids = parsed_body['resources'].map { |r| r['guid'] }
        expect(response.status).to eq(200)
        expect(response_guids).to match_array([task_1, task_2, task_3].map(&:guid))
      end
    end

    describe 'query params errors' do
      context 'invalid param format' do
        it 'returns 400' do
          get :index, per_page: 'meow'

          expect(response.status).to eq 400
          expect(response.body).to include('Per page is not a number')
          expect(response.body).to include('BadQueryParameter')
        end
      end

      context 'unknown query param' do
        it 'returns 400' do
          get :index, meow: 'bad-val', nyan: 'mow'

          expect(response.status).to eq 400
          expect(response.body).to include('BadQueryParameter')
          expect(response.body).to include('Unknown query parameter(s)')
          expect(response.body).to include('nyan')
          expect(response.body).to include('meow')
        end
      end
    end
  end

  describe '#cancel' do
    let!(:task) { VCAP::CloudController::TaskModel.make name: 'usher', app_guid: app_model.guid }
    let(:client) { instance_double(VCAP::CloudController::Diego::NsyncClient) }

    before do
      locator = CloudController::DependencyLocator.instance
      allow(locator).to receive(:nsync_client).and_return(client)
      allow(client).to receive(:cancel_task).and_return(nil)
    end

    it 'returns a 202' do
      put :cancel, task_guid: task.guid

      expect(response.status).to eq 202
      expect(parsed_body['name']).to eq('usher')
      expect(parsed_body['guid']).to eq(task.guid)
    end

    context 'when the task does not exist' do
      it 'returns a 404 ResourceNotFound' do
        put :cancel, task_guid: 'bogus-guid'

        expect(response.status).to eq 404
        expect(response.body).to include 'ResourceNotFound'
        expect(response.body).to include 'Task not found'
      end
    end

    context 'when the task has already succeeded or failed' do
      let(:task_to_cancel) { VCAP::CloudController::TaskModel.make(name: 'ursulina', app_guid: app_model.guid, state: VCAP::CloudController::TaskModel::SUCCEEDED_STATE) }
      it 'returns a 422 InvalidTaskRequest' do
        put :cancel, task_guid: task_to_cancel.guid

        expect(response.status).to eq 422
        expect(response.body).to include('InvalidTaskRequest')
      end
    end

    context 'when the user does not have read permissions on the app space' do
      before do
        allow(membership).to receive(:has_any_roles?).with(
          [VCAP::CloudController::Membership::SPACE_DEVELOPER,
           VCAP::CloudController::Membership::SPACE_MANAGER,
           VCAP::CloudController::Membership::SPACE_AUDITOR,
           VCAP::CloudController::Membership::ORG_MANAGER], space.guid, org.guid).and_return(false)
      end

      it 'returns a 404 ResourceNotFound' do
        put :cancel, task_guid: task.guid

        expect(response.status).to eq 404
        expect(response.body).to include 'ResourceNotFound'
        expect(response.body).to include 'Task not found'
      end
    end

    context 'when the user can see the task but does not have write permissions' do
      before do
        allow(membership).to receive(:has_any_roles?).with(
          [VCAP::CloudController::Membership::SPACE_DEVELOPER], space.guid).and_return(false)
        allow(membership).to receive(:has_any_roles?).with(
          [VCAP::CloudController::Membership::SPACE_DEVELOPER,
           VCAP::CloudController::Membership::SPACE_MANAGER,
           VCAP::CloudController::Membership::SPACE_AUDITOR,
           VCAP::CloudController::Membership::ORG_MANAGER], space.guid, org.guid).and_return(true)
      end

      it 'returns a 403 NotAuthorized' do
        put :cancel, task_guid: task.guid

        expect(response.status).to eq 403
        expect(response.body).to include('NotAuthorized')
      end
    end
  end
end
