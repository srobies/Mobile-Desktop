import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

const _kExpandDuration = Duration(milliseconds: 200);
const _kCollapsedWidth = 48.0;
const _kButtonHeight = 40.0;
const _kBorderRadius = 20.0;
const _kIconSize = 20.0;
const _kSpacing = 8.0;

class ExpandableIconButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final FocusNode? focusNode;
  final bool isActive;
  final Color activeColor;

  const ExpandableIconButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.focusNode,
    this.isActive = false,
    this.activeColor = const Color(0xFF00A4DC),
  });

  @override
  State<ExpandableIconButton> createState() => _ExpandableIconButtonState();
}

class _ExpandableIconButtonState extends State<ExpandableIconButton> {
  late final FocusNode _focusNode;
  bool _isFocused = false;
  bool _isHovered = false;

  bool get _expanded => _isFocused || _isHovered;

  @override
  void initState() {
    super.initState();
    _focusNode = widget.focusNode ?? FocusNode();
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    if (widget.focusNode == null) _focusNode.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    setState(() => _isFocused = _focusNode.hasFocus);
  }

  KeyEventResult _onKeyEvent(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent &&
        (event.logicalKey == LogicalKeyboardKey.select ||
            event.logicalKey == LogicalKeyboardKey.enter)) {
      widget.onPressed();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = widget.isActive
        ? widget.activeColor.withValues(alpha: 0.25)
        : _isFocused
            ? Colors.white.withValues(alpha: 0.15)
            : Colors.transparent;

    final fgColor = widget.isActive
        ? widget.activeColor
        : _isFocused
            ? Colors.white
            : Colors.white.withValues(alpha: 0.7);

    final borderColor = _isFocused
        ? widget.activeColor
        : widget.isActive
            ? widget.activeColor.withValues(alpha: 0.5)
            : Colors.white.withValues(alpha: 0.1);

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: Focus(
        focusNode: _focusNode,
        onKeyEvent: _onKeyEvent,
        child: GestureDetector(
          onTap: widget.onPressed,
          child: AnimatedContainer(
            duration: _kExpandDuration,
            curve: Curves.easeInOut,
            height: _kButtonHeight,
            constraints: BoxConstraints(
              minWidth: _kCollapsedWidth,
              maxWidth: _expanded ? 200 : _kCollapsedWidth,
            ),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(_kBorderRadius),
              border: Border.all(color: borderColor, width: _isFocused ? 2 : 1),
            ),
            padding: EdgeInsets.symmetric(
              horizontal: _expanded ? 14 : 0,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(widget.icon, size: _kIconSize, color: fgColor),
                if (_expanded) ...[
                  const SizedBox(width: _kSpacing),
                  Flexible(
                    child: Text(
                      widget.label,
                      style: TextStyle(
                        color: fgColor,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
