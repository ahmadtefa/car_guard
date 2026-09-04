import 'package:flutter/material.dart';

import '../../../core/constants/app_text_styles.dart';

/// Initial dashboard home page for the application.
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Car Guard',
              style: AppTextStyles.heading.copyWith(
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Flutter Project Ready',
              style: AppTextStyles.body,
            ),
          ],
        ),
      ),
    );
  }
}
