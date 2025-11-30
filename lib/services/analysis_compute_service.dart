import 'dart:convert';

/// Top-level function để xử lý JSON parsing trong isolate
/// Sử dụng với compute() để không block UI thread
/// Nhận List<String> với [rawResponse, originalReview]
Map<String, dynamic> parseAnalysisResponse(List<String> args) {
  final rawResponse = args[0];
  final originalReview = args[1];
  try {
    if (rawResponse.isEmpty) {
      throw Exception('Empty response from API');
    }

    String cleanedResponse = rawResponse.trim();

    // Remove markdown code blocks if present
    if (cleanedResponse.startsWith('```json')) {
      cleanedResponse = cleanedResponse.substring(7).trim();
    } else if (cleanedResponse.startsWith('```')) {
      cleanedResponse = cleanedResponse.substring(3).trim();
    }

    if (cleanedResponse.endsWith('```')) {
      cleanedResponse =
          cleanedResponse.substring(0, cleanedResponse.length - 3).trim();
    }

    // Try to extract JSON if there's extra text
    final jsonStart = cleanedResponse.indexOf('{');
    final jsonEnd = cleanedResponse.lastIndexOf('}');
    if (jsonStart != -1 && jsonEnd != -1 && jsonEnd > jsonStart) {
      cleanedResponse = cleanedResponse.substring(jsonStart, jsonEnd + 1);
    }

    print('Cleaned response: $cleanedResponse');
    final data = jsonDecode(cleanedResponse) as Map<String, dynamic>;

    // Validate required fields
    if (!data.containsKey('sentiment') || !data.containsKey('polarity_score')) {
      throw Exception('Missing required fields in response');
    }

    final double polarityScore = data['polarity_score'].toDouble();
    final int sentimentStrength = data['sentiment_strength'];

    Map<String, double> sentimentPercentages = {};

    if (data['sentiment'] == 'positive') {
      sentimentPercentages = {
        'positive_percent': sentimentStrength.toDouble(),
        'neutral_percent': 100 - sentimentStrength.toDouble(),
        'negative_percent': 0,
      };
    } else if (data['sentiment'] == 'negative') {
      sentimentPercentages = {
        'positive_percent': 0,
        'neutral_percent': 100 - sentimentStrength.toDouble(),
        'negative_percent': sentimentStrength.toDouble(),
      };
    } else {
      final remainingPercent = 100 - sentimentStrength.toDouble();
      sentimentPercentages = {
        'positive_percent': remainingPercent / 2,
        'neutral_percent': sentimentStrength.toDouble(),
        'negative_percent': remainingPercent / 2,
      };
    }

    return {
      'review': data['comment'],
      'main_keywords': List<String>.from(data['main_keywords']),
      'sentiment': data['sentiment'],
      'polarity_score': polarityScore,
      'sentiment_strength': sentimentStrength,
      'sentiment_percentages': sentimentPercentages,
    };
  } catch (e) {
    print('Error parsing analysis response in isolate: $e');
    print('Raw response was: $rawResponse');
    print('Original review: $originalReview');

    // Try to infer sentiment from review text as fallback
    String inferredSentiment = 'neutral';
    double inferredPolarity = 0.0;

    final reviewLower = originalReview.toLowerCase();
    final positiveWords = [
      'tốt',
      'hài lòng',
      'tuyệt',
      'đẹp',
      'chất lượng',
      'nhanh',
      'thích',
      'recommend',
      '5 sao',
      'rất tốt',
      'xuất sắc',
      'tuyệt vời',
    ];
    final negativeWords = [
      'kém',
      'thất vọng',
      'tệ',
      'chậm',
      'lỗi',
      'hỏng',
      'không tốt',
      'không hài lòng',
      '1 sao',
      '2 sao',
      'tồi',
      'dở',
    ];

    final hasPositive = positiveWords.any((word) => reviewLower.contains(word));
    final hasNegative = negativeWords.any((word) => reviewLower.contains(word));

    if (hasPositive && !hasNegative) {
      inferredSentiment = 'positive';
      inferredPolarity = 0.6;
    } else if (hasNegative && !hasPositive) {
      inferredSentiment = 'negative';
      inferredPolarity = -0.6;
    }

    return {
      'review': originalReview,
      'main_keywords': [],
      'sentiment': inferredSentiment,
      'polarity_score': inferredPolarity,
      'sentiment_strength': (inferredPolarity.abs() * 100).round(),
      'sentiment_percentages': {
        'positive_percent':
            inferredSentiment == 'positive'
                ? 60.0
                : (inferredSentiment == 'negative' ? 0.0 : 33.3),
        'neutral_percent': inferredSentiment == 'neutral' ? 60.0 : 20.0,
        'negative_percent':
            inferredSentiment == 'negative'
                ? 60.0
                : (inferredSentiment == 'positive' ? 0.0 : 33.3),
      },
    };
  }
}
