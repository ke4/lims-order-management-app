require 'common'
require 'lims-order-management-app/helpers/api'
require 'lims-order-management-app/rule_matcher'

module Lims::OrderManagementApp
  class OrderCreator
    include Virtus
    include Aequitas
    include Helpers::API
    include Lims::OrderManagementApp::RuleMatcher

    InvalidExtractionProcessField = Class.new(StandardError)
    UuidPattern = [8, 4, 4, 4, 12]
    UuidFormat = /#{UuidPattern.map { |n| "(\\w{#{n}})"}.join("-")}/i

    attribute :user_email, String, :required => true, :writer => :private
    attribute :study_uuid, String, :required => true, :writer => :private
    attribute :cost_code, String, :required => true, :writer => :private

    # @param [Hash] api_settings
    def initialize(order_settings, api_settings, rule_settings)
      url = api_settings["url"]      
      @user_email = order_settings["user_email"]
      @study_uuid = order_settings["study_uuid"]
      @cost_code = order_settings["cost_code"]
      @ruleset = rule_settings["rules"]
      initialize_api(url, @user_email)
    end

    # @param [Array] samples
    def create!(samples)
      container_roles = container_roles(samples)
      order_parameters = order_parameters(container_roles)
      post_order(order_parameters)
    end

    private

    # @param [Array] samples
    # @return [Hash] 
    # @example: {"11111111-2222-3333-4444-555555555555" => "role"}
    def container_roles(samples)
      {}.tap do |result|
        samples.each do |sample_data|
          validate_sample_extraction_process!(sample_data[:sample], sample_data[:uuid])
          match_rule(sample_data[:sample]).each do |container_uuid, role|
            result[container_uuid] = role unless result.has_key?(container_uuid)
          end
        end
      end
    end

    # @param [Lims::ManagementApp::Sample] sample
    # @param [String] sample_uuid
    # @raise [InvalidExtractionProcessField]
    def validate_sample_extraction_process!(sample, sample_uuid)
      begin
        # skip the validation if there is no extraction process field
        return unless sample.cellular_material && sample.cellular_material[:extraction_process]
        extraction_process = sample[:cellular_material][:extraction_process] 
        raise "Extraction process should be a hash" unless extraction_process.is_a?(Hash)

        extraction_process.each do |sample_extraction_process, container_uuids|
          unless container_uuids.is_a?(Array) && container_uuids.all? { |uuid| uuid =~ UuidFormat }      
            raise "Container uuids should be valid uuids in an array"
          end
        end
      rescue StandardError => e
        raise InvalidExtractionProcessField, "The extraction_process field is invalid for the sample #{sample_uuid} (#{e.message}): #{extraction_process.inspect}" 
      end
    end

    # @param [Hash] container_roles
    # @return [Hash]
    def order_parameters(container_roles)
      roles_to_container_uuids = container_roles.inject(Hash.new { |h,k| h[k] = [] }) do |m,(k,v)|
        m[v] << k
        m
      end

      {:order => {}.tap do |p|
        p[:study_uuid] = study_uuid 
        p[:pipeline] = 'Samples'
        p[:cost_code] = cost_code 
        p[:sources] = roles_to_container_uuids
      end
      }
    end

    # @param [Hash] order_parameters
    def post_order(order_parameters)
      post(url_for(:orders, :create), order_parameters)
    end
  end
end
