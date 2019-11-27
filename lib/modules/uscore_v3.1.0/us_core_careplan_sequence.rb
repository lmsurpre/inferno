# frozen_string_literal: true

module Inferno
  module Sequence
    class USCore310CareplanSequence < SequenceBase
      title 'CarePlan Tests'

      description 'Verify that CarePlan resources on the FHIR server follow the US Core Implementation Guide'

      test_id_prefix 'USCCP'

      requires :token, :patient_id
      conformance_supports :CarePlan

      def validate_resource_item(resource, property, value)
        case property

        when 'category'
          value_found = can_resolve_path(resource, 'category.coding.code') { |value_in_resource| value_in_resource == value }
          assert value_found, 'category on resource does not match category requested'

        when 'date'
          value_found = can_resolve_path(resource, 'period') do |period|
            validate_period_search(value, period)
          end
          assert value_found, 'date on resource does not match date requested'

        when 'patient'
          value_found = can_resolve_path(resource, 'subject.reference') { |reference| [value, 'Patient/' + value].include? reference }
          assert value_found, 'patient on resource does not match patient requested'

        when 'status'
          value_found = can_resolve_path(resource, 'status') { |value_in_resource| value_in_resource == value }
          assert value_found, 'status on resource does not match status requested'

        end
      end

      details %(
        The #{title} Sequence tests `#{title.gsub(/\s+/, '')}` resources associated with the provided patient.
      )

      @resources_found = false

      test :unauthorized_search do
        metadata do
          id '01'
          name 'Server rejects CarePlan search without authorization'
          link 'https://www.hl7.org/fhir/us/core/CapabilityStatement-us-core-server.html#behavior'
          description %(
            A server SHALL reject any unauthorized requests by returning an HTTP 401 unauthorized response code.
          )
          versions :r4
        end

        skip_if_not_supported(:CarePlan, [:search])

        @client.set_no_auth
        omit 'Do not test if no bearer token set' if @instance.token.blank?

        search_params = {
          'patient': @instance.patient_id,
          'category': 'assess-plan'
        }

        reply = get_resource_by_params(versioned_resource_class('CarePlan'), search_params)
        @client.set_bearer_token(@instance.token)
        assert_response_unauthorized reply
      end

      test :search_by_patient_category do
        metadata do
          id '02'
          name 'Server returns expected results from CarePlan search by patient+category'
          link 'https://www.hl7.org/fhir/us/core/CapabilityStatement-us-core-server.html'
          description %(

            A server SHALL support searching by patient+category on the CarePlan resource

          )
          versions :r4
        end

        category_val = ['assess-plan']
        category_val.each do |val|
          search_params = { 'patient': @instance.patient_id, 'category': val }
          reply = get_resource_by_params(versioned_resource_class('CarePlan'), search_params)
          assert_response_ok(reply)
          assert_bundle_response(reply)

          @resources_found = reply&.resource&.entry&.any? { |entry| entry&.resource&.resourceType == 'CarePlan' }
          next unless @resources_found

          @care_plan = reply.resource.entry
            .find { |entry| entry&.resource&.resourceType == 'CarePlan' }
            .resource
          @care_plan_ary = fetch_all_bundled_resources(reply.resource)

          save_resource_ids_in_bundle(versioned_resource_class('CarePlan'), reply)
          save_delayed_sequence_references(@care_plan_ary)
          validate_search_reply(versioned_resource_class('CarePlan'), reply, search_params)
          break
        end
        skip 'No resources appear to be available for this patient. Please use patients with more information.' unless @resources_found
      end

      test :search_by_patient_category_date do
        metadata do
          id '03'
          name 'Server returns expected results from CarePlan search by patient+category+date'
          link 'https://www.hl7.org/fhir/us/core/CapabilityStatement-us-core-server.html'
          optional
          description %(

            A server SHOULD support searching by patient+category+date on the CarePlan resource

              including support for these date comparators: gt, lt, le
          )
          versions :r4
        end

        skip 'No resources appear to be available for this patient. Please use patients with more information.' unless @resources_found

        search_params = {
          'patient': @instance.patient_id,
          'category': get_value_for_search_param(resolve_element_from_path(@care_plan_ary, 'category')),
          'date': get_value_for_search_param(resolve_element_from_path(@care_plan_ary, 'period'))
        }
        search_params.each { |param, value| skip "Could not resolve #{param} in given resource" if value.nil? }

        reply = get_resource_by_params(versioned_resource_class('CarePlan'), search_params)
        validate_search_reply(versioned_resource_class('CarePlan'), reply, search_params)

        ['gt', 'lt', 'le'].each do |comparator|
          comparator_val = date_comparator_value(comparator, search_params[:date])
          comparator_search_params = { 'patient': search_params[:patient], 'category': search_params[:category], 'date': comparator_val }
          reply = get_resource_by_params(versioned_resource_class('CarePlan'), comparator_search_params)
          validate_search_reply(versioned_resource_class('CarePlan'), reply, comparator_search_params)
        end
      end

      test :search_by_patient_category_status_date do
        metadata do
          id '04'
          name 'Server returns expected results from CarePlan search by patient+category+status+date'
          link 'https://www.hl7.org/fhir/us/core/CapabilityStatement-us-core-server.html'
          optional
          description %(

            A server SHOULD support searching by patient+category+status+date on the CarePlan resource

              including support for these date comparators: gt, lt, le
          )
          versions :r4
        end

        skip 'No resources appear to be available for this patient. Please use patients with more information.' unless @resources_found

        search_params = {
          'patient': @instance.patient_id,
          'category': get_value_for_search_param(resolve_element_from_path(@care_plan_ary, 'category')),
          'status': get_value_for_search_param(resolve_element_from_path(@care_plan_ary, 'status')),
          'date': get_value_for_search_param(resolve_element_from_path(@care_plan_ary, 'period'))
        }
        search_params.each { |param, value| skip "Could not resolve #{param} in given resource" if value.nil? }

        reply = get_resource_by_params(versioned_resource_class('CarePlan'), search_params)
        validate_search_reply(versioned_resource_class('CarePlan'), reply, search_params)

        ['gt', 'lt', 'le'].each do |comparator|
          comparator_val = date_comparator_value(comparator, search_params[:date])
          comparator_search_params = { 'patient': search_params[:patient], 'category': search_params[:category], 'status': search_params[:status], 'date': comparator_val }
          reply = get_resource_by_params(versioned_resource_class('CarePlan'), comparator_search_params)
          validate_search_reply(versioned_resource_class('CarePlan'), reply, comparator_search_params)
        end
      end

      test :search_by_patient_category_status do
        metadata do
          id '05'
          name 'Server returns expected results from CarePlan search by patient+category+status'
          link 'https://www.hl7.org/fhir/us/core/CapabilityStatement-us-core-server.html'
          optional
          description %(

            A server SHOULD support searching by patient+category+status on the CarePlan resource

          )
          versions :r4
        end

        skip 'No resources appear to be available for this patient. Please use patients with more information.' unless @resources_found

        search_params = {
          'patient': @instance.patient_id,
          'category': get_value_for_search_param(resolve_element_from_path(@care_plan_ary, 'category')),
          'status': get_value_for_search_param(resolve_element_from_path(@care_plan_ary, 'status'))
        }
        search_params.each { |param, value| skip "Could not resolve #{param} in given resource" if value.nil? }

        reply = get_resource_by_params(versioned_resource_class('CarePlan'), search_params)
        validate_search_reply(versioned_resource_class('CarePlan'), reply, search_params)
      end

      test :read_interaction do
        metadata do
          id '06'
          name 'CarePlan read interaction supported'
          link 'https://www.hl7.org/fhir/us/core/CapabilityStatement-us-core-server.html'
          description %(
            A server SHALL support the CarePlan read interaction.
          )
          versions :r4
        end

        skip_if_not_supported(:CarePlan, [:read])
        skip 'No CarePlan resources could be found for this patient. Please use patients with more information.' unless @resources_found

        validate_read_reply(@care_plan, versioned_resource_class('CarePlan'))
      end

      test :vread_interaction do
        metadata do
          id '07'
          name 'CarePlan vread interaction supported'
          link 'https://www.hl7.org/fhir/us/core/CapabilityStatement-us-core-server.html'
          description %(
            A server SHOULD support the CarePlan vread interaction.
          )
          versions :r4
        end

        skip_if_not_supported(:CarePlan, [:vread])
        skip 'No CarePlan resources could be found for this patient. Please use patients with more information.' unless @resources_found

        validate_vread_reply(@care_plan, versioned_resource_class('CarePlan'))
      end

      test :history_interaction do
        metadata do
          id '08'
          name 'CarePlan history interaction supported'
          link 'https://www.hl7.org/fhir/us/core/CapabilityStatement-us-core-server.html'
          description %(
            A server SHOULD support the CarePlan history interaction.
          )
          versions :r4
        end

        skip_if_not_supported(:CarePlan, [:history])
        skip 'No CarePlan resources could be found for this patient. Please use patients with more information.' unless @resources_found

        validate_history_reply(@care_plan, versioned_resource_class('CarePlan'))
      end

      test 'Server returns the appropriate resources from the following _revincludes: Provenance:target' do
        metadata do
          id '09'
          link 'https://www.hl7.org/fhir/search.html#revinclude'
          description %(
            A Server SHALL be capable of supporting the following _revincludes: Provenance:target
          )
          versions :r4
        end

        search_params = {
          'patient': @instance.patient_id,
          'category': get_value_for_search_param(resolve_element_from_path(@care_plan_ary, 'category'))
        }
        search_params.each { |param, value| skip "Could not resolve #{param} in given resource" if value.nil? }

        search_params['_revinclude'] = 'Provenance:target'
        reply = get_resource_by_params(versioned_resource_class('CarePlan'), search_params)
        assert_response_ok(reply)
        assert_bundle_response(reply)
        provenance_results = reply&.resource&.entry&.map(&:resource)&.any? { |resource| resource.resourceType == 'Provenance' }
        assert provenance_results, 'No Provenance resources were returned from this search'
      end

      test 'CarePlan resources associated with Patient conform to US Core R4 profiles' do
        metadata do
          id '10'
          link 'http://hl7.org/fhir/us/core/StructureDefinition/us-core-careplan'
          description %(

            This test checks if the resources returned from prior searches conform to the US Core profiles.
            This includes checking for missing data elements and valueset verification.

          )
          versions :r4
        end

        skip 'No resources appear to be available for this patient. Please use patients with more information.' unless @resources_found
        test_resources_against_profile('CarePlan')
      end

      test 'At least one of every must support element is provided in any CarePlan for this patient.' do
        metadata do
          id '11'
          link 'http://www.hl7.org/fhir/us/core/general-guidance.html#must-support'
          description %(

            US Core Responders SHALL be capable of populating all data elements as part of the query results as specified by the US Core Server Capability Statement.
            This will look through all CarePlan resources returned from prior searches to see if any of them provide the following must support elements:

            CarePlan.text

            CarePlan.text.status

            CarePlan.status

            CarePlan.intent

            CarePlan.category

            CarePlan.category

            CarePlan.subject

          )
          versions :r4
        end

        skip 'No resources appear to be available for this patient. Please use patients with more information' unless @care_plan_ary&.any?
        must_support_confirmed = {}
        must_support_elements = [
          'CarePlan.text',
          'CarePlan.text.status',
          'CarePlan.status',
          'CarePlan.intent',
          'CarePlan.category',
          'CarePlan.category',
          'CarePlan.subject'
        ]
        must_support_elements.each do |path|
          @care_plan_ary&.each do |resource|
            truncated_path = path.gsub('CarePlan.', '')
            must_support_confirmed[path] = true if can_resolve_path(resource, truncated_path)
            break if must_support_confirmed[path]
          end
          resource_count = @care_plan_ary.length

          skip "Could not find #{path} in any of the #{resource_count} provided CarePlan resource(s)" unless must_support_confirmed[path]
        end
        @instance.save!
      end

      test 'All references can be resolved' do
        metadata do
          id '12'
          link 'http://hl7.org/fhir/references.html'
          description %(
            This test checks if references found in resources from prior searches can be resolved.
          )
          versions :r4
        end

        skip_if_not_supported(:CarePlan, [:search, :read])
        skip 'No resources appear to be available for this patient. Please use patients with more information.' unless @resources_found

        validate_reference_resolutions(@care_plan)
      end
    end
  end
end
