import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:keepassux/bloc/entries/keepass_bloc.dart';
import 'package:keepassux/bloc/entries/keepass_states.dart';
import 'package:keepassux/ui/pages/main_tabs_page.dart';
import 'package:keepassux/ui/pages/start_page.dart';
import 'package:keepassux/services/saf_service.dart';
import 'package:keepassux/ui/theme/theme.dart';
import 'package:keepassux/ui/widgets/loading_overlay.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../bloc/entries/keepass_events.dart';

class CreateDatabasePage extends StatefulWidget {
  const CreateDatabasePage({super.key});

  @override
  State<CreateDatabasePage> createState() => _CreateDatabasePageState();
}

class _CreateDatabasePageState extends State<CreateDatabasePage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final SafService _safService = SafService();

  TextEditingController nameController = TextEditingController();
  TextEditingController passwordController = TextEditingController();

  bool obscurePassword = false;

  SharedPreferences? preferences;

  @override
  void initState() {
    SharedPreferences.getInstance().then((preferences) {
      this.preferences = preferences;
    });
    super.initState();
  }

  @override
  void dispose() {
    nameController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<KeePassBloc, KeePassState>(
      listener: (context, state) {
        if (state is KeePassCreated) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const MainTabsPage()),
          );
        }
        if (state is KeePassError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              duration: Duration(seconds: 2),
            ),
          );
        }
      },
      builder: (context, state) {
        return Stack(
          fit: StackFit.expand,
          children: [
            _page(),
            LoadingOverlay(isLoading: state is KeePassLoading),
          ],
        );
      },
    );
  }

  Widget _page() {
    return Scaffold(
      body: SafeArea(
        child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(),
          Center(
            child: Text(
              tr("create_database_page.title"),
              style: TextStyle(fontSize: 32),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Container(
              decoration: cardDecoration(context),
              child: Form(
                key: _formKey,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: nameController,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return tr("form_error.required");
                          }
                          return null;
                        },
                        decoration: InputDecoration(
                          labelText: tr("create_database_page.name_hint"),
                        ),
                      ),
                      SizedBox(height: 16),
                      TextFormField(
                        controller: passwordController,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return tr("form_error.required");
                          }
                          return null;
                        },
                        obscureText: obscurePassword,
                        decoration: InputDecoration(
                          labelText: tr("create_database_page.password_hint"),
                          suffixIcon: IconButton(
                            icon: Icon(
                              obscurePassword == true
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                            ),
                            onPressed: () {
                              setState(() {
                                obscurePassword = !obscurePassword;
                              });
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                InkWell(
                  onTap: () async {
                    if (_formKey.currentState!.validate()) {
                      if (preferences == null) {
                        return;
                      }
                      final safUri = await _safService.createDocument(
                        "${nameController.text}.kdbx",
                      );
                      if (safUri == null) {
                        return;
                      }
                      if (!mounted) return;
                      context.read<KeePassBloc>().add(
                        CreateDatabase(
                          uri: safUri,
                          password: passwordController.text,
                        ),
                      );
                    }
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: Color(0xFF374151),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Icon(Icons.call_received),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Text(
                              tr("create_database_page.create_database"),
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 16),
                InkWell(
                  onTap: () async {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const StartPage(),
                      ),
                    );
                  },
                  child: InkWell(
                    child: Text(tr("create_database_page.open_database")),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      ),
    );
  }
}
