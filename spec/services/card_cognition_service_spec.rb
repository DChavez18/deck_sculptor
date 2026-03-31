require "rails_helper"

RSpec.describe CardCognitionService do
  let(:commander_name) { "Atraxa, Praetors' Voice" }
  let(:slug)           { "atraxa-praetors-voice" }
  let(:url)            { "https://api.cardcognition.com/#{slug}/suggestions/50" }

  subject(:service) { described_class.new(commander_name) }

  let(:api_response) do
    [
      { "name" => "Doubling Season",  "score" => 0.75, "scryfall_id" => "abc-111" },
      { "name" => "Inexorable Tide",  "score" => 0.35, "scryfall_id" => "abc-222" },
      { "name" => "Sol Ring",         "score" => 0.10, "scryfall_id" => "abc-333" }
    ]
  end

  before do
    stub_request(:get, url).to_return(status: 200, body: api_response.to_json, headers: { "Content-Type" => "application/json" })
  end

  describe "#suggestions" do
    it "returns an array of card hashes from the API" do
      results = service.suggestions
      expect(results).to be_an(Array)
      expect(results.first["name"]).to eq("Doubling Season")
    end

    it "returns [] on a non-200 response" do
      stub_request(:get, url).to_return(status: 404, body: "Not Found")
      expect(service.suggestions).to eq([])
    end

    it "returns [] on a network error" do
      stub_request(:get, url).to_raise(StandardError.new("connection refused"))
      expect(service.suggestions).to eq([])
    end

    it "caches result after first call and does not hit the API again" do
      service.suggestions
      service.suggestions
      expect(a_request(:get, url)).to have_been_made.once
    end
  end

  describe "#slugify (via commander name)" do
    it "lowercases and hyphenates spaces" do
      svc = described_class.new("The Beamtown Bullies")
      stub_request(:get, "https://api.cardcognition.com/the-beamtown-bullies/suggestions/50")
        .to_return(status: 200, body: [].to_json)
      svc.suggestions
      expect(a_request(:get, "https://api.cardcognition.com/the-beamtown-bullies/suggestions/50"))
        .to have_been_made
    end

    it "removes apostrophes and commas" do
      svc = described_class.new("Atraxa, Praetors' Voice")
      stub_request(:get, "https://api.cardcognition.com/atraxa-praetors-voice/suggestions/50")
        .to_return(status: 200, body: [].to_json)
      svc.suggestions
      expect(a_request(:get, "https://api.cardcognition.com/atraxa-praetors-voice/suggestions/50"))
        .to have_been_made
    end

    it "does not produce double hyphens" do
      svc = described_class.new("Zur,  the Enchanter")
      stub_request(:get, "https://api.cardcognition.com/zur-the-enchanter/suggestions/50")
        .to_return(status: 200, body: [].to_json)
      svc.suggestions
      expect(a_request(:get, "https://api.cardcognition.com/zur-the-enchanter/suggestions/50"))
        .to have_been_made
    end
  end
end
