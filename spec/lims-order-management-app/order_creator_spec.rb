require 'lims-order-management-app/spec_helper'
require 'lims-order-management-app/order_creator'
require 'lims-management-app/sample/sample'

module Lims::OrderManagementApp
  describe OrderCreator do
    before do
      Lims::OrderManagementApp::OrderCreator.any_instance.stub(
        :initialize_api => nil,
        :url_for => mocked_search
      )
    end

    let(:mocked_search) {
      {
        "search"=> {
          "actions"=> {
            "read"=> "http://example.org/11111111-2222-3333-4444-555555555555",
            "first"=> "http://example.org/11111111-2222-3333-4444-555555555555/page=1",
            "last"=> "http://example.org/11111111-2222-3333-4444-555555555555/page=-1"
          },
          "uuid"=> "11111111-2222-3333-4444-555555555555"
        }
      }
    }

    let(:creator) { described_class.new({}).tap do |c|
      c.stub(:post) { |a| a }
      c.stub(:get) { mocked_tubes }
    end
    }    
    let(:pipeline) { "pipeline" }
    let(:samples) { [
      {:sample => Lims::ManagementApp::Sample.new, :uuid => '11111111-0000-0000-0000-111111111111'},
      {:sample => Lims::ManagementApp::Sample.new, :uuid => '11111111-0000-0000-0000-222222222222'}
    ] }

    context "valid context" do
      let(:mocked_tubes) {{
        "size"=> 2,
        "tubes"=> [
          {
            "uuid"=> "11111111-2222-3333-4444-666666666666",
            "aliquots"=> [{"sample"=> {"uuid"=> "11111111-0000-0000-0000-111111111111"}}]
          },
          {
            "uuid"=> "11111111-2222-3333-4444-888888888888",
            "aliquots"=> [{"sample"=> {"uuid"=> "11111111-0000-0000-0000-222222222222"}}]
          }
        ]
      }}

      let(:expected_order_parameters) { {
        :order => {
          :user_uuid => "66666666-2222-4444-9999-000000000000",
          :study_uuid => "55555555-2222-3333-6666-777777777777",
          :pipeline => pipeline,
          :cost_code => "cost code",
          :sources => {
            described_class::INPUT_TUBE_ROLE => ["11111111-2222-3333-4444-666666666666", "11111111-2222-3333-4444-888888888888"]
          }
        }
      } }

      it "posts an order" do
        creator.should_receive(:post_order).with(expected_order_parameters)
        creator.execute(samples, pipeline)
      end
    end


    context "invalid context" do
      let(:mocked_tubes) {{
        "size"=> 1,
        "tubes"=> [
          {
            "uuid"=> "11111111-2222-3333-4444-888888888888",
            "aliquots"=> [{"sample"=> {"uuid"=> "11111111-0000-0000-0000-222222222222"}}]
          }
        ]
      }}

      it "raises an error" do
        expect do
          creator.execute(samples, pipeline)
        end.to raise_error(OrderCreator::TubeNotFound)
      end
    end
  end
end
