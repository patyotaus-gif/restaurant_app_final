import 'package:flutter/foundation.dart';

/// Describes a fully schema-driven form that can be rendered dynamically
/// in the backoffice experience.
@immutable
class FormSchema {
  const FormSchema({
    required this.id,
    required this.title,
    required this.description,
    required this.fields,
    required this.submitLabel,
  });

  factory FormSchema.fromJson(Map<String, dynamic> json) {
    final rawFields = json['fields'] as List<dynamic>? ?? const [];
    return FormSchema(
      id: json['id'] as String,
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      submitLabel: json['submitLabel'] as String? ?? 'Submit',
      fields: rawFields
          .map((raw) => DynamicFormFieldSchema.fromJson(
                Map<String, dynamic>.from(raw as Map),
              ))
          .toList(growable: false),
    );
  }

  final String id;
  final String title;
  final String description;
  final List<DynamicFormFieldSchema> fields;
  final String submitLabel;
}

/// Supported field types for the schema driven form.
enum DynamicFieldType {
  text,
  multilineText,
  number,
  currency,
  dropdown,
  toggle,
  date,
}

DynamicFieldType dynamicFieldTypeFromString(String raw) {
  switch (raw) {
    case 'text':
      return DynamicFieldType.text;
    case 'multilineText':
      return DynamicFieldType.multilineText;
    case 'number':
      return DynamicFieldType.number;
    case 'currency':
      return DynamicFieldType.currency;
    case 'dropdown':
      return DynamicFieldType.dropdown;
    case 'toggle':
      return DynamicFieldType.toggle;
    case 'date':
      return DynamicFieldType.date;
    default:
      throw ArgumentError('Unsupported field type: $raw');
  }
}

/// Base schema for all dynamic fields. Concrete field schema implementations
/// extend this class and expose type-specific configuration.
@immutable
abstract class DynamicFormFieldSchema {
  const DynamicFormFieldSchema({
    required this.id,
    required this.type,
    required this.label,
    this.hint,
    this.required = false,
    this.defaultValue,
  });

  factory DynamicFormFieldSchema.fromJson(Map<String, dynamic> json) {
    final type = dynamicFieldTypeFromString(json['type'] as String);
    switch (type) {
      case DynamicFieldType.text:
      case DynamicFieldType.multilineText:
        return TextFieldSchema.fromJson(json, type);
      case DynamicFieldType.number:
      case DynamicFieldType.currency:
        return NumberFieldSchema.fromJson(json, type);
      case DynamicFieldType.dropdown:
        return DropdownFieldSchema.fromJson(json);
      case DynamicFieldType.toggle:
        return ToggleFieldSchema.fromJson(json);
      case DynamicFieldType.date:
        return DateFieldSchema.fromJson(json);
    }
  }

  final String id;
  final DynamicFieldType type;
  final String label;
  final String? hint;
  final bool required;
  final Object? defaultValue;
}

class TextFieldSchema extends DynamicFormFieldSchema {
  const TextFieldSchema({
    required super.id,
    required DynamicFieldType fieldType,
    required super.label,
    super.hint,
    super.required,
    super.defaultValue,
    this.placeholder,
    this.maxLength,
  })  : assert(fieldType == DynamicFieldType.text ||
            fieldType == DynamicFieldType.multilineText),
        super(type: fieldType);

  factory TextFieldSchema.fromJson(
    Map<String, dynamic> json,
    DynamicFieldType fieldType,
  ) {
    return TextFieldSchema(
      id: json['id'] as String,
      fieldType: fieldType,
      label: json['label'] as String? ?? '',
      hint: json['hint'] as String?,
      required: json['required'] as bool? ?? false,
      defaultValue: json['defaultValue'],
      placeholder: json['placeholder'] as String?,
      maxLength: json['maxLength'] as int?,
    );
  }

  final String? placeholder;
  final int? maxLength;

  bool get isMultiline => type == DynamicFieldType.multilineText;
}

