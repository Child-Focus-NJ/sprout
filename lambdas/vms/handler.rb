# frozen_string_literal: true

require "json"
require_relative "../shared/logger"
require_relative "session_manager"
require_relative "http_client"
require_relative "resources/inquiry"
require_relative "resources/volunteer"
require_relative "resources/lookup"

# Lambda handler for VMS CRUD operations (sync — API Gateway).
#
# Routes requests based on event["resource"] and event["httpMethod"]:
#   GET    /vms/inquiries          → list inquiries
#   POST   /vms/inquiries          → create inquiry
#   PUT    /vms/inquiries/{id}     → edit inquiry
#   DELETE /vms/inquiries/{id}     → delete inquiry
#   GET    /vms/volunteers         → list volunteers
#   POST   /vms/volunteers         → create volunteer
#   GET    /vms/lookups/{type}     → list lookup values

def handler(event:, context:)
  Shared::Log.logger.info("vms invoked — request_id=#{context.aws_request_id}")

  method = event["httpMethod"]
  path = event["path"] || ""
  body = JSON.parse(event["body"] || "{}")
  params = event["queryStringParameters"] || {}
  path_params = event["pathParameters"] || {}

  session = Vms::SessionManager.new
  http = Vms::HttpClient.new(session)

  route(method, path, body, params, path_params, http)
rescue StandardError => e
  Shared::Log.logger.error("vms error: #{e.class} — #{e.message}\n#{e.backtrace&.first(5)&.join("\n")}")

  {
    statusCode: 500,
    headers: { "Content-Type" => "application/json" },
    body: JSON.generate(error: e.message)
  }
end

private

def route(method, path, body, params, path_params, http)
  segments = path.split("/").reject(&:empty?)
  # segments[0] = "vms", segments[1] = resource, segments[2] = id or sub-resource

  resource = segments[1]
  id = path_params["id"] || path_params["type"] || segments[2]

  case resource
  when "inquiries"
    inquiry = Vms::Resources::Inquiry.new(http)
    route_inquiry(method, id, body, params, inquiry)
  when "volunteers"
    volunteer = Vms::Resources::Volunteer.new(http)
    route_volunteer(method, body, params, volunteer)
  when "lookups"
    lookup = Vms::Resources::Lookup.new(http)
    route_lookup(id, lookup)
  else
    {
      statusCode: 404,
      headers: { "Content-Type" => "application/json" },
      body: JSON.generate(error: "Unknown resource: #{resource}")
    }
  end
end

def route_inquiry(method, id, body, params, inquiry)
  case method
  when "GET"
    inquiry.list(params)
  when "POST"
    inquiry.create(body)
  when "PUT"
    return missing_id_response("inquiry") unless id
    inquiry.edit(id, body)
  when "DELETE"
    return missing_id_response("inquiry") unless id
    inquiry.delete(id)
  else
    method_not_allowed(method)
  end
end

def route_volunteer(method, body, params, volunteer)
  case method
  when "GET"
    volunteer.list(params)
  when "POST"
    volunteer.create(body)
  else
    method_not_allowed(method)
  end
end

def route_lookup(type, lookup)
  return missing_id_response("lookup type") unless type
  lookup.list(type)
end

def missing_id_response(name)
  {
    statusCode: 400,
    headers: { "Content-Type" => "application/json" },
    body: JSON.generate(error: "Missing #{name} ID in path")
  }
end

def method_not_allowed(method)
  {
    statusCode: 405,
    headers: { "Content-Type" => "application/json" },
    body: JSON.generate(error: "Method not allowed: #{method}")
  }
end
