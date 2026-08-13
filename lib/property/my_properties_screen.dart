import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'seller_listings_management_view.dart';

class MyPropertiesScreen extends StatelessWidget {
  const MyPropertiesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('Please login to view your properties')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('My Listings')),
      body: SellerListingsManagementView(userId: user.uid),
    );
  }
}
