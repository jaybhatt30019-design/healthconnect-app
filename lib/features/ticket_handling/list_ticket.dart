


import 'package:Vitanex/features/ticket_handling/create_ticket_page.dart';
import 'package:Vitanex/theme/app_design_system.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class TicketListPage extends StatelessWidget {
  const TicketListPage({super.key});

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'resolved':
        return const Color(0xFF2E7D32); // Deep Green
      case 'in progress':
        return const Color(0xFFEF6C00); // Amber Orange
      default:
        return const Color(0xFFC62828); // Muted Crimson Red
    }
  }

  Color _getStatusBg(String status) {
    switch (status.toLowerCase()) {
      case 'resolved':
        return const Color(0xFFE8F5E9);
      case 'in progress':
        return const Color(0xFFFFF3E0);
      default:
        return const Color(0xFFFFEBEE);
    }
  }

  void _deleteTicket(BuildContext context, String ticketId) async {


    showDialog(
      context: context,
      builder:(BuildContext context) {
            return AlertDialog(
              title: Text("Delete Ticket"),
              content: Text("Are you sure want to delete the ticket?"),
              actions: [
                TextButton(onPressed: () 
                
                async {

    Navigator.pop(context);

                }, child: Text("No")),
                 TextButton(onPressed: () 
                
                async {
try {


      await FirebaseFirestore.instance.collection('tickets').doc(ticketId).delete();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: const Text('Ticket deleted successfully'), backgroundColor: AppColors.primary),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red[800]),
      );
    }

    Navigator.pop(context);

                }, child: Text("Yes")),
              ],
            );
      }
    );
    
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(

      // floatingActionButton: FloatingActionButton(onPressed: 
      // (){
      //   Navigator.push(context, MaterialPageRoute(builder: (context) => CreateTicketPage()));
      // }),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: AppColors.gradient
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
                    Text('Support Tickets', style: AppTextStyles.heading.copyWith(fontSize: 22)),
                    const Spacer(),
                    IconButton(
                      icon:  Icon(Icons.add_circle_outline_rounded, color: AppColors.primary, size: 28),
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const CreateTicketPage()),
                      ),
                    )
                  ],
                ),
              ),

              // --- TICKETS STREAM LIST ---
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('tickets')
                      .where('uid', isEqualTo: FirebaseAuth.instance.currentUser!.uid)
                      .orderBy('createdAt', descending: true)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Center(child: Text('Something went wrong', style: AppTextStyles.body));
                    }
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
                    }
                    if (snapshot.data == null || snapshot.data!.docs.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.confirmation_number_outlined, size: 64, color: AppColors.hint),
                            const SizedBox(height: AppSpacing.sm),
                            Text('No complaint tickets raised yet.', style: AppTextStyles.body),
                          ],
                        ),
                      );
                    }

                    return ListView.separated(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      itemCount: snapshot.data!.docs.length,
                      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
                      itemBuilder: (context, index) {
                        final doc = snapshot.data!.docs[index];
                        final data = doc.data() as Map<String, dynamic>;
                        final String ticketId = doc.id;
                        final String title = data['title'] ?? 'No Title';
                        final String description = data['description'] ?? '';
                        final String category = data['category'] ?? 'General';
                        final String status = data['status'] ?? 'Pending';
                        final String responseText = data['response'] ?? '';

                        return Container(
                          padding: const EdgeInsets.all(AppSpacing.sm),
                          decoration: BoxDecoration(
                            color: AppColors.card,
                            borderRadius: BorderRadius.circular(AppRadius.md),
                            boxShadow: [AppShadows.light],
                            border: Border.all(color: AppColors.primary.withOpacity(0.4)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(category, style: AppTextStyles.small.copyWith(color: AppColors.primary, fontWeight: FontWeight.bold)),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: _getStatusBg(status),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      status,
                                      style: AppTextStyles.small.copyWith(
                                        color: _getStatusColor(status),
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: AppSpacing.xs),
                              Text(title, style: AppTextStyles.body.copyWith(fontSize: 16)),
                              const SizedBox(height: 4),
                              Text(description, style: AppTextStyles.subtitle),
                              
                              // Admin Response Display Block (Shows up if response is available)
                              if (responseText.isNotEmpty) ...[
                                const SizedBox(height: AppSpacing.sm),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color:  Color(0xFFE6F4F1).withOpacity(0.5),
                                    borderRadius: BorderRadius.circular(AppRadius.sm),
                                    border: Border.all(color: AppColors.primary, width: 0.5),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Support Response:', style: AppTextStyles.body.copyWith(fontSize: 13, fontWeight: FontWeight.bold)),
                                      const SizedBox(height: 2),
                                      Text(responseText, style: AppTextStyles.subtitle.copyWith(fontStyle: FontStyle.italic)),
                                    ],
                                  ),
                                ),
                              ],
                              
                              const Divider(height: AppSpacing.lg, color: AppColors.primary),
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton.icon(
                                  onPressed: () => _deleteTicket(context, ticketId),
                                  icon: const Icon(Icons.delete_outline_rounded, color: Colors.red, size: 18),
                                  label: Text('Delete Ticket', style: AppTextStyles.small.copyWith(color: Colors.red)),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}