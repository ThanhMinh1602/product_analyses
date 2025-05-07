import 'package:cloud_firestore/cloud_firestore.dart';

class AnalysisResult {
  final String id;
  final String userId;
  final FieldValue timestamp;
  final List<ReviewAnalysis> reviews;
  final double averageScore;
  final String overallSentiment;

  AnalysisResult({
    required this.id,
    required this.userId,
    required this.timestamp,
    required this.reviews,
    required this.averageScore,
    required this.overallSentiment,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'timestamp': timestamp,
      'reviews': reviews.map((r) => r.toJson()).toList(),
      'averageScore': averageScore,
      'overallSentiment': overallSentiment,
    };
  }

  factory AnalysisResult.fromJson(Map<String, dynamic> json) {
    return AnalysisResult(
      id: json['id'] as String,
      userId: json['userId'] as String,
      timestamp: json['timestamp'] as FieldValue,
      reviews:
          (json['reviews'] as List)
              .map((r) => ReviewAnalysis.fromJson(r as Map<String, dynamic>))
              .toList(),
      averageScore: json['averageScore'] as double,
      overallSentiment: json['overallSentiment'] as String,
    );
  }
}

class ReviewAnalysis {
  final String review;
  final String sentiment;
  final double score;
  final List<String> keywords;

  ReviewAnalysis({
    required this.review,
    required this.sentiment,
    required this.score,
    required this.keywords,
  });

  Map<String, dynamic> toJson() {
    return {
      'review': review,
      'sentiment': sentiment,
      'score': score,
      'keywords': keywords,
    };
  }

  factory ReviewAnalysis.fromJson(Map<String, dynamic> json) {
    return ReviewAnalysis(
      review: json['review'] as String,
      sentiment: json['sentiment'] as String,
      score: json['score'] as double,
      keywords: List<String>.from(json['keywords'] as List),
    );
  }
}
