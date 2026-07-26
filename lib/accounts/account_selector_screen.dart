import 'package:flutter/material.dart';
import 'accounts_repository.dart';
import 'current_account.dart';

class AccountSelectorScreen extends StatelessWidget {
  const AccountSelectorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final accounts = AccountsRepository.accounts;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Choisir un compte'),
      ),
      body: ListView.builder(
        itemCount: accounts.length,
        itemBuilder: (context, index) {
          final account = accounts[index];
          return ListTile(
            title: Text(account.name),
            trailing: account.id == CurrentAccount.active.id
                ? const Icon(Icons.check)
                : null,
            onTap: () {
              CurrentAccount.active = account;
              Navigator.pop(context);
            },
          );
        },
      ),
    );
  }
}
