import 'package:flutter/material.dart';
import '../app_colors.dart';

/// Auswahl einer An- oder Abfahrtszeit mit drei unterscheidbaren Zustaenden:
///
/// * `null`  — nichts eigenes eingestellt, es gilt die allgemeinere Vorgabe
///             (im Termin: der Kalender; in den Einstellungen: keine)
/// * `0`     — ausdruecklich keine Zeit, auch wenn es eine Vorgabe gibt
/// * `> 0`   — diese Zeit
///
/// Die Unterscheidung zwischen `null` und `0` ist der ganze Zweck: ohne sie
/// koennte man einen einzelnen Termin nicht von der Kalender-Vorgabe
/// ausnehmen.
class TravelTimePicker extends StatefulWidget {
  final String label;
  final int? minutes;

  /// Was ohne eigene Angabe gelten wuerde — nur fuer die Beschriftung.
  final int? inherited;

  /// Beschriftung des Vorgabe-Knopfs.
  final String inheritLabel;

  final ValueChanged<int?> onChanged;

  const TravelTimePicker({
    super.key,
    required this.label,
    required this.minutes,
    required this.onChanged,
    this.inherited,
    this.inheritLabel = 'Vorgabe',
  });

  @override
  State<TravelTimePicker> createState() => _TravelTimePickerState();
}

class _TravelTimePickerState extends State<TravelTimePicker> {
  static const _options = [0, 5, 10, 15, 20, 30, 45, 60];
  late final TextEditingController _ctrl;

  String _textFor(int? minutes) =>
      (minutes == null || minutes == 0) ? '' : '$minutes';

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: _textFor(widget.minutes));
  }

  @override
  void didUpdateWidget(TravelTimePicker old) {
    super.didUpdateWidget(old);
    if (old.minutes != widget.minutes) {
      final txt = _textFor(widget.minutes);
      if (_ctrl.text != txt) {
        _ctrl.text = txt;
        _ctrl.selection = TextSelection.collapsed(offset: txt.length);
      }
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  bool get _isCustom =>
      widget.minutes != null && !_options.contains(widget.minutes);

  String get _inheritText {
    final v = widget.inherited;
    if (v == null || v == 0) return widget.inheritLabel;
    return '${widget.inheritLabel} ($v min)';
  }

  Widget _chip(String text, bool selected, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.primary.withValues(alpha: 0.2)
                : AppColors.card,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.divider,
              width: 1,
            ),
          ),
          child: Text(
            text,
            style: TextStyle(
              fontSize: 12,
              color: selected ? AppColors.primary : AppColors.textSecondary,
              fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final customBorder = _isCustom ? AppColors.primary : AppColors.divider;
    return Row(
      children: [
        Icon(
          widget.label == 'Anfahrt'
              ? Icons.directions_car_outlined
              : Icons.directions_car,
          size: 16,
          color: AppColors.textSecondary,
        ),
        const SizedBox(width: 8),
        Text(widget.label,
            style:
                const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
        const SizedBox(width: 12),
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _chip(_inheritText, widget.minutes == null,
                    () => widget.onChanged(null)),
                ..._options.map((m) => _chip(
                      m == 0 ? 'Keine' : '${m}min',
                      widget.minutes == m,
                      () => widget.onChanged(m),
                    )),
                SizedBox(
                  width: 64,
                  height: 30,
                  child: TextField(
                    controller: _ctrl,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color: _isCustom
                          ? AppColors.primary
                          : AppColors.textSecondary,
                    ),
                    decoration: InputDecoration(
                      hintText: 'min',
                      hintStyle: const TextStyle(
                          fontSize: 12, color: AppColors.textDisabled),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      filled: true,
                      fillColor: _isCustom
                          ? AppColors.primary.withValues(alpha: 0.2)
                          : AppColors.card,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: customBorder),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: customBorder),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(
                            color: AppColors.primary, width: 1.5),
                      ),
                    ),
                    // Leeres Feld aendert nichts: „keine Zeit" und „Vorgabe"
                    // sind zwei verschiedene Aussagen und haben beide ihren
                    // eigenen Knopf. Eine Zahl hier ist immer ein eigener Wert.
                    onChanged: (val) {
                      if (val.isEmpty) return;
                      final parsed = int.tryParse(val);
                      if (parsed != null && parsed >= 0) {
                        widget.onChanged(parsed);
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
