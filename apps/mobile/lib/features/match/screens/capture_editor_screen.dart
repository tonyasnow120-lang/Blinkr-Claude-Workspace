import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/graffiti_highlight.dart';
import '../../profile/providers/profile_provider.dart';

/// Edits a still frame captured from the opponent's live video, then saves it
/// to the player's collage so it can be replayed as a photo bomb later.
///
/// Tools are deliberately light: freehand spray strokes in the acid palette,
/// draggable uppercase captions, undo/clear. The whole canvas is rendered to a
/// PNG via [RepaintBoundary] on save.
class CaptureEditorScreen extends ConsumerStatefulWidget {
  final Uint8List imageBytes;

  const CaptureEditorScreen({super.key, required this.imageBytes});

  @override
  ConsumerState<CaptureEditorScreen> createState() =>
      _CaptureEditorScreenState();
}

class _CaptureEditorScreenState extends ConsumerState<CaptureEditorScreen> {
  final GlobalKey _captureKey = GlobalKey();

  final List<_Stroke> _strokes = [];
  _Stroke? _current;
  final List<_Caption> _captions = [];

  Color _color = AppColors.acid;
  bool _saving = false;

  static const _palette = [
    AppColors.acid,
    AppColors.chalk,
    Color(0xFFFF3B30),
    AppColors.bg,
  ];

  void _onPanStart(DragStartDetails d) {
    setState(() {
      _current = _Stroke(color: _color, width: 6, points: [d.localPosition]);
      _strokes.add(_current!);
    });
  }

  void _onPanUpdate(DragUpdateDetails d) {
    if (_current == null) return;
    setState(() => _current!.points.add(d.localPosition));
  }

  void _onPanEnd(DragEndDetails d) => _current = null;

  void _undo() {
    if (_captions.isNotEmpty || _strokes.isNotEmpty) {
      setState(() {
        // Remove whichever was added most recently is ambiguous across two
        // lists; favour strokes since drawing is the common action.
        if (_strokes.isNotEmpty) {
          _strokes.removeLast();
        } else {
          _captions.removeLast();
        }
      });
    }
  }

  void _clear() => setState(() {
        _strokes.clear();
        _captions.clear();
      });

  Future<void> _addCaption() async {
    final controller = TextEditingController();
    final text = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        title: Text('ADD A TAUNT', style: TextStyle(color: context.colors.foreground)),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.characters,
          style: TextStyle(color: context.colors.foreground),
          decoration: InputDecoration(
            hintText: 'BLINKED ALREADY?',
            hintStyle: TextStyle(color: context.colors.ink(0.38)),
          ),
          onSubmitted: (v) => Navigator.pop(context, v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('ADD'),
          ),
        ],
      ),
    );
    if (text == null || text.trim().isEmpty) return;
    setState(() {
      _captions.add(_Caption(
        text: text.trim().toUpperCase(),
        position: const Offset(40, 80),
        color: _color,
      ));
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final boundary = _captureKey.currentContext!.findRenderObject()
          as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 2.0);
      final byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
      final bytes = byteData!.buffer.asUint8List();

      await ref.read(photoServiceProvider).uploadPhotoBytes(bytes);
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("COULDN'T SAVE: $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppBar(
        backgroundColor: context.colors.background,
        foregroundColor: context.colors.foreground,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context, false),
        ),
        title: const Text('CAPTURE',
            style: TextStyle(letterSpacing: 4, fontWeight: FontWeight.w300)),
        actions: [
          if (_saving)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 18),
              child: Center(
                child: SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: AppColors.acid),
                ),
              ),
            )
          else
            TextButton(
              onPressed: _save,
              child: const Text('SAVE',
                  style: TextStyle(
                      color: AppColors.acid,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 3)),
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: RepaintBoundary(
                key: _captureKey,
                child: AspectRatio(
                  aspectRatio: 3 / 4,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.memory(widget.imageBytes, fit: BoxFit.cover),
                      // Drawing surface.
                      GestureDetector(
                        onPanStart: _onPanStart,
                        onPanUpdate: _onPanUpdate,
                        onPanEnd: _onPanEnd,
                        child: CustomPaint(
                          painter: _DrawPainter(_strokes),
                          size: Size.infinite,
                        ),
                      ),
                      // Draggable captions sit above the drawing layer.
                      for (final caption in _captions)
                        _CaptionWidget(
                          caption: caption,
                          onDrag: (delta) => setState(
                              () => caption.position += delta),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          _Toolbar(
            palette: _palette,
            selected: _color,
            onColor: (c) => setState(() => _color = c),
            onUndo: _undo,
            onClear: _clear,
            onAddText: _addCaption,
          ),
        ],
      ),
    );
  }
}

