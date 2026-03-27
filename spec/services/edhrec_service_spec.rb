require "rails_helper"

RSpec.describe EdhrecService do
  subject(:service) { described_class.new }

  let(:commander_name) { "Atraxa, Praetors' Voice" }
  let(:slug)           { "atraxa-praetors-voice" }
  let(:url)            { "https://json.edhrec.com/pages/commanders/#{slug}.json" }

  let(:edhrec_response) do
    {
      "cardlist" => [
        { "name" => "Sol Ring",              "type" => "Artifact" },
        { "name" => "Arcane Signet",         "type" => "Artifact" },
        { "name" => "Command Tower",         "type" => "Land" },
        { "name" => "Propaganda",            "type" => "Enchantment" },
        { "name" => "Rhystic Study",         "type" => "Enchantment" },
        { "name" => "Cyclonic Rift",         "type" => "Instant" },
        { "name" => "Swords to Plowshares",  "type" => "Instant" },
        { "name" => "Path to Exile",         "type" => "Instant" },
        { "name" => "Demonic Tutor",         "type" => "Sorcery" },
        { "name" => "Vampiric Tutor",        "type" => "Instant" },
        { "name" => "Doubling Season",       "type" => "Enchantment" },
        { "name" => "Inexorable Tide",       "type" => "Enchantment" },
        { "name" => "Contagion Engine",      "type" => "Artifact" },
        { "name" => "Deepglow Skate",        "type" => "Creature — Fish" },
        { "name" => "Crystalline Crawler",   "type" => "Artifact Creature — Construct" },
        { "name" => "Astral Cornucopia",     "type" => "Artifact" },
        { "name" => "Darksteel Ingot",       "type" => "Artifact" },
        { "name" => "Kodama's Reach",        "type" => "Sorcery" },
        { "name" => "Nature's Lore",         "type" => "Sorcery" },
        { "name" => "Skyshroud Claim",       "type" => "Sorcery" },
        { "name" => "Atraxa, Praetors' Voice", "type" => "Legendary Creature — Angel Horror" }
      ]
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
        expect(data["cardlist"]).to be_an(Array)
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

      it "returns an array of hashes with name, category, and reason keys" do
        cards = service.top_cards_with_details(commander_name)
        expect(cards).to be_an(Array)
        expect(cards.first).to include(:name, :category, :reason)
      end

      it "returns at most 10 cards" do
        expect(service.top_cards_with_details(commander_name).length).to be <= 10
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
end
