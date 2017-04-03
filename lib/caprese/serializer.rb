require 'active_model_serializers'
require 'caprese/concerns/versioning'
require 'caprese/serializer/concerns/links'
require 'caprese/serializer/concerns/lookup'
require 'caprese/serializer/concerns/relationships'

module Caprese
  class Serializer < ActiveModel::Serializer
    extend Versioning
    include Versioning
    include Links
    include Lookup
    include Relationships

    def json_key
      object.caprese_type
    end
  end
end
