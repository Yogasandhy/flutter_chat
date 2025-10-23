import 'package:flutter/material.dart';

class ReactionStack extends StatelessWidget {
  const ReactionStack({
    super.key,
    required this.reactions,
  });

  final List<String> reactions;

  @override
  Widget build(BuildContext context) {
    if (reactions.isEmpty) return const SizedBox.shrink();

    // show up to 4 reactions
    final displayed = reactions.take(4).toList();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 4,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: displayed
            .map((r) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2.0),
                  child: Text(
                    r,
                    style: const TextStyle(fontSize: 14),
                  ),
                ))
            .toList(),
      ),
    );
  }
}
