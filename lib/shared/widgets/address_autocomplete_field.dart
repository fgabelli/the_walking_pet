import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/services/osm_service.dart';

class AddressAutocompleteField extends StatefulWidget {
  final String? initialValue;
  final Function(OSMPlace) onSelected;
  final String label;
  final String? Function(String?)? validator;
  final TextEditingController? controller;

  const AddressAutocompleteField({
    super.key,
    this.initialValue,
    required this.onSelected,
    this.label = 'Indirizzo',
    this.validator,
    this.controller,
  });

  @override
  State<AddressAutocompleteField> createState() => _AddressAutocompleteFieldState();
}

class _AddressAutocompleteFieldState extends State<AddressAutocompleteField> {
  final OSMService _osmService = OSMService();
  Timer? _debounce;
  List<OSMPlace> _options = [];
  late TextEditingController _textEditingController;
  final FocusNode _focusNode = FocusNode();
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;

  @override
  void initState() {
    super.initState();
    _textEditingController = widget.controller ?? TextEditingController(text: widget.initialValue);
    _focusNode.addListener(() {
      if (!_focusNode.hasFocus) {
        _removeOverlay();
      }
    });
  }

  @override
  void dispose() {
    if (widget.controller == null) {
      _textEditingController.dispose();
    }
    _focusNode.dispose();
    _debounce?.cancel();
    _removeOverlay();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () async {
      if (query.length < 3) {
        setState(() => _options = []);
        _removeOverlay();
        return;
      }

      final results = await _osmService.searchAddress(query);
      if (mounted) {
        setState(() => _options = results);
        if (results.isNotEmpty) {
          _showOverlay();
        } else {
          _removeOverlay();
        }
      }
    });
  }

  void _showOverlay() {
    _removeOverlay();
    final RenderBox renderBox = context.findRenderObject() as RenderBox;
    final size = renderBox.size;

    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        width: size.width,
        child: CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          offset: Offset(0.0, size.height + 5.0),
          child: Material(
            elevation: 4.0,
            borderRadius: BorderRadius.circular(8),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 200),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: _options.length,
                itemBuilder: (context, index) {
                  final option = _options[index];
                  return ListTile(
                    title: Text(option.displayName),
                    onTap: () {
                      _textEditingController.text = option.displayName;
                      widget.onSelected(option);
                      _removeOverlay();
                      _focusNode.unfocus();
                    },
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: TextFormField(
        controller: _textEditingController,
        focusNode: _focusNode,
        decoration: InputDecoration(
          labelText: widget.label,
          prefixIcon: const Icon(Icons.location_on),
          suffixIcon: _options.isNotEmpty && _focusNode.hasFocus
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _textEditingController.clear();
                    _removeOverlay();
                  },
                )
              : null,
        ),
        onChanged: _onSearchChanged,
        validator: widget.validator,
      ),
    );
  }
}
