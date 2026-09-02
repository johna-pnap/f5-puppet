require 'puppet/property'

class Puppet::Property::F5Name < Puppet::Property
  def self.postinit
    @doc ||= 'The /Partition/name of the linked object.
    Valid options: <string>'
  end

  validate do |value|
    fail ArgumentError, "#{name} must be a String" unless value.is_a?(String)
    fail ArgumentError, "#{name} must match the pattern /Partition/name" unless value.match(%r{/[\w\.-]+/[\w\.-]+$})
  end
end
