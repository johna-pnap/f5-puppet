require 'puppet/util/network_device'
require 'puppet/util/network_device/transport'
require 'puppet/util/network_device/transport/base'

class Puppet::Util::NetworkDevice::Transport::F5 < Puppet::Util::NetworkDevice::Transport::Base
  attr_reader :connection

  def initialize(url, _options = {})
    require 'faraday'
    require 'uri'

    if url.start_with?('vault+http://', 'vault+https://')
      creds = resolve_vault_creds(url)
      conn_uri = URI.parse(creds.fetch('url'))
      conn_uri.user = URI.encode_www_form_component(credentials.fetch('username'))
      conn_uri.password = URI.encode_www_form_component(credentials.fetch('password'))
      url = conn_uri.to_s
    end
    @connection = Faraday.new(url: url, ssl: { verify: false })
  end

  def resolve_vault_creds(url)
    require 'faraday'
    require 'json'
    require 'uri'

    vault_uri = URI.parse(url.sub(/\Avault\+/, ''))
    secret_path = vault_uri.path
    vault_uri.path = ''
    vault_uri.query = nil
    vault_uri.fragment = nil

    vault = Faraday.new(url: vault_uri.to_s)
    response = vault.get("/v1#{secret_path}")
    unless response.success?
      fail("Unable to retrieve F5 credentials from Vault: HTTP #{response.status}")
    end

    begin
      JSON.parse(response.body).fetch('data').fetch('data')
    rescue JSON::ParserError, KeyError => e
      fail("Invalid Vault credential response: #{e.message}")
    end
  end

  def call(url, args={})
    result = connection.get(url, args)
    JSON.parse(result.body)
  rescue JSON::ParserError
    # This should be better at handling errors
    return nil
  end

  def failure?(result)
    unless result.status == 200
      fail("REST failure: HTTP status code #{result.status} detected.  Body of failure is: #{result.body}")
    end
  end

  def post(url, json)
    if valid_json?(json)
      result = connection.post do |req|
        req.url url
        req.headers['Content-Type'] = 'application/json'
        req.body = json
      end
      failure?(result)
      return result
    else
      fail('Invalid JSON detected.')
    end
  end

  def put(url, json)
    if valid_json?(json)
      result = connection.put do |req|
        req.url url
        req.headers['Content-Type'] = 'application/json'
        req.body = json
      end
      failure?(result)
      return result
    else
      fail('Invalid JSON detected.')
    end
  end

  def patch(url, json)
    if valid_json?(json)
      result = connection.patch do |req|
        req.url url
        req.headers['Content-Type'] = 'application/json'
        req.body = json
      end
      failure?(result)
      return result
    else
      fail('Invalid JSON detected.')
    end
  end

  def delete(url)
    result = connection.delete(url)
    failure?(result)
    return result
  end

  def valid_json?(json)
    JSON.parse(json)
    return true
  rescue
    return false
  end

  # Given a string containing objects matching /Partition/Object, return an
  # array of all found objects.
  def find_monitors(string)
    return nil if string.nil?
    if string == "default"
      ["default"]
    elsif string =~ %r{/none$}
      ["none"]
    else
      string.scan(/(\/\S+)/).flatten
    end
  end

  # Monitoring:  Parse out the availability integer.
  def find_availability(string)
    return nil if string.nil?
    if string == "default" or string == "none"
      return nil
    end
    # Look for integers within the string.
    matches = string.match(/min\s(\d+)/)
    if matches
      matches[1]
    else
      "all"
    end
  end
end
