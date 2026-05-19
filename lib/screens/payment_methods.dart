import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../config/theme.dart';

class PaymentMethodsScreenFull extends StatefulWidget {
  const PaymentMethodsScreenFull({super.key});

  @override
  State<PaymentMethodsScreenFull> createState() => _PaymentMethodsScreenFullState();
}

class _PaymentMethodsScreenFullState extends State<PaymentMethodsScreenFull> {
  List<Map<String, dynamic>> paymentMethods = [
    {
      'id': 'visa',
      'type': 'Visa',
      'icon': Icons.credit_card,
      'lastFour': '4242',
      'expiry': '12/26',
      'isDefault': true,
    },
    {
      'id': 'mastercard',
      'type': 'Mastercard',
      'icon': Icons.credit_card,
      'lastFour': '8765',
      'expiry': '08/25',
      'isDefault': false,
    },
    {
      'id': 'amex',
      'type': 'American Express',
      'icon': Icons.credit_card,
      'lastFour': '1234',
      'expiry': '06/27',
      'isDefault': false,
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        centerTitle: false,
        title: Text(
          'Payment Methods',
          style: GoogleFonts.epilogue(
            fontSize: 28,
            fontWeight: FontWeight.w700,
            color: AppColors.onSurface,
          ),
        ),
        foregroundColor: AppColors.onSurface,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Add New Card Button
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: AppColors.fireSunGradient,
                  borderRadius: BorderRadius.circular(AppRadii.lg),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {},
                    borderRadius: BorderRadius.circular(AppRadii.lg),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.add, color: Colors.white, size: 20),
                          const SizedBox(width: AppSpacing.sm),
                          Text(
                            'Add New Card',
                            style: GoogleFonts.epilogue(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),

              // Saved Payment Methods
              Text(
                'Saved Cards',
                style: GoogleFonts.epilogue(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppColors.onSurface,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: paymentMethods.length,
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.md),
                    child: _buildPaymentMethodCard(paymentMethods[index], index),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPaymentMethodCard(Map<String, dynamic> method, int index) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        border: Border.all(
          color: method['isDefault']
              ? AppColors.primary
              : AppColors.outlineVariant,
          width: method['isDefault'] ? 2 : 1,
        ),
        borderRadius: BorderRadius.circular(AppRadii.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with Card Type and Default Badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    method['icon'],
                    color: AppColors.primary,
                    size: 24,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        method['type'],
                        style: GoogleFonts.epilogue(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.onSurface,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '•••• ${method['lastFour']}',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              if (method['isDefault'])
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: AppSpacing.xs,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primaryContainer,
                    border: Border.all(color: AppColors.primary),
                    borderRadius: BorderRadius.circular(AppRadii.full),
                  ),
                  child: Text(
                    'Default',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: AppColors.onPrimaryContainer,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          // Expiry and Actions
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Expires',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w400,
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    method['expiry'],
                    style: GoogleFonts.epilogue(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.onSurface,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  // Set as Default Button
                  if (!method['isDefault'])
                    GestureDetector(
                      onTap: () {},
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm,
                          vertical: AppSpacing.xs,
                        ),
                        decoration: BoxDecoration(
                          border: Border.all(color: AppColors.outline),
                          borderRadius: BorderRadius.circular(AppRadii.md),
                        ),
                        child: Text(
                          'Set Default',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(width: AppSpacing.sm),

                  // Delete Button
                  GestureDetector(
                    onTap: () {},
                    child: Container(
                      padding: const EdgeInsets.all(AppSpacing.xs),
                      decoration: BoxDecoration(
                        border: Border.all(color: AppColors.error),
                        borderRadius: BorderRadius.circular(AppRadii.md),
                      ),
                      child: Icon(
                        Icons.delete_outline,
                        color: AppColors.error,
                        size: 16,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
