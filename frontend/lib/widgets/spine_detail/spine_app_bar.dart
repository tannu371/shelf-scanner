import 'package:flutter/material.dart';

/// App bar widget for the BookSpineDetailScreen.
/// Displays a back button and "N Books Found" title.
class SpineAppBar extends StatelessWidget {
  final int total;
  const SpineAppBar({super.key, required this.total});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded),
            onPressed: () => Navigator.of(context).pop(),
          ),
          const SizedBox(width: 4),
          Text(
            total == 1 ? 'Book Found' : '$total Books Found',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
