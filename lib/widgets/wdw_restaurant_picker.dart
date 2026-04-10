import 'package:flutter/material.dart';

import 'package:mouseplate/data/wdw_restaurant_catalog.dart';
import 'package:mouseplate/models/usage_entry.dart';
import 'package:mouseplate/theme.dart';

/// Shared **Popular picks** + **search** UI for WDW restaurant names (QS/TS catalog).
/// Snack logs do not use the catalog — pass [UsageType.snack] to get [SizedBox.shrink].
class WdwRestaurantPicker extends StatefulWidget {
  final UsageType type;
  final TextEditingController controller;
  final VoidCallback onChanged;

  /// Called when the user picks from the dropdown or search (not on every keystroke).
  final ValueChanged<WdwRestaurantOption>? onCatalogSelected;

  final bool showFooterHint;

  const WdwRestaurantPicker({
    super.key,
    required this.type,
    required this.controller,
    required this.onChanged,
    this.onCatalogSelected,
    this.showFooterHint = true,
  });

  @override
  State<WdwRestaurantPicker> createState() => _WdwRestaurantPickerState();
}

class _WdwRestaurantPickerState extends State<WdwRestaurantPicker> {
  late final FocusNode _restaurantFocusNode;

  @override
  void initState() {
    super.initState();
    _restaurantFocusNode = FocusNode();
  }

  @override
  void dispose() {
    _restaurantFocusNode.dispose();
    super.dispose();
  }

  void _applyPick(WdwRestaurantOption o) {
    widget.controller.text = o.name;
    widget.onCatalogSelected?.call(o);
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.type == UsageType.snack) {
      return const SizedBox.shrink();
    }

    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final t = widget.type;
    final quick = WdwRestaurantCatalog.quickPicksForType(t);
    final qpVal = WdwRestaurantCatalog.quickPickDropdownValueForText(widget.controller.text, t);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<String>(
          key: ValueKey<String>('wdw_qp_${t.name}_$qpVal'),
          isExpanded: true,
          initialValue: qpVal.isEmpty ? '' : qpVal,
          decoration: const InputDecoration(
            labelText: 'Popular picks',
            prefixIcon: Icon(Icons.star_rounded),
          ),
          items: [
            DropdownMenuItem<String>(
              value: '',
              child: Text('— None —', style: text.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
            ),
            ...quick.map(
              (e) => DropdownMenuItem<String>(
                value: e.name,
                child: Text('${e.name} (~\$${e.avgPerAdult.toStringAsFixed(0)})', maxLines: 2, overflow: TextOverflow.ellipsis),
              ),
            ),
          ],
          onChanged: (v) {
            if (v == null) return;
            if (v.isEmpty) {
              widget.controller.clear();
              widget.onChanged();
            } else {
              final hit = WdwRestaurantCatalog.matchName(v, t);
              if (hit != null) _applyPick(hit);
            }
          },
        ),
        const SizedBox(height: 10),
        RawAutocomplete<WdwRestaurantOption>(
          textEditingController: widget.controller,
          focusNode: _restaurantFocusNode,
          displayStringForOption: (o) => o.name,
          optionsBuilder: (textEditingValue) {
            return WdwRestaurantCatalog.search(t, textEditingValue.text, limit: 8);
          },
          onSelected: _applyPick,
          fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
            return TextField(
              controller: controller,
              focusNode: focusNode,
              decoration: const InputDecoration(
                labelText: 'Search all restaurants',
                hintText: 'Type a name — up to 8 matches',
                prefixIcon: Icon(Icons.search_rounded),
              ),
              onChanged: (_) => widget.onChanged(),
            );
          },
          optionsViewBuilder: (context, onSelected, options) {
            if (options.isEmpty) return const SizedBox.shrink();
            return Align(
              alignment: Alignment.topLeft,
              child: Material(
                elevation: 6,
                borderRadius: BorderRadius.circular(AppRadius.md),
                clipBehavior: Clip.antiAlias,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 220),
                  child: ListView.builder(
                    padding: EdgeInsets.zero,
                    shrinkWrap: true,
                    itemCount: options.length,
                    itemBuilder: (ctx, i) {
                      final o = options.elementAt(i);
                      return ListTile(
                        dense: true,
                        title: Text(o.name, maxLines: 2, overflow: TextOverflow.ellipsis),
                        subtitle: Text('~\$${o.avgPerAdult.toStringAsFixed(0)} avg'),
                        onTap: () => onSelected(o),
                      );
                    },
                  ),
                ),
              ),
            );
          },
        ),
        if (widget.showFooterHint) ...[
          const SizedBox(height: 4),
          Text(
            'Approx. entrée + drink (planning). Menus change — check allears.net/dining/menu/',
            style: text.bodySmall?.copyWith(color: cs.onSurface.withValues(alpha: 0.62), height: 1.25),
          ),
        ],
      ],
    );
  }
}
