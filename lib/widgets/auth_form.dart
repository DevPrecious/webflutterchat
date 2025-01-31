import 'package:flutter/material.dart';

class AuthForm extends StatelessWidget {
  final String title;
  final String buttonText;
  final bool isLoading;
  final String? error;
  final List<Widget> fields;
  final VoidCallback onSubmit;
  final Widget? bottomWidget;

  const AuthForm({
    Key? key,
    required this.title,
    required this.buttonText,
    required this.isLoading,
    required this.error,
    required this.fields,
    required this.onSubmit,
    this.bottomWidget,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 768;
    final maxWidth = isMobile ? double.infinity : 400.0;

    return Center(
      child: SingleChildScrollView(
        child: Container(
          width: maxWidth,
          margin: EdgeInsets.symmetric(
            horizontal: isMobile ? 20 : 0,
            vertical: 20,
          ),
          child: Card(
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Title
                  Text(
                    title,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  
                  // Form fields
                  ...fields.expand((field) => [field, const SizedBox(height: 16)]),
                  
                  // Error message
                  if (error != null && error!.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.errorContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Submit button
                  SizedBox(
                    height: 50,
                    child: ElevatedButton(
                      onPressed: isLoading ? null : onSubmit,
                      style: ElevatedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(25),
                        ),
                      ),
                      child: isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                              ),
                            )
                          : Text(buttonText),
                    ),
                  ),

                  // Bottom widget (if any)
                  if (bottomWidget != null) ...[
                    const SizedBox(height: 24),
                    bottomWidget!,
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
