import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as ll;

import '../../services/admin_service.dart';
import '../../services/auth_service.dart';

class AdminSettingsScreen extends StatefulWidget {
  const AdminSettingsScreen({super.key});

  @override
  State<AdminSettingsScreen> createState() => _AdminSettingsScreenState();
}

class _AdminSettingsScreenState extends State<AdminSettingsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final AdminService _adminService = AdminService();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Check if user is admin
    final authService = context.watch<AuthService>();
    if (authService.currentUser?.role != 'admin') {
      return Scaffold(
        appBar: AppBar(title: Text('admin_settings'.tr())),
        body: Center(child: Text('access_denied'.tr())),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('admin_settings'.tr()),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: 'users'.tr()),
            Tab(text: 'rhu'.tr()),
            Tab(text: 'facilities'.tr()),
            Tab(text: 'barangays'.tr()),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _UserManagementTab(adminService: _adminService),
          _RHUManagementTab(adminService: _adminService),
          _FacilityManagementTab(adminService: _adminService),
          _BarangayManagementTab(adminService: _adminService),
        ],
      ),
    );
  }
}

// ============================================
// USER MANAGEMENT TAB
// ============================================

class _UserManagementTab extends StatefulWidget {
  final AdminService adminService;

  const _UserManagementTab({required this.adminService});

  @override
  State<_UserManagementTab> createState() => _UserManagementTabState();
}

class _UserManagementTabState extends State<_UserManagementTab> {
  late Future<List<Map<String, dynamic>>> _usersFuture;

  @override
  void initState() {
    super.initState();
    _refreshUsers();
  }

  void _refreshUsers() {
    _usersFuture = widget.adminService.getUsers();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: ElevatedButton.icon(
            onPressed: () => _showAddUserDialog(context),
            icon: const Icon(Icons.add),
            label: Text('add_user'.tr()),
          ),
        ),
        Expanded(
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: _usersFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return Center(
                  child: Text(
                    '${'error_loading_users'.tr()}: ${snapshot.error}',
                  ),
                );
              }

              final users = snapshot.data ?? [];
              if (users.isEmpty) {
                return Center(child: Text('no_users_found'.tr()));
              }

              return ListView.builder(
                itemCount: users.length,
                itemBuilder: (context, index) {
                  final user = users[index];
                  return _UserListTile(
                    user: user,
                    adminService: widget.adminService,
                    onUpdate: _refreshUsers,
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  void _showAddUserDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => _AddUserDialog(
        adminService: widget.adminService,
        onUserAdded: _refreshUsers,
      ),
    );
  }
}

class _UserListTile extends StatelessWidget {
  final Map<String, dynamic> user;
  final AdminService adminService;
  final VoidCallback onUpdate;

  const _UserListTile({
    required this.user,
    required this.adminService,
    required this.onUpdate,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: ListTile(
        title: Text(user['name'] ?? 'Unknown'),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Email: ${user['email']}'),
            Text(
              'Role: ${user['roles']?['display_name'] ?? user['role'] ?? 'Unknown'}',
            ),
            if (user['active'] == false)
              const Text('Inactive', style: TextStyle(color: Colors.red)),
          ],
        ),
        trailing: PopupMenuButton(
          itemBuilder: (context) => [
            PopupMenuItem(
              child: Text('edit'.tr()),
              onTap: () => _showEditUserDialog(context),
            ),
            if (user['active'] == true)
              PopupMenuItem(
                child: Text('deactivate'.tr()),
                onTap: () => _deactivateUser(context),
              )
            else
              PopupMenuItem(
                child: Text('reactivate'.tr()),
                onTap: () => _reactivateUser(context),
              ),
          ],
        ),
      ),
    );
  }

  void _showEditUserDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => _EditUserDialog(
        user: user,
        adminService: adminService,
        onUserUpdated: onUpdate,
      ),
    );
  }

  void _deactivateUser(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('confirm_deactivate'.tr()),
        content: Text('deactivate_user_confirm'.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('cancel'.tr()),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('deactivate'.tr()),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await adminService.deactivateUser(user['id']);
      if (success) {
        onUpdate();
        if (context.mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('user_deactivated'.tr())));
        }
      }
    }
  }

  void _reactivateUser(BuildContext context) async {
    final success = await adminService.reactivateUser(user['id']);
    if (success) {
      onUpdate();
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('user_reactivated'.tr())));
      }
    }
  }
}

class _EditUserDialog extends StatefulWidget {
  final Map<String, dynamic> user;
  final AdminService adminService;
  final VoidCallback onUserUpdated;

  const _EditUserDialog({
    required this.user,
    required this.adminService,
    required this.onUserUpdated,
  });

  @override
  State<_EditUserDialog> createState() => _EditUserDialogState();
}

