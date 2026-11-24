class Profile {
  const Profile({
    required this.id,
    required this.role,
    required this.fullName,
    this.email,
    this.phone,
    this.address,
    this.farmName,
    this.pickupAddress,
    this.createdAt,
  });

  factory Profile.fromJson(Map<String, dynamic> json) => Profile(
    id: json['id'].toString(),
    role: json['role'] as String,
    fullName: json['full_name'] as String? ?? '',
    email: json['email'] as String?,
    phone: json['phone'] as String?,
    address: json['address'] as String?,
    farmName: json['farm_name'] as String?,
    pickupAddress: json['pickup_address'] as String?,
    createdAt: json['created_at'] == null
        ? null
        : DateTime.parse(json['created_at'].toString()).toLocal(),
  );

  final String id;
  final String role;
  final String fullName;
  final String? email;
  final String? phone;
  final String? address;
  final String? farmName;
  final String? pickupAddress;
  final DateTime? createdAt;

  Map<String, dynamic> toJson() => {
    'id': id,
    'role': role,
    'full_name': fullName,
    'email': email,
    'phone': phone,
    'address': address,
    'farm_name': farmName,
    'pickup_address': pickupAddress,
    'created_at': createdAt?.toUtc().toIso8601String(),
  };
}
