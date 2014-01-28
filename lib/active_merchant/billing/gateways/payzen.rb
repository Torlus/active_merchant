module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class PayzenGateway < Gateway
      self.test_url = self.live_url = 'http://api.payzen.io/'
      self.supported_countries = ['DE', 'FR', 'BR']
      self.supported_cardtypes = [:visa, :master, :american_express]
      self.homepage_url = 'https://api.payzen.io/'
      self.display_name = 'PayZen'

      def initialize(options = {})
        requires!(options, :login)
        super
      end

      def authorize(money, creditcard, options = {})
        post = {}
        add_invoice(post, options)
        add_creditcard(post, creditcard)
        add_address(post, creditcard, options)
        add_customer_data(post, options)

        commit('authonly', money, post)
      end

      def purchase(money, creditcard, options = {})
        post = {}
        add_invoice(post, options)
        add_creditcard(post, creditcard)
        add_address(post, creditcard, options)
        add_customer_data(post, options)

        commit('sale', money, post)
      end

      def capture(money, authorization, options = {})
        commit('capture', money, post)
      end

      private

      CARD_TYPE = {
        'visa' => 'VISA',
        'master' => 'MASTERCARD',
        'american_express' => 'AMEX'
      }

      def add_customer_data(post, options)
      end

      def add_address(post, creditcard, options)
      end

      def add_invoice(post, options)
        add_entry post, :currency, options[:currency]
      end

      def add_creditcard(post, creditcard)
        card = {}
        add_entry card, :method, CARD_TYPE[creditcard.brand]
        add_entry card, :pan, creditcard.number
        add_entry card, :exp_month, creditcard.month
        add_entry card, :exp_year, creditcard.year
        add_entry card, :csc, creditcard.verification_value
        cards = (post[:available_instruments] ||= [])
        cards << card
      end

      def parse(body)
        JSON.parse(body)
      end

      def add_entry(hash, key, value, default = nil)
        if value
          hash[key] = value
        elsif default
          hash[key] = default
        end
      end

      def commit(action, money, parameters)
        raise 'TODO' if action == 'capture'
        add_entry parameters, :amount, money
        headers = {
          "Content-Type" => "application/json",
          "Authorization" => "Basic #{Base64.strict_encode64(options[:login] + ':').strip}"
        }
        url = "#{live_url}/charges"
        begin
          body = parse(ssl_post(url, post_data(action, parameters), headers))
        rescue ResponseError => e
          body = parse(e.response.body)
        end

        Rails.logger.info body

        message = 'Internal error'
        success = false
        options = {}
        begin
          charge_status = body['charge']['status']
          messages = body['charge']['messages']
          success = (charge_status == 'complete')
          if messages.to_a.any?
            message = messages.last['description']
          else
            message = 'Transaction approved.' if success
          end
          if success
            options[:authorization] = body['charge']['id']
          end
        rescue
        end

        Response.new( success, message, body )
      end

      def message_from(response)
      end

      def post_data(action, parameters = {})
        parameters.to_json
      end
    end
  end
end
