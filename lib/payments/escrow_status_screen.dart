// import 'package:flutter/material.dart';
// import 'escrow_service.dart';

// class EscrowStatusScreen extends StatelessWidget {
//   final String dealId;

//   const EscrowStatusScreen({super.key, required this.dealId});

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(title: const Text("Escrow Status")),
//       body: StreamBuilder(
//         stream: EscrowService().forDeal(dealId),
//         builder: (context, snapshot) {
//           if (!snapshot.hasData) {
//             return const CircularProgressIndicator();
//           }

//           final docs = snapshot.data!.docs;
//           if (docs.isEmpty) {
//             return const Text("No escrow record");
//           }

//           final data = docs.first.data();

//           return ListTile(
//             title: Text("₹${data['amount']}"),
//             subtitle: Text("Status: ${data['status']}"),
//           );
//         },
//       ),
//     );
//   }
// }
