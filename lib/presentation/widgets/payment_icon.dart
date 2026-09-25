import 'package:flutter/material.dart';

import '../../domain/entities/sale.dart';

IconData paymentIcon(PaymentMethod method) => switch (method) {
      PaymentMethod.cash => Icons.payments_outlined,
      PaymentMethod.card => Icons.credit_card,
      PaymentMethod.gcash || PaymentMethod.maya || PaymentMethod.cashless => Icons.qr_code_2,
    };
