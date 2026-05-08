require "rails_helper"

RSpec.describe NlPromptParserService, type: :service do
  subject(:service) { described_class.new(prompt) }

  let(:claude_api_url) { "https://api.anthropic.com/v1/messages" }

  def stub_llm(json_response)
    stub_request(:post, claude_api_url)
      .to_return(
        status:  200,
        body:    { "content" => [ { "type" => "text", "text" => json_response.to_json } ] }.to_json,
        headers: { "Content-Type" => "application/json" }
      )
  end

  before { Rails.cache.clear }

  describe "#parse" do
    context "with a subtype filter query" do
      let(:prompt) { "show me only elves" }

      before { stub_llm({ "filter_type" => "type", "subtypes" => [ "Elf" ] }) }

      it "returns a filter spec with filter_type type and the Elf subtype" do
        result = service.parse
        expect(result["filter_type"]).to eq("type")
        expect(result["subtypes"]).to include("Elf")
      end

      it "makes exactly one API call" do
        service.parse
        expect(WebMock).to have_requested(:post, claude_api_url).once
      end
    end

    context "with a color + type + CMC filter query" do
      let(:prompt) { "cheap blue instants" }

      before do
        stub_llm({ "filter_type" => "type", "types" => [ "Instant" ],
                   "colors" => [ "U" ], "max_cmc" => 3 })
      end

      it "returns types, colors, and max_cmc" do
        result = service.parse
        expect(result["filter_type"]).to eq("type")
        expect(result["types"]).to include("Instant")
        expect(result["colors"]).to include("U")
        expect(result["max_cmc"]).to eq(3)
      end
    end

    context "with a similarity query" do
      let(:prompt) { "cards like Sol Ring" }

      before { stub_llm({ "filter_type" => "similarity", "reference_card" => "Sol Ring" }) }

      it "returns filter_type similarity with the reference card name" do
        result = service.parse
        expect(result["filter_type"]).to eq("similarity")
        expect(result["reference_card"]).to eq("Sol Ring")
      end
    end

    context "with a combo query" do
      let(:prompt) { "cards that combo with Thassa's Oracle" }

      before { stub_llm({ "filter_type" => "combo", "reference_card" => "Thassa's Oracle" }) }

      it "returns filter_type combo with the reference card name" do
        result = service.parse
        expect(result["filter_type"]).to eq("combo")
        expect(result["reference_card"]).to eq("Thassa's Oracle")
      end
    end

    context "caching" do
      let(:prompt)       { "show me only elves" }
      let(:memory_store) { ActiveSupport::Cache::MemoryStore.new }

      # Swap in a real memory store; test env uses :null_store which never stores anything.
      before do
        allow(Rails).to receive(:cache).and_return(memory_store)
        stub_llm({ "filter_type" => "type", "subtypes" => [ "Elf" ] })
      end

      it "returns the same spec on a second call without hitting the API again" do
        first  = service.parse
        second = described_class.new(prompt).parse

        expect(first).to eq(second)
        expect(WebMock).to have_requested(:post, claude_api_url).once
      end

      it "treats the same prompt case-insensitively as the same cache key" do
        described_class.new("show me only elves").parse
        described_class.new("SHOW ME ONLY ELVES").parse

        expect(WebMock).to have_requested(:post, claude_api_url).once
      end
    end

    context "when the API returns a non-200 response" do
      let(:prompt) { "show me elves" }

      before do
        stub_request(:post, claude_api_url)
          .to_return(status: 401, body: { "error" => "unauthorized" }.to_json)
      end

      it "returns nil" do
        expect(service.parse).to be_nil
      end
    end

    context "when the API raises a network error" do
      let(:prompt) { "show me elves" }

      before { stub_request(:post, claude_api_url).to_raise(StandardError.new("timeout")) }

      it "returns nil" do
        expect(service.parse).to be_nil
      end
    end

    context "when the response contains invalid JSON" do
      let(:prompt) { "show me elves" }

      before do
        stub_request(:post, claude_api_url)
          .to_return(
            status:  200,
            body:    { "content" => [ { "type" => "text", "text" => "not valid json {{{" } ] }.to_json,
            headers: { "Content-Type" => "application/json" }
          )
      end

      it "returns nil" do
        expect(service.parse).to be_nil
      end
    end

    context "with a blank prompt" do
      let(:prompt) { "   " }

      it "returns nil without calling the API" do
        service.parse
        expect(WebMock).not_to have_requested(:post, claude_api_url)
      end
    end

    context "when the LLM returns filter_type null (non-MTG query)" do
      let(:prompt) { "what is the weather today" }

      before { stub_llm({ "filter_type" => nil }) }

      it "returns a spec with null filter_type" do
        result = service.parse
        expect(result["filter_type"]).to be_nil
      end
    end
  end
end
