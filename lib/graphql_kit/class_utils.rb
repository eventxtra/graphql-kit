class GraphqlKit::ClassUtils
  class << self
    def ancestor_distance(subject_class, target)
      subject_class <= target and subject_class.ancestors.index(target)
    end

    def closest_ancestor(subject_class, candidate_classes)
      candidate_classes
        .collect { |candidate| candidate_distance(subject_class, candidate) }
        .compact
        .sort_by { |candidate, distance| distance }
        .lazy
        .collect { |candidate, distance| candidate }.first
    end

    private

    def candidate_distance(subject_class, candidate)
      distance = ancestor_distance(subject_class, candidate)
      distance and [candidate, distance]
    end
  end
end
