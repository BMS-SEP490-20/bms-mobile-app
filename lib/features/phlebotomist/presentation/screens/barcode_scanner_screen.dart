import 'package:flutter/material.dart';
import '../../../laboratory/presentation/screens/trace_sample_origin_screen.dart';

/// Specimen Barcode Lookup Screen delegating to [TraceSampleOriginScreen].
class BarcodeScannerScreen extends StatelessWidget {
  const BarcodeScannerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const TraceSampleOriginScreen();
  }
}
