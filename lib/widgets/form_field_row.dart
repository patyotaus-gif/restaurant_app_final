import 'package:flutter/material.dart';

/// A responsive row for arranging form fields without causing overflow.
class FormFieldRow extends StatelessWidget {
  const FormFieldRow({
    super.key,
    required this.children,
    this.trailing,
    this.spacing = 16,
    this.verticalSpacing,
    this.breakpoint = 520,
    this.crossAxisAlignment = CrossAxisAlignment.start,
  }) : assert(children.length > 0, 'FormFieldRow requires at least one child.');

  /// The form field children to layout.
  final List<FormFieldRowChild> children;

  /// An optional trailing widget (e.g. an action button).
  final Widget? trailing;

  /// Horizontal spacing between children when laid out in a row.
  final double spacing;

  /// Vertical spacing between children when stacked.
  final double? verticalSpacing;

  /// The minimum width required to layout the children horizontally.
  final double breakpoint;

  /// The cross axis alignment when laid out horizontally.
  final CrossAxisAlignment crossAxisAlignment;

  @override
  Widget build(BuildContext context) {
    final verticalGap = verticalSpacing ?? spacing;
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth;
        final isHorizontal = !maxWidth.isFinite || maxWidth >= breakpoint;

        if (isHorizontal) {
          final rowChildren = <Widget>[];
          for (var i = 0; i < children.length; i++) {
            if (i > 0) {
              rowChildren.add(SizedBox(width: spacing));
            }
            final child = children[i];
            rowChildren.add(
              Expanded(
                flex: child.flex,
                child: child.child,
              ),
            );
          }
          if (trailing != null) {
            if (rowChildren.isNotEmpty) {
              rowChildren.add(SizedBox(width: spacing));
            }
            rowChildren.add(trailing!);
          }
          return Row(
            crossAxisAlignment: crossAxisAlignment,
            children: rowChildren,
          );
        }

        final columnChildren = <Widget>[];
        for (var i = 0; i < children.length; i++) {
          if (i > 0) {
            columnChildren.add(SizedBox(height: verticalGap));
          }
          columnChildren.add(children[i].child);
        }
        if (trailing != null) {
          if (columnChildren.isNotEmpty) {
            columnChildren.add(SizedBox(height: verticalGap));
          }
          columnChildren.add(
            Align(
              alignment: Alignment.centerRight,
              child: trailing,
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: columnChildren,
        );
      },
    );
  }
}

/// Describes an individual child within a [FormFieldRow].
class FormFieldRowChild {
  const FormFieldRowChild({
    required this.child,
    this.flex = 1,
  }) : assert(flex > 0, 'flex must be greater than zero.');

  /// The widget to render for this child.
  final Widget child;

  /// The flex factor when laid out horizontally.
  final int flex;
}
