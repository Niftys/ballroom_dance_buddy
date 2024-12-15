class Choreography {
  int? id;
  String name;
  int danceId;
  String style;
  String dance;
  String level;
  List<ChoreographyStep> steps;

  Choreography({
    this.id,
    required this.name,
    required this.danceId,
    required this.style,
    required this.dance,
    required this.level,
    required this.steps,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'danceId': danceId,
      'style': style,
      'dance': dance,
      'level': level,
      'steps': steps.map((step) => step.toJson()).toList(),
    };
  }

  factory Choreography.fromJson(Map<String, dynamic> json) {
    return Choreography(
      id: json['id'],
      name: json['name'],
      danceId: json['danceId'],
      style: json['style'],
      dance: json['dance'],
      level: json['level'],
      steps: (json['steps'] as List)
          .map((stepJson) => ChoreographyStep.fromJson(stepJson))
          .toList(),
    );
  }
}

class ChoreographyStep {
  int? id;
  String description;
  String notes;

  ChoreographyStep({
    this.id,
    required this.description,
    this.notes = '',
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'description': description,
      'notes': notes,
    };
  }

  factory ChoreographyStep.fromJson(Map<String, dynamic> json) {
    return ChoreographyStep(
      id: json['id'],
      description: json['description'],
      notes: json['notes'] ?? '',
    );
  }
}
