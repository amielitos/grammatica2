import 'package:flutter/material.dart';

class PaymongoQrDialog extends StatefulWidget {
  final String tier;
  final double amount;
  final String educatorName;

  const PaymongoQrDialog({
    super.key,
    required this.tier,
    required this.amount,
    required this.educatorName,
  });

  @override
  State<PaymongoQrDialog> createState() => _PaymongoQrDialogState();
}

class _PaymongoQrDialogState extends State<PaymongoQrDialog> {
  bool _isProcessing = false;

  void _simulateSuccess() async {
    setState(() => _isProcessing = true);
    // Simulate network delay
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) {
      Navigator.pop(context, true); // Returns true when payment succeeds
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      child: Container(
        width: 450,
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.9),
        padding: const EdgeInsets.all(32.0),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Header Image / Logo
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.qr_code_scanner, color: Color(0xFF1E88E5), size: 36),
                  const SizedBox(width: 12),
                  Text(
                    'PayMongo QR PH',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: Colors.blue.shade800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text(
                'Scan to Pay using any compatible e-wallet or banking app (GCash, Maya, UnionBank, etc.)',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.black54),
              ),
              const SizedBox(height: 32),
              
              // The QR Mock/Image
              Container(
                width: 250,
                height: 250,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.blue.shade100, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blue.shade900.withOpacity(0.08),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    )
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Image.asset(
                    'assets/qrph.jpg',
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Stack(
                      alignment: Alignment.center,
                      children: [
                        Icon(Icons.qr_code_2, size: 200, color: Colors.blue.shade900),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.warning, color: Colors.amber, size: 40),
                        )
                      ],
                    ),
                  ),
                ),
              ),
              
              const SizedBox(height: 32),
              
              // Payment Details
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  children: [
                    _buildDetailRow('Merchant', 'Grammatica'),
                    const SizedBox(height: 8),
                    _buildDetailRow('Subscription', '${widget.tier} to ${widget.educatorName}'),
                    const SizedBox(height: 8),
                    const Divider(),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Total Amount', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black54)),
                        Text('₱${widget.amount.toStringAsFixed(2)}', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Color(0xFF1E88E5))),
                      ],
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 32),
              
              // Testing Actions
              if (_isProcessing)
                const CircularProgressIndicator(color: Color(0xFF1E88E5))
              else
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 16,
                  runSpacing: 16,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel Request', style: TextStyle(color: Colors.red, fontSize: 16)),
                    ),
                    ElevatedButton(
                      onPressed: _simulateSuccess,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1E88E5), // PayMongo Blue theme
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Simulate Payment'),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String val) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Colors.black54, fontSize: 14)),
        Text(val, style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 14)),
      ],
    );
  }
}
