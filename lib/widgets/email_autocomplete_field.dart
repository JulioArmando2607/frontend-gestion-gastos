import 'package:flutter/material.dart';

const List<String> kEmailDomains = <String>[
  'gmail.com',
  'hotmail.com',
  'outlook.com',
  'yahoo.com',
];

String normalizeEmailInput(String raw, {String fallbackDomain = 'gmail.com'}) {
  final email = raw.trim().toLowerCase();
  if (email.isEmpty) return email;
  if (email.contains('@')) return email;
  return '$email@$fallbackDomain';
}

class EmailAutocompleteField extends StatefulWidget {
  const EmailAutocompleteField({
    super.key,
    required this.controller,
    required this.decoration,
    this.validator,
    this.textInputAction,
    this.onChanged,
  });

  final TextEditingController controller;
  final InputDecoration decoration;
  final FormFieldValidator<String>? validator;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onChanged;

  @override
  State<EmailAutocompleteField> createState() => _EmailAutocompleteFieldState();
}

class _EmailAutocompleteFieldState extends State<EmailAutocompleteField> {
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  Iterable<String> _optionsBuilder(String query) {
    final text = query.trim().toLowerCase();
    if (text.isEmpty) return const Iterable<String>.empty();

    final parts = text.split('@');
    final user = parts.first.trim();
    if (user.isEmpty) return const Iterable<String>.empty();

    if (parts.length > 1) {
      final domainFragment = parts.sublist(1).join('@');
      return kEmailDomains
          .where((d) => d.startsWith(domainFragment))
          .map((d) => '$user@$d');
    }

    return kEmailDomains.map((d) => '$user@$d');
  }

  @override
  Widget build(BuildContext context) {
    return RawAutocomplete<String>(
      textEditingController: widget.controller,
      focusNode: _focusNode,
      optionsBuilder: (textEditingValue) {
        return _optionsBuilder(textEditingValue.text);
      },
      onSelected: (selection) {
        widget.controller.value = TextEditingValue(
          text: selection,
          selection: TextSelection.collapsed(offset: selection.length),
        );
        widget.onChanged?.call(selection);
      },
      fieldViewBuilder: (context, textController, focusNode, onFieldSubmitted) {
        return TextFormField(
          controller: textController,
          focusNode: focusNode,
          keyboardType: TextInputType.emailAddress,
          autofillHints: const [AutofillHints.email],
          textInputAction: widget.textInputAction ?? TextInputAction.next,
          decoration: widget.decoration,
          validator: widget.validator,
          onChanged: widget.onChanged,
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        final opts = options.toList(growable: false);
        if (opts.isEmpty) return const SizedBox.shrink();

        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 6,
            borderRadius: BorderRadius.circular(12),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520, maxHeight: 220),
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 6),
                shrinkWrap: true,
                itemCount: opts.length,
                itemBuilder: (context, i) {
                  final option = opts[i];
                  return InkWell(
                    onTap: () => onSelected(option),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      child: Text(option),
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}
