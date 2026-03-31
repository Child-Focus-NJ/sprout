# frozen_string_literal: true

class FakeHttpClient
  Call = Struct.new(:method, :path, :body, :headers, keyword_init: true)

  attr_reader :calls

  def initialize
    @calls = []
    @responses = {}
    @hidden_fields = {}
    @csrf_tokens = {}
  end

  # --- Stubbing API ---

  def stub_response(method, path, response)
    @responses["#{method}:#{path}"] = response
  end

  def stub_hidden_fields(path, fields)
    @hidden_fields[path] = fields
  end

  def stub_csrf_token(path, token)
    @csrf_tokens[path] = token
  end

  # --- HttpClient interface ---

  def get(path, headers: {})
    record_call(:get, path, nil, headers)
  end

  def post_form(path, form_data, headers: {})
    record_call(:post_form, path, form_data, headers)
  end

  def post_json(path, data, headers: {})
    record_call(:post_json, path, data, headers)
  end

  def submit_form(get_path, post_path, form_data)
    @calls << Call.new(method: :submit_form_get, path: get_path, body: nil, headers: {})
    record_call(:submit_form, post_path, form_data, {})
  end

  def extract_csrf_token(_html)
    nil
  end

  def extract_hidden_fields(html_or_path)
    # Return stubbed fields if the path was stubbed, otherwise empty hash
    @hidden_fields.values.first || {}
  end

  private

  def record_call(method, path, body, headers)
    @calls << Call.new(method: method, path: path, body: body, headers: headers)
    lookup_key = "#{method}:#{path}"
    @responses[lookup_key] || fallback_response(method)
  end

  # Form submissions default to 302 (ASP.NET MVC success pattern).
  # Other methods fall back to last stubbed response (allows Kendo grid
  # stubs to cover query-string variations).
  def fallback_response(method)
    if %i[post_form submit_form].include?(method)
      default_response
    else
      @responses.values.last || default_response
    end
  end

  def default_response
    response = Net::HTTPFound.new("1.1", "302", "Found")
    allow_body(response)
    response
  end

  def allow_body(response)
    # Net::HTTPResponse needs a body accessor for test purposes
    response.instance_variable_set(:@read, true)
    response.instance_variable_set(:@body, "")
    response
  end
end
