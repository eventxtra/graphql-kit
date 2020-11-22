class GraphqlKit::TypeTaggedDelegator
  def initialize(tagged_type, delegation_target)
    @tagged_type = tagged_type
    @delegation_target = delegation_target
  end

  def __tagged_type
    @tagged_type
  end

  delegate_missing_to :'@delegation_target'
end
