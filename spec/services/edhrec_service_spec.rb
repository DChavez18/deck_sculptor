require "rails_helper"

RSpec.describe EdhrecService do
  subject(:service) { described_class.new }

  let(:commander_name) { "Atraxa, Praetors' Voice" }
  let(:slug)           { "atraxa-praetors-voice" }
  let(:url)            { "https://json.edhrec.com/pages/commanders/#{slug}.json" }

  let(:edhrec_response) do
    {
      "cardlist" => [
        { "name" => "Sol Ring" },
        { "name" => "Arcane Signet" },
        { "name" => "Command Tower" },
        { "name" => "Propaganda" },
        { "name" => "Rhystic Study" },
        { "name" => "Cyclonic Rift" },
        { "name" => "Swords to Plowshares" },
        { "name" => "Path to Exile" },
        { "name" => "Demonic Tutor" },
        { "name" => "Vampiric Tutor" },
        { "name" => "Doubling Season" },
        { "name" => "Inexorable Tide" },
        { "name" => "Contagion Engine" },
        { "name" => "Atraxa, Praetors' Voice" },
        { "name" => "Deepglow Skate" },
        { "name" => "Crystalline Crawler" },
        { "name" => "Astral Cornucopia" },
        { "name" => "Darksteel Ingot" },
        { "name" => "Kodama's Reach" },
        { "name" => "Nature's Lore" },
        { "name" => "Skyshroud Claim" }
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
end