class _EditUserDialogState extends State<_EditUserDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  String _selectedRole = 'rhu_staff';
  String? _selectedRHUId;
  String? _selectedFacilityId;
  String? _selectedBarangayId;
  bool _isLoading = false;
  List<Map<String, dynamic>> _availableRoles = [];

  String _normalizeRoleId(String? role) {
    if (role == null || role.isEmpty || role == 'pending') {
      return 'rhu_staff';
    }

    return role;
  }

  Map<String, dynamic>? get _selectedRoleDefinition {
    for (final role in _availableRoles) {
      if (role['id']?.toString() == _selectedRole) return role;
    }
    return null;
  }

  bool get _requiresRhu => _selectedRoleDefinition?['requires_rhu'] == true;
  bool get _requiresFacility =>
      _selectedRoleDefinition?['requires_facility'] == true;
  bool get _requiresBarangay =>
      _selectedRoleDefinition?['requires_barangay'] == true;

  late Future<List<Map<String, dynamic>>> _rhusFuture;
  late Future<List<Map<String, dynamic>>> _facilitiesFuture;
  late Future<List<Map<String, dynamic>>> _barangaysFuture;
  late Future<List<Map<String, dynamic>>> _rolesFuture;

  @override
  void initState() {
    super.initState();
    _nameController.text = widget.user['name'] ?? '';
    _emailController.text = widget.user['email'] ?? '';
    _selectedRole = _normalizeRoleId(widget.user['role']?.toString());
    _selectedRHUId = widget.user['rhu_id']?.toString();
    _selectedFacilityId = widget.user['facility_id']?.toString();
    _selectedBarangayId = widget.user['barangay_id']?.toString();

    _rhusFuture = widget.adminService.getRHUs();
    _facilitiesFuture = Future.value([]);
    _barangaysFuture = Future.value([]);
    _rolesFuture = widget.adminService.getRoles();

    _rolesFuture.then((roles) {
      if (!mounted) return;
      setState(() {
        _availableRoles = roles
            .where((role) => role['is_assignable'] == true)
            .toList();
        if (!_availableRoles.any(
          (role) => role['id']?.toString() == _selectedRole,
        )) {
          final defaultRole = _availableRoles.firstWhere(
            (role) => role['id'] == 'rhu_staff',
            orElse: () => _availableRoles.isNotEmpty
                ? _availableRoles.first
                : <String, dynamic>{},
          );
          _selectedRole = defaultRole['id']?.toString() ?? '';
        }
        _loadDependentDropdowns();
      });
    });
  }

  void _loadDependentDropdowns() {
    _facilitiesFuture = _requiresFacility && _selectedRHUId != null
        ? widget.adminService.getFacilities(rhuId: _selectedRHUId)
        : Future.value([]);
    _barangaysFuture = _requiresBarangay && _selectedRHUId != null
        ? widget.adminService.getBarangays(rhuId: _selectedRHUId)
        : Future.value([]);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('edit_user'.tr()),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(labelText: 'name'.tr()),
                validator: (value) {
                  if (value?.isEmpty ?? true) return 'name_required'.tr();
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _emailController,
                decoration: InputDecoration(labelText: 'email'.tr()),
                keyboardType: TextInputType.emailAddress,
                readOnly: true,
                validator: (value) {
                  if (value?.isEmpty ?? true) return 'email_required'.tr();
                  if (!value!.contains('@')) return 'invalid_email'.tr();
                  return null;
                },
              ),
              const SizedBox(height: 12),
              FutureBuilder<List<Map<String, dynamic>>>(
                future: _rolesFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const LinearProgressIndicator();
                  }
                  final safeRoles = _availableRoles;
                  if (snapshot.hasError || safeRoles.isEmpty) {
                    return Text(
                      'Could not load assignable roles from Supabase.',
                    );
                  }

                  return DropdownButtonFormField<String>(
                    initialValue:
                        safeRoles.any(
                          (role) => role['id']?.toString() == _selectedRole,
                        )
                        ? _selectedRole
                        : safeRoles.first['id']?.toString(),
                    decoration: InputDecoration(labelText: 'role'.tr()),
                    items: safeRoles
                        .map<DropdownMenuItem<String>>(
                          (role) => DropdownMenuItem<String>(
                            value: role['id']?.toString(),
                            child: Text(
                              role['display_name']?.toString() ??
                                  'Unknown role',
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedRole = value ?? 'rhu_staff';
                        _selectedFacilityId = null;
                        _selectedBarangayId = null;
                        _loadDependentDropdowns();
                      });
                    },
                  );
                },
              ),
              const SizedBox(height: 12),
              if (_requiresRhu)
                FutureBuilder<List<Map<String, dynamic>>>(
                  future: _rhusFuture,
                  builder: (context, snapshot) {
                    final rhus = snapshot.data ?? [];
                    return DropdownButtonFormField<String>(
                      initialValue: _selectedRHUId,
                      decoration: InputDecoration(labelText: 'select_rhu'.tr()),
                      items: rhus
                          .map<DropdownMenuItem<String>>(
                            (rhu) => DropdownMenuItem<String>(
                              value: rhu['id']?.toString(),
                              child: Text(rhu['name'] ?? 'Unknown RHU'),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedRHUId = value;
                          _selectedFacilityId = null;
                          _selectedBarangayId = null;
                          _loadDependentDropdowns();
                        });
                      },
                      validator: (value) {
                        if (_requiresRhu && (value?.isEmpty ?? true)) {
                          return 'rhu_required'.tr();
                        }
                        return null;
                      },
                    );
                  },
                ),
              if (_requiresFacility) ...[
                const SizedBox(height: 12),
                FutureBuilder<List<Map<String, dynamic>>>(
                  future: _facilitiesFuture,
                  builder: (context, snapshot) {
                    final facilities = snapshot.data ?? [];
                    return DropdownButtonFormField<String>(
                      initialValue: _selectedFacilityId,
                      decoration: InputDecoration(
                        labelText: 'select_facility'.tr(),
                      ),
                      items: facilities
                          .map(
                            (facility) => DropdownMenuItem<String>(
                              value: facility['id']?.toString(),
                              child: Text(facility['name'] ?? 'Unknown'),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        setState(() => _selectedFacilityId = value);
                      },
                      validator: (value) {
                        if (_requiresFacility && (value?.isEmpty ?? true)) {
                          return 'facility_required'.tr();
                        }
                        return null;
                      },
                    );
                  },
                ),
              ],
              if (_requiresBarangay) ...[
                const SizedBox(height: 12),
                FutureBuilder<List<Map<String, dynamic>>>(
                  future: _barangaysFuture,
                  builder: (context, snapshot) {
                    final barangays = snapshot.data ?? [];
                    return DropdownButtonFormField<String>(
                      initialValue: _selectedBarangayId,
                      decoration: InputDecoration(
                        labelText: 'select_barangay'.tr(),
                      ),
                      items: barangays
                          .map<DropdownMenuItem<String>>(
                            (barangay) => DropdownMenuItem<String>(
                              value: barangay['id']?.toString(),
                              child: Text(barangay['name'] ?? 'Unknown'),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        setState(() => _selectedBarangayId = value);
                      },
                      validator: (value) {
                        if (_requiresBarangay && (value?.isEmpty ?? true)) {
                          return 'barangay_required'.tr();
                        }
                        return null;
                      },
                    );
                  },
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('cancel'.tr()),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _handleUpdateUser,
          child: _isLoading
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text('update'.tr()),
        ),
      ],
    );
  }

  Future<void> _handleUpdateUser() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final role = _selectedRoleDefinition;
    if (role == null || role['is_assignable'] != true) {
      setState(() => _isLoading = false);
      return;
    }

    final updates = <String, dynamic>{
      'name': _nameController.text.trim(),
      'role': _selectedRole,
      'rhu_id': role['requires_rhu'] == true ? _selectedRHUId : null,
      'facility_id': role['requires_facility'] == true
          ? _selectedFacilityId
          : null,
      'barangay_id': role['requires_barangay'] == true
          ? _selectedBarangayId
          : null,
    };

    final success = await widget.adminService.updateUser(
      widget.user['id'].toString(),
      updates,
    );

    setState(() => _isLoading = false);

    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('user_updated_successfully'.tr())),
        );
        widget.onUserUpdated();
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('error_updating_user'.tr()),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

class _AddUserDialog extends StatefulWidget {
  final AdminService adminService;
  final VoidCallback onUserAdded;

  const _AddUserDialog({required this.adminService, required this.onUserAdded});

  @override
  State<_AddUserDialog> createState() => _AddUserDialogState();
}

