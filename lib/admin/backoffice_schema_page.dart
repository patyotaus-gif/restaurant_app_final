import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';

import '../widgets/dynamic_forms/dynamic_form.dart';
import '../widgets/dynamic_forms/form_schema.dart';
import 'backoffice_schema_registry.dart';

class BackofficeSchemaPage extends StatefulWidget {
  const BackofficeSchemaPage({super.key});

  @override
  State<BackofficeSchemaPage> createState() => _BackofficeSchemaPageState();
}

class _BackofficeSchemaPageState extends State<BackofficeSchemaPage> {
  late final BackofficeSchemaRegistry _registry;
  late final List<FormSchema> _schemas;
  late FormSchema _activeSchema;

  Map<String, dynamic> _liveValues = const {};
  Map<String, dynamic>? _lastSubmission;
  DateTime? _lastSubmissionTimestamp;

  @override
  void initState() {
    super.initState();
    _registry = BackofficeSchemaRegistry.instance;
    _schemas = List<FormSchema>.from(_registry.allSchemas)
      ..sort((a, b) => a.title.compareTo(b.title));
    if (_schemas.isEmpty) {
      throw StateError('At least one backoffice schema must be registered.');
    }
    _activeSchema = _schemas.first;
    _liveValues = _buildDefaultValues(_activeSchema);
  }

  Map<String, dynamic> _buildDefaultValues(FormSchema schema) {
    final values = <String, dynamic>{};
    for (final field in schema.fields) {
      if (field.defaultValue != null) {
        values[field.id] = field.defaultValue!;
      }
    }
    return values;
  }

  void _handleSchemaChanged(String? newValue) {
    if (newValue == null) {
      return;
    }
    final nextSchema =
        _schemas.firstWhereOrNull((schema) => schema.id == newValue);
    if (nextSchema == null) {
      return;
    }
    setState(() {
      _activeSchema = nextSchema;
      _liveValues = _buildDefaultValues(nextSchema);
      _lastSubmission = null;
    });
  }

  void _handleChanged(Map<String, dynamic> values) {
    setState(() {
      _liveValues = Map<String, dynamic>.from(values);
    });
  }

  void _handleSubmit(Map<String, dynamic> values) {
    setState(() {
      _lastSubmission = Map<String, dynamic>.from(values);
      _lastSubmissionTimestamp = DateTime.now();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Schema-driven Backoffice'),
        actions: [
          if (_lastSubmission != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Chip(
                avatar: const Icon(Icons.check_circle, color: Colors.white),
                label: Text(
                  'Saved ${MaterialLocalizations.of(context).formatTimeOfDay(
                    TimeOfDay.fromDateTime(
                      _lastSubmissionTimestamp ?? DateTime.now(),
                    ),
                  )}',
                  style: const TextStyle(color: Colors.white),
                ),
                backgroundColor: theme.colorScheme.primary,
              ),
            ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 900;
          final form = _buildFormPane(theme);
          final preview = _buildPreviewPane(theme);
          if (isWide) {
            return Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 3, child: form),
                  const SizedBox(width: 24),
                  Expanded(flex: 2, child: preview),
                ],
              ),
            );
          }
          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              form,
              const SizedBox(height: 24),
              preview,
            ],
          );
        },
      ),
    );
  }

  Widget _buildFormPane(ThemeData theme) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _activeSchema.title,
                        style: theme.textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _activeSchema.description,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_schemas.length > 1)
                  SizedBox(
                    width: 220,
                    child: DropdownButtonFormField<String>(
                      value: _activeSchema.id,
                      decoration: const InputDecoration(
                        labelText: 'Blueprint',
                      ),
                      onChanged: _handleSchemaChanged,
                      items: [
                        for (final schema in _schemas)
                          DropdownMenuItem<String>(
                            value: schema.id,
                            child: Text(schema.title),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
            const Divider(height: 32),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: DynamicForm(
                key: ValueKey(_activeSchema.id),
                schema: _activeSchema,
                initialValues: _liveValues,
                onChanged: _handleChanged,
                onSubmit: _handleSubmit,
                autovalidateMode: AutovalidateMode.onUserInteraction,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreviewPane(ThemeData theme) {
    final encoder = const JsonEncoder.withIndent('  ');
    final effectiveValues = _lastSubmission ?? _liveValues;
    final preview = encoder.convert(
      effectiveValues.map((key, value) => MapEntry(key, _serialiseValue(value))),
    );
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.auto_awesome, color: theme.colorScheme.secondary),
                const SizedBox(width: 8),
                Text(
                  'Real-time schema output',
                  style: theme.textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Use this feed to power automations or syncs with your ERP.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceVariant.withOpacity(0.4),
                borderRadius: BorderRadius.circular(12),
              ),
              child: SingleChildScrollView(
                child: SelectableText(
                  preview,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontFamily: 'monospace',
                    height: 1.4,
                  ),
                ),
              ),
            ),
            if (_lastSubmission != null) ...[
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () => setState(() => _lastSubmission = null),
                icon: const Icon(Icons.history),
                label: const Text('Show live form values'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Object? _serialiseValue(Object? value) {
    if (value is DateTime) {
      return value.toIso8601String();
    }
    return value;
  }
}
