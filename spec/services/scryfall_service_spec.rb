require "rails_helper"
require "uri"

RSpec.describe ScryfallService, type: :service do
  subject(:service) { described_class.new }

  let(:base_url) { "https://api.scryfall.com" }

  let(:card_hash) do
    {
      "id" => "abc-123",
      "name" => "Atraxa, Praetors' Voice",
      "color_identity" => %w[B G U W],
      "type_line" => "Legendary Creature — Phyrexian Angel Horror",
      "oracle_text" => "Flying, vigilance, deathtouch, lifelink. Proliferate.",
      "mana_cost" => "{G}{W}{U}{B}",
      "keywords" => %w[Flying Vigilance Deathtouch Lifelink Proliferate]
    }
  end

  let(:search_response) do
    { "data" => [ card_hash ], "total_cards" => 1 }.to_json
  end

  let(:not_found_response) do
    { "object" => "error", "code" => "not_found", "status" => 404 }.to_json
  end

  let(:error_response) do
    { "object" => "error", "status" => 500 }.to_json
  end

  # ── search_commander ────────────────────────────────────────────────────────

  describe "#search_commander" do
    let(:url) do
      "#{base_url}/cards/search?q=name%3AAtraxa+is%3Acommander+legal%3Acommander"
    end

    context "when results are found" do
      before do
        stub_request(:get, url).to_return(status: 200, body: search_response)
      end

      it "returns an array of card hashes" do
        result = service.search_commander("Atraxa")
        expect(result).to be_an(Array)
        expect(result.first["name"]).to eq("Atraxa, Praetors' Voice")
      end
    end

    context "when the API returns 404" do
      before do
        stub_request(:get, url).to_return(status: 404, body: not_found_response)
      end

      it "returns an empty array" do
        expect(service.search_commander("Atraxa")).to eq([])
      end
    end

    context "when the API returns 500" do
      before do
        stub_request(:get, url).to_return(status: 500, body: error_response)
      end

      it "returns an empty array" do
        expect(service.search_commander("Atraxa")).to eq([])
      end
    end
  end

  # ── find_commander ──────────────────────────────────────────────────────────

  describe "#find_commander" do
    let(:url) { "#{base_url}/cards/named?fuzzy=Atraxa" }
    let(:scryfall_id) { card_hash["id"] }

    context "when there is a cache hit" do
      before do
        CardCache.store(scryfall_id, card_hash["name"], card_hash)
      end

      it "returns the cached data without hitting the API" do
        result = service.find_commander("Atraxa")
        expect(result).to eq(card_hash)
        expect(a_request(:get, url)).not_to have_been_made
      end
    end

    context "when there is a cache miss and the API succeeds" do
      before do
        stub_request(:get, url).to_return(status: 200, body: card_hash.to_json)
      end

      it "returns the card hash" do
        result = service.find_commander("Atraxa")
        expect(result["name"]).to eq("Atraxa, Praetors' Voice")
      end

      it "stores the result in CardCache" do
        expect { service.find_commander("Atraxa") }
          .to change(CardCache, :count).by(1)
      end
    end

    context "when the API returns 404" do
      before do
        stub_request(:get, url).to_return(status: 404, body: not_found_response)
      end

      it "returns nil" do
        expect(service.find_commander("Atraxa")).to be_nil
      end
    end

    context "when the API returns 500" do
      before do
        stub_request(:get, url).to_return(status: 500, body: error_response)
      end

      it "returns nil" do
        expect(service.find_commander("Atraxa")).to be_nil
      end
    end
  end

  # ── find_card_by_name ────────────────────────────────────────────────────────

  describe "#find_card_by_name" do
    let(:card_name) { "Atraxa, Praetors' Voice" }
    let(:url) { "#{base_url}/cards/named?fuzzy=#{URI.encode_www_form_component(card_name)}" }

    context "when there is a cache hit" do
      before do
        CardCache.store(card_hash["id"], card_hash["name"], card_hash)
      end

      it "returns the cached data without hitting the API" do
        result = service.find_card_by_name(card_name)
        expect(result).to eq(card_hash)
        expect(a_request(:get, url)).not_to have_been_made
      end
    end

    context "when there is a cache miss and the API succeeds" do
      before do
        stub_request(:get, url).to_return(status: 200, body: card_hash.to_json)
      end

      it "returns the card hash" do
        result = service.find_card_by_name(card_name)
        expect(result["name"]).to eq("Atraxa, Praetors' Voice")
      end

      it "stores the result in CardCache" do
        expect { service.find_card_by_name(card_name) }
          .to change(CardCache, :count).by(1)
      end
    end

    context "when the API returns 404" do
      before do
        stub_request(:get, url).to_return(status: 404, body: not_found_response)
      end

      it "returns nil" do
        expect(service.find_card_by_name(card_name)).to be_nil
      end
    end
  end

  # ── search_cards ─────────────────────────────────────────────────────────────

  describe "#search_cards" do
    let(:url) { "#{base_url}/cards/search?q=proliferate" }

    context "when results are found" do
      before do
        stub_request(:get, url).to_return(status: 200, body: search_response)
      end

      it "returns an array of card hashes" do
        result = service.search_cards("proliferate")
        expect(result).to be_an(Array)
        expect(result.first["name"]).to eq("Atraxa, Praetors' Voice")
      end
    end

    context "when no results are found (404)" do
      before do
        stub_request(:get, url).to_return(status: 404, body: not_found_response)
      end

      it "returns an empty array" do
        expect(service.search_cards("proliferate")).to eq([])
      end
    end

    context "when the API returns 500" do
      before do
        stub_request(:get, url).to_return(status: 500, body: error_response)
      end

      it "returns an empty array" do
        expect(service.search_cards("proliferate")).to eq([])
      end
    end
  end

  # ── find_card_by_id ──────────────────────────────────────────────────────────

  describe "#find_card_by_id" do
    let(:scryfall_id) { "abc-123" }
    let(:url) { "#{base_url}/cards/#{scryfall_id}" }

    context "when there is a cache hit" do
      before do
        CardCache.store(scryfall_id, card_hash["name"], card_hash)
      end

      it "returns the cached data without hitting the API" do
        result = service.find_card_by_id(scryfall_id)
        expect(result).to eq(card_hash)
        expect(a_request(:get, url)).not_to have_been_made
      end
    end

    context "when there is a cache miss and the API succeeds" do
      before do
        stub_request(:get, url).to_return(status: 200, body: card_hash.to_json)
      end

      it "returns the card hash" do
        result = service.find_card_by_id(scryfall_id)
        expect(result["name"]).to eq("Atraxa, Praetors' Voice")
      end

      it "stores the result in CardCache" do
        expect { service.find_card_by_id(scryfall_id) }
          .to change(CardCache, :count).by(1)
      end
    end

    context "when the API returns 404" do
      before do
        stub_request(:get, url).to_return(status: 404, body: not_found_response)
      end

      it "returns nil" do
        expect(service.find_card_by_id(scryfall_id)).to be_nil
      end
    end

    context "when the API returns 500" do
      before do
        stub_request(:get, url).to_return(status: 500, body: error_response)
      end

      it "returns nil" do
        expect(service.find_card_by_id(scryfall_id)).to be_nil
      end
    end
  end

  # ── cards_by_color_identity ──────────────────────────────────────────────────

  describe "#cards_by_color_identity" do
    context "with a single color" do
      let(:url) { "#{base_url}/cards/search?q=id%3C%3DU" }

      before do
        stub_request(:get, url).to_return(status: 200, body: search_response)
      end

      it "returns an array of card hashes" do
        result = service.cards_by_color_identity(%w[U])
        expect(result).to be_an(Array)
        expect(result.first["name"]).to eq("Atraxa, Praetors' Voice")
      end
    end

    context "with multiple colors" do
      let(:url) { "#{base_url}/cards/search?q=id%3C%3DBGUW" }

      before do
        stub_request(:get, url).to_return(status: 200, body: search_response)
      end

      it "builds the correct color identity query" do
        result = service.cards_by_color_identity(%w[B G U W])
        expect(result).to be_an(Array)
      end
    end

    context "with options[:type]" do
      let(:url) { "#{base_url}/cards/search?q=id%3C%3DU+t%3ACreature" }

      before do
        stub_request(:get, url).to_return(status: 200, body: search_response)
      end

      it "appends a type filter to the query" do
        result = service.cards_by_color_identity(%w[U], type: "Creature")
        expect(result).to be_an(Array)
      end
    end

    context "with options[:exclude_ids]" do
      let(:url) { "#{base_url}/cards/search?q=id%3C%3DU+-id%3Aabc-123" }

      before do
        stub_request(:get, url).to_return(status: 200, body: search_response)
      end

      it "appends exclusions to the query" do
        result = service.cards_by_color_identity(%w[U], exclude_ids: %w[abc-123])
        expect(result).to be_an(Array)
      end
    end

    context "when the API returns no results" do
      let(:url) { "#{base_url}/cards/search?q=id%3C%3DU" }

      before do
        stub_request(:get, url).to_return(status: 404, body: not_found_response)
      end

      it "returns an empty array" do
        expect(service.cards_by_color_identity(%w[U])).to eq([])
      end
    end
  end

  # ── commander_suggestions ────────────────────────────────────────────────────

  describe "#commander_suggestions" do
    let(:url) do
      "#{base_url}/cards/search?q=id%3C%3DBGUW+o%3AFlying"
    end

    before do
      stub_request(:get, url).to_return(status: 200, body: search_response)
    end

    it "returns an array of suggested cards" do
      result = service.commander_suggestions(card_hash)
      expect(result).to be_an(Array)
    end

    it "builds a query from the commander's color identity and keywords" do
      service.commander_suggestions(card_hash)
      expect(a_request(:get, url)).to have_been_made
    end

    context "when the commander has no keywords" do
      let(:commander_no_keywords) { card_hash.merge("keywords" => []) }
      let(:fallback_url) { "#{base_url}/cards/search?q=id%3C%3DBGUW" }

      before do
        stub_request(:get, fallback_url).to_return(status: 200, body: search_response)
      end

      it "falls back to a color-identity-only query" do
        result = service.commander_suggestions(commander_no_keywords)
        expect(result).to be_an(Array)
      end
    end
  end
end