class _AddUserDialogState extends State<_AddUserDialog> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _nameController = TextEditingController();
  String _selectedRole = 'rhu_staff';
  String? _selectedRHUId;
  String? _selectedFacilityId;
  String? _selectedBarangayId;
  bool _isLoading = false;

  late Future<List<Map<String, dynamic>>> _rhusFuture;
  late Future<List<Map<String, dynamic>>> _facilitiesFuture;
  late Future<List<Map<String, dynamic>>> _barangaysFuture;
  late Future<List<Map<String, dynamic>>> _rolesFuture;

  @override
  void initState() {
    super.initState();
    _rhusFuture = widget.adminService.getRHUs();
    _facilitiesFuture = Future.value([]);
    _barangaysFuture = Future.value([]);
    _rolesFuture = widget.adminService.getRoles();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('add_new_user'.tr()),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _emailController,
                decoration: InputDecoration(labelText: 'email'.tr()),
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value?.isEmpty ?? true) return 'email_required'.tr();
                  if (!value!.contains('@')) return 'invalid_email'.tr();
                  return null;
                },
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text('user_invitation_help'.tr()),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(labelText: 'name'.tr()),
                validator: (value) {
                  if (value?.isEmpty ?? true) return 'name_required'.tr();
                  return null;
                },
              ),
              const SizedBox(height: 12),
              FutureBuilder<List<Map<String, dynamic>>>(
                future: _rolesFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const LinearProgressIndicator();
                  }
                  if (snapshot.hasError || !snapshot.hasData) {
                    return Text(
                      'Could not load assignable roles from Supabase.',
                    );
                  }

                  final roles = (snapshot.data ?? [])
                      .where(
                        (role) =>
                            role['is_assignable'] == true &&
                            role['id']?.toString() != 'pending',
                      )
                      .toList();

                  if (roles.isEmpty) {
                    return const Text('No assignable roles are configured.');
                  }

                  final selectedRoleValue =
                      roles.any(
                        (role) => role['id']?.toString() == _selectedRole,
                      )
                      ? _selectedRole
                      : roles.first['id']?.toString();

                  return DropdownButtonFormField<String>(
                    initialValue: selectedRoleValue,
                    decoration: InputDecoration(labelText: 'role'.tr()),
                    items: roles
                        .map<DropdownMenuItem<String>>(
                          (role) => DropdownMenuItem<String>(
                            value: role['id']?.toString(),
                            child: Text(
                              role['display_name']?.toString() ?? 'Unknown',
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedRole = value ?? '';
                        _selectedFacilityId = null;
                        _selectedBarangayId = null;
                        if (value != null) {
                          final selectedRole = roles.firstWhere(
                            (r) => r['id'] == value,
                            orElse: () => {
                              'requires_facility': false,
                              'requires_barangay': false,
                            },
                          );
                          if (selectedRole['requires_facility'] == true &&
                              _selectedRHUId != null) {
                            _facilitiesFuture = widget.adminService
                                .getFacilities(rhuId: _selectedRHUId);
                          } else {
                            _facilitiesFuture = Future.value([]);
                          }
                          if (selectedRole['requires_barangay'] == true &&
                              _selectedRHUId != null) {
                            _barangaysFuture = widget.adminService.getBarangays(
                              rhuId: _selectedRHUId,
                            );
                          } else {
                            _barangaysFuture = Future.value([]);
                          }
                        }
                      });
                    },
                    validator: (value) =>
                        (value?.isEmpty ?? true) ? 'role_required'.tr() : null,
                  );
                },
              ),
              const SizedBox(height: 12),
              // Show RHU selection if required by role
              FutureBuilder<List<List<Map<String, dynamic>>>>(
                future: Future.wait([_rolesFuture, _rhusFuture]),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const SizedBox();
                  final roles = snapshot.data![0];
                  final rhus = snapshot.data![1];

                  final selectedRole = roles.firstWhere(
                    (r) => r['id'] == _selectedRole,
                    orElse: () => {},
                  );
                  final requiresRhu = selectedRole['requires_rhu'] == true;

                  if (!requiresRhu) return const SizedBox();

                  return DropdownButtonFormField<String>(
                    initialValue: _selectedRHUId,
                    decoration: InputDecoration(labelText: 'select_rhu'.tr()),
                    items: rhus
                        .map<DropdownMenuItem<String>>(
                          (rhu) => DropdownMenuItem<String>(
                            value: rhu['id']?.toString(),
                            child: Text(rhu['name'] ?? 'Unknown RHU'),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedRHUId = value;
                        _selectedFacilityId = null;
                        _selectedBarangayId = null;

                        // Update facility/barangay dropdowns based on role requirements
                        if (selectedRole['requires_facility'] == true &&
                            value != null) {
                          _facilitiesFuture = widget.adminService.getFacilities(
                            rhuId: value,
                          );
                        } else {
                          _facilitiesFuture = Future.value([]);
                        }
                        if (selectedRole['requires_barangay'] == true &&
                            value != null) {
                          _barangaysFuture = widget.adminService.getBarangays(
                            rhuId: value,
                          );
                        } else {
                          _barangaysFuture = Future.value([]);
                        }
                      });
                    },
                    validator: (value) {
                      if (requiresRhu && (value?.isEmpty ?? true)) {
                        return 'rhu_required'.tr();
                      }
                      return null;
                    },
                  );
                },
              ),
              FutureBuilder<List<Map<String, dynamic>>>(
                future: _rolesFuture,
                builder: (context, snapshot) {
                  final roles = snapshot.data ?? [];

                  final selectedRole = roles.firstWhere(
                    (r) => r['id'] == _selectedRole,
                    orElse: () => {},
                  );
                  final requiresFacility =
                      selectedRole['requires_facility'] == true;

                  if (!requiresFacility) return const SizedBox();

                  return Column(
                    children: [
                      const SizedBox(height: 12),
                      FutureBuilder<List<Map<String, dynamic>>>(
                        future: _facilitiesFuture,
                        builder: (context, snapshot) {
                          final facilities = snapshot.data ?? [];
                          return DropdownButtonFormField<String>(
                            initialValue: _selectedFacilityId,
                            decoration: InputDecoration(
                              labelText: 'select_facility'.tr(),
                            ),
                            items: facilities
                                .map(
                                  (facility) => DropdownMenuItem<String>(
                                    value: facility['id']?.toString(),
                                    child: Text(facility['name'] ?? 'Unknown'),
                                  ),
                                )
                                .toList(),
                            onChanged: (value) {
                              setState(() => _selectedFacilityId = value);
                            },
                            validator: (value) {
                              if (requiresFacility &&
                                  (value?.isEmpty ?? true)) {
                                return 'facility_required'.tr();
                              }
                              return null;
                            },
                          );
                        },
                      ),
                    ],
                  );
                },
              ),
              FutureBuilder<List<Map<String, dynamic>>>(
                future: _rolesFuture,
                builder: (context, snapshot) {
                  final roles = snapshot.data ?? [];

                  final selectedRole = roles.firstWhere(
                    (r) => r['id'] == _selectedRole,
                    orElse: () => {},
                  );
                  final requiresBarangay =
                      selectedRole['requires_barangay'] == true;

                  if (!requiresBarangay) return const SizedBox();

                  return Column(
                    children: [
                      const SizedBox(height: 12),
                      FutureBuilder<List<Map<String, dynamic>>>(
                        future: _barangaysFuture,
                        builder: (context, snapshot) {
                          final barangays = snapshot.data ?? [];
                          return DropdownButtonFormField<String>(
                            initialValue: _selectedBarangayId,
                            decoration: InputDecoration(
                              labelText: 'select_barangay'.tr(),
                            ),
                            items: barangays
                                .map<DropdownMenuItem<String>>(
                                  (barangay) => DropdownMenuItem<String>(
                                    value: barangay['id']?.toString(),
                                    child: Text(barangay['name'] ?? 'Unknown'),
                                  ),
                                )
                                .toList(),
                            onChanged: (value) {
                              setState(() => _selectedBarangayId = value);
                            },
                            validator: (value) {
                              if (requiresBarangay &&
                                  (value?.isEmpty ?? true)) {
                                return 'barangay_required'.tr();
                              }
                              return null;
                            },
                          );
                        },
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('cancel'.tr()),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _handleAddUser,
          child: _isLoading
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text('add'.tr()),
        ),
      ],
    );
  }

  Future<void> _handleAddUser() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final roles = await _rolesFuture;
    final selectedRole = roles.firstWhere(
      (role) =>
          role['id']?.toString() == _selectedRole &&
          role['is_assignable'] == true,
      orElse: () => <String, dynamic>{},
    );
    String? errorMessage;
    if (selectedRole.isEmpty) {
      errorMessage = 'Select a valid role from the configured role list.';
    } else if (selectedRole['requires_rhu'] == true &&
        (_selectedRHUId == null || _selectedRHUId!.isEmpty)) {
      errorMessage = 'RHU selection is required for this role';
    } else if (selectedRole['requires_facility'] == true &&
        (_selectedFacilityId == null || _selectedFacilityId!.isEmpty)) {
      errorMessage = 'Facility selection is required for this role';
    } else if (selectedRole['requires_barangay'] == true &&
        (_selectedBarangayId == null || _selectedBarangayId!.isEmpty)) {
      errorMessage = 'Barangay selection is required for this role';
    }

    if (errorMessage != null) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMessage), backgroundColor: Colors.red),
      );
      return;
    }

    final error = await widget.adminService.createUser(
      email: _emailController.text.trim(),
      name: _nameController.text.trim(),
      roleId: _selectedRole,
      rhuId: _selectedRHUId,
      facilityId: _selectedFacilityId,
      barangayId: _selectedBarangayId,
    );

    setState(() => _isLoading = false);

    if (mounted) {
      if (error == null) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('user_invitation_sent'.tr())));
        widget.onUserAdded();
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error), backgroundColor: Colors.red),
        );
      }
    }
  }
}

// ============================================
// RHU MANAGEMENT TAB
// ============================================

class _RHUManagementTab extends StatefulWidget {
  final AdminService adminService;

  const _RHUManagementTab({required this.adminService});

