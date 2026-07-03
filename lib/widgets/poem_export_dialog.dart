import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/history_entry.dart';
import '../theme/app_theme.dart';

class PoemExportDialog extends StatefulWidget {
  final HistoryEntry entry;

  const PoemExportDialog({super.key, required this.entry});

  @override
  State<PoemExportDialog> createState() => _PoemExportDialogState();
}

class _PoemExportDialogState extends State<PoemExportDialog> {
  final GlobalKey _globalKey = GlobalKey();
  bool _isSharing = false;

  Future<void> _captureAndShare() async {
    setState(() => _isSharing = true);

    try {
      RenderRepaintBoundary boundary = _globalKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      
      ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      Uint8List pngBytes = byteData!.buffer.asUint8List();

      final directory = await getTemporaryDirectory();
      final file = File('${directory.path}/poem_${widget.entry.id}.png');
      await file.writeAsBytes(pngBytes);

      final xFile = XFile(file.path, mimeType: 'image/png');
      await Share.shareXFiles([xFile], text: 'A poem mentored by ${widget.entry.personaName}');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error generating image: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
  }

  bool _isChinese(String text) {
    return RegExp(r'[\u4e00-\u9fa5]').hasMatch(text);
  }

  @override
  Widget build(BuildContext context) {
    final isChinese = _isChinese(widget.entry.poem);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          RepaintBoundary(
            key: _globalKey,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: AppColors.ink, 
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: AppColors.gold.withOpacity(0.3), width: 2),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 20, offset: const Offset(0, 10)),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  isChinese ? _buildVerticalChinesePoem() : _buildStandardPoem(),
                  
                  const SizedBox(height: 40),
                  
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('Mentored by', style: TextStyle(color: AppColors.paper.withOpacity(0.5), fontSize: 10, letterSpacing: 1)),
                          Text(widget.entry.personaEnglishName, style: TextStyle(color: AppColors.paper.withOpacity(0.8), fontSize: 12, fontStyle: FontStyle.italic)),
                        ],
                      ),
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          border: Border.all(color: AppColors.seal, width: 1.5),
                          borderRadius: BorderRadius.circular(2),
                        ),
                        child: Text(
                          widget.entry.personaName,
                          style: const TextStyle(color: AppColors.seal, fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 2),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 24),
          
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
              ),
              ElevatedButton.icon(
                onPressed: _isSharing ? null : _captureAndShare,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.gold,
                  foregroundColor: AppColors.ink,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
                icon: _isSharing 
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: AppColors.ink, strokeWidth: 2))
                    : const Icon(Icons.ios_share, size: 18),
                label: Text(_isSharing ? 'Generating...' : 'Share Postcard'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildVerticalChinesePoem() {
    final lines = widget.entry.poem.split('\n').where((l) => l.trim().isNotEmpty).toList().reversed.toList();
    
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: lines.map((line) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: line.characters.map((char) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 6.0),
                child: Text(
                  char,
                  style: const TextStyle(color: AppColors.paper, fontSize: 22, height: 1.1),
                ),
              );
            }).toList(),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildStandardPoem() {
    return Text(
      widget.entry.poem,
      textAlign: TextAlign.center,
      style: const TextStyle(color: AppColors.paper, fontSize: 18, height: 1.8, fontStyle: FontStyle.italic),
    );
  }
}