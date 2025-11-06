class Task {
  final int? id;                 // mudou: agora é inteiro autoincrement
  final String title;
  final String description;
  final String priority;         // 'low' | 'medium' | 'high'
  final bool completed;
  final DateTime createdAt;

  // existentes no seu projeto
  final DateTime? dueDate;
  final String? categoryId;

  // NOVOS CAMPOS (câmera, sensores, GPS)
  final String? photoPath;       // caminho do arquivo da foto
  final DateTime? completedAt;   // quando foi concluída
  final String? completedBy;     // 'manual' | 'shake'
  final double? latitude;
  final double? longitude;
  final String? locationName;

  Task({
    this.id,
    required this.title,
    this.description = '',
    this.priority = 'medium',
    this.completed = false,
    DateTime? createdAt,
    this.dueDate,
    this.categoryId,
    this.photoPath,
    this.completedAt,
    this.completedBy,
    this.latitude,
    this.longitude,
    this.locationName,
  }) : createdAt = createdAt ?? DateTime.now();

  // helpers
  bool get hasPhoto => (photoPath != null && photoPath!.isNotEmpty);
  bool get hasLocation => (latitude != null && longitude != null);
  bool get wasCompletedByShake => completedBy == 'shake';

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'description': description,
        'priority': priority,
        'completed': completed ? 1 : 0,
        'createdAt': createdAt.toIso8601String(),
        'dueDate': dueDate?.toIso8601String(),
        'categoryId': categoryId,
        'photoPath': photoPath,
        'completedAt': completedAt?.toIso8601String(),
        'completedBy': completedBy,
        'latitude': latitude,
        'longitude': longitude,
        'locationName': locationName,
      };

  factory Task.fromMap(Map<String, dynamic> map) => Task(
        id: map['id'] as int?,
        title: map['title'] as String,
        description: (map['description'] ?? '') as String,
        priority: (map['priority'] ?? 'medium') as String,
        completed: (map['completed'] as int) == 1,
        createdAt: DateTime.parse(map['createdAt'] as String),
        dueDate: map['dueDate'] != null ? DateTime.parse(map['dueDate'] as String) : null,
        categoryId: map['categoryId'] as String?,
        photoPath: map['photoPath'] as String?,
        completedAt: map['completedAt'] != null ? DateTime.parse(map['completedAt'] as String) : null,
        completedBy: map['completedBy'] as String?,
        latitude: (map['latitude'] as num?)?.toDouble(),
        longitude: (map['longitude'] as num?)?.toDouble(),
        locationName: map['locationName'] as String?,
      );

  Task copyWith({
    int? id,
    String? title,
    String? description,
    String? priority,
    bool? completed,
    DateTime? createdAt,
    DateTime? dueDate,
    String? categoryId,
    String? photoPath,
    DateTime? completedAt,
    String? completedBy,
    double? latitude,
    double? longitude,
    String? locationName,
  }) {
    return Task(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      priority: priority ?? this.priority,
      completed: completed ?? this.completed,
      createdAt: createdAt ?? this.createdAt,
      dueDate: dueDate ?? this.dueDate,
      categoryId: categoryId ?? this.categoryId,
      photoPath: photoPath ?? this.photoPath,
      completedAt: completedAt ?? this.completedAt,
      completedBy: completedBy ?? this.completedBy,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      locationName: locationName ?? this.locationName,
    );
  }
}
