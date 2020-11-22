class GraphqlKit::MutationErrorEncoder
  attr_reader :error_base_path

  def initialize(error_base_path)
    @error_base_path = error_base_path
  end

  def encode(errors, base_path: nil)
    errors.keys.collect do |field|
      errors[field].each_with_index.collect do |_, error_index|
        error_message = errors.full_messages_for(field)[error_index]
        error_details = errors.details[field][error_index]
        base_path ||= [error_base_path.to_s]
        if field.to_sym == :base
          current_path = base_path
        else
          current_path = base_path + [field.to_s]
        end

        nested_object = error_details[:nested_object]
        if nested_object.is_a?(Enumerable)
          nested_object.collect.with_index do |obj, index|
            nested_object_base_path = current_path + [index]
            if obj.respond_to?(:errors)
              encode(obj.errors, base_path: nested_object_base_path)
            end
          end
        elsif nested_object.respond_to?(:errors)
          encode(nested_object.errors, base_path: base_path)
        else
          {
            type: error_details[:error],
            message: error_message,
            path: current_path,
            details: error_details.except(:error).collect do |key, value|
              { key: key, value: value.to_s }
            end
          }
        end
      end
    end.flatten
  end
end
