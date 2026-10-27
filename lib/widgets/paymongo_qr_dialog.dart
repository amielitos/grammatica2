import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/paymongo_service.dart';

class PaymongoQrDialog extends StatefulWidget {
  final String tier;
  final double amount;
  final String educatorName;
  final String? learnerName;
  final String? learnerEmail;
  final String? idempotencyKey;

  const PaymongoQrDialog({
    super.key,
    required this.tier,
    required this.amount,
    required this.educatorName,
    this.learnerName,
    this.learnerEmail,
    this.idempotencyKey,
  });

  @override
  State<PaymongoQrDialog> createState() => _PaymongoQrDialogState();
}

class _PaymongoQrDialogState extends State<PaymongoQrDialog> {
  PaymongoPaymentLink? _paymentLink;
  bool _isLoading = true;
  String? _errorMessage;
  Timer? _pollTimer;
  bool _isSuccess = false;
  bool _isProcessing = false;
  bool _copied = false;
  bool _hasDispatchedSuccess = false;

  @override
  void initState() {
    super.initState();
    _initPaymentLink();
  }

  Future<void> _initPaymentLink() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final link = await PaymongoService.createPaymentLinkDetailed(
      amount: widget.amount,
      description: 'Grammatica ${widget.tier} Tier - ${widget.educatorName}',
      remarks: 'Grammatica Subscription for ${widget.learnerName ?? "Learner"}',
      idempotencyKey: widget.idempotencyKey,
    );

    if (!mounted) return;

    if (link != null) {
      setState(() {
        _paymentLink = link;
        _isLoading = false;
      });
      if (!link.isLocalFallback && link.checkoutUrl.isNotEmpty) {
        _startPolling(link.id);
      }
    } else {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _startPolling(String linkId) {
    if (linkId.isEmpty || linkId.startsWith('link_merchant_')) return;
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (timer) async {
      final updated = await PaymongoService.getPaymentLink(linkId);
      if (updated != null && updated.isPaid) {
        timer.cancel();
        _handleSuccess(
          referenceNumber: updated.referenceNumber,
          paymentMethod: 'PayMongo QR PH / Checkout',
          linkId: updated.id,
        );
      }
    });
  }

  void _handleSuccess({
    required String referenceNumber,
    required String paymentMethod,
    String? linkId,
  }) async {
    if (_hasDispatchedSuccess) return; // Prevent duplicate fulfillment
    _hasDispatchedSuccess = true;
    _pollTimer?.cancel();
    if (!mounted) return;

    setState(() {
      _isSuccess = true;
      _isProcessing = false;
    });

    await Future.delayed(const Duration(milliseconds: 1400));
    if (mounted) {
      Navigator.pop(
        context,
        PaymongoPaymentResult(
          isSuccess: true,
          referenceNumber: referenceNumber,
          amount: widget.amount,
          tier: widget.tier,
          educatorName: widget.educatorName,
          paymentMethod: paymentMethod,
          linkId: linkId,
          paidAt: DateTime.now(),
          idempotencyKey: _paymentLink?.idempotencyKey ?? widget.idempotencyKey,
        ),
      );
    }
  }

  void _simulateSuccess() async {
    if (_hasDispatchedSuccess || _isProcessing) return;
    setState(() => _isProcessing = true);
    await Future.delayed(const Duration(seconds: 1));
    final simulatedRef =
        'SIM-${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}';
    _handleSuccess(
      referenceNumber: simulatedRef,
      paymentMethod: 'PayMongo QR PH (Simulated)',
      linkId: _paymentLink?.id,
    );
  }