class NumberFieldSchema extends DynamicFormFieldSchema {
  const NumberFieldSchema({
    required super.id,
    required DynamicFieldType fieldType,
    required super.label,
    super.hint,
    super.required,
    super.defaultValue,
    this.min,
    this.max,
    this.decimals = 0,
  })  : assert(fieldType == DynamicFieldType.number ||
            fieldType == DynamicFieldType.currency),
        super(type: fieldType);

  factory NumberFieldSchema.fromJson(
    Map<String, dynamic> json,
    DynamicFieldType fieldType,
  ) {
    return NumberFieldSchema(
      id: json['id'] as String,
      fieldType: fieldType,
      label: json['label'] as String? ?? '',
      hint: json['hint'] as String?,
      required: json['required'] as bool? ?? false,
      defaultValue: (json['defaultValue'] as num?)?.toDouble(),
      min: (json['min'] as num?)?.toDouble(),
      max: (json['max'] as num?)?.toDouble(),
      decimals: json['decimals'] as int? ?? 0,
    );
  }

  final double? min;
  final double? max;
  final int decimals;

  bool get isCurrency => type == DynamicFieldType.currency;
}

class DropdownOption {
  const DropdownOption({required this.value, required this.label});

  factory DropdownOption.fromJson(Map<String, dynamic> json) {
    return DropdownOption(
      value: json['value']?.toString() ?? '',
      label: json['label']?.toString() ?? '',
    );
  }

  final String value;
  final String label;
}

class DropdownFieldSchema extends DynamicFormFieldSchema {
  const DropdownFieldSchema({
    required super.id,
    required super.label,
    required this.options,
    super.hint,
    super.required,
    super.defaultValue,
    this.enableSearch = false,
  }) : super(type: DynamicFieldType.dropdown);

  factory DropdownFieldSchema.fromJson(Map<String, dynamic> json) {
    final rawOptions = json['options'] as List<dynamic>? ?? const [];
    return DropdownFieldSchema(
      id: json['id'] as String,
      label: json['label'] as String? ?? '',
      hint: json['hint'] as String?,
      required: json['required'] as bool? ?? false,
      defaultValue: json['defaultValue']?.toString(),
      enableSearch: json['enableSearch'] as bool? ?? false,
      options: rawOptions
          .map((raw) => DropdownOption.fromJson(
                Map<String, dynamic>.from(raw as Map),
              ))
          .toList(growable: false),
    );
  }

  final List<DropdownOption> options;
  final bool enableSearch;
}

class ToggleFieldSchema extends DynamicFormFieldSchema {
  const ToggleFieldSchema({
    required super.id,
    required super.label,
    super.hint,
    super.required,
    super.defaultValue,
    this.trueLabel,
    this.falseLabel,
  }) : super(type: DynamicFieldType.toggle);

  factory ToggleFieldSchema.fromJson(Map<String, dynamic> json) {
    return ToggleFieldSchema(
      id: json['id'] as String,
      label: json['label'] as String? ?? '',
      hint: json['hint'] as String?,
      required: json['required'] as bool? ?? false,
      defaultValue: json['defaultValue'] as bool? ?? false,
      trueLabel: json['trueLabel'] as String?,
      falseLabel: json['falseLabel'] as String?,
    );
  }

  final String? trueLabel;
  final String? falseLabel;
}

class DateFieldSchema extends DynamicFormFieldSchema {
  const DateFieldSchema({
    required super.id,
    required super.label,
    super.hint,
    super.required,
    super.defaultValue,
    this.firstDate,
    this.lastDate,
  }) : super(type: DynamicFieldType.date);

  factory DateFieldSchema.fromJson(Map<String, dynamic> json) {
    return DateFieldSchema(
      id: json['id'] as String,
      label: json['label'] as String? ?? '',
      hint: json['hint'] as String?,
      required: json['required'] as bool? ?? false,
      defaultValue: json['defaultValue'] is String
          ? DateTime.tryParse(json['defaultValue'] as String)
          : json['defaultValue'],
      firstDate: json['firstDate'] as String?,
      lastDate: json['lastDate'] as String?,
    );
  }

  final String? firstDate;
  final String? lastDate;
}
