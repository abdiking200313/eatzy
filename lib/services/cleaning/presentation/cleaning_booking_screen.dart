import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../config/theme.dart';
import '../../../platform/localization/app_money.dart';
import '../../../widgets/app_cards.dart';
import '../../../widgets/app_scaffold.dart';
import '../models/cleaning_models.dart';
import 'cleaning_controller.dart';

class CleaningBookingScreen extends StatefulWidget {
  const CleaningBookingScreen({super.key, this.controller});

  final CleaningController? controller;

  @override
  State<CleaningBookingScreen> createState() => _CleaningBookingScreenState();
}

class _CleaningBookingScreenState extends State<CleaningBookingScreen> {
  late final CleaningController _controller;
  late final TextEditingController _addressController;
  late final TextEditingController _instructionsController;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? CleaningController.instance;
    _addressController = TextEditingController(text: _controller.streetAddress);
    _instructionsController = TextEditingController(
      text: _controller.instructions,
    );
  }

  @override
  void dispose() {
    _addressController.dispose();
    _instructionsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final booking = _controller.lastBooking;
        return AppScaffold(
          title: 'Arrange a cleaner',
          showBackButton: true,
          body: booking == null
              ? _CleaningBookingForm(
                  controller: _controller,
                  addressController: _addressController,
                  instructionsController: _instructionsController,
                  onChooseDateTime: _chooseDateTime,
                )
              : _ConfirmationView(
                  booking: booking,
                  onBookAnother: () {
                    _addressController.clear();
                    _instructionsController.clear();
                    _controller.startNewBooking();
                  },
                ),
        );
      },
    );
  }

  Future<void> _chooseDateTime(BuildContext context) async {
    final now = DateTime.now();
    final current = _controller.startsAt;
    final initialDate = current != null && current.isAfter(now)
        ? current
        : now.add(const Duration(days: 1));
    final date = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 365)),
    );
    if (date == null || !context.mounted) {
      return;
    }

    final time = await showTimePicker(
      context: context,
      initialTime: current == null
          ? const TimeOfDay(hour: 9, minute: 0)
          : TimeOfDay.fromDateTime(current),
    );
    if (time == null) {
      return;
    }
    _controller.setStartsAt(
      DateTime(date.year, date.month, date.day, time.hour, time.minute),
    );
  }
}

class _CleaningBookingForm extends StatelessWidget {
  const _CleaningBookingForm({
    required this.controller,
    required this.addressController,
    required this.instructionsController,
    required this.onChooseDateTime,
  });

  final CleaningController controller;
  final TextEditingController addressController;
  final TextEditingController instructionsController;
  final Future<void> Function(BuildContext context) onChooseDateTime;

  @override
  Widget build(BuildContext context) {
    final errors = controller.validationErrors;
    return ListView(
      padding: const EdgeInsets.all(TwSpacing.x5),
      children: [
        _CleanerField(controller: controller, errors: errors),
        const SizedBox(height: TwSpacing.x6),
        _SpecialtyField(controller: controller, errors: errors),
        const SizedBox(height: TwSpacing.x5),
        _PlanField(controller: controller, errors: errors),
        const SizedBox(height: TwSpacing.x6),
        _AddressSection(
          controller: controller,
          addressController: addressController,
          errors: errors,
        ),
        const SizedBox(height: TwSpacing.x6),
        _StartTimeField(
          controller: controller,
          errors: errors,
          onTap: () => onChooseDateTime(context),
        ),
        const SizedBox(height: TwSpacing.x6),
        _InstructionsField(
          controller: controller,
          instructionsController: instructionsController,
          errors: errors,
        ),
        const SizedBox(height: TwSpacing.x3),
        _PriceSummary(controller: controller),
        if (controller.submissionError case final error?) ...[
          const SizedBox(height: TwSpacing.x3),
          Text(error, style: TwText.textSm().copyWith(color: TwColors.error)),
        ],
        const SizedBox(height: TwSpacing.x5),
        GradientActionButton(
          label: controller.isSubmitting
              ? 'Saving arrangement...'
              : 'Request arrangement',
          icon: const Icon(Icons.arrow_forward, color: TwColors.white),
          onPressed: controller.isSubmitting ? null : controller.confirmBooking,
        ),
        const SizedBox(height: TwSpacing.x8),
      ],
    );
  }
}

