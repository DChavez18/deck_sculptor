require "rails_helper"

RSpec.describe EdhrecService do
  subject(:service) { described_class.new }

  let(:commander_name) { "Atraxa, Praetors' Voice" }
  let(:slug)           { "atraxa-praetors-voice" }
  let(:url)            { "https://json.edhrec.com/pages/commanders/#{slug}.json" }

  let(:edhrec_response) do
    {
      "container" => {
        "json_dict" => {
          "cardlists" => [
            {
              "tag"       => "highsynergycards",
              "cardviews" => [
                { "name" => "Doubling Season",    "type" => "Enchantment", "synergy" => 0.65, "inclusion" => 8500 },
                { "name" => "Inexorable Tide",    "type" => "Enchantment", "synergy" => 0.45, "inclusion" => 5000 },
                { "name" => "Contagion Engine",   "type" => "Artifact",    "synergy" => 0.40, "inclusion" => 4800 },
                { "name" => "Deepglow Skate",     "type" => "Creature — Fish", "synergy" => 0.38, "inclusion" => 4200 }
              ]
            },
            {
              "tag"       => "topcards",
              "cardviews" => [
                { "name" => "Sol Ring",             "type" => "Artifact",    "synergy" => 0.05, "inclusion" => 95000 },
                { "name" => "Arcane Signet",        "type" => "Artifact",    "synergy" => 0.05, "inclusion" => 85000 },
                { "name" => "Command Tower",        "type" => "Land",        "synergy" => 0.02, "inclusion" => 90000 },
                { "name" => "Rhystic Study",        "type" => "Enchantment", "synergy" => 0.15, "inclusion" => 70000 },
                { "name" => "Cyclonic Rift",        "type" => "Instant",     "synergy" => 0.10, "inclusion" => 65000 },
                { "name" => "Swords to Plowshares", "type" => "Instant",     "synergy" => 0.08, "inclusion" => 60000 },
                { "name" => "Demonic Tutor",        "type" => "Sorcery",     "synergy" => 0.12, "inclusion" => 55000 }
              ]
            },
            {
              "tag"       => "gamechangers",
              "cardviews" => [
                { "name" => "Propaganda", "type" => "Enchantment", "synergy" => 0.20, "inclusion" => 40000 }
              ]
            }
          ]
        }
      },
      "panels" => {
        "tags" => [
          { "label" => "Proliferate" },
          { "label" => "Counters" },
          { "label" => "Superfriends" }
        ]
      }
    }.to_json
  end

  describe "#name_to_slug" do
    it "lowercases the name" do
      expect(service.name_to_slug("Atraxa")).to eq("atraxa")
    end

    it "replaces spaces with hyphens" do
      expect(service.name_to_slug("Sol Ring")).to eq("sol-ring")
    end

    it "removes special characters like commas and apostrophes" do
      expect(service.name_to_slug("Atraxa, Praetors' Voice")).to eq("atraxa-praetors-voice")
    end

    it "handles names with numbers" do
      expect(service.name_to_slug("Elesh Norn, Grand Cenobite")).to eq("elesh-norn-grand-cenobite")
    end
  end

  describe "#commander_data" do
    context "on a successful response" do
      before do
        stub_request(:get, url).to_return(status: 200, body: edhrec_response, headers: { "Content-Type" => "application/json" })
      end

      it "returns the parsed JSON hash" do
        data = service.commander_data(commander_name)
        expect(data).to be_a(Hash)
        expect(data.dig("container", "json_dict", "cardlists")).to be_an(Array)
      end

      it "caches the result in CardCache" do
        expect { service.commander_data(commander_name) }.to change(CardCache, :count).by(1)
      end

      it "returns the cached result on subsequent calls" do
        service.commander_data(commander_name)
        expect(a_request(:get, url)).to have_been_made.once

        service.commander_data(commander_name)
        expect(a_request(:get, url)).to have_been_made.once
      end
    end

    context "on a 404 response" do
      before do
        stub_request(:get, url).to_return(status: 404, body: "Not Found")
      end

      it "returns nil" do
        expect(service.commander_data(commander_name)).to be_nil
      end

      it "does not cache anything" do
        expect { service.commander_data(commander_name) }.not_to change(CardCache, :count)
      end
    end

    context "on a network error" do
      before do
        stub_request(:get, url).to_raise(StandardError.new("connection refused"))
      end

      it "returns nil" do
        expect(service.commander_data(commander_name)).to be_nil
      end
    end
  end

  describe "#top_cards" do
    context "when commander_data returns a valid response" do
      before do
        stub_request(:get, url).to_return(status: 200, body: edhrec_response, headers: { "Content-Type" => "application/json" })
      end

      it "returns an array of card name strings" do
        cards = service.top_cards(commander_name)
        expect(cards).to be_an(Array)
        expect(cards.first).to be_a(String)
      end

      it "returns at most 20 cards" do
        expect(service.top_cards(commander_name).length).to be <= 20
      end

      it "includes known popular cards" do
        expect(service.top_cards(commander_name)).to include("Sol Ring")
      end
    end

    context "when commander_data returns nil" do
      before do
        stub_request(:get, url).to_return(status: 404, body: "Not Found")
      end

      it "returns an empty array" do
        expect(service.top_cards(commander_name)).to eq([])
      end
    end

    context "on a network error" do
      before do
        stub_request(:get, url).to_raise(StandardError.new("connection refused"))
      end

      it "returns an empty array" do
        expect(service.top_cards(commander_name)).to eq([])
      end
    end
  end

  describe "#top_cards_with_details" do
    context "when commander_data returns a valid response" do
      before do
        stub_request(:get, url).to_return(status: 200, body: edhrec_response, headers: { "Content-Type" => "application/json" })
      end

      it "returns an array of hashes with name, synergy, inclusion, category, and reason keys" do
        cards = service.top_cards_with_details(commander_name)
        expect(cards).to be_an(Array)
        expect(cards.first).to include(:name, :synergy, :inclusion, :category, :reason)
      end

      it "returns at most 20 cards" do
        expect(service.top_cards_with_details(commander_name).length).to be <= 20
      end

      it "sorts results by synergy descending" do
        cards = service.top_cards_with_details(commander_name)
        synergies = cards.map { |c| c[:synergy] }
        expect(synergies).to eq(synergies.sort.reverse)
      end

      it "deduplicates cards across lists" do
        names = service.top_cards_with_details(commander_name).map { |c| c[:name] }
        expect(names.uniq).to eq(names)
      end

      it "includes the commander name in the reason" do
        cards = service.top_cards_with_details(commander_name)
        expect(cards.first[:reason]).to include(commander_name)
      end

      it "infers artifact category from type line" do
        cards = service.top_cards_with_details(commander_name)
        sol_ring = cards.find { |c| c[:name] == "Sol Ring" }
        expect(sol_ring[:category]).to eq("artifact")
      end

      it "infers land category from type line" do
        cards = service.top_cards_with_details(commander_name)
        command_tower = cards.find { |c| c[:name] == "Command Tower" }
        expect(command_tower[:category]).to eq("land")
      end

      it "infers instant category from type line" do
        cards = service.top_cards_with_details(commander_name)
        cyclonic_rift = cards.find { |c| c[:name] == "Cyclonic Rift" }
        expect(cyclonic_rift[:category]).to eq("instant")
      end

      it "surfaces highest synergy card first" do
        cards = service.top_cards_with_details(commander_name)
        expect(cards.first[:name]).to eq("Doubling Season")
        expect(cards.first[:synergy]).to eq(0.65)
      end
    end

    context "when commander_data returns nil" do
      before do
        stub_request(:get, url).to_return(status: 404, body: "Not Found")
      end

      it "returns an empty array" do
        expect(service.top_cards_with_details(commander_name)).to eq([])
      end
    end

    context "on a network error" do
      before do
        stub_request(:get, url).to_raise(StandardError.new("connection refused"))
      end

      it "returns an empty array" do
        expect(service.top_cards_with_details(commander_name)).to eq([])
      end
    end
  end

  describe "#commander_themes" do
    context "when commander_data includes panels tags" do
      before do
        stub_request(:get, url).to_return(status: 200, body: edhrec_response, headers: { "Content-Type" => "application/json" })
      end

      it "returns an array of theme label strings" do
        themes = service.commander_themes(commander_name)
        expect(themes).to be_an(Array)
        expect(themes).to include("Proliferate", "Counters", "Superfriends")
      end
    end

    context "when commander_data returns nil" do
      before do
        stub_request(:get, url).to_return(status: 404, body: "Not Found")
      end

      it "returns an empty array" do
        expect(service.commander_themes(commander_name)).to eq([])
      end
    end

    context "when panels are absent from the response" do
      before do
        body = { "container" => { "json_dict" => { "cardlists" => [] } } }.to_json
        stub_request(:get, url).to_return(status: 200, body: body, headers: { "Content-Type" => "application/json" })
      end

      it "returns an empty array" do
        expect(service.commander_themes(commander_name)).to eq([])
      end
    end
  end
end
