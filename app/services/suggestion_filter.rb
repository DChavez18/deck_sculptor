class SuggestionFilter
  SIMILARITY_THRESHOLD = 2

  def initialize(suggestions, filter_spec)
    @suggestions = suggestions
    @spec        = filter_spec
  end

  def apply
    return @suggestions if @spec.nil? || @spec["filter_type"].nil?

    case @spec["filter_type"]
    when "type"       then apply_type_filter
    when "similarity" then apply_similarity_filter
    when "combo"      then apply_combo_filter
    else @suggestions
    end
  end

  private

  def apply_type_filter
    @suggestions.select { |s| matches_type_spec?(s[:card]) }
  end

  def matches_type_spec?(card)
    type_line = card["type_line"].to_s
    cmc       = card["cmc"].to_f
    colors    = card["color_identity"] || []
    keywords  = card["keywords"] || []

    return false if @spec["types"].present?    && @spec["types"].none?    { |t|  type_line.include?(t) }
    return false if @spec["subtypes"].present? && @spec["subtypes"].none? { |st| type_line.include?(st) }
    return false if @spec["colors"].present?   && (@spec["colors"] & colors).empty?
    return false if @spec["max_cmc"].present?  && cmc > @spec["max_cmc"]
    return false if @spec["min_cmc"].present?  && cmc < @spec["min_cmc"]
    return false if @spec["keywords"].present? && (@spec["keywords"] & keywords).empty?

    true
  end

  def apply_similarity_filter
    reference_name = @spec["reference_card"].to_s
    return @suggestions if reference_name.blank?

    ref_card = CardCache.fetch_by_name(reference_name) ||
               ScryfallService.new.find_card_by_name(reference_name)
    return @suggestions if ref_card.nil?

    ref_subtypes = extract_subtypes(ref_card["type_line"].to_s)
    ref_keywords = ref_card["keywords"] || []
    ref_cmc      = ref_card["cmc"].to_f
    ref_colors   = ref_card["color_identity"] || []

    @suggestions.select { |s|
      similarity_score(s[:card], ref_subtypes, ref_keywords, ref_cmc, ref_colors) >= SIMILARITY_THRESHOLD
    }
  end

  def similarity_score(card, ref_subtypes, ref_keywords, ref_cmc, ref_colors)
    score = 0
    score += 1 if ref_subtypes.any? && (extract_subtypes(card["type_line"].to_s) & ref_subtypes).any?
    score += 1 if ref_keywords.any? && ((card["keywords"] || []) & ref_keywords).any?
    score += 1 if (card["cmc"].to_f - ref_cmc).abs <= 2
    score += 1 if ref_colors.any?   && ((card["color_identity"] || []) & ref_colors).any?
    score
  end

  def extract_subtypes(type_line)
    type_line.split(/[—\-]/).last.to_s.split.map(&:strip).reject(&:empty?)
  end

  def apply_combo_filter
    reference_name = @spec["reference_card"].to_s
    return @suggestions if reference_name.blank?

    combos = ComboFinderService.new.find_combos([ reference_name ])
    return @suggestions if combos.empty?

    partner_names = combos.flat_map { |c| c[:cards] }
                          .map(&:downcase)
                          .reject { |n| n == reference_name.downcase }
                          .to_set

    @suggestions.select { |s| partner_names.include?(s[:card]["name"].to_s.downcase) }
  end
end
