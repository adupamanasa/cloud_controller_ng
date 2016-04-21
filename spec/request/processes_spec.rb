require 'spec_helper'

describe 'Processes' do
  let(:space) { VCAP::CloudController::Space.make }
  let(:app_model) { VCAP::CloudController::AppModel.make(space_guid: space.guid, name: 'my_app') }
  let(:developer) { make_developer_for_space(space) }
  let(:developer_headers) { headers_for(developer) }

  describe 'GET /v3/processes' do
    it 'returns a paginated list of processes' do
      process1 = VCAP::CloudController::ProcessModel.make(
        :process,
        app:        app_model,
        space:      space,
        type:       'web',
        instances:  2,
        memory:     1024,
        disk_quota: 1024,
        command:    'rackup',
      )
      process2 = VCAP::CloudController::ProcessModel.make(
        :process,
        app:        app_model,
        space:      space,
        type:       'worker',
        instances:  1,
        memory:     100,
        disk_quota: 200,
        command:    'start worker',
      )
      VCAP::CloudController::ProcessModel.make(:process, app: app_model, space: space)

      get '/v3/processes?per_page=2', nil, developer_headers

      expected_response = {
        'pagination' => {
          'total_results' => 3,
          'first'         => { 'href' => '/v3/processes?page=1&per_page=2' },
          'last'          => { 'href' => '/v3/processes?page=2&per_page=2' },
          'next'          => { 'href' => '/v3/processes?page=2&per_page=2' },
          'previous'      => nil,
        },
        'resources' => [
          {
            'guid'         => process1.guid,
            'type'         => 'web',
            'command'      => 'rackup',
            'instances'    => 2,
            'memory_in_mb' => 1024,
            'disk_in_mb'   => 1024,
            'ports'        => [8080],
            'health_check' => {
              'type' => 'port',
              'data' => {
                'timeout' => nil
              }
            },
            'created_at'   => iso8601,
            'updated_at'   => nil,
            'links'        => {
              'self'  => { 'href' => "/v3/processes/#{process1.guid}" },
              'scale' => { 'href' => "/v3/processes/#{process1.guid}/scale", 'method' => 'PUT' },
              'app'   => { 'href' => "/v3/apps/#{app_model.guid}" },
              'space' => { 'href' => "/v2/spaces/#{space.guid}" },
            },
          },
          {
            'guid'         => process2.guid,
            'type'         => 'worker',
            'command'      => 'start worker',
            'instances'    => 1,
            'memory_in_mb' => 100,
            'disk_in_mb'   => 200,
            'ports'        => [],
            'health_check' => {
              'type' => 'port',
              'data' => {
                'timeout' => nil
              }
            },
            'created_at'   => iso8601,
            'updated_at'   => nil,
            'links'        => {
              'self'  => { 'href' => "/v3/processes/#{process2.guid}" },
              'scale' => { 'href' => "/v3/processes/#{process2.guid}/scale", 'method' => 'PUT' },
              'app'   => { 'href' => "/v3/apps/#{app_model.guid}" },
              'space' => { 'href' => "/v2/spaces/#{space.guid}" },
            },
          }
        ]
      }

      parsed_response = MultiJson.load(last_response.body)

      expect(last_response.status).to eq(200)
      expect(parsed_response).to be_a_response_like(expected_response)
    end
  end

  describe 'GET /v3/processes/:guid' do
    it 'retrieves the process' do
      process = VCAP::CloudController::ProcessModel.make(
        :process,
        app:        app_model,
        space:      space,
        type:       'web',
        instances:  2,
        memory:     1024,
        disk_quota: 1024,
        command:    'rackup',
      )

      get "/v3/processes/#{process.guid}", nil, developer_headers

      expected_response = {
        'guid'         => process.guid,
        'type'         => 'web',
        'command'      => 'rackup',
        'instances'    => 2,
        'memory_in_mb' => 1024,
        'disk_in_mb'   => 1024,
        'ports'        => [8080],
        'health_check' => {
          'type' => 'port',
          'data' => {
            'timeout' => nil
          }
        },
        'created_at'   => iso8601,
        'updated_at'   => nil,
        'links'        => {
          'self'  => { 'href' => "/v3/processes/#{process.guid}" },
          'scale' => { 'href' => "/v3/processes/#{process.guid}/scale", 'method' => 'PUT' },
          'app'   => { 'href' => "/v3/apps/#{app_model.guid}" },
          'space' => { 'href' => "/v2/spaces/#{space.guid}" },
        },
      }

      parsed_response = MultiJson.load(last_response.body)

      expect(last_response.status).to eq(200)
      expect(parsed_response).to be_a_response_like(expected_response)
    end
  end

  describe 'GET /v3/processes/:guid/stats' do
    it 'retrieves the stats for a process' do
      process = VCAP::CloudController::ProcessModel.make(:process, type: 'worker', space: space, diego: true)

      usage_time = Time.now.utc.to_s
      tps_response = [{
        process_guid:  process.guid,
        instance_guid: 'instance-A',
        index:         0,
        state:         'RUNNING',
        details:       'some-details',
        uptime:        1,
        since:         101,
        host:          'toast',
        port:          8080,
        stats:         { time: usage_time, cpu: 80, mem: 128, disk: 1024 }
      }].to_json

      process_guid = VCAP::CloudController::Diego::ProcessGuid.from_app(process)
      stub_request(:get, "http://tps.service.cf.internal:1518/v1/actual_lrps/#{process_guid}/stats").to_return(status: 200, body: tps_response)

      get "/v3/processes/#{process.guid}/stats", nil, developer_headers

      expected_response = {
        'pagination' => {
          'total_results' => 1,
          'first'         => { 'href' => "/v3/processes/#{process.guid}/stats" },
          'last'          => { 'href' => "/v3/processes/#{process.guid}/stats" },
          'next'          => nil,
          'previous'      => nil,
        },
        'resources' => [{
          'type'       => 'worker',
          'index'      => 0,
          'state'      => 'RUNNING',
          'usage'      => {
            'time' => usage_time,
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
        }]
      }

      parsed_response = MultiJson.load(last_response.body)

      expect(last_response.status).to eq(200)
      expect(parsed_response).to be_a_response_like(expected_response)
    end
  end

  describe 'PATCH /v3/processes/:guid' do
    it 'updates the process' do
      process = VCAP::CloudController::ProcessModel.make(
        :process,
        diego:      true,
        app:        app_model,
        space:      space,
        type:       'web',
        instances:  2,
        memory:     1024,
        disk_quota: 1024,
        command:    'rackup',
        ports:      [4444, 5555],
        health_check_type: 'port',
        health_check_timeout: 10
      )

      update_request = {
        command: 'new command',
        ports: [1234, 5678],
        health_check: {
          type: 'process',
          data: {
            timeout: 20
          }
        }
      }.to_json

      patch "/v3/processes/#{process.guid}", update_request, developer_headers.merge('CONTENT_TYPE' => 'application/json')

      expected_response = {
        'guid'         => process.guid,
        'type'         => 'web',
        'command'      => 'new command',
        'instances'    => 2,
        'memory_in_mb' => 1024,
        'disk_in_mb'   => 1024,
        'ports'        => [1234, 5678],
        'health_check' => {
          'type' => 'process',
          'data' => {
            'timeout' => 20
          }
        },
        'created_at'   => iso8601,
        'updated_at'   => iso8601,
        'links'        => {
          'self'  => { 'href' => "/v3/processes/#{process.guid}" },
          'scale' => { 'href' => "/v3/processes/#{process.guid}/scale", 'method' => 'PUT' },
          'app'   => { 'href' => "/v3/apps/#{app_model.guid}" },
          'space' => { 'href' => "/v2/spaces/#{space.guid}" },
        },
      }

      parsed_response = MultiJson.load(last_response.body)

      expect(last_response.status).to eq(200)
      expect(parsed_response).to be_a_response_like(expected_response)

      process.reload
      expect(process.command).to eq('new command')
      expect(process.health_check_type).to eq('process')
      expect(process.health_check_timeout).to eq(20)
      expect(process.ports).to match_array([1234, 5678])

      event = VCAP::CloudController::Event.last
      expect(event.values).to include({
        type:              'audit.app.process.update',
        actee:             app_model.guid,
        actee_type:        'v3-app',
        actee_name:        'my_app',
        actor:             developer.guid,
        actor_type:        'user',
        space_guid:        space.guid,
        organization_guid: space.organization.guid
      })
      expect(event.metadata).to eq({
        'process_guid' => process.guid,
        'process_type' => 'web',
        'request'      => {
          'command' => 'PRIVATE DATA HIDDEN',
          'ports' => [1234, 5678],
          'health_check' => {
            'type' => 'process',
            'data' => {
              'timeout' => 20,
            }
          }
        }
      })
    end
  end

  describe 'PUT /v3/processes/:guid/scale' do
    it 'scales the process' do
      process = VCAP::CloudController::ProcessModel.make(
        :process,
        app:        app_model,
        space:      space,
        type:       'web',
        instances:  2,
        memory:     1024,
        disk_quota: 1024,
        command:    'rackup',
      )

      scale_request = {
        instances:    5,
        memory_in_mb: 10,
        disk_in_mb:   20,
      }

      put "/v3/processes/#{process.guid}/scale", scale_request, developer_headers

      expected_response = {
        'guid'         => process.guid,
        'type'         => 'web',
        'command'      => 'rackup',
        'instances'    => 5,
        'memory_in_mb' => 10,
        'disk_in_mb'   => 20,
        'ports'        => [8080],
        'health_check' => {
          'type' => 'port',
          'data' => {
            'timeout' => nil
          }
        },
        'created_at'   => iso8601,
        'updated_at'   => iso8601,
        'links'        => {
          'self'  => { 'href' => "/v3/processes/#{process.guid}" },
          'scale' => { 'href' => "/v3/processes/#{process.guid}/scale", 'method' => 'PUT' },
          'app'   => { 'href' => "/v3/apps/#{app_model.guid}" },
          'space' => { 'href' => "/v2/spaces/#{space.guid}" },
        },
      }

      parsed_response = MultiJson.load(last_response.body)

      expect(last_response.status).to eq(202)
      expect(parsed_response).to be_a_response_like(expected_response)

      process.reload
      expect(process.instances).to eq(5)
      expect(process.memory).to eq(10)
      expect(process.disk_quota).to eq(20)

      events = VCAP::CloudController::Event.where(actor: developer.guid).all

      process_event = events.find { |e| e.type == 'audit.app.process.scale' }
      expect(process_event.values).to include({
        type:              'audit.app.process.scale',
        actee:             app_model.guid,
        actee_type:        'v3-app',
        actee_name:        'my_app',
        actor:             developer.guid,
        actor_type:        'user',
        space_guid:        space.guid,
        organization_guid: space.organization.guid
      })
      expect(process_event.metadata).to eq({
        'process_guid' => process.guid,
        'process_type' => 'web',
        'request'      => {
          'instances' => '5',
          'memory_in_mb' => '10',
          'disk_in_mb' => '20'
        }
      })
    end
  end

  describe 'DELETE /v3/processes/:guid/instances/:index' do
    it 'terminates a single instance of a process' do
      process = VCAP::CloudController::ProcessModel.make(:process, space: space, type: 'web', app: app_model)

      process_guid = VCAP::CloudController::Diego::ProcessGuid.from_app(process)
      stub_request(:delete, "http://nsync.service.cf.internal:8787/v1/apps/#{process_guid}/index/0").to_return(status: 202, body: '')

      delete "/v3/processes/#{process.guid}/instances/0", nil, developer_headers

      expect(last_response.status).to eq(204)

      events = VCAP::CloudController::Event.where(actor: developer.guid).all
      process_event = events.find { |e| e.type == 'audit.app.process.terminate_instance' }
      expect(process_event.values).to include({
        type:              'audit.app.process.terminate_instance',
        actee:             app_model.guid,
        actee_type:        'v3-app',
        actee_name:        'my_app',
        actor:             developer.guid,
        actor_type:        'user',
        space_guid:        space.guid,
        organization_guid: space.organization.guid
      })
      expect(process_event.metadata).to eq({
        'process_guid' => process.guid,
        'process_type' => 'web',
        'process_index' => 0
      })
    end
  end

  describe 'GET /v3/apps/:guid/processes' do
    it 'returns a paginated list of processes for an app' do
      process1 = VCAP::CloudController::ProcessModel.make(
        :process,
        app:        app_model,
        space:      space,
        type:       'web',
        instances:  2,
        memory:     1024,
        disk_quota: 1024,
        command:    'rackup',
      )
      process2 = VCAP::CloudController::ProcessModel.make(
        :process,
        app:        app_model,
        space:      space,
        type:       'worker',
        instances:  1,
        memory:     100,
        disk_quota: 200,
        command:    'start worker',
      )
      VCAP::CloudController::ProcessModel.make(:process, app: app_model, space: space)

      get "/v3/apps/#{app_model.guid}/processes?per_page=2", nil, developer_headers

      expected_response = {
        'pagination' => {
          'total_results' => 3,
          'first'         => { 'href' => "/v3/apps/#{app_model.guid}/processes?page=1&per_page=2" },
          'last'          => { 'href' => "/v3/apps/#{app_model.guid}/processes?page=2&per_page=2" },
          'next'          => { 'href' => "/v3/apps/#{app_model.guid}/processes?page=2&per_page=2" },
          'previous'      => nil,
        },
        'resources' => [
          {
            'guid'         => process1.guid,
            'type'         => 'web',
            'command'      => 'rackup',
            'instances'    => 2,
            'memory_in_mb' => 1024,
            'disk_in_mb'   => 1024,
            'ports'        => [8080],
            'health_check' => {
              'type' => 'port',
              'data' => {
                'timeout' => nil
              }
            },
            'created_at'   => iso8601,
            'updated_at'   => nil,
            'links'        => {
              'self'  => { 'href' => "/v3/processes/#{process1.guid}" },
              'scale' => { 'href' => "/v3/processes/#{process1.guid}/scale", 'method' => 'PUT' },
              'app'   => { 'href' => "/v3/apps/#{app_model.guid}" },
              'space' => { 'href' => "/v2/spaces/#{space.guid}" },
            },
          },
          {
            'guid'         => process2.guid,
            'type'         => 'worker',
            'command'      => 'start worker',
            'instances'    => 1,
            'memory_in_mb' => 100,
            'disk_in_mb'   => 200,
            'ports'        => [],
            'health_check' => {
              'type' => 'port',
              'data' => {
                'timeout' => nil
              }
            },
            'created_at'   => iso8601,
            'updated_at'   => nil,
            'links'        => {
              'self'  => { 'href' => "/v3/processes/#{process2.guid}" },
              'scale' => { 'href' => "/v3/processes/#{process2.guid}/scale", 'method' => 'PUT' },
              'app'   => { 'href' => "/v3/apps/#{app_model.guid}" },
              'space' => { 'href' => "/v2/spaces/#{space.guid}" },
            },
          }
        ]
      }

      parsed_response = MultiJson.load(last_response.body)

      expect(last_response.status).to eq(200)
      expect(parsed_response).to be_a_response_like(expected_response)
    end
  end

  describe 'GET /v3/apps/:guid/processes/:type' do
    it 'retrieves the process for an app with the requested type' do
      process = VCAP::CloudController::ProcessModel.make(
        :process,
        app:        app_model,
        space:      space,
        type:       'web',
        instances:  2,
        memory:     1024,
        disk_quota: 1024,
        command:    'rackup',
      )

      get "/v3/apps/#{app_model.guid}/processes/web", nil, developer_headers

      expected_response = {
        'guid'         => process.guid,
        'type'         => 'web',
        'command'      => 'rackup',
        'instances'    => 2,
        'memory_in_mb' => 1024,
        'disk_in_mb'   => 1024,
        'ports'        => [8080],
        'health_check' => {
          'type' => 'port',
          'data' => {
            'timeout' => nil
          }
        },
        'created_at'   => iso8601,
        'updated_at'   => nil,
        'links'        => {
          'self'  => { 'href' => "/v3/processes/#{process.guid}" },
          'scale' => { 'href' => "/v3/processes/#{process.guid}/scale", 'method' => 'PUT' },
          'app'   => { 'href' => "/v3/apps/#{app_model.guid}" },
          'space' => { 'href' => "/v2/spaces/#{space.guid}" },
        },
      }

      parsed_response = MultiJson.load(last_response.body)

      expect(last_response.status).to eq(200)
      expect(parsed_response).to be_a_response_like(expected_response)
    end
  end

  describe 'GET /v3/apps/:guid/processes/:type/stats' do
    it 'retrieves the stats for a process belonging to an app' do
      process = VCAP::CloudController::ProcessModel.make(:process, type: 'worker', app: app_model, space: space, diego: true)

      usage_time = Time.now.utc.to_s
      tps_response = [{
        process_guid:  process.guid,
        instance_guid: 'instance-A',
        index:         0,
        state:         'RUNNING',
        details:       'some-details',
        uptime:        1,
        since:         101,
        host:          'toast',
        port:          8080,
        stats:         { time: usage_time, cpu: 80, mem: 128, disk: 1024 }
      }].to_json

      process_guid = VCAP::CloudController::Diego::ProcessGuid.from_app(process)
      stub_request(:get, "http://tps.service.cf.internal:1518/v1/actual_lrps/#{process_guid}/stats").to_return(status: 200, body: tps_response)

      get "/v3/apps/#{app_model.guid}/processes/worker/stats", nil, developer_headers

      expected_response = {
        'pagination' => {
          'total_results' => 1,
          'first'         => { 'href' => "/v3/apps/#{app_model.guid}/processes/worker/stats" },
          'last'          => { 'href' => "/v3/apps/#{app_model.guid}/processes/worker/stats" },
          'next'          => nil,
          'previous'      => nil,
        },
        'resources' => [{
          'type'       => 'worker',
          'index'      => 0,
          'state'      => 'RUNNING',
          'usage'      => {
            'time' => usage_time,
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
        }]
      }

      parsed_response = MultiJson.load(last_response.body)

      expect(last_response.status).to eq(200)
      expect(parsed_response).to be_a_response_like(expected_response)
    end
  end

  describe 'PUT /v3/apps/:guid/processes/:type/scale' do
    it 'scales the process belonging to an app' do
      process = VCAP::CloudController::ProcessModel.make(
        :process,
        app:        app_model,
        space:      space,
        type:       'web',
        instances:  2,
        memory:     1024,
        disk_quota: 1024,
        command:    'rackup',
      )

      scale_request = {
        instances:    5,
        memory_in_mb: 10,
        disk_in_mb:   20,
      }

      put "/v3/apps/#{app_model.guid}/processes/web/scale", scale_request, developer_headers

      expected_response = {
        'guid'         => process.guid,
        'type'         => 'web',
        'command'      => 'rackup',
        'instances'    => 5,
        'memory_in_mb' => 10,
        'disk_in_mb'   => 20,
        'ports'        => [8080],
        'health_check' => {
          'type' => 'port',
          'data' => {
            'timeout' => nil
          }
        },
        'created_at'   => iso8601,
        'updated_at'   => iso8601,
        'links'        => {
          'self'  => { 'href' => "/v3/processes/#{process.guid}" },
          'scale' => { 'href' => "/v3/processes/#{process.guid}/scale", 'method' => 'PUT' },
          'app'   => { 'href' => "/v3/apps/#{app_model.guid}" },
          'space' => { 'href' => "/v2/spaces/#{space.guid}" },
        },
      }

      parsed_response = MultiJson.load(last_response.body)

      expect(last_response.status).to eq(202)
      expect(parsed_response).to be_a_response_like(expected_response)

      process.reload
      expect(process.instances).to eq(5)
      expect(process.memory).to eq(10)
      expect(process.disk_quota).to eq(20)

      events = VCAP::CloudController::Event.where(actor: developer.guid).all

      process_event = events.find { |e| e.type == 'audit.app.process.scale' }
      expect(process_event.values).to include({
        type:              'audit.app.process.scale',
        actee:             app_model.guid,
        actee_type:        'v3-app',
        actee_name:        'my_app',
        actor:             developer.guid,
        actor_type:        'user',
        space_guid:        space.guid,
        organization_guid: space.organization.guid
      })
      expect(process_event.metadata).to eq({
        'process_guid' => process.guid,
        'process_type' => 'web',
        'request'      => {
          'instances' => '5',
          'memory_in_mb' => '10',
          'disk_in_mb' => '20'
        }
      })
    end
  end

  describe 'DELETE /v3/apps/:guid/processes/:type/instances/:index' do
    it 'terminates a single instance of a process belonging to an app' do
      process = VCAP::CloudController::ProcessModel.make(:process, type: 'web', app: app_model, space: space)

      process_guid = VCAP::CloudController::Diego::ProcessGuid.from_app(process)
      stub_request(:delete, "http://nsync.service.cf.internal:8787/v1/apps/#{process_guid}/index/0").to_return(status: 202, body: '')

      delete "/v3/apps/#{app_model.guid}/processes/web/instances/0", nil, developer_headers

      expect(last_response.status).to eq(204)

      events = VCAP::CloudController::Event.where(actor: developer.guid).all
      process_event = events.find { |e| e.type == 'audit.app.process.terminate_instance' }
      expect(process_event.values).to include({
        type:              'audit.app.process.terminate_instance',
        actee:             app_model.guid,
        actee_type:        'v3-app',
        actee_name:        'my_app',
        actor:             developer.guid,
        actor_type:        'user',
        space_guid:        space.guid,
        organization_guid: space.organization.guid
      })
      expect(process_event.metadata).to eq({
        'process_guid' => process.guid,
        'process_type' => 'web',
        'process_index' => 0
      })
    end
  end
end
