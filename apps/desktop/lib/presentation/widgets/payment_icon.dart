import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';

import 'package:shop_core/domain/entities/sale.dart';

IconData paymentIcon(PaymentMethod method) => switch (method) {
      PaymentMethod.cash => CupertinoIcons.rectangle_stack,
      PaymentMethod.card => CupertinoIcons.creditcard,
      PaymentMethod.gcash || PaymentMethod.maya || PaymentMethod.cashless => CupertinoIcons.qrcode,
    };
