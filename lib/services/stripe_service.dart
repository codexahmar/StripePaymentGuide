import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:stripe_payment/consts.dart';

class StripeService {
  StripeService._();
  static final StripeService instance = StripeService._();

  bool _isStripeInitialized = false;

  /// Initialize Stripe with the publishable key
  Future<void> initStripe() async {
    if (_isStripeInitialized) return;
    Stripe.publishableKey = stripePublishableKey;
    await Stripe.instance.applySettings();
    _isStripeInitialized = true;
    print("Stripe initialized");
  }

  /// Entry point to make a payment
  Future<void> makePayment({
    required int amount,
    required String currency,
    required BuildContext context,
  }) async {
    try {
      await initStripe();

      // 1. Create a PaymentIntent on Stripe server
      final clientSecret = await createPaymentIntent(amount, currency);
      if (clientSecret == null) {
        throw Exception("Failed to create PaymentIntent");
      }

      // 2. Initialize the payment sheet
      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          paymentIntentClientSecret: clientSecret,
          style: ThemeMode.dark,
          merchantDisplayName: 'Codex Ahmar',
        ),
      );

      // 3. Present the payment sheet
      await Stripe.instance.presentPaymentSheet();

      // 4. Handle success
      _handlePaymentSuccess(context);
    } catch (e) {
      _handlePaymentError(e, context);
    }
  }

  /// Create a payment intent and return the client secret
  Future<String?> createPaymentIntent(int amount, String currency) async {
    try {
      final Dio dio = Dio();

      final Map<String, dynamic> data = {
        'amount': _calculateAmount(amount),
        'currency': currency,
        'payment_method_types[]': 'card',
      };

      final response = await dio.post(
        'https://api.stripe.com/v1/payment_intents',
        data: data,
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
          headers: {
            'Authorization': 'Bearer $stripeSecretKey',
            'Content-Type': 'application/x-www-form-urlencoded',
          },
        ),
      );

      if (response.data != null && response.data['client_secret'] != null) {
        print('Payment Intent Created: ${response.data}');
        return response.data['client_secret'];
      }

      return null;
    } catch (e) {
      print('Error creating PaymentIntent: $e');
      return null;
    }
  }

  /// Convert amount to cents
  String _calculateAmount(int amount) {
    final amountInCents = amount * 100;
    return amountInCents.toString();
  }

  /// Handle successful payment
  void _handlePaymentSuccess(BuildContext context) {
    print("🎉 Payment successful!");
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Payment Successful')));
  }

  /// Handle payment failure or cancellation
  void _handlePaymentError(dynamic error, BuildContext context) {
    if (error is StripeException) {
      print("StripeException: ${error.error.localizedMessage}");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Stripe error: ${error.error.localizedMessage}"),
        ),
      );
    } else {
      print("Unexpected error: $error");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Payment failed. Please try again.")),
      );
    }
  }
}
