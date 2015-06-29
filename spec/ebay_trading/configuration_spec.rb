require 'securerandom'

require 'ebay_trading'
require 'ebay_trading/configuration'
require 'ebay_trading/ebay_trading_error'

include EbayTrading

describe Configuration do

  subject(:config) { Configuration.new }

  context 'when specifying the environment' do

    it { is_expected.to respond_to 'environment=' }
    it { is_expected.to respond_to 'sandbox?' }
    it { is_expected.to respond_to 'production?' }

    context 'when default settings' do
      it { is_expected.to be_sandbox }
      it { is_expected.not_to be_production }
    end

    context 'when setting production mode' do

      it 'should accept to :production symbol' do
        config.environment = :production
        expect(config).to be_production
      end

      it 'should accept to "Production" String' do
        config.environment = 'Production'
        expect(config).to be_production
      end

      it 'should revert to sandbox if sandbox is anything other than :production' do
        config.environment = :sandbox
        expect(config).to be_sandbox
        config.environment = 'random_string'
        expect(config).to be_sandbox
        config.environment = nil
        expect(config).to be_sandbox
      end
    end
  end


  context 'when getting the URI' do

    subject(:uri) { config.uri }
    it { is_expected.not_to be_nil }
    it { is_expected.to be_a URI }

    context 'when sandbox environment' do
      it { expect(uri.to_s).to eq(Configuration::URI_SANDBOX) }
    end

    context 'when production environment' do
      let(:environment) { :production }
      before { config.environment = environment }

      it { expect(config).to be_production }
      it { expect(uri.to_s).to eq(Configuration::URI_PRODUCTION) }
    end
  end


  context 'when setting application keys' do

    it { is_expected.not_to have_keys_set }

    it 'should accept valid keys' do
      config.dev_id  = SecureRandom.uuid
      config.app_id  = SecureRandom.uuid
      config.cert_id = SecureRandom.uuid
      is_expected.to have_keys_set
    end

    it 'should raise exception to invalid keys' do
      is_expected.not_to have_keys_set
      expect { config.dev_id  = 'INVALID' }.to raise_error EbayTradingError
      expect { config.app_id  = 'INVALID' }.to raise_error EbayTradingError
      expect { config.cert_id = 'INVALID' }.to raise_error EbayTradingError
    end
  end
end