  Future<void> _openCheckoutUrl() async {
    if (_paymentLink == null || _paymentLink!.checkoutUrl.isEmpty) return;
    final uri = Uri.parse(_paymentLink!.checkoutUrl);
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('[PayMongo] Launch URL error: $e');
    }
  }

  void _copyLink() {
    if (_paymentLink == null) return;
    Clipboard.setData(ClipboardData(text: _paymentLink!.checkoutUrl));
    setState(() => _copied = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isSuccess) {
      return Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 76,
                height: 76,
                decoration: const BoxDecoration(
                  color: Color(0xFFDCFCE7),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle_rounded,
                  color: Color(0xFF16A34A),
                  size: 52,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Payment Confirmed! 🎉',
                style: GoogleFonts.outfit(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Enrolled in ${widget.tier} Tier with ${widget.educatorName}. Receipt will be emailed to you.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: const Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Container(
        width: 460,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.92,
        ),
        padding: const EdgeInsets.all(28.0),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E88E5).withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.qr_code_scanner_rounded,
                      color: Color(0xFF1E88E5),
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'PayMongo QR PH',
                        style: GoogleFonts.outfit(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFF1E88E5),
                        ),
                      ),
                      Text(
                        'Instant E-Wallet & Bank Transfer',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.black45,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                'Scan using GCash, Maya, ShopeePay, or any QR PH banking app to complete your enrollment.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(fontSize: 13, color: Colors.black54),
              ),
              const SizedBox(height: 24),

              // QR Code Container
              Container(
                width: 240,
                height: 240,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0), width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blue.shade900.withValues(alpha: 0.06),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: _isLoading
                      ? const Center(
                          child: CircularProgressIndicator(
                            color: Color(0xFF1E88E5),
                          ),
                        )
                      : (_paymentLink != null && _paymentLink!.checkoutUrl.isNotEmpty)
                          ? Image.network(
                              'https://api.qrserver.com/v1/create-qr-code/?size=300x300&margin=8&data=${Uri.encodeComponent(_paymentLink!.checkoutUrl)}',
                              fit: BoxFit.contain,
                              errorBuilder: (context, error, stackTrace) =>
                                  Image.asset(
                                'assets/qrph.jpg',
                                fit: BoxFit.cover,
                              ),
                            )
                          : Image.asset(
                              'assets/qrph.jpg',
                              fit: BoxFit.cover,
                            ),
                ),
              ),

              if (_paymentLink != null && _paymentLink!.checkoutUrl.isNotEmpty) ...[
                const SizedBox(height: 16),
                // Action Buttons for Mobile / Web Users
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 10,
                  runSpacing: 8,
                  children: [
                    ElevatedButton.icon(
                      onPressed: _openCheckoutUrl,
                      icon: const Icon(Icons.open_in_new_rounded, size: 16),
                      label: Text(
                        'Open Checkout Link',
                        style: GoogleFonts.outfit(fontWeight: FontWeight.w700),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1E88E5),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: _copyLink,
                      icon: Icon(
                        _copied ? Icons.check_rounded : Icons.copy_rounded,
                        size: 16,
                        color: _copied
                            ? const Color(0xFF16A34A)
                            : const Color(0xFF1E88E5),
                      ),
                      label: Text(
                        _copied ? 'Copied!' : 'Copy Link',
                        style: GoogleFonts.outfit(
                          fontWeight: FontWeight.w700,
                          color: _copied
                              ? const Color(0xFF16A34A)
                              : const Color(0xFF1E88E5),
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(
                          color: _copied
                              ? const Color(0xFF16A34A)
                              : const Color(0xFF1E88E5),
                        ),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ],
                ),
              ],

              const SizedBox(height: 20),

              // Status Badge
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFBBF7D0)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_paymentLink != null && _paymentLink!.checkoutUrl.isNotEmpty) ...[
                      const SizedBox(
                        width: 10,
                        height: 10,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Color(0xFF16A34A),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Waiting for payment… auto-detects upon completion',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF166534),
                        ),
                      ),
                    ] else ...[
                      const Icon(Icons.qr_code_scanner_rounded, size: 14, color: Color(0xFF16A34A)),
                      const SizedBox(width: 8),
                      Text(
                        'Scan QR PH via GCash/Maya & tap Confirm below',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF166534),
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              if (_errorMessage != null) ...[
                const SizedBox(height: 12),
                Text(
                  _errorMessage!,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: Colors.orange.shade800,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],

              const SizedBox(height: 20),

              // Payment Details Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  children: [
                    _buildDetailRow('Merchant', 'Grammatica Language Platform'),
                    const SizedBox(height: 8),
                    _buildDetailRow(
                      'Enrollment',
                      '${widget.tier} Tier (${widget.educatorName})',
                    ),
                    if (_paymentLink != null) ...[
                      const SizedBox(height: 8),
                      _buildDetailRow('Reference No.', _paymentLink!.referenceNumber),
                    ],
                    const SizedBox(height: 10),
                    const Divider(height: 1),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Total Due',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.black54,
                          ),
                        ),
                        Text(
                          '₱${widget.amount.toStringAsFixed(2)}',
                          style: GoogleFonts.outfit(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: const Color(0xFF1E88E5),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Actions
              if (_isProcessing)
                const CircularProgressIndicator(color: Color(0xFF1E88E5))
              else
                Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      height: 46,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          _handleSuccess(
                            referenceNumber: _paymentLink?.referenceNumber ??
                                'PM-${DateTime.now().millisecondsSinceEpoch}',
                            paymentMethod: 'PayMongo QR PH',
                            linkId: _paymentLink?.id,
                          );
                        },
                        icon: const Icon(Icons.check_circle_rounded, size: 18),
                        label: Text(
                          'I Have Completed Payment',
                          style: GoogleFonts.outfit(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF81B655),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, null),
                          child: Text(
                            'Cancel',
                            style: GoogleFonts.inter(
                              color: Colors.red.shade600,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        TextButton.icon(
                          onPressed: _simulateSuccess,
                          icon: const Icon(Icons.flash_on_rounded, size: 15),
                          label: Text(
                            'Simulate Payment (Test)',
                            style: GoogleFonts.outfit(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF1E88E5),
                            ),
                          ),
                        ),
                      ],
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
        Text(
          label,
          style: GoogleFonts.inter(color: Colors.black54, fontSize: 13),
        ),
        Flexible(
          child: Text(
            val,
            style: GoogleFonts.inter(
              color: const Color(0xFF0F172A),
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
            textAlign: TextAlign.right,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