class _CleanerField extends StatelessWidget {
  const _CleanerField({required this.controller, required this.errors});

  final CleaningController controller;
  final Map<String, String> errors;

  @override
  Widget build(BuildContext context) {
    final professional = controller.selectedProfessional;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Cleaner', style: TwText.fontBoldBase()),
        const SizedBox(height: TwSpacing.x2),
        DropdownButtonFormField<CleaningProfessional>(
          key: ValueKey(professional?.id),
          initialValue: professional,
          isExpanded: true,
          decoration: InputDecoration(
            hintText: 'Choose a cleaner',
            errorText: errors['professional'],
            border: const OutlineInputBorder(),
          ),
          items: [
            for (final cleaner in controller.professionals)
              DropdownMenuItem(
                value: cleaner,
                child: Text(
                  '${cleaner.displayName} • '
                  '${cleaner.rating.toStringAsFixed(1)}★',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
          onChanged: controller.selectProfessional,
        ),
        if (professional != null) ...[
          const SizedBox(height: TwSpacing.x3),
          _SelectedCleaner(cleaner: professional),
        ],
      ],
    );
  }
}

class _SpecialtyField extends StatelessWidget {
  const _SpecialtyField({required this.controller, required this.errors});

  final CleaningController controller;
  final Map<String, String> errors;

  @override
  Widget build(BuildContext context) {
    final professional = controller.selectedProfessional;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Specialty', style: TwText.fontBoldBase()),
        const SizedBox(height: TwSpacing.x2),
        DropdownButtonFormField<CleaningSpecialty>(
          key: ValueKey(
            '${professional?.id}-${controller.selectedSpecialty?.id}',
          ),
          initialValue: controller.selectedSpecialty,
          isExpanded: true,
          decoration: InputDecoration(
            hintText: professional == null
                ? 'Choose a cleaner first'
                : 'What support do you need?',
            errorText: errors['specialty'],
            border: const OutlineInputBorder(),
          ),
          items: [
            for (final specialty
                in professional?.specialties ?? const <CleaningSpecialty>[])
              DropdownMenuItem(
                value: specialty,
                child: Text(specialty.name, overflow: TextOverflow.ellipsis),
              ),
          ],
          onChanged: professional == null ? null : controller.selectSpecialty,
        ),
      ],
    );
  }
}

class _PlanField extends StatelessWidget {
  const _PlanField({required this.controller, required this.errors});

  final CleaningController controller;
  final Map<String, String> errors;

  @override
  Widget build(BuildContext context) {
    final professional = controller.selectedProfessional;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Arrangement', style: TwText.fontBoldBase()),
        const SizedBox(height: TwSpacing.x2),
        DropdownButtonFormField<CleaningStayPlan>(
          key: ValueKey(
            '${professional?.id}-${controller.selectedPlan?.durationWeeks}',
          ),
          initialValue: controller.selectedPlan,
          isExpanded: true,
          decoration: InputDecoration(
            hintText: professional == null
                ? 'Choose a cleaner first'
                : 'Choose 1, 2, or 4 weeks',
            errorText: errors['plan'],
            border: const OutlineInputBorder(),
          ),
          items: [
            for (final plan
                in professional?.stayPlans ?? const <CleaningStayPlan>[])
              DropdownMenuItem(
                value: plan,
                child: Text(
                  '${plan.durationWeeks} '
                  '${plan.durationWeeks == 1 ? 'week' : 'weeks'} • '
                  '${AppMoney.format(plan.weeklyRate)}/week',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
          onChanged: professional == null ? null : controller.selectPlan,
        ),
      ],
    );
  }
}

class _AddressSection extends StatelessWidget {
  const _AddressSection({
    required this.controller,
    required this.addressController,
    required this.errors,
  });

