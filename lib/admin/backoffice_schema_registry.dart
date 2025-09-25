import 'package:collection/collection.dart';

import '../widgets/dynamic_forms/form_schema.dart';

/// Registry of schema-driven forms used in the backoffice experience.
class BackofficeSchemaRegistry {
  BackofficeSchemaRegistry._();

  static final BackofficeSchemaRegistry instance =
      BackofficeSchemaRegistry._();

  final Map<String, FormSchema> _schemas = {
    for (final json in _defaultSchemas) json['id'] as String: FormSchema.fromJson(json),
  };

  List<FormSchema> get allSchemas => _schemas.values.toList(growable: false);

  FormSchema? schemaById(String id) => _schemas[id];

  void register(FormSchema schema) {
    _schemas[schema.id] = schema;
  }

  void registerFromJson(Map<String, dynamic> json) {
    final schema = FormSchema.fromJson(json);
    register(schema);
  }

  bool contains(String id) => _schemas.containsKey(id);

  /// Returns a schema matching one of the provided categories, falling back to
  /// the first available schema.
  FormSchema? findByCategory(Iterable<String> preferredIds) {
    return preferredIds.map(schemaById).firstWhereOrNull((schema) => schema != null);
  }
}

const List<Map<String, dynamic>> _defaultSchemas = [
  {
    'id': 'menu_item',
    'title': 'Menu Item Blueprint',
    'description':
        'Configure how dishes are published across POS, QR, and delivery channels.',
    'submitLabel': 'Save menu item',
    'fields': [
      {
        'id': 'name',
        'type': 'text',
        'label': 'Menu item name',
        'required': true,
        'placeholder': 'E.g. Pad Thai with Shrimp',
        'maxLength': 60,
      },
      {
        'id': 'category',
        'type': 'dropdown',
        'label': 'Category',
        'required': true,
        'hint': 'Controls which production line sees the order',
        'options': [
          {'label': 'Starters', 'value': 'starters'},
          {'label': 'Mains', 'value': 'mains'},
          {'label': 'Desserts', 'value': 'desserts'},
          {'label': 'Beverages', 'value': 'beverages'},
        ],
      },
      {
        'id': 'basePrice',
        'type': 'currency',
        'label': 'Base price',
        'required': true,
        'hint': 'Displayed on the POS, QR menu, and delivery platforms',
        'min': 0,
        'decimals': 2,
      },
      {
        'id': 'costOfGoods',
        'type': 'currency',
        'label': 'Cost of goods',
        'hint': 'Used for theoretical margin calculations',
        'min': 0,
        'decimals': 2,
      },
      {
        'id': 'isPublished',
        'type': 'toggle',
        'label': 'Publish to channels',
        'hint': 'Hide from ordering channels while experimenting',
        'defaultValue': true,
      },
      {
        'id': 'allergens',
        'type': 'multilineText',
        'label': 'Allergen & dietary notes',
        'hint': 'Shown on QR menus and receipts',
        'maxLength': 120,
      },
      {
        'id': 'launchDate',
        'type': 'date',
        'label': 'Launch date',
        'hint': 'Schedule when this dish becomes available',
        'firstDate': '2023-01-01',
        'lastDate': '2030-12-31',
      },
    ],
  },
  {
    'id': 'modifier_group',
    'title': 'Modifier Group',
    'description': 'Model product options and upsells in a reusable way.',
    'submitLabel': 'Save modifier group',
    'fields': [
      {
        'id': 'title',
        'type': 'text',
        'label': 'Group title',
        'required': true,
        'placeholder': 'E.g. Choose your protein',
        'maxLength': 50,
      },
      {
        'id': 'selection',
        'type': 'dropdown',
        'label': 'Selection rules',
        'required': true,
        'options': [
          {'label': 'Choose exactly one', 'value': 'exactly_one'},
          {'label': 'Choose up to two', 'value': 'up_to_two'},
          {'label': 'Unlimited choices', 'value': 'unlimited'},
        ],
      },
      {
        'id': 'maxOptions',
        'type': 'number',
        'label': 'Maximum options',
        'hint': 'Leave empty for unlimited',
        'min': 0,
      },
      {
        'id': 'isUpsell',
        'type': 'toggle',
        'label': 'Mark as premium upsell',
        'hint': 'Flag to highlight in online ordering',
        'defaultValue': false,
      },
      {
        'id': 'notes',
        'type': 'multilineText',
        'label': 'Backoffice notes',
        'hint': 'Internal context for the kitchen or marketing teams',
        'maxLength': 200,
      },
    ],
  },
  {
    'id': 'supplier_profile',
    'title': 'Supplier Profile',
    'description': 'Keep vendor onboarding consistent across the organisation.',
    'submitLabel': 'Save supplier',
    'fields': [
      {
        'id': 'supplierName',
        'type': 'text',
        'label': 'Supplier name',
        'required': true,
      },
      {
        'id': 'contactEmail',
        'type': 'text',
        'label': 'Contact email',
        'hint': 'Used for purchase order notifications',
      },
      {
        'id': 'preferredDeliveryDay',
        'type': 'dropdown',
        'label': 'Preferred delivery day',
        'options': [
          {'label': 'Monday', 'value': 'monday'},
          {'label': 'Wednesday', 'value': 'wednesday'},
          {'label': 'Friday', 'value': 'friday'},
        ],
      },
      {
        'id': 'leadTime',
        'type': 'number',
        'label': 'Lead time (days)',
        'hint': 'Impacts replenishment recommendations',
        'min': 0,
        'max': 30,
      },
      {
        'id': 'isPreferred',
        'type': 'toggle',
        'label': 'Preferred vendor',
        'hint': 'Highlight in purchasing workflows',
        'defaultValue': true,
      },
    ],
  },
];