  @override
  State<_RHUManagementTab> createState() => _RHUManagementTabState();
}

class _RHUManagementTabState extends State<_RHUManagementTab> {
  late Future<List<Map<String, dynamic>>> _rhusFuture;

  @override
  void initState() {
    super.initState();
    _refreshRHUs();
  }

  void _refreshRHUs() {
    _rhusFuture = widget.adminService.getRHUs();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: ElevatedButton.icon(
            onPressed: () => _showAddRHUDialog(context),
            icon: const Icon(Icons.add),
            label: Text('add_rhu'.tr()),
          ),
        ),
        Expanded(
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: _rhusFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return Center(
                  child: Text('${'error'.tr()}: ${snapshot.error}'),
                );
              }

              final rhus = snapshot.data ?? [];
              if (rhus.isEmpty) {
                return Center(child: Text('no_rhus_found'.tr()));
              }

              return ListView.builder(
                itemCount: rhus.length,
                itemBuilder: (context, index) {
                  final rhu = rhus[index];
                  return Card(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    child: ListTile(
                      title: Text(rhu['name'] ?? 'Unknown'),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Region: ${rhu['region']}'),
                          Text('Contact: ${rhu['contact_number']}'),
                        ],
                      ),
                      trailing: PopupMenuButton(
                        itemBuilder: (context) => [
                          PopupMenuItem(
                            child: Text('edit'.tr()),
                            onTap: () => _showEditRHUDialog(context, rhu),
                          ),
                          PopupMenuItem(
                            child: Text('delete'.tr()),
                            onTap: () => _deleteRHU(context, rhu['id']),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  void _showAddRHUDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => _AddRHUDialog(
        adminService: widget.adminService,
        onRHUAdded: _refreshRHUs,
      ),
    );
  }

  void _showEditRHUDialog(BuildContext context, Map<String, dynamic> rhu) {
    showDialog(
      context: context,
      builder: (context) => _EditRHUDialog(
        rhu: rhu,
        adminService: widget.adminService,
        onRHUUpdated: _refreshRHUs,
      ),
    );
  }

  void _deleteRHU(BuildContext context, String rhuId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('confirm_delete'.tr()),
        content: Text('delete_rhu_confirm'.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('cancel'.tr()),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('delete'.tr()),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await widget.adminService.deleteRHU(rhuId);
      if (success) {
        _refreshRHUs();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('rhu_deleted_successfully'.tr())),
          );
        }
      }
    }
  }
}

class _AddRHUDialog extends StatefulWidget {
  final AdminService adminService;
  final VoidCallback onRHUAdded;

  const _AddRHUDialog({required this.adminService, required this.onRHUAdded});

  @override
  State<_AddRHUDialog> createState() => _AddRHUDialogState();
}

