import 'package:flutter/material.dart';

class BookCard extends StatelessWidget {
  final String title;
  final String author;
  final String status;
  final VoidCallback? onPressed;

  const BookCard({
    super.key,
    required this.title,
    required this.author,
    required this.status,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final bool isAvailable = status == "Available";

    return Card(
      color: isAvailable ? const Color.fromARGB(255, 162, 160, 110) : Colors.red[300],
      child: ListTile(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(author),
        trailing: isAvailable
            ? ElevatedButton(
                onPressed: onPressed,
                child: const Text("Booking"),
              )
            : null,
      ),
    );
  }
}
