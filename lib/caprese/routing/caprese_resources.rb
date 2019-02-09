require 'action_dispatch/routing/mapper'

class ActionDispatch::Routing::Mapper
  def caprese_resources(*resources)
    options = resources.extract_options!

    resources.each do |r|
      resources r, options do
        yield if block_given?

        member do
          get 'relationships/:relationship',
              to: "#{parent_resource.controller}#get_relationship_definition",
              as: :relationship_definition

          match 'relationships/:relationship',
                to: "#{parent_resource.controller}#update_relationship_definition",
                via: %i[patch post delete]

          get ':relationship(/:relation_primary_key_value)',
              to: "#{parent_resource.controller}#get_relationship_data",
              as: :relationship_data
        end
      end
    end
  end
end
