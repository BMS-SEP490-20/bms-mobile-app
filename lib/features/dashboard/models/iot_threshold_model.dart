/// IoT Device Telemetry Alert Threshold model (UC67 / Configure IoT Thresholds).
class IotThresholdModel {
  final String deviceId;
  final String deviceName;
  final String location;
  final String sensorType; // 'Temperature' | 'Humidity'
  final String unit; // '°C' | '%'
  double lowAlert;
  double highAlert;
  int intervalSeconds;
  final String status;
  final String updatedBy;

  IotThresholdModel({
    required this.deviceId,
    required this.deviceName,
    required this.location,
    required this.sensorType,
    required this.unit,
    required this.lowAlert,
    required this.highAlert,
    required this.intervalSeconds,
    this.status = 'Active',
    this.updatedBy = 'Manager',
  });

  factory IotThresholdModel.fromJson(Map<String, dynamic> json) {
    return IotThresholdModel(
      deviceId: json['deviceId'] ?? json['DeviceId'] ?? '',
      deviceName: json['deviceName'] ?? json['DeviceName'] ?? '',
      location: json['location'] ?? json['Location'] ?? '',
      sensorType: json['sensorType'] ?? json['SensorType'] ?? 'Temperature',
      unit: json['unit'] ?? json['Unit'] ?? '°C',
      lowAlert: (json['lowAlert'] ?? json['LowAlert'] ?? 0.0).toDouble(),
      highAlert: (json['highAlert'] ?? json['HighAlert'] ?? 0.0).toDouble(),
      intervalSeconds: (json['intervalSeconds'] ?? json['IntervalSeconds'] ?? 60).toInt(),
      status: json['status'] ?? json['Status'] ?? 'Active',
      updatedBy: json['updatedBy'] ?? json['UpdatedBy'] ?? 'Manager',
    );
  }

  Map<String, dynamic> toJson() => {
    'deviceId': deviceId,
    'deviceName': deviceName,
    'location': location,
    'sensorType': sensorType,
    'unit': unit,
    'lowAlert': lowAlert,
    'highAlert': highAlert,
    'intervalSeconds': intervalSeconds,
    'status': status,
    'updatedBy': updatedBy,
  };
}

/// IoT Alert Recipient model.
class IotAlertRecipientModel {
  final String id;
  final String fullName;
  final String role;
  final String email;
  final String phone;
  final List<String> channels;
  final bool isActive;

  IotAlertRecipientModel({
    required this.id,
    required this.fullName,
    required this.role,
    required this.email,
    required this.phone,
    required this.channels,
    this.isActive = true,
  });

  factory IotAlertRecipientModel.fromJson(Map<String, dynamic> json) {
    var rawChannels = json['channels'] ?? json['Channels'] as List? ?? ['Push', 'Email'];
    return IotAlertRecipientModel(
      id: json['id'] ?? json['Id'] ?? '',
      fullName: json['fullName'] ?? json['FullName'] ?? '',
      role: json['role'] ?? json['Role'] ?? '',
      email: json['email'] ?? json['Email'] ?? '',
      phone: json['phone'] ?? json['Phone'] ?? '',
      channels: rawChannels.map((c) => c.toString()).toList(),
      isActive: json['isActive'] ?? json['IsActive'] ?? true,
    );
  }
}

/// Summary Packet model for IoT configurations.
class IotConfigSummaryModel {
  final int totalDevices;
  final int totalRules;
  final List<IotThresholdModel> thresholds;
  final List<IotAlertRecipientModel> recipients;
  final String escalationPolicy;

  IotConfigSummaryModel({
    required this.totalDevices,
    required this.totalRules,
    required this.thresholds,
    required this.recipients,
    required this.escalationPolicy,
  });

  factory IotConfigSummaryModel.fromJson(Map<String, dynamic> json) {
    var rawThresholds = json['thresholds'] ?? json['Thresholds'] as List? ?? [];
    var rawRecipients = json['recipients'] ?? json['Recipients'] as List? ?? [];

    return IotConfigSummaryModel(
      totalDevices: json['totalDevices'] ?? json['TotalDevices'] ?? 0,
      totalRules: json['totalRules'] ?? json['TotalRules'] ?? 0,
      thresholds: rawThresholds.map((t) => IotThresholdModel.fromJson(t)).toList(),
      recipients: rawRecipients.map((r) => IotAlertRecipientModel.fromJson(r)).toList(),
      escalationPolicy: json['escalationPolicy'] ?? json['EscalationPolicy'] ?? '',
    );
  }
}
