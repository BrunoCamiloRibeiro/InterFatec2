/// Perfis de acesso do aplicativo (RBAC).
enum UserRole {
  admin('admin', 'Administrador'),
  motorista('motorista', 'Motorista'),
  paciente('paciente', 'Paciente');

  /// Chave canônica persistida no campo `role` do Firestore.
  final String valor;

  /// Rótulo amigável exibido na interface.
  final String label;

  const UserRole(this.valor, this.label);

  /// Converte a string recebida do banco para [UserRole], usando `paciente`
  /// como fallback seguro pelo princípio do menor privilégio.
  static UserRole fromString(String? role) {
    if (role == 'admin') return UserRole.admin;
    if (role == 'motorista') return UserRole.motorista;
    return UserRole.paciente;
  }
}
