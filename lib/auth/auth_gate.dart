/*
AUTH GATE - This will continuosly lsiten for auth state changes.

unauthenticated -> show login screen
authenticated -> show home screen

*/

import 'package:chowflow/screens/home.dart';
import 'package:chowflow/screens/login.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      // Listen to auth state changes
      stream: Supabase.instance.client.auth.onAuthStateChange,
      //Build UI based on auth state
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        //check if there is a valid session currently
        final session = snapshot.hasData ? snapshot.data!.session : null;
        if (session == null) {
          return const LoginScreen();
        } else {
          return const HomeScreen();
        }
      },
    );
  }
}
