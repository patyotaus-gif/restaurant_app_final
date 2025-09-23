// lib/widgets/customer_header_widget.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../cart_provider.dart';
import '../customer_lookup_page.dart';
import '../models/punch_card_model.dart';
import '../models/customer_model.dart'; // Make sure this is imported

class CustomerHeaderWidget extends StatelessWidget {
  const CustomerHeaderWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final cart = Provider.of<CartProvider>(context);

    if (cart.customer == null) {
      // Default view when no customer is selected
      return ListTile(
        leading: const Icon(Icons.person_add_alt_1),
        title: const Text('Add Customer'),
        subtitle: const Text('To earn loyalty points'),
        tileColor: Colors.blue.shade50,
        onTap: () async {
          final selectedCustomer = await Navigator.of(context)
              .push<DocumentSnapshot>(
                MaterialPageRoute(builder: (ctx) => const CustomerLookupPage()),
              );
          if (selectedCustomer != null) {
            cart.setCustomer(selectedCustomer);
          }
        },
      );
    } else {
      // View when a customer is selected
      return Column(
        children: [
          // Birthday promotion takes priority
          if (cart.isCustomerBirthdayMonth && cart.discountType == 'none')
            _buildBirthdayBanner(context, cart)
          else
            _buildDefaultCustomerBanner(context, cart),

          // --- This is the new Punch Card section ---
          _buildPunchCardSection(context, cart),
        ],
      );
    }
  }

  Widget _buildDefaultCustomerBanner(BuildContext context, CartProvider cart) {
    return ListTile(
      leading: const Icon(Icons.person, color: Colors.indigo),
      title: Text(
        cart.customer!.name,
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      subtitle: Text(
        'Points: ${cart.customer!.loyaltyPoints} • Credit: ${cart.customer!.storeCreditBalance.toStringAsFixed(2)}',
      ),
      tileColor: Colors.green.shade50,
      trailing: IconButton(
        icon: const Icon(Icons.close),
        tooltip: 'Remove Customer',
        onPressed: () {
          cart.setCustomer(null);
        },
      ),
    );
  }

  Widget _buildBirthdayBanner(BuildContext context, CartProvider cart) {
    return ListTile(
      leading: const Icon(Icons.cake, color: Colors.pink),
      title: Text(
        cart.customer!.name,
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      subtitle: const Text('It\'s their birthday month!'),
      tileColor: Colors.pink.shade50,
      trailing: ElevatedButton(
        onPressed: () => cart.applyBirthdayDiscount(),
        child: const Text('Apply Promo'),
      ),
    );
  }

  // --- PASTE THE REFINED WIDGET HERE ---
  Widget _buildPunchCardSection(BuildContext context, CartProvider cart) {
    // Get the punch cards the customer is part of
    final customerPunchCards = cart.customer!.punchCards;

    // If the customer isn't part of any campaigns, show nothing
    if (customerPunchCards.isEmpty) {
      return const SizedBox.shrink();
    }

    final cardEntries = customerPunchCards.entries.toList();

    return Container(
      color: Colors.grey.shade100,
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0),
            child: Text(
              'Punch Card Progress',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 4),
          ...cardEntries.map((entry) {
            final campaignId = entry.key;
            final progress = entry.value;

            // Each tile will fetch its own campaign details
            return _PunchCardTile(
              campaignId: campaignId,
              progress: progress,
              cart: cart, // Pass the cart provider
            );
          }).toList(),
        ],
      ),
    );
  }
} // <--- End of CustomerHeaderWidget class

// --- PASTE THIS NEW HELPER WIDGET AT THE END OF THE FILE ---
class _PunchCardTile extends StatelessWidget {
  final String campaignId;
  final int progress;
  final CartProvider cart;

  const _PunchCardTile({
    required this.campaignId,
    required this.progress,
    required this.cart,
  });

  // Use a Future to fetch campaign details once
  Future<PunchCardCampaign?> _fetchCampaignDetails() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('punch_card_campaigns')
          .doc(campaignId)
          .get();
      if (doc.exists) {
        return PunchCardCampaign.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<PunchCardCampaign?>(
      future: _fetchCampaignDetails(),
      builder: (context, snapshot) {
        // While loading...
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const ListTile(dense: true, title: Text('Loading...'));
        }

        // If campaign not found or there's an error
        final campaign = snapshot.data;
        if (campaign == null) {
          return const SizedBox.shrink(); // Don't show anything
        }

        final bool isGoalReached = progress >= campaign.goal;

        return ListTile(
          dense: true,
          leading: Icon(
            Icons.card_giftcard,
            color: isGoalReached ? Colors.orange.shade700 : Colors.brown,
          ),
          title: Text(
            campaign.name,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: Text('Progress: $progress / ${campaign.goal}'),
          trailing: isGoalReached
              ? ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                  onPressed: () async {
                    // Call the redeem function you already wrote in CartProvider!
                    final result = await cart.redeemPunchCardReward(campaign);
                    if (context.mounted) {
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(SnackBar(content: Text(result)));
                    }
                  },
                  child: Text(campaign.rewardDescription),
                )
              : null,
        );
      },
    );
  }
}
