import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html_parser;
import 'dart:convert';

class TikiService {
  /// Extract product ID from Tiki URL
  /// Example: https://tiki.vn/sach-...-p275406600.html
  /// Returns: 275406600
  static String? extractProductId(String url) {
    try {
      // Match pattern: -p{number}.html
      final regex = RegExp(r'-p(\d+)\.html');
      final match = regex.firstMatch(url);
      if (match != null) {
        return match.group(1);
      }
      return null;
    } catch (e) {
      print('Error extracting product ID: $e');
      return null;
    }
  }

  /// Extract SPID (Seller Product ID) from Tiki URL query parameters
  /// Example: https://tiki.vn/...?spid=275406603
  /// Returns: 275406603
  static String? extractSpid(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.queryParameters['spid'];
    } catch (e) {
      print('Error extracting SPID: $e');
      return null;
    }
  }

  /// Validate if URL is a valid Tiki product URL
  static bool isValidTikiUrl(String url) {
    return url.contains('tiki.vn') &&
        (extractSpid(url) != null || extractProductId(url) != null);
  }

  /// Fetch reviews from Tiki product page
  /// Returns list of review texts
  static Future<List<String>> fetchReviewsFromTiki(String url) async {
    try {
      final productId = extractProductId(url);
      final spid = extractSpid(url);

      // Need at least one of product_id or spid
      if (productId == null && spid == null) {
        throw Exception('Không thể lấy product_id hoặc spid từ URL');
      }

      final allReviews = <String>[];
      const int limit = 20; // Max reviews per page (Tiki API limitation)

      print('Fetching reviews - product_id: $productId, spid: $spid');

      // Build API URL - only fetch first page
      var apiUrlString =
          'https://tiki.vn/api/v2/reviews?'
          'limit=$limit&'
          'include=comments&'
          'page=1';

      // Add spid if available
      if (spid != null && spid.isNotEmpty) {
        apiUrlString += '&spid=$spid';
      }

      // Add product_id if available
      if (productId != null && productId.isNotEmpty) {
        apiUrlString += '&product_id=$productId';
      }

      final apiUrl = Uri.parse(apiUrlString);
      print('API URL: $apiUrl');

      final response = await http.get(
        apiUrl,
        headers: {
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
          'Accept': 'application/json, text/plain, */*',
          'Accept-Language': 'vi-VN,vi;q=0.9,en-US;q=0.8,en;q=0.7',
          'Referer': url,
          'Origin': 'https://tiki.vn',
        },
      );

      print('Response status: ${response.statusCode}');
      print('Response body length: ${response.body.length}');

      if (response.statusCode == 200) {
        try {
          final data = jsonDecode(response.body);
          print('Parsed data keys: ${data.keys.toList()}');

          // Parse reviews from data array
          if (data['data'] != null && data['data'] is List) {
            final dataList = data['data'] as List;
            print('Found ${dataList.length} reviews');

            for (var review in dataList) {
              if (review is Map<String, dynamic>) {
                final content = review['content'];
                if (content != null && content.toString().trim().isNotEmpty) {
                  // Clean content: remove \r\n and extra whitespace
                  final cleanContent =
                      content
                          .toString()
                          .replaceAll('\r\n', ' ')
                          .replaceAll('\r', ' ')
                          .replaceAll('\n', ' ')
                          .replaceAll(RegExp(r'\s+'), ' ')
                          .trim();
                  if (cleanContent.isNotEmpty) {
                    allReviews.add(cleanContent);
                  }
                }
              }
            }
          } else {
            print('No data array found or data is not a list');
          }
        } catch (e) {
          print('Error parsing JSON: $e');
          if (response.body.length > 1000) {
            print('Response body: ${response.body.substring(0, 1000)}...');
          } else {
            print('Response body: ${response.body}');
          }
          // Fallback to HTML scraping
          if (productId != null) {
            return await _scrapeReviewsFromHTML(url, productId);
          }
          throw Exception('Không thể parse response từ API');
        }
      } else if (response.statusCode == 404 || response.statusCode == 403) {
        print('API returned ${response.statusCode}, trying fallback');
        // If API fails, try fallback
        if (productId != null) {
          return await _scrapeReviewsFromHTML(url, productId);
        }
        throw Exception('API trả về lỗi ${response.statusCode}');
      } else {
        print('Unexpected status code: ${response.statusCode}');
        if (response.body.length > 500) {
          print('Response: ${response.body.substring(0, 500)}...');
        } else {
          print('Response: ${response.body}');
        }
        // For other errors, try fallback
        if (productId != null) {
          return await _scrapeReviewsFromHTML(url, productId);
        }
        throw Exception('API trả về lỗi ${response.statusCode}');
      }

      print('Total reviews fetched: ${allReviews.length}');

      if (allReviews.isEmpty) {
        print('No reviews found, trying HTML fallback');
        // Fallback: Try scraping from HTML page
        if (productId != null) {
          return await _scrapeReviewsFromHTML(url, productId);
        }
        throw Exception('Không tìm thấy đánh giá nào cho sản phẩm này');
      }

      return allReviews;
    } catch (e, stackTrace) {
      print('Error fetching reviews from API: $e');
      print('Stack trace: $stackTrace');
      // Fallback to HTML scraping
      final productId = extractProductId(url);
      if (productId != null) {
        return await _scrapeReviewsFromHTML(url, productId);
      }
      throw Exception('Không thể lấy đánh giá từ Tiki: $e');
    }
  }

  /// Fallback method: Scrape reviews from HTML page
  static Future<List<String>> _scrapeReviewsFromHTML(
    String url,
    String productId,
  ) async {
    try {
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
          'Accept':
              'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
        },
      );

      if (response.statusCode == 200) {
        final document = html_parser.parse(response.body);
        final reviews = <String>[];

        // Try multiple selectors for Tiki review structure
        final reviewSelectors = [
          '.review-item .review-content',
          '.review-content',
          '[data-testid="review-content"]',
          '.ReviewItem__content',
          '.review-text',
        ];

        for (var selector in reviewSelectors) {
          final elements = document.querySelectorAll(selector);
          if (elements.isNotEmpty) {
            for (var element in elements) {
              final text = element.text.trim();
              if (text.isNotEmpty && text.length > 10) {
                reviews.add(text);
              }
            }
            break; // Use first working selector
          }
        }

        // If no reviews found with selectors, try to find in script tags (JSON data)
        if (reviews.isEmpty) {
          final scriptTags = document.querySelectorAll('script');
          for (var script in scriptTags) {
            final scriptContent = script.text;
            if (scriptContent.contains('reviews') ||
                scriptContent.contains('review')) {
              try {
                // Try to extract JSON data from script
                final jsonMatch = RegExp(
                  r'\{.*"reviews".*\}',
                  dotAll: true,
                ).firstMatch(scriptContent);
                if (jsonMatch != null) {
                  final jsonData = jsonDecode(jsonMatch.group(0)!);
                  if (jsonData['reviews'] != null) {
                    for (var review in jsonData['reviews']) {
                      if (review['content'] != null) {
                        reviews.add(review['content'].toString().trim());
                      }
                    }
                  }
                }
              } catch (e) {
                // Continue to next script tag
              }
            }
          }
        }

        return reviews;
      } else {
        throw Exception('Không thể tải trang sản phẩm: ${response.statusCode}');
      }
    } catch (e) {
      print('Error scraping reviews from HTML: $e');
      throw Exception('Không thể lấy đánh giá từ trang web: $e');
    }
  }

  /// Get product name from Tiki URL
  static Future<String?> getProductName(String url) async {
    try {
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
          'Accept':
              'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
        },
      );

      if (response.statusCode == 200) {
        final document = html_parser.parse(response.body);

        // Try to get product name from title or h1
        final title =
            document.querySelector('h1')?.text ??
            document.querySelector('title')?.text ??
            document.querySelector('[data-testid="product-name"]')?.text;

        return title?.trim();
      }
      return null;
    } catch (e) {
      print('Error getting product name: $e');
      return null;
    }
  }
}
