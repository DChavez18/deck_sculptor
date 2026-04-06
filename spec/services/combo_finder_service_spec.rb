require "rails_helper"

RSpec.describe ComboFinderService do
  subject(:service) { described_class.new }

  let(:base_url) { "https://backend.commanderspellbook.com/api/v1/variants/" }
  let(:commander_name) { "Thrasios, Triton Hero" }

  let(:combo_response) do
    {
      "count"   => 1,
      "results" => [
        {
          "uses"        => [
            { "card" => { "name" => "Thrasios, Triton Hero" } },
            { "card" => { "name" => "Kenrith, the Returned King" } },
            { "card" => { "name" => "Basalt Monolith" } }
          ],
          "produces"    => [
            { "feature" => { "name" => "Infinite Mana" } },
            { "feature" => { "name" => "Win the Game" } }
          ],
          "description" => "1. Tap Basalt Monolith for mana. 2. Use mana to untap it. 3. Repeat."
        }
      ]
    }.to_json
  end

  describe "#find_combos" do
    context "with a successful API response" do
      before do
        stub_request(:get, base_url)
          .with(query: { "q" => "card:#{commander_name}" })
          .to_return(status: 200, body: combo_response, headers: { "Content-Type" => "application/json" })
      end

      it "returns an array of combo hashes" do
        combos = service.find_combos([ commander_name ])
        expect(combos).to be_an(Array)
        expect(combos.length).to eq(1)
      end

      it "each combo has cards, result, and steps keys" do
        combo = service.find_combos([ commander_name ]).first
        expect(combo).to include(:cards, :result, :steps)
      end

      it "extracts card names from the combo" do
        combo = service.find_combos([ commander_name ]).first
        expect(combo[:cards]).to include("Thrasios, Triton Hero", "Basalt Monolith")
      end

      it "combines produced features into the result string" do
        combo = service.find_combos([ commander_name ]).first
        expect(combo[:result]).to include("Infinite Mana")
      end

      it "includes the steps description" do
        combo = service.find_combos([ commander_name ]).first
        expect(combo[:steps]).to include("Basalt Monolith")
      end

      it "uses the first card name to query the API" do
        service.find_combos([ commander_name, "Some Other Card" ])
        expect(a_request(:get, base_url).with(query: { "q" => "card:#{commander_name}" })).to have_been_made.once
      end
    end

    context "when the API returns no combos" do
      before do
        stub_request(:get, base_url)
          .with(query: { "q" => "card:#{commander_name}" })
          .to_return(status: 200, body: { "count" => 0, "results" => [] }.to_json, headers: { "Content-Type" => "application/json" })
      end

      it "returns an empty array" do
        expect(service.find_combos([ commander_name ])).to eq([])
      end
    end

    context "on a non-200 response" do
      before do
        stub_request(:get, base_url)
          .with(query: { "q" => "card:#{commander_name}" })
          .to_return(status: 500, body: "Internal Server Error")
      end

      it "returns an empty array" do
        expect(service.find_combos([ commander_name ])).to eq([])
      end
    end

    context "on a network error" do
      before do
        stub_request(:get, base_url)
          .with(query: { "q" => "card:#{commander_name}" })
          .to_raise(StandardError.new("connection refused"))
      end

      it "returns an empty array" do
        expect(service.find_combos([ commander_name ])).to eq([])
      end
    end

    context "with an empty card names array" do
      it "returns an empty array without making any HTTP requests" do
        result = service.find_combos([])
        expect(result).to eq([])
        expect(a_request(:get, base_url)).not_to have_been_made
      end
    end
  end

  describe "#near_miss_combos" do
    # combo_response has 3 cards: Thrasios, Kenrith, Basalt Monolith
    # deck has Thrasios + Kenrith → missing Basalt Monolith (one away)
    let(:two_card_names) { [ commander_name, "Kenrith, the Returned King" ] }

    context "when the deck has all but one combo card" do
      before do
        stub_request(:get, base_url)
          .with(query: { "q" => "card:#{commander_name}" })
          .to_return(status: 200, body: combo_response, headers: { "Content-Type" => "application/json" })
      end

      it "returns combos missing exactly one card" do
        near_misses = service.near_miss_combos(two_card_names)
        expect(near_misses).not_to be_empty
        expect(near_misses.first[:missing_card]).to eq("Basalt Monolith")
      end

      it "includes the full combo details" do
        near_miss = service.near_miss_combos(two_card_names).first
        expect(near_miss[:combo][:cards]).to include("Thrasios, Triton Hero")
        expect(near_miss[:combo][:result]).to include("Infinite Mana")
      end
    end

    context "when the deck has all combo cards (complete combo)" do
      before do
        stub_request(:get, base_url)
          .with(query: { "q" => "card:#{commander_name}" })
          .to_return(status: 200, body: combo_response, headers: { "Content-Type" => "application/json" })
      end

      it "does not return complete combos" do
        all_names = two_card_names + [ "Basalt Monolith" ]
        near_misses = service.near_miss_combos(all_names)
        expect(near_misses).to be_empty
      end
    end

    context "on a network error" do
      before do
        stub_request(:get, base_url)
          .with(query: { "q" => "card:#{commander_name}" })
          .to_raise(StandardError.new("connection refused"))
      end

      it "returns an empty array" do
        expect(service.near_miss_combos(two_card_names)).to eq([])
      end
    end

    context "with an empty card names array" do
      it "returns an empty array without making any HTTP requests" do
        result = service.near_miss_combos([])
        expect(result).to eq([])
        expect(a_request(:get, base_url)).not_to have_been_made
      end
    end
  end
end
