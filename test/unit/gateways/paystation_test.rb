require 'test_helper'

class PaystationTest < Test::Unit::TestCase
  include CommStub
  def setup
    @gateway = PaystationGateway.new(
      :paystation_id => 'some_id_number',
      :gateway_id    => 'another_id_number'
    )

    @credit_card = credit_card
    @amount = 100

    @options = {
      :order_id => '1',
      :customer => 'Joe Bloggs, Customer ID #56',
      :description => 'Store Purchase'
    }
  end

  def test_successful_purchase
    @gateway.expects(:ssl_post).returns(successful_purchase_response)

    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response

    assert_equal '0008813023-01', response.authorization

    assert_equal 'Store Purchase', response.params['merchant_reference']
    assert response.test?
  end

  def test_unsuccessful_request
    @gateway.expects(:ssl_post).returns(failed_purchase_response)

    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert response.test?
  end

  def test_successful_store
    @gateway.expects(:ssl_post).returns(successful_store_response)

    assert response = @gateway.store(@credit_card, @options.merge(:token => 'justatest1310263135'))
    assert_success response
    assert response.test?

    assert_equal 'justatest1310263135', response.token
  end

  def test_successful_purchase_from_token
    @gateway.expects(:ssl_post).returns(successful_stored_purchase_response)

    token = 'u09fxli14afpnd6022x0z82317beqe9e2w048l9it8286k6lpvz9x27hdal9bl95'

    assert response = @gateway.purchase(@amount, token, @options)
    assert_success response

    assert_equal '0009062149-01', response.authorization

    assert_equal 'Store Purchase', response.params['merchant_reference']
    assert response.test?
  end

  def test_successful_authorization
    @gateway.expects(:ssl_post).returns(successful_authorization_response)

    assert response = @gateway.authorize(@amount, @credit_card, @options)
    assert_success response

    assert response.authorization
  end

  def test_successful_capture
    @gateway.expects(:ssl_post).returns(successful_capture_response)

    assert response = @gateway.capture(@amount, '0009062250-01', @options.merge(:credit_card_verification => 123))
    assert_success response
  end

  def test_successful_refund
    response = stub_comms do
      @gateway.purchase(@amount, @credit_card, @options)
    end.respond_with(successful_purchase_response)

    assert_success response
    assert_equal '0008813023-01', response.authorization
    assert_equal 'Store Purchase', response.params['merchant_reference']

    refund = stub_comms do
      @gateway.refund(@amount, response.authorization, @options)
    end.check_request do |endpoint, data, headers|
      assert_match(/0008813023-01/, data)
    end.respond_with(successful_refund_response)

    assert_success refund
  end

  def test_failed_refund
    response = stub_comms do
      @gateway.refund(nil, '', @options)
    end.respond_with(failed_refund_response)

    assert_failure response
  end

  def test_successful_verify
    @gateway.expects(:ssl_post).returns(successful_authorization_response)

    assert response = @gateway.verify(@credit_card, @options)
    assert_success response
  end

  def test_scrub
    assert @gateway.supports_scrubbing?
    assert_equal @gateway.scrub(pre_scrubbed), post_scrubbed
  end

  private

  def successful_purchase_response
    %(<?xml version="1.0" standalone="yes"?>
    <response>
    <ec>0</ec>
    <em>Transaction successful</em>
    <ti>0006713018-01</ti>
    <ct>mastercard</ct>
    <merchant_ref>Store Purchase</merchant_ref>
    <tm>T</tm>
    <MerchantSession>1</MerchantSession>
    <UsedAcquirerMerchantID>123456</UsedAcquirerMerchantID>
    <TransactionID>0008813023-01</TransactionID>
    <PurchaseAmount>10000</PurchaseAmount>
    <Locale/>
    <ReturnReceiptNumber>8813023</ReturnReceiptNumber>
    <ShoppingTransactionNumber/>
    <AcqResponseCode>00</AcqResponseCode>
    <QSIResponseCode>0</QSIResponseCode>
    <CSCResultCode/>
    <AVSResultCode/>
    <TransactionTime>2011-06-22 00:05:52</TransactionTime>
    <PaystationErrorCode>0</PaystationErrorCode>
    <PaystationErrorMessage>Transaction successful</PaystationErrorMessage>
    <MerchantReference>Store Purchase</MerchantReference>
    <TransactionMode>T</TransactionMode>
    <BatchNumber>0622</BatchNumber>
    <AuthorizeID/>
    <Cardtype>MC</Cardtype>
    <Username>12345</Username>
    <RequestIP>192.168.0.1</RequestIP>
    <RequestUserAgent/>
    <RequestHttpReferrer/>
    <PaymentRequestTime>2011-06-22 00:05:52</PaymentRequestTime>
    <DigitalOrderTime/>
    <DigitalReceiptTime>2011-06-22 00:05:52</DigitalReceiptTime>
    <PaystationTransactionID>0008813023-01</PaystationTransactionID>
    <IssuerName>unknown</IssuerName>
    <IssuerCountry>unknown</IssuerCountry>
    </response>)
  end

  def failed_purchase_response
    %(<?xml version="1.0" standalone="yes"?>
    <response>
    <ec>5</ec>
    <em>Insufficient Funds</em>
    <ti>0006713018-01</ti>
    <ct>mastercard</ct>
    <merchant_ref>Store Purchase</merchant_ref>
    <tm>T</tm>
    <MerchantSession>1</MerchantSession>
    <UsedAcquirerMerchantID>123456</UsedAcquirerMerchantID>
    <TransactionID>0008813018-01</TransactionID>
    <PurchaseAmount>10051</PurchaseAmount>
    <Locale/>
    <ReturnReceiptNumber>8813018</ReturnReceiptNumber>
    <ShoppingTransactionNumber/>
    <AcqResponseCode>51</AcqResponseCode>
    <QSIResponseCode>5</QSIResponseCode>
    <CSCResultCode/>
    <AVSResultCode/>
    <TransactionTime>2011-06-22 00:05:46</TransactionTime>
    <PaystationErrorCode>5</PaystationErrorCode>
    <PaystationErrorMessage>Insufficient Funds</PaystationErrorMessage>
    <MerchantReference>Store Purchase</MerchantReference>
    <TransactionMode>T</TransactionMode>
    <BatchNumber>0622</BatchNumber>
    <AuthorizeID/>
    <Cardtype>MC</Cardtype>
    <Username>123456</Username>
    <RequestIP>192.168.0.1</RequestIP>
    <RequestUserAgent/>
    <RequestHttpReferrer/>
    <PaymentRequestTime>2011-06-22 00:05:46</PaymentRequestTime>
    <DigitalOrderTime/>
    <DigitalReceiptTime>2011-06-22 00:05:46</DigitalReceiptTime>
    <PaystationTransactionID>0008813018-01</PaystationTransactionID>
    <IssuerName>unknown</IssuerName>
    <IssuerCountry>unknown</IssuerCountry>
    </response>)
  end

  def successful_store_response
    %(<?xml version="1.0" standalone="yes"?>
    <PaystationFuturePaymentResponse>
    <ec>34</ec>
    <em>Future Payment Saved Ok</em>
    <ti/>
    <ct/>
    <merchant_ref>Store Purchase</merchant_ref>
    <tm>T</tm>
    <MerchantSession>3e48fa9a6b0fe36177adf7269db7a3c4</MerchantSession>
    <UsedAcquirerMerchantID/>
    <TransactionID/>
    <PurchaseAmount>0</PurchaseAmount>
    <Locale/>
    <ReturnReceiptNumber/>
    <ShoppingTransactionNumber/>
    <AcqResponseCode/>
    <QSIResponseCode/>
    <CSCResultCode/>
    <AVSResultCode/>
    <TransactionTime>2011-07-10 13:58:55</TransactionTime>
    <PaystationErrorCode>34</PaystationErrorCode>
    <PaystationErrorMessage>Future Payment Saved Ok</PaystationErrorMessage>
    <MerchantReference>Store Purchase</MerchantReference>
    <TransactionMode>T</TransactionMode>
    <BatchNumber/>
    <AuthorizeID/>
    <Cardtype/>
    <Username>123456</Username>
    <RequestIP>192.168.0.1</RequestIP>
    <RequestUserAgent/>
    <RequestHttpReferrer/>
    <PaymentRequestTime>2011-07-10 13:58:55</PaymentRequestTime>
    <DigitalOrderTime/>
    <DigitalReceiptTime>2011-07-10 13:58:55</DigitalReceiptTime>
    <PaystationTransactionID>0009062177-01</PaystationTransactionID>
    <FuturePaymentToken>justatest1310263135</FuturePaymentToken>
    <IssuerName>unknown</IssuerName>
    <IssuerCountry>unknown</IssuerCountry>
    </PaystationFuturePaymentResponse>)
  end

  def successful_stored_purchase_response
    %(<?xml version="1.0" standalone="yes"?>
    <PaystationFuturePaymentResponse>
    <ec>0</ec>
    <em>Transaction successful</em>
    <ti>0006713018-01</ti>
    <ct>visa</ct>
    <merchant_ref>Store Purchase</merchant_ref>
    <tm>T</tm>
    <MerchantSession>0fc70a577f19ae63f651f53c7044640a</MerchantSession>
    <UsedAcquirerMerchantID>123456</UsedAcquirerMerchantID>
    <TransactionID>0009062149-01</TransactionID>
    <PurchaseAmount>10000</PurchaseAmount>
    <Locale/>
    <ReturnReceiptNumber>9062149</ReturnReceiptNumber>
    <ShoppingTransactionNumber/>
    <AcqResponseCode>00</AcqResponseCode>
    <QSIResponseCode>0</QSIResponseCode>
    <CSCResultCode/>
    <AVSResultCode/>
    <TransactionTime>2011-07-10 13:55:00</TransactionTime>
    <PaystationErrorCode>0</PaystationErrorCode>
    <PaystationErrorMessage>Transaction successful</PaystationErrorMessage>
    <MerchantReference>Store Purchase</MerchantReference>
    <TransactionMode>T</TransactionMode>
    <BatchNumber>0710</BatchNumber>
    <AuthorizeID/>
    <Cardtype>VC</Cardtype>
    <Username>123456</Username>
    <RequestIP>192.168.0.1</RequestIP>
    <RequestUserAgent/>
    <RequestHttpReferrer/>
    <PaymentRequestTime>2011-07-10 13:55:00</PaymentRequestTime>
    <DigitalOrderTime/>
    <DigitalReceiptTime>2011-07-10 13:55:00</DigitalReceiptTime>
    <PaystationTransactionID>0009062149-01</PaystationTransactionID>
    <FuturePaymentToken>u09fxli14afpnd6022x0z82317beqe9e2w048l9it8286k6lpvz9x27hdal9bl95</FuturePaymentToken>
    <IssuerName>unknown</IssuerName>
    <IssuerCountry>unknown</IssuerCountry>
    </PaystationFuturePaymentResponse>)
  end

  def successful_authorization_response
    %(<?xml version="1.0" standalone="yes"?>
    <response>
    <ec>0</ec>
    <em>Transaction successful</em>
    <ti>0009062250-01</ti>
    <ct>visa</ct>
    <merchant_ref>Store Purchase</merchant_ref>
    <tm>T</tm>
    <MerchantSession>b2168af96076522466af4e3d61e5ba0c</MerchantSession>
    <UsedAcquirerMerchantID>123456</UsedAcquirerMerchantID>
    <TransactionID>0009062250-01</TransactionID>
    <PurchaseAmount>10000</PurchaseAmount>
    <Locale/>
    <ReturnReceiptNumber>9062250</ReturnReceiptNumber>
    <ShoppingTransactionNumber/>
    <AcqResponseCode>00</AcqResponseCode>
    <QSIResponseCode>0</QSIResponseCode>
    <CSCResultCode/>
    <AVSResultCode/>
    <TransactionTime>2011-07-10 14:11:00</TransactionTime>
    <PaystationErrorCode>0</PaystationErrorCode>
    <PaystationErrorMessage>Transaction successful</PaystationErrorMessage>
    <MerchantReference>Store Purchase</MerchantReference>
    <TransactionMode>T</TransactionMode>
    <BatchNumber>0710</BatchNumber>
    <AuthorizeID/>
    <Cardtype>VC</Cardtype>
    <Username>123456</Username>
    <RequestIP>192.168.0.1</RequestIP>
    <RequestUserAgent/>
    <RequestHttpReferrer/>
    <PaymentRequestTime>2011-07-10 14:11:00</PaymentRequestTime>
    <DigitalOrderTime/>
    <DigitalReceiptTime>2011-07-10 14:11:00</DigitalReceiptTime>
    <PaystationTransactionID>0009062250-01</PaystationTransactionID>
    <IssuerName>unknown</IssuerName>
    <IssuerCountry>unknown</IssuerCountry>
    </response>)
  end

  def successful_capture_response
    %(<?xml version="1.0" standalone="yes"?>
    <PaystationCaptureResponse>
    <ec>0</ec>
    <em>Transaction successful</em>
    <ti>0009062289-01</ti>
    <ct/>
    <merchant_ref>Store Purchase</merchant_ref>
    <tm>T</tm>
    <MerchantSession>485fdedc81dc83848dd799cd10a869db</MerchantSession>
    <UsedAcquirerMerchantID>123456</UsedAcquirerMerchantID>
    <TransactionID>0009062289-01</TransactionID>
    <CaptureAmount>10000</CaptureAmount>
    <Locale/>
    <ReturnReceiptNumber>9062289</ReturnReceiptNumber>
    <ShoppingTransactionNumber/>
    <AcqResponseCode>00</AcqResponseCode>
    <QSIResponseCode>0</QSIResponseCode>
    <CSCResultCode/>
    <AVSResultCode/>
    <TransactionTime>2011-07-10 14:17:36</TransactionTime>
    <PaystationErrorCode>0</PaystationErrorCode>
    <PaystationErrorMessage>Transaction successful</PaystationErrorMessage>
    <MerchantReference>Store Purchase</MerchantReference>
    <TransactionMode>T</TransactionMode>
    <BatchNumber>0710</BatchNumber>
    <AuthorizeID/>
    <Cardtype/>
    <Username>123456</Username>
    <RequestIP>192.168.0.1</RequestIP>
    <RequestUserAgent/>
    <RequestHttpReferrer/>
    <PaymentRequestTime>2011-07-10 14:17:36</PaymentRequestTime>
    <DigitalOrderTime>2011-07-10 14:17:36</DigitalOrderTime>
    <DigitalReceiptTime>2011-07-10 14:17:36</DigitalReceiptTime>
    <PaystationTransactionID/>
    <RefundedAmount/>
    <CapturedAmount>10000</CapturedAmount>
    <AuthorisedAmount/>
    </PaystationCaptureResponse>)
  end

  def successful_refund_response
    %(<?xml version="1.0" standalone="yes"?>
    <PaystationRefundResponse>
    <ec>0</ec>
    <em>Transaction successful</em>
    <ti>0008813023-01</ti>
    <ct>mastercard</ct>
    <merchant_ref>Store Purchase</merchant_ref>
    <tm>T</tm>
    <MerchantSession>70ceae1b3f069e41ca7f4350a1180cb1</MerchantSession>
    <UsedAcquirerMerchantID>924518</UsedAcquirerMerchantID>
    <TransactionID>0008813023-01</TransactionID>
    <RefundAmount>10000</RefundAmount>
    <SurchargeAmount/>
    <Locale>en</Locale>
    <ReturnReceiptNumber>58160420</ReturnReceiptNumber>
    <ShoppingTransactionNumber/>
    <AcqResponseCode>00</AcqResponseCode>
    <QSIResponseCode>0</QSIResponseCode>
    <CSCResultCode/>
    <AVSResultCode/>
    <TransactionTime>2015-06-25 03:23:24</TransactionTime>
    <PaystationErrorCode>0</PaystationErrorCode>
    <PaystationErrorMessage>Transaction successful</PaystationErrorMessage>
    <PaystationExtendedErrorMessage/>
    <MerchantReference>Store Purchase</MerchantReference>
    <CardNo>512345XXXXXXX346</CardNo>
    <CardExpiry>1305</CardExpiry>
    <TransactionProcess>refund</TransactionProcess>
    <TransactionMode>T</TransactionMode>
    <BatchNumber>0625</BatchNumber>
    <AuthorizeID/>
    <Cardtype>MC</Cardtype>
    <Username>609035</Username>
    <RequestIP>173.95.131.239</RequestIP>
    <RequestUserAgent>Ruby</RequestUserAgent>
    <RequestHttpReferrer/>
    <PaymentRequestTime>2015-06-25 03:23:24</PaymentRequestTime>
    <DigitalOrderTime>2015-06-25 03:23:24</DigitalOrderTime>
    <DigitalReceiptTime/>
    <PaystationTransactionID/>
    <RefundedAmount>10000</RefundedAmount>
    <CapturedAmount/>
    </PaystationRefundResponse>)
  end

  def failed_refund_response
    %(<?xml version="1.0" standalone="yes"?>
      <FONT FACE="Arial" SIZE="2"><strong>Error 11:</strong> Not enough input parameters.</FONT>)
  end

  def pre_scrubbed
    'pstn_pi=609035&pstn_gi=PUSHPAY&pstn_2p=t&pstn_nr=t&pstn_df=yymm&pstn_ms=a755b9c84a530aee91dc3077f57294b0&pstn_mo=Store+Purchase&pstn_mr=&pstn_am=&pstn_cu=NZD&pstn_cn=5123456789012346&pstn_ct=visa&pstn_ex=1305&pstn_cc=123&pstn_tm=T&paystation=_empty'
  end

  def post_scrubbed
    'pstn_pi=609035&pstn_gi=PUSHPAY&pstn_2p=t&pstn_nr=t&pstn_df=yymm&pstn_ms=a755b9c84a530aee91dc3077f57294b0&pstn_mo=Store+Purchase&pstn_mr=&pstn_am=&pstn_cu=NZD&pstn_cn=[FILTERED]&pstn_ct=visa&pstn_ex=1305&pstn_cc=[FILTERED]&pstn_tm=T&paystation=_empty'
  end
end
