import 'package:Vitanex/theme/app_design_system.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';



class CreateTicketPage extends StatefulWidget {
  const CreateTicketPage({super.key});

  @override
  State<CreateTicketPage> createState() => _CreateTicketPageState();
}

class _CreateTicketPageState extends State<CreateTicketPage> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descController = TextEditingController();
  
  String _selectedCategory = 'App Bug';
  bool _isLoading = false;

  final List<String> _categories = ['App Bug', 'Account Issue', 'Payment Failure', 'Emergency Feature Feedback', 'Other'];

  void _submitTicket() async {
    final String title = _titleController.text.trim();
    final String desc = _descController.text.trim();

    if (title.isEmpty || desc.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all the fields'), backgroundColor: Colors.redAccent),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final docRef = FirebaseFirestore.instance.collection('tickets').doc();
      await docRef.set({
        "uid":FirebaseAuth.instance.currentUser!.uid,
        'id': docRef.id,
        'title': title,
        'description': desc,
        'category': _selectedCategory,
        'status': 'Pending', // Default operational lifecycle tag
        'response': '',      // Empty until admin interacts
        'createdAt': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ticket submitted successfully!'), backgroundColor: AppColors.primary),
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Submission failed: $e'), backgroundColor: Colors.red[800]),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration:  BoxDecoration(
          gradient: AppColors.gradient,
        ),
        child: SafeArea(
          child: Column(
            children: [
              // --- APP BAR ---
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
                child: Row(
                  children: [
                    AppBackButton(onTap: () => Navigator.pop(context)),
                    const SizedBox(width: AppSpacing.sm),
                    Text('Raise a Complaint', style: AppTextStyles.heading.copyWith(fontSize: 22)),
                  ],
                ),
              ),

              // --- FORM COMPLIANCE LAYOUT ---
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Issue Category', style: AppTextStyles.subtitle.copyWith(fontSize: 16)),
                      const SizedBox(height: AppSpacing.xs),
                      
                      // Custom Styled Category Selection Dropdown Button Frame
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: AppColors.card,
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                          border: Border.all(color: AppColors.primary),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _selectedCategory,
                            isExpanded: true,
                            icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.primary),
                            items: _categories.map((String val) {
                              return DropdownMenuItem<String>(
                                value: val,
                                child: Text(val, style: AppTextStyles.body.copyWith(fontWeight: FontWeight.normal)),
                              );
                            }).toList(),
                            onChanged: (newVal) {
                              if (newVal != null) setState(() => _selectedCategory = newVal);
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),

                      Text('Ticket Title', style: AppTextStyles.body.copyWith(fontSize: 16)),
                      const SizedBox(height: AppSpacing.xs),
                      // Reuses your precise AppInputField specification style format mapping
                      TextField(
                        controller: _titleController,
                        style: AppTextStyles.body,
                        decoration: _inputDecoration(hintText: 'Brief summary of the problem'),
                      ),
                      const SizedBox(height: AppSpacing.md),

                      Text('Detailed Explanation', style: AppTextStyles.body.copyWith(fontSize: 16)),
                      const SizedBox(height: AppSpacing.xs),
                      TextField(
                        controller: _descController,
                        maxLines: 5,
                        style: AppTextStyles.body,
                        decoration: _inputDecoration(hintText: 'Please describe the steps to reproduce or explain what happened...'),
                      ),
                      const SizedBox(height: AppSpacing.xl),

                      // Submit Button Action Trigger
                      _isLoading
                          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                          : ElevatedButton(
                              onPressed: _submitTicket,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                minimumSize: const Size(double.infinity, 56),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.sm)),
                                elevation: 2,
                              ),
                              child: Text('Submit Ticket', style:  GoogleFonts.poppins(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                  color: Color(0xFFFFFFFF),
                                )),
                            ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({required String hintText}) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: GoogleFonts.poppins(fontSize: 14, color: const Color(0xFFC5D0D5), fontWeight: FontWeight.w400),
      filled: true,
      fillColor: AppColors.card,
      contentPadding: const EdgeInsets.all(16),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.sm), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.sm), borderSide:  BorderSide(color: AppColors.primary)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.sm), borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
    );
  }
}