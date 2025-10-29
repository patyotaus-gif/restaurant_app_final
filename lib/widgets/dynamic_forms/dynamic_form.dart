import 'package:flutter/material.dart';

import 'form_schema.dart';

/// A schema-driven form renderer that powers the backoffice UI.
class DynamicForm extends StatefulWidget {
  const DynamicForm({
    super.key,
    required this.schema,
    this.initialValues,
    this.onChanged,
    this.onSubmit,
    this.autovalidateMode = AutovalidateMode.disabled,
  });

  final FormSchema schema;
  final Map<String, dynamic>? initialValues;
  final ValueChanged<Map<String, dynamic>>? onChanged;
  final ValueChanged<Map<String, dynamic>>? onSubmit;
  final AutovalidateMode autovalidateMode;

  @override
  State<DynamicForm> createState() => _DynamicFormState();
}

class _DynamicFormState extends State<DynamicForm>
    with AutomaticKeepAliveClientMixin {
  final _formKey = GlobalKey<FormState>();
  late Map<String, dynamic> _values;
  final Map<String, TextEditingController> _textControllers = {};

  @override
  void initState() {
    super.initState();
    _values = Map<String, dynamic>.from(widget.initialValues ?? {});
    for (final field in widget.schema.fields) {
      if (field is TextFieldSchema) {
        _textControllers[field.id] = TextEditingController(
          text: (_values[field.id] ?? field.defaultValue ?? '').toString(),
        );
      } else if (field is NumberFieldSchema) {
        _textControllers[field.id] = TextEditingController(
          text: (_values[field.id] ?? field.defaultValue ?? '').toString(),
        );
      }
    }
  }

  @override
  void didUpdateWidget(covariant DynamicForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.schema.id != widget.schema.id) {
      _values = Map<String, dynamic>.from(widget.initialValues ?? {});
      _resetControllers();
    }
  }

  void _resetControllers() {
    for (final controller in _textControllers.values) {
      controller.dispose();
    }
    _textControllers
      ..clear()
      ..addEntries(
        widget.schema.fields.whereType<TextFieldSchema>().map(
          (field) => MapEntry(
            field.id,
            TextEditingController(
              text: (_values[field.id] ?? field.defaultValue ?? '').toString(),
            ),
          ),
        ),
      )
      ..addEntries(
        widget.schema.fields.whereType<NumberFieldSchema>().map(
          (field) => MapEntry(
            field.id,
            TextEditingController(
              text: (_values[field.id] ?? field.defaultValue ?? '').toString(),
            ),
          ),
        ),
      );
    setState(() {});
  }

  @override
  void dispose() {
    for (final controller in _textControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _handleChanged(String fieldId, Object? value) {
    setState(() {
      _values[fieldId] = value;
    });
    widget.onChanged?.call(Map<String, dynamic>.from(_values));
  }

  String? _validateRequired(DynamicFormFieldSchema field, Object? value) {
    if (!field.required) {
      return null;
    }
    if (value == null) {
      return 'Required';
    }
    if (value is String && value.trim().isEmpty) {
      return 'Required';
    }
    return null;
  }

  String? _validateNumber(NumberFieldSchema field, String value) {
    final requiredError = _validateRequired(field, value);
    if (requiredError != null) {
      return requiredError;
    }
    if (value.isEmpty) {
      return null;
    }
    final parsed = double.tryParse(value);
    if (parsed == null) {
      return 'Enter a valid number';
    }
    if (field.min != null && parsed < field.min!) {
      return 'Min ${field.min}';
    }
    if (field.max != null && parsed > field.max!) {
      return 'Max ${field.max}';
    }
    return null;
  }

  Future<void> _submit() async {
    final formState = _formKey.currentState;
    if (formState == null) {
      return;
    }
    if (formState.validate()) {
      formState.save();
      widget.onSubmit?.call(Map<String, dynamic>.from(_values));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${widget.schema.title} saved successfully')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Form(
      key: _formKey,
      autovalidateMode: widget.autovalidateMode,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ...widget.schema.fields.map(_buildField),
          const SizedBox(height: 24),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton.icon(
              onPressed: _submit,
              icon: const Icon(Icons.check_circle_outline),
              label: Text(widget.schema.submitLabel),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildField(DynamicFormFieldSchema field) {
    switch (field) {
      case TextFieldSchema textField:
        return _buildTextField(textField);
      case NumberFieldSchema numberField:
        return _buildNumberField(numberField);
      case DropdownFieldSchema dropdownField:
        return _buildDropdownField(dropdownField);
      case ToggleFieldSchema toggleField:
        return _buildToggleField(toggleField);
      case DateFieldSchema dateField:
        return _buildDateField(dateField);
    }
    throw UnsupportedError(
      'Unsupported dynamic form field type: ${field.runtimeType}',
    );
  }

  Widget _buildTextField(TextFieldSchema field) {
    final controller = _textControllers[field.id]!;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: TextFormField(
        controller: controller,
        maxLines: field.isMultiline ? null : 1,
        maxLength: field.maxLength,
        decoration: InputDecoration(
          labelText: field.label,
          hintText: field.placeholder ?? field.hint,
        ),
        validator: (value) => _validateRequired(field, value),
        onChanged: (value) => _handleChanged(field.id, value),
        onSaved: (value) => _handleChanged(field.id, value ?? ''),
      ),
    );
  }

  Widget _buildNumberField(NumberFieldSchema field) {
    final controller = _textControllers[field.id]!;
    final numberFormat = field.decimals > 0
        ? const TextInputType.numberWithOptions(decimal: true)
        : const TextInputType.numberWithOptions();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: TextFormField(
        controller: controller,
        keyboardType: numberFormat,
        decoration: InputDecoration(
          labelText: field.label,
          hintText: field.hint,
          prefixText: field.isCurrency ? '\$' : null,
        ),
        validator: (value) => _validateNumber(field, value ?? ''),
        onChanged: (value) => _handleChanged(field.id, value),
        onSaved: (value) {
          final parsed = double.tryParse(value ?? '');
          if (parsed != null) {
            _handleChanged(field.id, parsed);
          } else {
            _handleChanged(field.id, value ?? '');
          }
        },
      ),
    );
  }

  Widget _buildDropdownField(DropdownFieldSchema field) {
    final current = (_values[field.id] ?? field.defaultValue)?.toString();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: DropdownButtonFormField<String>(
        initialValue: field.options.any((option) => option.value == current)
            ? current
            : null,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: field.label,
          hintText: field.hint,
        ),
        validator: (value) => _validateRequired(field, value),
        onChanged: (value) => _handleChanged(field.id, value),
        items: [
          for (final option in field.options)
            DropdownMenuItem<String>(
              value: option.value,
              child: Text(option.label),
            ),
        ],
      ),
    );
  }

  Widget _buildToggleField(ToggleFieldSchema field) {
    final current = (_values[field.id] ?? field.defaultValue ?? false) as bool;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: FormField<bool>(
        initialValue: current,
        validator: (value) => _validateRequired(field, value),
        builder: (state) {
          final value = state.value ?? false;
          final error = state.hasError ? state.errorText : null;
          final errorColor = Theme.of(context).colorScheme.error;
          final theme = Theme.of(context);
          final subtitle = <Widget>[];
          if (field.hint != null) {
            subtitle.add(Text(field.hint!));
          }
          if (field.trueLabel != null || field.falseLabel != null) {
            subtitle.add(
              Text(
                value
                    ? (field.trueLabel ?? 'Enabled')
                    : (field.falseLabel ?? 'Disabled'),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SwitchListTile(
                value: value,
                title: Text(field.label),
                subtitle: subtitle.isNotEmpty
                    ? Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (final child in subtitle)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: child,
                            ),
                        ],
                      )
                    : null,
                onChanged: (changed) {
                  state.didChange(changed);
                  _handleChanged(field.id, changed);
                },
                secondary: Icon(value ? Icons.toggle_on : Icons.toggle_off),
              ),
              if (error != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    error,
                    style: TextStyle(color: errorColor, fontSize: 12),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildDateField(DateFieldSchema field) {
    final selected = _values[field.id] as DateTime?;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: FormField<DateTime>(
        initialValue: selected,
        validator: (value) => _validateRequired(field, value),
        builder: (state) {
          final value = state.value;
          final error = state.hasError ? state.errorText : null;
          final theme = Theme.of(context);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(field.label),
                subtitle: Text(
                  value != null
                      ? MaterialLocalizations.of(
                          context,
                        ).formatMediumDate(value)
                      : (field.hint ?? 'Tap to choose a date'),
                ),
                trailing: const Icon(Icons.calendar_today),
                onTap: () async {
                  final now = DateTime.now();
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: value ?? now,
                    firstDate: field.firstDate != null
                        ? DateTime.parse(field.firstDate!)
                        : DateTime(now.year - 5),
                    lastDate: field.lastDate != null
                        ? DateTime.parse(field.lastDate!)
                        : DateTime(now.year + 5),
                  );
                  if (picked != null) {
                    state.didChange(picked);
                    _handleChanged(field.id, picked);
                  }
                },
              ),
              if (error != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    error,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  @override
  bool get wantKeepAlive => true;
}