  final CleaningController controller;
  final TextEditingController addressController;
  final Map<String, String> errors;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Address in Somalia', style: TwText.fontBoldBase()),
        const SizedBox(height: TwSpacing.x2),
        DropdownButtonFormField<String>(
          key: ValueKey(controller.city),
          initialValue: controller.city,
          decoration: InputDecoration(
            labelText: 'City',
            errorText: errors['city'],
            border: const OutlineInputBorder(),
          ),
          items: [
            for (final city in CleaningController.supportedCities)
              DropdownMenuItem(value: city, child: Text(city)),
          ],
          onChanged: controller.selectCity,
        ),
        const SizedBox(height: TwSpacing.x3),
        TextField(
          key: const Key('cleaning-address-field'),
          controller: addressController,
          onChanged: controller.setStreetAddress,
          textInputAction: TextInputAction.next,
          decoration: InputDecoration(
            labelText: 'Street or neighbourhood',
            hintText: 'e.g. Maka Al-Mukarama Road',
            suffixText: 'Somalia',
            errorText: errors['address'],
            border: const OutlineInputBorder(),
          ),
        ),
      ],
    );
  }
}

class _StartTimeField extends StatelessWidget {
  const _StartTimeField({
    required this.controller,
    required this.errors,
    required this.onTap,
  });

  final CleaningController controller;
  final Map<String, String> errors;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.serviceColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Preferred start', style: TwText.fontBoldBase()),
        const SizedBox(height: TwSpacing.x2),
        OutlinedCard(
          padding: EdgeInsets.zero,
          backgroundColor: palette.card,
          borderColor: errors.containsKey('startsAt')
              ? TwColors.error
              : palette.border,
          child: ListTile(
            key: const Key('cleaning-date-time-picker'),
            leading: Icon(Icons.calendar_month_outlined, color: palette.accent),
            title: Text(
              controller.startsAt == null
                  ? 'Choose start date and time'
                  : DateFormat(
                      'EEE, MMM d • h:mm a',
                    ).format(controller.startsAt!),
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: onTap,
          ),
        ),
        if (errors['startsAt'] case final error?) ...[
          const SizedBox(height: TwSpacing.x1),
          Text(error, style: TwText.textXs().copyWith(color: TwColors.error)),
        ],
      ],
    );
  }
}

class _InstructionsField extends StatelessWidget {
  const _InstructionsField({
    required this.controller,
    required this.instructionsController,
    required this.errors,
  });

  final CleaningController controller;
  final TextEditingController instructionsController;
  final Map<String, String> errors;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Instructions', style: TwText.fontBoldBase()),
        const SizedBox(height: TwSpacing.x2),
        TextField(
          key: const Key('cleaning-instructions-field'),
          controller: instructionsController,
          onChanged: controller.setInstructions,
          minLines: 3,
          maxLines: 5,
          maxLength: CleaningController.maxInstructionsLength,
          decoration: InputDecoration(
            hintText: 'Household routine, access notes, pets, or priorities',
            helperText: 'Optional',
            errorText: errors['instructions'],
            border: const OutlineInputBorder(),
          ),
        ),
      ],
    );
  }
}

class _SelectedCleaner extends StatelessWidget {
  const _SelectedCleaner({required this.cleaner});

  final CleaningProfessional cleaner;

