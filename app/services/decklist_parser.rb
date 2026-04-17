class DecklistParser
  SECTION_HEADERS = %w[Commander Deck Sideboard Maybeboard].freeze
  SKIP_SECTIONS   = %w[Commander Sideboard Maybeboard].freeze

  def initialize(text)
    @text = text.to_s
  end

  def parse
    current_section = nil
    @text.lines.filter_map do |line|
      line = line.strip
      next if line.blank? || line.start_with?("//", "#")

      if SECTION_HEADERS.any? { |h| line.start_with?(h) }
        current_section = SECTION_HEADERS.find { |h| line.start_with?(h) }
        next
      end

      next if SKIP_SECTIONS.include?(current_section)
      parse_line(line)
    end
  end

  private

  def parse_line(line)
    clean = line.sub(/\s*\([A-Z0-9]{2,6}\)\s*[\w-]*/, "").strip

    if (m = clean.match(/\A(\d+)x?\s+(.+)\z/))
      { name: m[2].strip, quantity: m[1].to_i }
    elsif clean.present?
      { name: clean, quantity: 1 }
    end
  end
end