class _AddRHUDialogState extends State<_AddRHUDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _regionController = TextEditingController();
  final _contactPersonController = TextEditingController();
  final _contactNumberController = TextEditingController();
  final _emailController = TextEditingController();
  final _addressController = TextEditingController();
  bool _isLoading = false;
  double? _latitude;
  double? _longitude;

  @override
  void dispose() {
    _nameController.dispose();
    _regionController.dispose();
    _contactPersonController.dispose();
    _contactNumberController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('add_new_rhu'.tr()),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(labelText: 'rhu_name'.tr()),
                validator: (value) =>
                    (value?.isEmpty ?? true) ? 'name_required'.tr() : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _regionController,
                decoration: InputDecoration(labelText: 'region'.tr()),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _contactPersonController,
                decoration: InputDecoration(labelText: 'contact_person'.tr()),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _contactNumberController,
                decoration: InputDecoration(labelText: 'contact_number'.tr()),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _emailController,
                decoration: InputDecoration(labelText: 'email'.tr()),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _addressController,
                decoration: InputDecoration(labelText: 'address'.tr()),
                maxLines: 2,
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade300),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: Colors.blue.shade700,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Location is required for map navigation and area focusing.',
                        style: TextStyle(
                          color: Colors.blue.shade700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  ElevatedButton.icon(
                    onPressed: () async {
                      final picked = await showDialog<Map<String, dynamic>>(
                        context: context,
                        builder: (ctx) => _LocationPickerDialog(
                          initialLatitude: _latitude,
                          initialLongitude: _longitude,
                          title: 'Select RHU Location',
                        ),
                      );
                      if (picked != null) {
                        setState(() {
                          _latitude = picked['latitude'] as double;
                          _longitude = picked['longitude'] as double;
                        });
                      }
                    },
                    icon: const Icon(Icons.map),
                    label: const Text('Pick on Map *'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: (_latitude != null && _longitude != null)
                            ? Colors.green.shade50
                            : Colors.red.shade50,
                        border: Border.all(
                          color: (_latitude != null && _longitude != null)
                              ? Colors.green
                              : Colors.red,
                        ),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        _latitude != null && _longitude != null
                            ? '✓ ${_latitude!.toStringAsFixed(5)}, ${_longitude!.toStringAsFixed(5)}'
                            : '✗ No location selected',
                        style: TextStyle(
                          fontSize: 12,
                          color: (_latitude != null && _longitude != null)
                              ? Colors.green.shade700
                              : Colors.red.shade700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      decoration: InputDecoration(
                        labelText: 'Latitude',
                        hintText: 'or enter manually',
                      ),
                      keyboardType: TextInputType.number,
                      onChanged: (value) =>
                          setState(() => _latitude = double.tryParse(value)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      decoration: InputDecoration(
                        labelText: 'Longitude',
                        hintText: 'or enter manually',
                      ),
                      keyboardType: TextInputType.number,
                      onChanged: (value) =>
                          setState(() => _longitude = double.tryParse(value)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('cancel'.tr()),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _handleAddRHU,
          child: _isLoading
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text('add'.tr()),
        ),
      ],
    );
  }

  Future<void> _handleAddRHU() async {
    if (!_formKey.currentState!.validate()) return;

    if (_latitude == null || _longitude == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Location is required'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    final success = await widget.adminService.createRHU(
      name: _nameController.text.trim(),
      region: _regionController.text.trim(),
      contactPerson: _contactPersonController.text.trim(),
      contactNumber: _contactNumberController.text.trim(),
      email: _emailController.text.trim(),
      address: _addressController.text.trim(),
      latitude: _latitude,
      longitude: _longitude,
    );

    setState(() => _isLoading = false);

    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('rhu_created_successfully'.tr())),
        );
        widget.onRHUAdded();
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('error_creating_rhu'.tr()),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

class _EditRHUDialog extends StatefulWidget {
  final Map<String, dynamic> rhu;
  final AdminService adminService;
  final VoidCallback onRHUUpdated;

  const _EditRHUDialog({
    required this.rhu,
    required this.adminService,
    required this.onRHUUpdated,
  });

  @override
  State<_EditRHUDialog> createState() => _EditRHUDialogState();
}

class _EditRHUDialogState extends State<_EditRHUDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _regionController = TextEditingController();
  final _contactPersonController = TextEditingController();
  final _contactNumberController = TextEditingController();
  final _emailController = TextEditingController();
  final _addressController = TextEditingController();
  bool _isLoading = false;
  double? _latitude;
  double? _longitude;

  @override
  void initState() {
    super.initState();
    _nameController.text = widget.rhu['name'] ?? '';
    _regionController.text = widget.rhu['region'] ?? '';
    _contactPersonController.text = widget.rhu['contact_person'] ?? '';
    _contactNumberController.text = widget.rhu['contact_number'] ?? '';
    _emailController.text = widget.rhu['email'] ?? '';
    _addressController.text = widget.rhu['address'] ?? '';
    _latitude = widget.rhu['latitude'] as double?;
    _longitude = widget.rhu['longitude'] as double?;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _regionController.dispose();
    _contactPersonController.dispose();
    _contactNumberController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('edit_rhu'.tr()),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(labelText: 'rhu_name'.tr()),
                validator: (value) =>
                    (value?.isEmpty ?? true) ? 'name_required'.tr() : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _regionController,
                decoration: InputDecoration(labelText: 'region'.tr()),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _contactPersonController,
                decoration: InputDecoration(labelText: 'contact_person'.tr()),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _contactNumberController,
                decoration: InputDecoration(labelText: 'contact_number'.tr()),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _emailController,
                decoration: InputDecoration(labelText: 'email'.tr()),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _addressController,
                decoration: InputDecoration(labelText: 'address'.tr()),
                maxLines: 2,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  ElevatedButton.icon(
                    onPressed: () async {
                      final picked = await showDialog<Map<String, dynamic>>(
                        context: context,
                        builder: (ctx) => _LocationPickerDialog(
                          initialLatitude: _latitude,
                          initialLongitude: _longitude,
                          title: 'Select RHU Location',
                        ),
                      );
                      if (picked != null) {
                        setState(() {
                          _latitude = picked['latitude'] as double;
                          _longitude = picked['longitude'] as double;
                        });
                      }
                    },
                    icon: const Icon(Icons.map),
                    label: const Text('Pick on Map'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: (_latitude != null && _longitude != null)
                            ? Colors.green.shade50
                            : Colors.red.shade50,
                        border: Border.all(
                          color: (_latitude != null && _longitude != null)
                              ? Colors.green
                              : Colors.red,
                        ),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        _latitude != null && _longitude != null
                            ? '✓ ${_latitude!.toStringAsFixed(5)}, ${_longitude!.toStringAsFixed(5)}'
                            : '✗ No location selected',
                        style: TextStyle(
                          fontSize: 12,
                          color: (_latitude != null && _longitude != null)
                              ? Colors.green.shade700
                              : Colors.red.shade700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      decoration: InputDecoration(
                        labelText: 'Latitude',
                        hintText: 'or enter manually',
                      ),
                      keyboardType: TextInputType.number,
                      initialValue: _latitude?.toString(),
                      onChanged: (value) =>
                          setState(() => _latitude = double.tryParse(value)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      decoration: InputDecoration(
                        labelText: 'Longitude',
                        hintText: 'or enter manually',
                      ),
                      keyboardType: TextInputType.number,
                      initialValue: _longitude?.toString(),
                      onChanged: (value) =>
                          setState(() => _longitude = double.tryParse(value)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('cancel'.tr()),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _handleUpdateRHU,
          child: _isLoading
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text('update'.tr()),
        ),
      ],
    );
  }

  Future<void> _handleUpdateRHU() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final updates = <String, dynamic>{
      'name': _nameController.text.trim(),
      'region': _regionController.text.trim(),
      'contact_person': _contactPersonController.text.trim(),
      'contact_number': _contactNumberController.text.trim(),
      'email': _emailController.text.trim(),
      'address': _addressController.text.trim(),
      'latitude': _latitude,
      'longitude': _longitude,
    };

    final success = await widget.adminService.updateRHU(
      widget.rhu['id'],
      updates,
    );

    setState(() => _isLoading = false);

    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('rhu_updated_successfully'.tr())),
        );
        widget.onRHUUpdated();
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('error_updating_rhu'.tr()),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

// ============================================
// FACILITY MANAGEMENT TAB
// ============================================

class _FacilityManagementTab extends StatefulWidget {
  final AdminService adminService;

  const _FacilityManagementTab({required this.adminService});

  @override
  State<_FacilityManagementTab> createState() => _FacilityManagementTabState();
}

class _FacilityManagementTabState extends State<_FacilityManagementTab> {
  late Future<List<Map<String, dynamic>>> _facilitiesFuture;

  @override
  void initState() {
    super.initState();
    _refreshFacilities();
  }

  void _refreshFacilities() {
    _facilitiesFuture = widget.adminService.getFacilities();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: ElevatedButton.icon(
            onPressed: () => _showAddFacilityDialog(context),
            icon: const Icon(Icons.add),
            label: Text('add_facility'.tr()),
          ),
        ),
        Expanded(
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: _facilitiesFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return Center(
                  child: Text('${'error'.tr()}: ${snapshot.error}'),
                );
              }

              final facilities = snapshot.data ?? [];
              if (facilities.isEmpty) {
                return Center(child: Text('no_facilities_found'.tr()));
              }

              return ListView.builder(
                itemCount: facilities.length,
                itemBuilder: (context, index) {
                  final facility = facilities[index];
                  return Card(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    child: ListTile(
                      title: Text(facility['name'] ?? 'Unknown'),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Type: ${facility['facility_type']?.toUpperCase() ?? 'Unknown'}',
                          ),
                          Text('Barangay: ${facility['barangay']}'),
                        ],
                      ),
                      trailing: PopupMenuButton(
                        itemBuilder: (context) => [
                          PopupMenuItem(
                            child: Text('edit'.tr()),
                            onTap: () =>
                                _showEditFacilityDialog(context, facility),
                          ),
                          PopupMenuItem(
                            child: Text('delete'.tr()),
                            onTap: () =>
                                _deleteFacility(context, facility['id']),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  void _showAddFacilityDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => _AddFacilityDialog(
        adminService: widget.adminService,
        onFacilityAdded: _refreshFacilities,
      ),
    );
  }

  void _showEditFacilityDialog(
    BuildContext context,
    Map<String, dynamic> facility,
  ) {
    showDialog(
      context: context,
      builder: (context) => _EditFacilityDialog(
        facility: facility,
        adminService: widget.adminService,
        onFacilityUpdated: _refreshFacilities,
      ),
    );
  }

  void _deleteFacility(BuildContext context, String facilityId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('confirm_delete'.tr()),
        content: Text('delete_facility_confirm'.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('cancel'.tr()),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('delete'.tr()),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await widget.adminService.deleteFacility(facilityId);
      if (success) {
        _refreshFacilities();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('facility_deleted_successfully'.tr())),
          );
        }
      }
    }
  }
}

class _AddFacilityDialog extends StatefulWidget {
  final AdminService adminService;
  final VoidCallback onFacilityAdded;

  const _AddFacilityDialog({
    required this.adminService,
    required this.onFacilityAdded,
  });

  @override
  State<_AddFacilityDialog> createState() => _AddFacilityDialogState();
}

