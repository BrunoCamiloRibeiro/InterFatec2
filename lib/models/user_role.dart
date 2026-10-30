/// Perfis de acesso do aplicativo
enum UserRole {
  admin('admin', 'Administrador'),
  motorista('motorista', 'Motorista'),
  paciente('paciente', 'Paciente');

  final String valor;
  final String label;

  const UserRole(this.valor, this.label);

  static UserRole fromString(String? role) {
    if (role == 'admin') return UserRole.admin;
    if (role == 'motorista') return UserRole.motorista;
    return UserRole.paciente;
  }
}
