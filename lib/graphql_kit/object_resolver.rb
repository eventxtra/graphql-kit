class GraphqlKit::ObjectResolver
  attr_reader :schema
  attr_reader :type_mapper
  attr_reader :guid_coder

  def initialize(schema:, type_mapper:, guid_coder:)
    @schema = schema
    @type_mapper = type_mapper
    @guid_coder = guid_coder
  end

  def type_of_object(obj)
    if obj.is_a?(GraphqlKit::RawObject)
      type_name = obj.type
    elsif obj.is_a?(GraphqlKit::TypeTaggedDelegator)
      type_name = @schema.gqt(obj.__tagged_type).graphql_name
    else
      type_name = type_mapper.type_from_object(obj)
    end
    raise "Unexpected object: #{obj}" unless type_name

    schema.types[type_name]
  end

  def id_of_object(object)
    type_definition = type_of_object(object)
    guid_coder.encode(type_definition.graphql_name, object.id)
  end

  def object_by_id(id, finder: :none)
    return nil if finder.nil?

    type_name, item_id = guid_coder.decode(id)

    model_class = type_mapper.model_class_for_graphql_type(type_name)
    if finder == :none
      finder = model_class
    elsif finder.is_a?(Proc)
      finder = finder.call(
        id: id, type_name: type_name, item_id: item_id,
        model_class: model_class
      )
    elsif !type_mapper.model_class_compatible?(type_name, finder.klass)
      finder = nil
    end

    if finder.respond_to?(:find_with_api_id)
      finder&.find_with_api_id(item_id, model_class: model_class)
    else
      finder&.find_by_id(item_id)
    end
  end

  def objects_by_ids(ids, finder:, set_result: false)
    return nil if finder.nil?

    db_ids = ids.collect do |gq_id|
      type_name, db_id = guid_coder.decode(gq_id)
      if type_mapper.model_class_compatible?(type_name, finder.klass)
        db_id
      end
    end
    fetched_objects = finder&.where(id: db_ids)

    if set_result
      fetched_objects.to_set
    else
      id_attr = finder.klass.primary_key
      id_of_obj = proc { |obj| obj.send(id_attr).to_s }

      obj_by_id = fetched_objects.group_by(&id_of_obj).transform_values(&:first)
      db_ids.collect { |db_id| obj_by_id[db_id] }
    end
  end
end
