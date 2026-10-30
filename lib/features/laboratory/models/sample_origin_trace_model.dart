/// Specimen Origin Traceability models (UC77 / Trace Sample Origin / Issue I3-090).
/// Conforms to: Production Engineering Standards & AGENTS-CODE.md.

library;

class TraceNodeModel {
  final String nodeType;
  final String title;
  final String subtitle;
  final String code;
  final String? badge;
  final String badgeType;
  final DateTime? timestamp;

  TraceNodeModel({
    required this.nodeType,
    required this.title,
    required this.subtitle,
    required this.code,
    this.badge,
    required this.badgeType,
    this.timestamp,
  });

  factory TraceNodeModel.fromJson(Map<String, dynamic> json) {
    return TraceNodeModel(
      nodeType: json['nodeType'] as String? ?? '',
      title: json['title'] as String? ?? '',
      subtitle: json['subtitle'] as String? ?? '',
      code: json['code'] as String? ?? '',
      badge: json['badge'] as String?,
      badgeType: json['badgeType'] as String? ?? 'default',
      timestamp: json['timestamp'] != null
          ? DateTime.tryParse(json['timestamp'] as String)
          : null,
    );
  }
}

class ChainOfCustodyModel {
  final String integrity;
  final int barcodeScansCount;
  final String transportDuration;
  final String analyzerModel;
  final String reagentLot;
  final String qcStatus;
  final int rerunCount;
  final int notesCount;

  ChainOfCustodyModel({
    required this.integrity,
    required this.barcodeScansCount,
    required this.transportDuration,
    required this.analyzerModel,
    required this.reagentLot,
    required this.qcStatus,
    required this.rerunCount,
    required this.notesCount,
  });

  factory ChainOfCustodyModel.fromJson(Map<String, dynamic> json) {
    return ChainOfCustodyModel(
      integrity: json['integrity'] as String? ?? 'Unbroken',
      barcodeScansCount: json['barcodeScansCount'] as int? ?? 7,
      transportDuration: json['transportDuration'] as String? ?? '12 min',
      analyzerModel: json['analyzerModel'] as String? ?? 'BC-01',
      reagentLot: json['reagentLot'] as String? ?? 'LOT-7721',
      qcStatus: json['qcStatus'] as String? ?? 'QCF-1142',
      rerunCount: json['rerunCount'] as int? ?? 1,
      notesCount: json['notesCount'] as int? ?? 3,
    );
  }
}

class SampleOriginTraceModel {
  final String specimenId;
  final String orderId;
  final String patientId;
  final String patientName;
  final List<TraceNodeModel> nodes;
  final ChainOfCustodyModel custody;
  final DateTime createdAt;

  SampleOriginTraceModel({
    required this.specimenId,
    required this.orderId,
    required this.patientId,
    required this.patientName,
    required this.nodes,
    required this.custody,
    required this.createdAt,
  });

  factory SampleOriginTraceModel.fromJson(Map<String, dynamic> json) {
    var rawNodes = json['nodes'] as List<dynamic>? ?? [];
    var parsedNodes = rawNodes
        .map((e) => TraceNodeModel.fromJson(e as Map<String, dynamic>))
        .toList();

    return SampleOriginTraceModel(
      specimenId: json['specimenId'] as String? ?? '',
      orderId: json['orderId'] as String? ?? '',
      patientId: json['patientId'] as String? ?? '',
      patientName: json['patientName'] as String? ?? '',
      nodes: parsedNodes,
      custody: json['custody'] != null
          ? ChainOfCustodyModel.fromJson(json['custody'] as Map<String, dynamic>)
          : ChainOfCustodyModel(
              integrity: 'Unbroken',
              barcodeScansCount: 7,
              transportDuration: '12 min',
              analyzerModel: 'BC-01',
              reagentLot: 'LOT-7721',
              qcStatus: 'QCF-1142',
              rerunCount: 1,
              notesCount: 3,
            ),
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}
