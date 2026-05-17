// lib/features/scan_report/scan_report_screen.dart

import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:healthconnect/theme/app_design_system.dart';
import 'package:healthconnect/core/services/scan_service.dart';
import 'package:healthconnect/features/scan_report/scan_result_screen.dart';

class ScanReportScreen extends StatefulWidget {
  const ScanReportScreen({super.key});

  @override
  State<ScanReportScreen> createState() =>
      _ScanReportScreenState();
}

class _ScanReportScreenState
    extends State<ScanReportScreen> {
  final _picker = ImagePicker();
  final _scanService = ScanService();

  bool _isScanning = false;
  String _statusText = '';
  Uint8List? _previewBytes;

  Future<void> _pick(ImageSource source) async {
    final file = await _picker.pickImage(
      source: source,
      imageQuality: 90, // mild quality at pick
      maxWidth: 2048,
      maxHeight: 2048,
    );
    if (file == null) return;

    final bytes = await file.readAsBytes();
    _startScan(bytes);
  }

  Future<void> _startScan(Uint8List bytes) async {
    setState(() {
      _isScanning = true;
      _previewBytes = bytes;
      _statusText = 'Preparing image...';
    });

    try {
      // ✅ Compress aggressively before sending
      // Target: under 400KB to stay within Gemini token limits
      // This prevents 429 errors caused by large images
      Uint8List compressed = bytes;

      if (bytes.length > 400 * 1024) {
        setState(
            () => _statusText = 'Compressing image...');

        final result =
            await FlutterImageCompress.compressWithList(
          bytes,
          minHeight: 800,
          minWidth: 800,
          quality: 60, // aggressive compression
          format: CompressFormat.jpeg,
        );
        compressed = result;

        debugPrint(
            '[Scan] Compressed: '
            '${(bytes.length / 1024).toStringAsFixed(0)}KB → '
            '${(compressed.length / 1024).toStringAsFixed(0)}KB');
      }

      setState(
          () => _statusText = 'Reading document...');

      final result =
          await _scanService.scanDocument(compressed);

      if (!mounted) return;

      if (result.isEmpty) {
        setState(() => _isScanning = false);
        _snack(
            "No medical data found. Try a clearer photo.");
        return;
      }

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              ScanResultScreen(result: result),
        ),
      );

      setState(() {
        _isScanning = false;
        _previewBytes = null;
        _statusText = '';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isScanning = false);
      _snack('Scan failed: $e');
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        duration: const Duration(seconds: 5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding:
                    const EdgeInsets.all(AppSpacing.lg),
                child: Row(
                  children: [
                    AppBackButton(
                        onTap: () =>
                            Navigator.pop(context)),
                    const SizedBox(width: AppSpacing.md),
                    Text("Scan Report",
                        style: AppTextStyles.heading),
                  ],
                ),
              ),
              Expanded(
                child: _isScanning
                    ? _scanningState()
                    : _idleState(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _idleState() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg),
      child: Column(
        children: [
          const SizedBox(height: AppSpacing.xl),

          Container(
            width: 110,
            height: 110,
            decoration: BoxDecoration(
              color: AppColors.iconBg,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.document_scanner_outlined,
              size: 52,
              color: AppColors.primary,
            ),
          ),

          const SizedBox(height: AppSpacing.lg),

          Text(
            "Scan a Medical Document",
            style: AppTextStyles.body.copyWith(
                fontWeight: FontWeight.w700),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 8),

          Text(
            "Take a photo or upload from gallery.\nWorks with lab reports, prescriptions,\ndischarge summaries and blood reports.",
            style: AppTextStyles.small,
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: AppSpacing.xl),

          _pickButton(
            icon: Icons.camera_alt_outlined,
            label: "Take Photo",
            subtitle: "Best for printed reports",
            onTap: () => _pick(ImageSource.camera),
          ),

          const SizedBox(height: AppSpacing.md),

          _pickButton(
            icon: Icons.photo_library_outlined,
            label: "Upload from Gallery",
            subtitle: "Select a saved image",
            onTap: () => _pick(ImageSource.gallery),
          ),

          const SizedBox(height: AppSpacing.xl),

          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius:
                  BorderRadius.circular(AppRadius.md),
              border: Border.all(
                  color: Colors.blue.shade200),
            ),
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Icon(
                      Icons.tips_and_updates_outlined,
                      color: Colors.blue.shade700,
                      size: 16),
                  const SizedBox(width: 6),
                  Text("Tips for best results",
                      style: AppTextStyles.small.copyWith(
                          color: Colors.blue.shade800,
                          fontWeight: FontWeight.w700)),
                ]),
                const SizedBox(height: 8),
                _tip("Ensure document is flat and fully visible"),
                _tip("Good lighting — avoid shadows"),
                _tip("Hold camera steady for sharp text"),
                _tip("Works best with printed documents"),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.md),

          Text(
            "⚠️ Always verify extracted data before saving. "
            "This tool assists data entry — not a medical diagnosis.",
            style: AppTextStyles.small.copyWith(
                fontSize: 11,
                color: Colors.orange.shade800),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }

  Widget _scanningState() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg),
        child: Column(
          children: [
            const SizedBox(height: AppSpacing.xl),

            if (_previewBytes != null) ...[
              ClipRRect(
                borderRadius:
                    BorderRadius.circular(AppRadius.md),
                child: Image.memory(
                  _previewBytes!,
                  height: 220,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
            ],

            const CircularProgressIndicator(
              color: AppColors.primary,
              strokeWidth: 3,
            ),

            const SizedBox(height: AppSpacing.lg),

            Text(
              _statusText,
              style: AppTextStyles.body.copyWith(
                  fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 8),

            Text(
              "Gethering all the informations from the document...",
              style: AppTextStyles.small,
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: AppSpacing.xl),
          ],
        ),
      ),
    );
  }

  Widget _pickButton({
    required IconData icon,
    required String label,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius:
              BorderRadius.circular(AppRadius.md),
          boxShadow: [AppShadows.light],
          border:
              Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: AppColors.iconBg,
                shape: BoxShape.circle,
              ),
              child: Icon(icon,
                  color: AppColors.primary, size: 26),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: AppTextStyles.body.copyWith(
                          fontWeight: FontWeight.w600)),
                  Text(subtitle,
                      style: AppTextStyles.small),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios,
                size: 16, color: AppColors.hint),
          ],
        ),
      ),
    );
  }

  Widget _tip(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.check_circle_outline,
              size: 13,
              color: Colors.blue.shade600),
          const SizedBox(width: 6),
          Expanded(
            child: Text(text,
                style: AppTextStyles.small
                    .copyWith(fontSize: 11)),
          ),
        ],
      ),
    );
  }
}