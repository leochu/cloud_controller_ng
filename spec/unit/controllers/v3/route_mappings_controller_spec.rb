require 'rails_helper'

describe RouteMappingsController, type: :controller do
  let(:membership) { instance_double(VCAP::CloudController::Membership) }
  let(:app) { VCAP::CloudController::AppModel.make }
  let(:space) { app.space }
  let(:org) { space.organization }
  let!(:app_process) { VCAP::CloudController::App.make(app_guid: app.guid, type: 'web', space_guid: space.guid) }
  let(:route) { VCAP::CloudController::Route.make(space: space) }
  let(:process_type) { 'web' }

  describe '#create' do
    let(:req_body) do
      {
        relationships: {
          route:   { guid: route.guid },
          process: { type: process_type }
        }
      }
    end

    before do
      @request.env.merge!(headers_for(VCAP::CloudController::User.make))
      allow(VCAP::CloudController::Membership).to receive(:new).and_return(membership)
      allow(membership).to receive(:has_any_roles?).and_return(true)
    end

    it 'successfully creates a route mapping' do
      post :create, app_guid: app.guid, body: req_body

      expect(response.status).to eq(201)
      expect(parsed_body['guid']).to eq(VCAP::CloudController::RouteMappingModel.last.guid)
    end

    context 'when there is a validation error' do
      let(:process_type) { true }

      it 'raises an unprocessable error' do
        post :create, app_guid: app.guid, body: req_body

        expect(response.body).to include 'UnprocessableEntity'
      end
    end

    context 'when process type is not provided in the request' do
      let(:process_type) { nil }
      let(:route_fetcher) { instance_double(VCAP::CloudController::AddRouteFetcher) }
      before do
        allow(VCAP::CloudController::AddRouteFetcher).to receive(:new).and_return(route_fetcher)
        allow(route_fetcher).to receive(:fetch)
      end

      it 'defaults to "web"' do
        post :create, app_guid: app.guid, body: req_body

        expect(route_fetcher).to have_received(:fetch).with(app.guid, route.guid, 'web')
      end
    end

    context 'when process type is provided in the request' do
      let(:process_type) { 'worker' }
      let(:route_fetcher) { instance_double(VCAP::CloudController::AddRouteFetcher) }
      before do
        allow(VCAP::CloudController::AddRouteFetcher).to receive(:new).and_return(route_fetcher)
        allow(route_fetcher).to receive(:fetch)
      end

      it 'fetches the requested process type' do
        post :create, app_guid: app.guid, body: req_body

        expect(route_fetcher).to have_received(:fetch).with(app.guid, route.guid, 'worker')
      end
    end

    context 'when the requested route does not exist' do
      let(:req_body) do
        {
          relationships: {
            route: { guid: 'bad-route-guid' }
          }
        }
      end

      it 'raises an API 404 error' do
        post :create, app_guid: app.guid, body: req_body

        expect(response.status).to eq 404
        expect(response.body).to include('ResourceNotFound')
        expect(response.body).to include('Route not found')
      end
    end

    context 'when the requested app does not exist' do
      it 'raises an API 404 error' do
        post :create, app_guid: 'bogus-app-guid', body: req_body

        expect(response.status).to eq 404
        expect(response.body).to include 'ResourceNotFound'
        expect(response.body).to include 'App not found'
      end
    end

    context 'when the user does not have write scope' do
      before do
        @request.env.merge!(headers_for(VCAP::CloudController::User.make, scopes: ['cloud_controller.read']))
      end

      it 'raises an ApiError with a 403 code' do
        post :create, app_guid: app.guid, body: req_body

        expect(response.status).to eq(403)
        expect(response.body).to include('NotAuthorized')
      end
    end

    context 'when the user does not have the required space and org roles to see the app or route' do
      before do
        allow(membership).to receive(:has_any_roles?).with(
          [VCAP::CloudController::Membership::SPACE_DEVELOPER,
           VCAP::CloudController::Membership::SPACE_MANAGER,
           VCAP::CloudController::Membership::SPACE_AUDITOR,
           VCAP::CloudController::Membership::ORG_MANAGER], space.guid, org.guid).and_return(false)
      end

      it 'returns a 404 ResourceNotFound error' do
        post :create, app_guid: app.guid, body: req_body

        expect(response.status).to eq 404
        expect(response.body).to include 'ResourceNotFound'
      end
    end

    context 'when the user can read but cannot write to the route' do
      before do
        allow(membership).to receive(:has_any_roles?).with(
          [VCAP::CloudController::Membership::SPACE_DEVELOPER,
           VCAP::CloudController::Membership::SPACE_MANAGER,
           VCAP::CloudController::Membership::SPACE_AUDITOR,
           VCAP::CloudController::Membership::ORG_MANAGER], space.guid, org.guid).
          and_return(true)

        allow(membership).to receive(:has_any_roles?).with([VCAP::CloudController::Membership::SPACE_DEVELOPER], space.guid).
          and_return(false)
      end

      it 'raises ApiError NotAuthorized' do
        post :create, app_guid: app.guid, body: req_body

        expect(response.status).to eq 403
        expect(response.body).to include 'NotAuthorized'
      end
    end

    context 'when the mapping is invalid' do
      before do
        add_route_to_app = instance_double(VCAP::CloudController::AddRouteToApp)
        allow(VCAP::CloudController::AddRouteToApp).to receive(:new).and_return(add_route_to_app)
        allow(add_route_to_app).to receive(:add).and_raise(VCAP::CloudController::AddRouteToApp::InvalidRouteMapping.new('shablam'))
      end

      it 'returns an UnprocessableEntity error' do
        post :create, app_guid: app.guid, body: req_body

        expect(response.status).to eq 422
        expect(response.body).to include 'UnprocessableEntity'
      end
    end

    context 'admin' do
      before do
        @request.env.merge!(admin_headers)
        allow(membership).to receive(:has_any_roles?).and_return(false)
      end

      it 'returns 201' do
        post :create, app_guid: app.guid, body: req_body

        expect(response.status).to eq(201)
      end
    end

    context 'when route is not in the same space as the app' do
      let(:route_in_other_space) { VCAP::CloudController::Route.make(space: VCAP::CloudController::Space.make) }
      let(:req_body) do
        {
          relationships: {
            route:   { guid: route_in_other_space.guid },
            process: { type: 'web' }
          }
        }
      end

      it 'raises UnprocessableRequest' do
        post :create, app_guid: app.guid, body: req_body

        expect(response.status).to eq 422
        expect(response.body).to include 'belong to the same space'
      end
    end
  end

  describe '#show' do
    let(:route_mapping) { VCAP::CloudController::RouteMappingModel.make(app: app, route: route) }

    before do
      @request.env.merge!(headers_for(VCAP::CloudController::User.make))
      allow(VCAP::CloudController::Membership).to receive(:new).and_return(membership)
      allow(membership).to receive(:has_any_roles?).and_return(true)
    end

    it 'successfully get a route mapping' do
      get :show, app_guid: app.guid, route_mapping_guid: route_mapping.guid

      expect(response.status).to eq(200)
      expect(parsed_body['guid']).to eq(VCAP::CloudController::RouteMappingModel.last.guid)
    end

    it 'returns a 404 if the route mapping does not exist' do
      get :show, app_guid: app.guid, route_mapping_guid: 'fake-guid'

      expect(response.status).to eq(404)
      expect(response.body).to include 'ResourceNotFound'
      expect(response.body).to include 'Route mapping not found'
    end

    describe 'access permissions' do
      context 'when the user does not have read scope' do
        before do
          @request.env.merge!(json_headers(headers_for(VCAP::CloudController::User.make, scopes: [])))
        end

        it 'raises 403' do
          get :show, app_guid: app.guid, route_mapping_guid: route_mapping.guid

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
          get :show, app_guid: app.guid, route_mapping_guid: route_mapping.guid

          expect(response.status).to eq 404
          expect(response.body).to include 'ResourceNotFound'
          expect(response.body).to include 'Route mapping not found'
        end
      end
    end
  end

  describe '#index' do
    before do
      @request.env.merge!(headers_for(VCAP::CloudController::User.make))
      allow(VCAP::CloudController::Membership).to receive(:new).and_return(membership)
      allow(membership).to receive(:has_any_roles?).and_return(true)
    end

    it 'returns route mappings the user has roles to see' do
      route_mapping_1 = VCAP::CloudController::RouteMappingModel.make(app_guid: app.guid)
      route_mapping_2 = VCAP::CloudController::RouteMappingModel.make(app_guid: app.guid)
      VCAP::CloudController::RouteMappingModel.make

      get :index, app_guid: app.guid

      response_guids = parsed_body['resources'].map { |r| r['guid'] }
      expect(response.status).to eq(200)
      expect(response_guids).to match_array([route_mapping_1.guid, route_mapping_2.guid])
    end

    context 'when the app does not exist' do
      it 'raises an API 404 error' do
        get :index, app_guid: 'bogus-guid'

        expect(response.body).to include 'ResourceNotFound'
        expect(response.body).to include 'App not found'
        expect(response.status).to eq 404
      end
    end

    context 'when the user is not one of the required roles' do
      before do
        allow(membership).to receive(:has_any_roles?).with(
          [VCAP::CloudController::Membership::SPACE_DEVELOPER,
           VCAP::CloudController::Membership::SPACE_MANAGER,
           VCAP::CloudController::Membership::SPACE_AUDITOR,
           VCAP::CloudController::Membership::ORG_MANAGER], space.guid, org.guid).
          and_return(false)
      end

      it 'raises an API 404 error' do
        get :index, app_guid: app.guid

        expect(response.status).to eq 404
        expect(response.body).to include 'ResourceNotFound'
        expect(response.body).to include 'App not found'
      end
    end

    context 'when the user does not have read scope' do
      before do
        @request.env.merge!(headers_for(VCAP::CloudController::User.make, scopes: ['cloud_controller.write']))
      end

      it 'raises an ApiError with a 403 code' do
        get :index, app_guid: app.guid

        expect(response.status).to eq 403
        expect(response.body).to include 'NotAuthorized'
      end
    end

    context 'admin' do
      before do
        @request.env.merge!(admin_headers)
        allow(membership).to receive(:has_any_roles?).and_return(false)
      end

      it 'succeeds' do
        get :index, app_guid: app.guid

        expect(response.status).to eq 200
      end
    end
  end

  describe '#destroy' do
    before do
      @request.env.merge!(headers_for(VCAP::CloudController::User.make))
      allow(VCAP::CloudController::Membership).to receive(:new).and_return(membership)
      allow(membership).to receive(:has_any_roles?).and_return(true)
    end

    let(:route_mapping) { VCAP::CloudController::RouteMappingModel.make(app: app, route: route) }

    it 'successfully deletes the specified route mapping' do
      delete :destroy, app_guid: app.guid, route_mapping_guid: route_mapping.guid

      expect(response.status).to eq 204
      expect(route_mapping.exists?).to be_falsey
    end

    context 'admin' do
      before do
        @request.env.merge!(admin_headers)
        allow(membership).to receive(:has_any_roles?).and_return(false)
      end

      it 'succeeds' do
        delete :destroy, app_guid: app.guid, route_mapping_guid: route_mapping.guid

        expect(response.status).to eq 204
      end
    end

    context 'when the app does not exist' do
      it 'raises an API 404 error' do
        delete :destroy, app_guid: 'not-exist', route_mapping_guid: route_mapping.guid

        expect(response.body).to include 'ResourceNotFound'
        expect(response.body).to include 'App not found'
        expect(response.status).to eq 404
      end
    end

    context 'when the route mapping does not exist' do
      it 'raises an API 404 error' do
        delete :destroy, app_guid: app.guid, route_mapping_guid: 'not-real'

        expect(response.body).to include 'ResourceNotFound'
        expect(response.body).to include 'Route mapping not found'
        expect(response.status).to eq 404
      end
    end

    context 'when the user is not a space developer' do
      before do
        allow(membership).to receive(:has_any_roles?).with(
          [VCAP::CloudController::Membership::SPACE_DEVELOPER], space.guid).
            and_return(false)
      end

      it 'raises an API 403 error' do
        delete :destroy, app_guid: app.guid, route_mapping_guid: route_mapping.guid

        expect(response.status).to eq 403
        expect(response.body).to include 'NotAuthorized'
      end
    end

    context 'when the user does not have write scope' do
      before do
        @request.env.merge!(headers_for(VCAP::CloudController::User.make, scopes: ['cloud_controller.read']))
      end

      it 'raises an ApiError with a 403 code' do
        delete :destroy, app_guid: app.guid, route_mapping_guid: route_mapping.guid

        expect(response.status).to eq 403
        expect(response.body).to include 'NotAuthorized'
      end
    end
  end
end