class _AddFacilityDialogState extends State<_AddFacilityDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _contactPersonController = TextEditingController();
  final _contactNumberController = TextEditingController();
  final _emailController = TextEditingController();
  final _addressController = TextEditingController();
  final _barangayController = TextEditingController();
  String? _selectedRHUId;
  String _facilityType = 'clinic';
  bool _isLoading = false;
  double? _latitude;
  double? _longitude;

  late Future<List<Map<String, dynamic>>> _rhusFuture;

  @override
  void initState() {
    super.initState();
    _rhusFuture = widget.adminService.getRHUs();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _contactPersonController.dispose();
    _contactNumberController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _barangayController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('add_new_facility'.tr()),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FutureBuilder<List<Map<String, dynamic>>>(
                future: _rhusFuture,
                builder: (context, snapshot) {
                  final rhus = snapshot.data ?? [];
                  return DropdownButtonFormField<String>(
                    initialValue: _selectedRHUId,
                    decoration: InputDecoration(labelText: 'select_rhu'.tr()),
                    items: rhus
                        .map(
                          (rhu) => DropdownMenuItem(
                            value: rhu['id']?.toString(),
                            child: Text(rhu['name'] ?? 'Unknown'),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      setState(() => _selectedRHUId = value);
                    },
                    validator: (value) =>
                        (value?.isEmpty ?? true) ? 'rhu_required'.tr() : null,
                  );
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(labelText: 'facility_name'.tr()),
                validator: (value) =>
                    (value?.isEmpty ?? true) ? 'name_required'.tr() : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _facilityType,
                decoration: InputDecoration(labelText: 'facility_type'.tr()),
                items: [
                  DropdownMenuItem(
                    value: 'hospital',
                    child: Text('hospital'.tr()),
                  ),
                  DropdownMenuItem(value: 'clinic', child: Text('clinic'.tr())),
                ],
                onChanged: (value) {
                  setState(() => _facilityType = value ?? 'clinic');
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _barangayController,
                decoration: InputDecoration(labelText: 'barangay'.tr()),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _contactPersonController,
                decoration: InputDecoration(labelText: 'contact_person'.tr()),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _contactNumberController,
                decoration: InputDecoration(labelText: 'contact_number'.tr()),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _emailController,
                decoration: InputDecoration(labelText: 'email'.tr()),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _addressController,
                decoration: InputDecoration(labelText: 'address'.tr()),
                maxLines: 2,
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade300),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: Colors.blue.shade700,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Location is required for map navigation and area focusing.',
                        style: TextStyle(
                          color: Colors.blue.shade700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  ElevatedButton.icon(
                    onPressed: () async {
                      final picked = await showDialog<Map<String, dynamic>>(
                        context: context,
                        builder: (ctx) => _LocationPickerDialog(
                          initialLatitude: _latitude,
                          initialLongitude: _longitude,
                          title: 'Select Facility Location',
                        ),
                      );
                      if (picked != null) {
                        setState(() {
                          _latitude = picked['latitude'] as double;
                          _longitude = picked['longitude'] as double;
                        });
                      }
                    },
                    icon: const Icon(Icons.map),
                    label: const Text('Pick on Map *'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: (_latitude != null && _longitude != null)
                            ? Colors.green.shade50
                            : Colors.red.shade50,
                        border: Border.all(
                          color: (_latitude != null && _longitude != null)
                              ? Colors.green
                              : Colors.red,
                        ),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        _latitude != null && _longitude != null
                            ? '✓ ${_latitude!.toStringAsFixed(5)}, ${_longitude!.toStringAsFixed(5)}'
                            : '✗ No location selected',
                        style: TextStyle(
                          fontSize: 12,
                          color: (_latitude != null && _longitude != null)
                              ? Colors.green.shade700
                              : Colors.red.shade700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      decoration: InputDecoration(
                        labelText: 'Latitude',
                        hintText: 'or enter manually',
                      ),
                      keyboardType: TextInputType.number,
                      onChanged: (value) =>
                          setState(() => _latitude = double.tryParse(value)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      decoration: InputDecoration(
                        labelText: 'Longitude',
                        hintText: 'or enter manually',
                      ),
                      keyboardType: TextInputType.number,
                      onChanged: (value) =>
                          setState(() => _longitude = double.tryParse(value)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('cancel'.tr()),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _handleAddFacility,
          child: _isLoading
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text('add'.tr()),
        ),
      ],
    );
  }

  Future<void> _handleAddFacility() async {
    if (!_formKey.currentState!.validate()) return;

    if (_latitude == null || _longitude == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Location is required'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    final success = await widget.adminService.createFacility(
      rhuId: _selectedRHUId!,
      name: _nameController.text.trim(),
      facilityType: _facilityType,
      contactPerson: _contactPersonController.text.trim(),
      contactNumber: _contactNumberController.text.trim(),
      email: _emailController.text.trim(),
      address: _addressController.text.trim(),
      barangay: _barangayController.text.trim(),
      latitude: _latitude,
      longitude: _longitude,
    );

    setState(() => _isLoading = false);

    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('facility_created_successfully'.tr())),
        );
        widget.onFacilityAdded();
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('error_creating_facility'.tr()),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

class _EditFacilityDialog extends StatefulWidget {
  final Map<String, dynamic> facility;
  final AdminService adminService;
  final VoidCallback onFacilityUpdated;

  const _EditFacilityDialog({
    required this.facility,
    required this.adminService,
    required this.onFacilityUpdated,
  });

  @override
  State<_EditFacilityDialog> createState() => _EditFacilityDialogState();
}

class _EditFacilityDialogState extends State<_EditFacilityDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _contactPersonController = TextEditingController();
  final _contactNumberController = TextEditingController();
  final _emailController = TextEditingController();
  final _addressController = TextEditingController();
  final _barangayController = TextEditingController();
  String? _selectedRHUId;
  String _facilityType = 'clinic';
  bool _isLoading = false;
  double? _latitude;
  double? _longitude;

  late Future<List<Map<String, dynamic>>> _rhusFuture;

  @override
  void initState() {
    super.initState();
    _nameController.text = widget.facility['name'] ?? '';
    _contactPersonController.text = widget.facility['contact_person'] ?? '';
    _contactNumberController.text = widget.facility['contact_number'] ?? '';
    _emailController.text = widget.facility['email'] ?? '';
    _addressController.text = widget.facility['address'] ?? '';
    _barangayController.text = widget.facility['barangay'] ?? '';
    _selectedRHUId = widget.facility['rhu_id']?.toString();
    _facilityType = widget.facility['facility_type'] ?? 'clinic';
    _latitude = widget.facility['latitude'] as double?;
    _longitude = widget.facility['longitude'] as double?;
    _rhusFuture = widget.adminService.getRHUs();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _contactPersonController.dispose();
    _contactNumberController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _barangayController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('edit_facility'.tr()),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FutureBuilder<List<Map<String, dynamic>>>(
                future: _rhusFuture,
                builder: (context, snapshot) {
                  final rhus = snapshot.data ?? [];
                  return DropdownButtonFormField<String>(
                    initialValue: _selectedRHUId,
                    decoration: InputDecoration(labelText: 'select_rhu'.tr()),
                    items: rhus
                        .map(
                          (rhu) => DropdownMenuItem(
                            value: rhu['id']?.toString(),
                            child: Text(rhu['name'] ?? 'Unknown'),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      setState(() => _selectedRHUId = value);
                    },
                    validator: (value) =>
                        (value?.isEmpty ?? true) ? 'rhu_required'.tr() : null,
                  );
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(labelText: 'facility_name'.tr()),
                validator: (value) =>
                    (value?.isEmpty ?? true) ? 'name_required'.tr() : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _facilityType,
                decoration: InputDecoration(labelText: 'facility_type'.tr()),
                items: [
                  DropdownMenuItem(
                    value: 'hospital',
                    child: Text('hospital'.tr()),
                  ),
                  DropdownMenuItem(value: 'clinic', child: Text('clinic'.tr())),
                ],
                onChanged: (value) {
                  setState(() => _facilityType = value ?? 'clinic');
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _barangayController,
                decoration: InputDecoration(labelText: 'barangay'.tr()),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _contactPersonController,
                decoration: InputDecoration(labelText: 'contact_person'.tr()),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _contactNumberController,
                decoration: InputDecoration(labelText: 'contact_number'.tr()),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _emailController,
                decoration: InputDecoration(labelText: 'email'.tr()),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _addressController,
                decoration: InputDecoration(labelText: 'address'.tr()),
                maxLines: 2,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  ElevatedButton.icon(
                    onPressed: () async {
                      final picked = await showDialog<Map<String, dynamic>>(
                        context: context,
                        builder: (ctx) => _LocationPickerDialog(
                          initialLatitude: _latitude,
                          initialLongitude: _longitude,
                          title: 'Select Facility Location',
                        ),
                      );
                      if (picked != null) {
                        setState(() {
                          _latitude = picked['latitude'] as double;
                          _longitude = picked['longitude'] as double;
                        });
                      }
                    },
                    icon: const Icon(Icons.map),
                    label: const Text('Pick on Map'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: (_latitude != null && _longitude != null)
                            ? Colors.green.shade50
                            : Colors.red.shade50,
                        border: Border.all(
                          color: (_latitude != null && _longitude != null)
                              ? Colors.green
                              : Colors.red,
                        ),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        _latitude != null && _longitude != null
                            ? '✓ ${_latitude!.toStringAsFixed(5)}, ${_longitude!.toStringAsFixed(5)}'
                            : '✗ No location selected',
                        style: TextStyle(
                          fontSize: 12,
                          color: (_latitude != null && _longitude != null)
                              ? Colors.green.shade700
                              : Colors.red.shade700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      decoration: InputDecoration(
                        labelText: 'Latitude',
                        hintText: 'or enter manually',
                      ),
                      keyboardType: TextInputType.number,
                      initialValue: _latitude?.toString(),
                      onChanged: (value) =>
                          setState(() => _latitude = double.tryParse(value)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      decoration: InputDecoration(
                        labelText: 'Longitude',
                        hintText: 'or enter manually',
                      ),
                      keyboardType: TextInputType.number,
                      initialValue: _longitude?.toString(),
                      onChanged: (value) =>
                          setState(() => _longitude = double.tryParse(value)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('cancel'.tr()),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _handleUpdateFacility,
          child: _isLoading
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text('update'.tr()),
        ),
      ],
    );
  }

  Future<void> _handleUpdateFacility() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final updates = <String, dynamic>{
      'rhu_id': _selectedRHUId,
      'name': _nameController.text.trim(),
      'facility_type': _facilityType,
      'contact_person': _contactPersonController.text.trim(),
      'contact_number': _contactNumberController.text.trim(),
      'email': _emailController.text.trim(),
      'address': _addressController.text.trim(),
      'barangay': _barangayController.text.trim(),
      'latitude': _latitude,
      'longitude': _longitude,
    };

    final success = await widget.adminService.updateFacility(
      widget.facility['id'],
      updates,
    );

    setState(() => _isLoading = false);

    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('facility_updated_successfully'.tr())),
        );
        widget.onFacilityUpdated();
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('error_updating_facility'.tr()),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

// ============================================
// BARANGAY MANAGEMENT TAB
// ============================================

class _BarangayManagementTab extends StatefulWidget {
  final AdminService adminService;

  const _BarangayManagementTab({required this.adminService});

  @override
  State<_BarangayManagementTab> createState() => _BarangayManagementTabState();
}

class _BarangayManagementTabState extends State<_BarangayManagementTab> {
  late Future<List<Map<String, dynamic>>> _barangaysFuture;

  @override
  void initState() {
    super.initState();
    _refreshBarangays();
  }

  void _refreshBarangays() {
    _barangaysFuture = widget.adminService.getBarangays();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: ElevatedButton.icon(
            onPressed: () => _showAddBarangayDialog(context),
            icon: const Icon(Icons.add),
            label: Text('add_barangay'.tr()),
          ),
        ),
        Expanded(
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: _barangaysFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return Center(
                  child: Text('${'error'.tr()}: ${snapshot.error}'),
                );
              }

              final barangays = snapshot.data ?? [];
              if (barangays.isEmpty) {
                return Center(child: Text('no_barangays_found'.tr()));
              }

              return ListView.builder(
                itemCount: barangays.length,
                itemBuilder: (context, index) {
                  final barangay = barangays[index];
                  return Card(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    child: ListTile(
                      title: Text(barangay['name'] ?? 'Unknown'),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Region: ${barangay['region']}'),
                          if (barangay['population'] != null)
                            Text('Population: ${barangay['population']}'),
                        ],
                      ),
                      trailing: PopupMenuButton(
                        itemBuilder: (context) => [
                          PopupMenuItem(
                            child: Text('edit'.tr()),
                            onTap: () =>
                                _showEditBarangayDialog(context, barangay),
                          ),
                          PopupMenuItem(
                            child: Text('delete'.tr()),
                            onTap: () =>
                                _deleteBarangay(context, barangay['id']),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  void _showAddBarangayDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => _AddBarangayDialog(
        adminService: widget.adminService,
        onBarangayAdded: _refreshBarangays,
      ),
    );
  }

  void _showEditBarangayDialog(
    BuildContext context,
    Map<String, dynamic> barangay,
  ) {
    showDialog(
      context: context,
      builder: (context) => _EditBarangayDialog(
        barangay: barangay,
        adminService: widget.adminService,
        onBarangayUpdated: _refreshBarangays,
      ),
    );
  }

  void _deleteBarangay(BuildContext context, String barangayId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('confirm_delete'.tr()),
        content: Text('delete_barangay_confirm'.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('cancel'.tr()),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('delete'.tr()),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await widget.adminService.deleteBarangay(barangayId);
      if (success) {
        _refreshBarangays();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('barangay_deleted_successfully'.tr())),
          );
        }
      }
    }
  }
}

class _AddBarangayDialog extends StatefulWidget {
  final AdminService adminService;
  final VoidCallback onBarangayAdded;

  const _AddBarangayDialog({
    required this.adminService,
    required this.onBarangayAdded,
  });

  @override
  State<_AddBarangayDialog> createState() => _AddBarangayDialogState();
}

class _AddBarangayDialogState extends State<_AddBarangayDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _regionController = TextEditingController();
  final _populationController = TextEditingController();
  String? _selectedRHUId;
  bool _isLoading = false;
  double? _latitude;
  double? _longitude;

  late Future<List<Map<String, dynamic>>> _rhusFuture;

  @override
  void initState() {
    super.initState();
    _rhusFuture = widget.adminService.getRHUs();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _regionController.dispose();
    _populationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('add_new_barangay'.tr()),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FutureBuilder<List<Map<String, dynamic>>>(
                future: _rhusFuture,
                builder: (context, snapshot) {
                  final rhus = snapshot.data ?? [];
                  return DropdownButtonFormField<String>(
                    initialValue: _selectedRHUId,
                    decoration: InputDecoration(labelText: 'select_rhu'.tr()),
                    items: rhus
                        .map(
                          (rhu) => DropdownMenuItem(
                            value: rhu['id']?.toString(),
                            child: Text(rhu['name'] ?? 'Unknown'),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      setState(() => _selectedRHUId = value);
                    },
                    validator: (value) =>
                        (value?.isEmpty ?? true) ? 'rhu_required'.tr() : null,
                  );
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(labelText: 'barangay_name'.tr()),
                validator: (value) =>
                    (value?.isEmpty ?? true) ? 'name_required'.tr() : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _regionController,
                decoration: InputDecoration(labelText: 'region'.tr()),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _populationController,
                decoration: InputDecoration(labelText: 'population'.tr()),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade300),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: Colors.blue.shade700,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Location is required for map navigation and area focusing.',
                        style: TextStyle(
                          color: Colors.blue.shade700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  ElevatedButton.icon(
                    onPressed: () async {
                      final picked = await showDialog<Map<String, dynamic>>(
                        context: context,
                        builder: (ctx) => _LocationPickerDialog(
                          initialLatitude: _latitude,
                          initialLongitude: _longitude,
                          title: 'Select Barangay Hall Location',
                        ),
                      );
                      if (picked != null) {
                        setState(() {
                          _latitude = picked['latitude'] as double;
                          _longitude = picked['longitude'] as double;
                        });
                      }
                    },
                    icon: const Icon(Icons.map),
                    label: const Text('Pick on Map *'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: (_latitude != null && _longitude != null)
                            ? Colors.green.shade50
                            : Colors.red.shade50,
                        border: Border.all(
                          color: (_latitude != null && _longitude != null)
                              ? Colors.green
                              : Colors.red,
                        ),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        _latitude != null && _longitude != null
                            ? '✓ ${_latitude!.toStringAsFixed(5)}, ${_longitude!.toStringAsFixed(5)}'
                            : '✗ No location selected',
                        style: TextStyle(
                          fontSize: 12,
                          color: (_latitude != null && _longitude != null)
                              ? Colors.green.shade700
                              : Colors.red.shade700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      decoration: InputDecoration(
                        labelText: 'Latitude',
                        hintText: 'or enter manually',
                      ),
                      keyboardType: TextInputType.number,
                      onChanged: (value) =>
                          setState(() => _latitude = double.tryParse(value)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      decoration: InputDecoration(
                        labelText: 'Longitude',
                        hintText: 'or enter manually',
                      ),
                      keyboardType: TextInputType.number,
                      onChanged: (value) =>
                          setState(() => _longitude = double.tryParse(value)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('cancel'.tr()),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _handleAddBarangay,
          child: _isLoading
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text('add'.tr()),
        ),
      ],
    );
  }

  Future<void> _handleAddBarangay() async {
    if (!_formKey.currentState!.validate()) return;

    if (_latitude == null || _longitude == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Location is required'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    final success = await widget.adminService.createBarangay(
      rhuId: _selectedRHUId!,
      name: _nameController.text.trim(),
      region: _regionController.text.trim(),
      population: int.tryParse(_populationController.text),
      latitude: _latitude,
      longitude: _longitude,
    );

    setState(() => _isLoading = false);

    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('barangay_created_successfully'.tr())),
        );
        widget.onBarangayAdded();
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('error_creating_barangay'.tr()),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

class _EditBarangayDialog extends StatefulWidget {
  final Map<String, dynamic> barangay;
  final AdminService adminService;
  final VoidCallback onBarangayUpdated;

  const _EditBarangayDialog({
    required this.barangay,
    required this.adminService,
    required this.onBarangayUpdated,
  });

  @override
  State<_EditBarangayDialog> createState() => _EditBarangayDialogState();
}

class _EditBarangayDialogState extends State<_EditBarangayDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _regionController = TextEditingController();
  final _populationController = TextEditingController();
  String? _selectedRHUId;
  bool _isLoading = false;
  double? _latitude;
  double? _longitude;

  late Future<List<Map<String, dynamic>>> _rhusFuture;

  @override
  void initState() {
    super.initState();
    _nameController.text = widget.barangay['name'] ?? '';
    _regionController.text = widget.barangay['region'] ?? '';
    _populationController.text =
        widget.barangay['population']?.toString() ?? '';
    _selectedRHUId = widget.barangay['rhu_id']?.toString();
    _latitude = widget.barangay['latitude'] as double?;
    _longitude = widget.barangay['longitude'] as double?;
    _rhusFuture = widget.adminService.getRHUs();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _regionController.dispose();
    _populationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('edit_barangay'.tr()),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FutureBuilder<List<Map<String, dynamic>>>(
                future: _rhusFuture,
                builder: (context, snapshot) {
                  final rhus = snapshot.data ?? [];
                  return DropdownButtonFormField<String>(
                    initialValue: _selectedRHUId,
                    decoration: InputDecoration(labelText: 'select_rhu'.tr()),
                    items: rhus
                        .map(
                          (rhu) => DropdownMenuItem(
                            value: rhu['id']?.toString(),
                            child: Text(rhu['name'] ?? 'Unknown'),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      setState(() => _selectedRHUId = value);
                    },
                    validator: (value) =>
                        (value?.isEmpty ?? true) ? 'rhu_required'.tr() : null,
                  );
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(labelText: 'barangay_name'.tr()),
                validator: (value) =>
                    (value?.isEmpty ?? true) ? 'name_required'.tr() : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _regionController,
                decoration: InputDecoration(labelText: 'region'.tr()),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _populationController,
                decoration: InputDecoration(labelText: 'population'.tr()),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  ElevatedButton.icon(
                    onPressed: () async {
                      final picked = await showDialog<Map<String, dynamic>>(
                        context: context,
                        builder: (ctx) => _LocationPickerDialog(
                          initialLatitude: _latitude,
                          initialLongitude: _longitude,
                          title: 'Select Barangay Hall Location',
                        ),
                      );
                      if (picked != null) {
                        setState(() {
                          _latitude = picked['latitude'] as double;
                          _longitude = picked['longitude'] as double;
                        });
                      }
                    },
                    icon: const Icon(Icons.map),
                    label: const Text('Pick on Map'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: (_latitude != null && _longitude != null)
                            ? Colors.green.shade50
                            : Colors.red.shade50,
                        border: Border.all(
                          color: (_latitude != null && _longitude != null)
                              ? Colors.green
                              : Colors.red,
                        ),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        _latitude != null && _longitude != null
                            ? '✓ ${_latitude!.toStringAsFixed(5)}, ${_longitude!.toStringAsFixed(5)}'
                            : '✗ No location selected',
                        style: TextStyle(
                          fontSize: 12,
                          color: (_latitude != null && _longitude != null)
                              ? Colors.green.shade700
                              : Colors.red.shade700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      decoration: InputDecoration(
                        labelText: 'Latitude',
                        hintText: 'or enter manually',
                      ),
                      keyboardType: TextInputType.number,
                      initialValue: _latitude?.toString(),
                      onChanged: (value) =>
                          setState(() => _latitude = double.tryParse(value)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      decoration: InputDecoration(
                        labelText: 'Longitude',
                        hintText: 'or enter manually',
                      ),
                      keyboardType: TextInputType.number,
                      initialValue: _longitude?.toString(),
                      onChanged: (value) =>
                          setState(() => _longitude = double.tryParse(value)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('cancel'.tr()),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _handleUpdateBarangay,
          child: _isLoading
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text('update'.tr()),
        ),
      ],
    );
  }

  Future<void> _handleUpdateBarangay() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final updates = <String, dynamic>{
      'rhu_id': _selectedRHUId,
      'name': _nameController.text.trim(),
      'region': _regionController.text.trim(),
      'population': int.tryParse(_populationController.text),
      'latitude': _latitude,
      'longitude': _longitude,
    };

    final success = await widget.adminService.updateBarangay(
      widget.barangay['id'],
      updates,
    );

    setState(() => _isLoading = false);

    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('barangay_updated_successfully'.tr())),
        );
        widget.onBarangayUpdated();
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('error_updating_barangay'.tr()),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

// ============================================
// LOCATION PICKER DIALOG
// ============================================

class _LocationPickerDialog extends StatefulWidget {
  final double? initialLatitude;
  final double? initialLongitude;
  final String? title;

  const _LocationPickerDialog({
    this.initialLatitude,
    this.initialLongitude,
    this.title,
  });

  @override
  State<_LocationPickerDialog> createState() => _LocationPickerDialogState();
}

class _LocationPickerDialogState extends State<_LocationPickerDialog> {
  late ll.LatLng _center;
  ll.LatLng? _picked;
  final MapController _mapController = MapController();

  @override
  void initState() {
    super.initState();
    // Default center around Salcedo coordinates (will be updated when proper coordinates are available)
    _center = ll.LatLng(
      widget.initialLatitude ?? 11.14922,
      widget.initialLongitude ?? 125.66287,
    );
    if (widget.initialLatitude != null && widget.initialLongitude != null) {
      _picked = ll.LatLng(widget.initialLatitude!, widget.initialLongitude!);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title ?? 'Select Location'),
      contentPadding: EdgeInsets.zero,
      content: SizedBox(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.6,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _center,
              initialZoom: 13.0,
              onTap: (tapPosition, point) {
                setState(() => _picked = point);
              },
            ),
            children: [
              TileLayer(
                urlTemplate:
                    'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                subdomains: const ['a', 'b', 'c'],
                userAgentPackageName: 'com.example.salcedo_dengue_watch',
              ),
              if (_picked != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _picked!,
                      width: 40,
                      height: 40,
                      child: const Icon(
                        Icons.location_on,
                        color: Colors.red,
                        size: 40,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
          onPressed: _picked == null
              ? null
              : () => Navigator.pop(context, {
                  'latitude': _picked!.latitude,
                  'longitude': _picked!.longitude,
                }),
          child: const Text('Use location'),
        ),
      ],
    );
  }
}