class _Stroke {
  final Color color;
  final double width;
  final List<Offset> points;

  _Stroke({required this.color, required this.width, required this.points});
}

class _Caption {
  String text;
  Offset position;
  Color color;

  _Caption({required this.text, required this.position, required this.color});
}

class _DrawPainter extends CustomPainter {
  final List<_Stroke> strokes;

  _DrawPainter(this.strokes);

  @override
  void paint(Canvas canvas, Size size) {
    for (final stroke in strokes) {
      final paint = Paint()
        ..color = stroke.color
        ..strokeWidth = stroke.width
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;
      if (stroke.points.length == 1) {
        canvas.drawPoints(ui.PointMode.points, stroke.points, paint);
        continue;
      }
      final path = Path()..moveTo(stroke.points.first.dx, stroke.points.first.dy);
      for (var i = 1; i < stroke.points.length; i++) {
        path.lineTo(stroke.points[i].dx, stroke.points[i].dy);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(_DrawPainter old) => true;
}

class _CaptionWidget extends StatelessWidget {
  final _Caption caption;
  final ValueChanged<Offset> onDrag;

  const _CaptionWidget({required this.caption, required this.onDrag});

  @override
  Widget build(BuildContext context) {
    final isAcid = caption.color == AppColors.acid;
    return Positioned(
      left: caption.position.dx,
      top: caption.position.dy,
      child: GestureDetector(
        onPanUpdate: (d) => onDrag(d.delta),
        child: isAcid
            ? GraffitiHighlight(
                child: Text(
                  caption.text,
                  style: const TextStyle(
                    color: AppColors.acidInk,
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2,
                  ),
                ),
              )
            : Text(
                caption.text,
                style: TextStyle(
                  color: caption.color,
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 2,
                  shadows: [
                    Shadow(blurRadius: 6, color: AppColors.bg.withOpacity(0.54)),
                  ],
                ),
              ),
      ),
    );
  }
}

class _Toolbar extends StatelessWidget {
  final List<Color> palette;
  final Color selected;
  final ValueChanged<Color> onColor;
  final VoidCallback onUndo;
  final VoidCallback onClear;
  final VoidCallback onAddText;

  const _Toolbar({
    required this.palette,
    required this.selected,
    required this.onColor,
    required this.onUndo,
    required this.onClear,
    required this.onAddText,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                for (final color in palette)
                  GestureDetector(
                    onTap: () => onColor(color),
                    child: Container(
                      width: 28,
                      height: 28,
                      margin: const EdgeInsets.only(right: 10),
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: selected == color
                              ? AppColors.dark.foreground
                              : AppColors.dark.ink(0.24),
                          width: selected == color ? 2.5 : 1,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            Row(
              children: [
                IconButton(
                  onPressed: onAddText,
                  icon: const Icon(Icons.text_fields, color: AppColors.chalk),
                  tooltip: 'ADD TEXT',
                ),
                IconButton(
                  onPressed: onUndo,
                  icon: const Icon(Icons.undo, color: AppColors.chalk),
                  tooltip: 'UNDO',
                ),
                IconButton(
                  onPressed: onClear,
                  icon: const Icon(Icons.delete_outline, color: AppColors.chalk),
                  tooltip: 'CLEAR',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