  @override
  Widget build(BuildContext context) {
    final palette = context.serviceColors;
    return OutlinedCard(
      backgroundColor: palette.card,
      borderColor: palette.border,
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: palette.soft,
            foregroundColor: palette.accent,
            child: Text(cleaner.initials, style: TwText.fontBoldSm()),
          ),
          const SizedBox(width: TwSpacing.x3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(cleaner.displayName, style: TwText.fontBoldBase()),
                const SizedBox(height: TwSpacing.x1),
                Text(
                  '${cleaner.city} • ${cleaner.experienceYears} years • '
                  '${cleaner.languages.join(', ')}',
                  style: TwText.textXs(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PriceSummary extends StatelessWidget {
  const _PriceSummary({required this.controller});

  final CleaningController controller;

  @override
  Widget build(BuildContext context) {
    final plan = controller.selectedPlan;
    return OutlinedCard(
      child: Column(
        children: [
          _SummaryRow(
            label: 'Weekly rate',
            value: plan == null
                ? '—'
                : '${AppMoney.format(plan.weeklyRate)}/week',
          ),
          const SizedBox(height: TwSpacing.x2),
          _SummaryRow(
            label: 'Arrangement',
            value: plan == null
                ? '—'
                : '${plan.durationWeeks} '
                      '${plan.durationWeeks == 1 ? 'week' : 'weeks'}',
          ),
          const Divider(height: TwSpacing.x6),
          _SummaryRow(
            label: 'Estimated total',
            value: AppMoney.format(controller.estimatedTotal),
            emphasize: true,
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.value,
    this.emphasize = false,
  });

  final String label;
  final String value;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    final style = emphasize ? TwText.fontBoldBase() : TwText.textSm();
    return Row(
      children: [
        Expanded(child: Text(label, style: style)),
        Text(value, style: style),
      ],
    );
  }
}

class _ConfirmationView extends StatelessWidget {
  const _ConfirmationView({required this.booking, required this.onBookAnother});

  final CleaningBooking booking;
  final VoidCallback onBookAnother;

  @override
  Widget build(BuildContext context) {
    final request = booking.request;
    final palette = context.serviceColors;
    return ListView(
      padding: const EdgeInsets.all(TwSpacing.x5),
      children: [
        Icon(Icons.check_circle, color: palette.accent, size: 72),
        const SizedBox(height: TwSpacing.x4),
        Text(
          'Arrangement requested',
          textAlign: TextAlign.center,
          style: TwText.text2xl(),
        ),
        const SizedBox(height: TwSpacing.x2),
        Text(
          'Demo confirmation only. No cleaner was contacted and no payment '
          'was taken.',
          textAlign: TextAlign.center,
          style: TwText.textSm(),
        ),
        const SizedBox(height: TwSpacing.x6),
        OutlinedCard(
          backgroundColor: palette.card,
          borderColor: palette.border,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(request.specialty.name, style: TwText.textXl()),
              const SizedBox(height: TwSpacing.x4),
              _ConfirmationLine(
                icon: Icons.person_outline,
                text:
                    '${booking.cleaner.displayName} • '
                    '${booking.cleaner.rating.toStringAsFixed(1)}★',
              ),
              _ConfirmationLine(
                icon: Icons.schedule_outlined,
                text:
                    '${DateFormat('EEE, MMM d • h:mm a').format(request.startsAt)} '
                    'for ${request.plan.durationWeeks} '
                    '${request.plan.durationWeeks == 1 ? 'week' : 'weeks'}',
              ),
              _ConfirmationLine(
                icon: Icons.location_on_outlined,
                text: request.address.formatted,
              ),
              _ConfirmationLine(
                icon: Icons.payments_outlined,
                text: '${AppMoney.format(booking.total)} estimated total',
              ),
            ],
          ),
        ),
        const SizedBox(height: TwSpacing.x6),
        OutlinedButton(
          onPressed: onBookAnother,
          child: const Text('Choose another cleaner'),
        ),
      ],
    );
  }
}

class _ConfirmationLine extends StatelessWidget {
  const _ConfirmationLine({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: TwSpacing.x3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: context.serviceColors.accent),
          const SizedBox(width: TwSpacing.x3),
          Expanded(child: Text(text, style: TwText.textSm())),
        ],
      ),
    );
  }
}
