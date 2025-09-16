// lib/admin/punch_card_management_page.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/punch_card_model.dart';

class PunchCardManagementPage extends StatefulWidget {
  const PunchCardManagementPage({super.key});

  @override
  State<PunchCardManagementPage> createState() =>
      _PunchCardManagementPageState();
}

class _PunchCardManagementPageState extends State<PunchCardManagementPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  void _showCampaignDialog({PunchCardCampaign? campaign}) {
    final isNew = campaign == null;
    final nameController = TextEditingController(text: campaign?.name);
    final descController = TextEditingController(text: campaign?.description);
    final goalController = TextEditingController(
      text: campaign?.goal.toString(),
    );
    final rewardController = TextEditingController(
      text: campaign?.rewardDescription,
    );
    final categoriesController = TextEditingController(
      text: campaign?.applicableCategories.join(', '),
    );
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(isNew ? 'Create Punch Card' : 'Edit Punch Card'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Campaign Name (e.g., Coffee Lovers)',
                    ),
                  ),
                  TextFormField(
                    controller: descController,
                    decoration: const InputDecoration(labelText: 'Description'),
                  ),
                  TextFormField(
                    controller: goalController,
                    decoration: const InputDecoration(
                      labelText: 'Goal (e.g., 10)',
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  TextFormField(
                    controller: rewardController,
                    decoration: const InputDecoration(
                      labelText: 'Reward (e.g., Free Coffee)',
                    ),
                  ),
                  TextFormField(
                    controller: categoriesController,
                    decoration: const InputDecoration(
                      labelText: 'Applicable Categories (comma separated)',
                      hintText: 'hot_drinks,soft_drinks',
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  final data = {
                    'name': nameController.text,
                    'description': descController.text,
                    'goal': int.tryParse(goalController.text) ?? 10,
                    'rewardDescription': rewardController.text,
                    'applicableCategories': categoriesController.text
                        .split(',')
                        .map((e) => e.trim())
                        .toList(),
                  };
                  if (isNew) {
                    data['isActive'] = false;
                    _firestore.collection('punch_card_campaigns').add(data);
                  } else {
                    _firestore
                        .collection('punch_card_campaigns')
                        .doc(campaign!.id)
                        .update(data);
                  }
                  Navigator.of(context).pop();
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Punch Card Campaigns')),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('punch_card_campaigns')
            .orderBy('name')
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData)
            return const Center(child: CircularProgressIndicator());
          if (snapshot.data!.docs.isEmpty)
            return const Center(child: Text('No campaigns found.'));

          final campaigns = snapshot.data!.docs
              .map((doc) => PunchCardCampaign.fromFirestore(doc))
              .toList();

          return ListView.builder(
            itemCount: campaigns.length,
            itemBuilder: (context, index) {
              final campaign = campaigns[index];
              return ListTile(
                title: Text(campaign.name),
                subtitle: Text(
                  'Goal: ${campaign.goal} -> ${campaign.rewardDescription}',
                ),
                trailing: Switch(
                  value: campaign.isActive,
                  onChanged: (value) {
                    _firestore
                        .collection('punch_card_campaigns')
                        .doc(campaign.id)
                        .update({'isActive': value});
                  },
                ),
                onTap: () => _showCampaignDialog(campaign: campaign),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showCampaignDialog,
        child: const Icon(Icons.add),
      ),
    );
  }
}
