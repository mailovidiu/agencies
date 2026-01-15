import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

class OpenAIConfig {
  static const String apiKey = String.fromEnvironment('OPENAI_PROXY_API_KEY');
  static const String endpoint = String.fromEnvironment('OPENAI_PROXY_ENDPOINT', 
    defaultValue: 'https://us-central1-u-s-departments-and-age-gnkn5k.cloudfunctions.net/dreamopenaiproxy');
  
  static const String gpt4oModel = 'gpt-4o';
  static const String gpt4oMiniModel = 'gpt-4o-mini';
  static const String o3MiniModel = 'o3-mini';
}

class OpenAIService {
  static Future<String> chatCompletion({
    required List<Map<String, dynamic>> messages,
    String model = OpenAIConfig.gpt4oModel,
    double temperature = 0.7,
    int maxTokens = 1000,
    Map<String, dynamic>? responseFormat,
  }) async {
    try {
      final url = Uri.parse(OpenAIConfig.endpoint);
      
      final requestBody = {
        'model': model,
        'messages': messages,
        'temperature': temperature,
        'max_tokens': maxTokens,
      };
      
      if (responseFormat != null) {
        requestBody['response_format'] = responseFormat;
      }
      
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${OpenAIConfig.apiKey}',
        },
        body: utf8.encode(jsonEncode(requestBody)),
      );
      
      if (response.statusCode == 200) {
        final decodedResponse = utf8.decode(response.bodyBytes);
        final data = jsonDecode(decodedResponse);
        
        if (data['choices'] != null && data['choices'].isNotEmpty) {
          return data['choices'][0]['message']['content'];
        } else {
          throw Exception('No response content from OpenAI');
        }
      } else {
        throw Exception('OpenAI API Error: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      throw Exception('Failed to get response from OpenAI: $e');
    }
  }
  
  static Future<String> generateDepartmentSummary(Map<String, dynamic> departmentData) async {
    final messages = [
      {
        'role': 'system',
        'content': '''You are a helpful assistant that creates concise, informative summaries of U.S. government departments and agencies. 
        Focus on key responsibilities, main services, and how they serve citizens. Keep summaries under 200 words and make them easy to understand.'''
      },
      {
        'role': 'user',
        'content': '''Please create a summary for this department/agency:
        
        Name: ${departmentData['name']}
        Description: ${departmentData['description']}
        Category: ${departmentData['category']}
        Website: ${departmentData['website']}
        Phone: ${departmentData['phone']}
        Address: ${departmentData['address']}
        Services: ${departmentData['services']?.join(', ')}'''
      }
    ];
    
    return await chatCompletion(
      messages: messages,
      model: OpenAIConfig.gpt4oMiniModel,
      temperature: 0.5,
      maxTokens: 300,
    );
  }
  
  static Future<String> compareDepartments(List<Map<String, dynamic>> departments) async {
    final departmentInfo = departments.map((dept) => {
      'name': dept['name'],
      'description': dept['description'],
      'category': dept['category'],
      'services': dept['services']?.join(', '),
    }).toList();
    
    final messages = [
      {
        'role': 'system',
        'content': '''You are a helpful assistant that compares U.S. government departments and agencies. 
        Provide clear, concise comparisons highlighting key differences in responsibilities, services, and target audiences.
        Focus on what makes each department unique and how they complement each other in serving citizens.'''
      },
      {
        'role': 'user',
        'content': '''Please compare these government departments/agencies and highlight their key differences and similarities:
        
        ${departmentInfo.map((dept) => '''
        Name: ${dept['name']}
        Description: ${dept['description']}
        Category: ${dept['category']}
        Services: ${dept['services']}
        ''').join('\n---\n')}'''
      }
    ];
    
    return await chatCompletion(
      messages: messages,
      model: OpenAIConfig.gpt4oModel,
      temperature: 0.6,
      maxTokens: 800,
    );
  }
  
  static Future<String> answerContextualQuestion({
    required String question,
    required Map<String, dynamic> departmentData,
  }) async {
    final messages = [
      {
        'role': 'system',
        'content': '''You are a knowledgeable assistant specializing in U.S. government departments and agencies.
        Answer questions accurately based on the provided department information and your knowledge of government operations.
        Be helpful, concise, and provide actionable information when possible. If you don't know something specific about the department, be honest about it.'''
      },
      {
        'role': 'user',
        'content': '''Based on this department information, please answer the following question:
        
        Department: ${departmentData['name']}
        Description: ${departmentData['description']}
        Category: ${departmentData['category']}
        Website: ${departmentData['website']}
        Phone: ${departmentData['phone']}
        Address: ${departmentData['address']}
        Services: ${departmentData['services']?.join(', ')}
        
        Question: $question'''
      }
    ];
    
    return await chatCompletion(
      messages: messages,
      model: OpenAIConfig.gpt4oModel,
      temperature: 0.7,
      maxTokens: 600,
    );
  }
  
  static Future<String> answerGeneralQuestion(String question) async {
    final messages = [
      {
        'role': 'system',
        'content': '''You are a helpful assistant specializing in U.S. government departments, agencies, and public services.
        Provide accurate, helpful information about government operations, services, and how citizens can access them.
        If the question is not related to government services, politely redirect to government-related topics.'''
      },
      {
        'role': 'user',
        'content': question
      }
    ];
    
    return await chatCompletion(
      messages: messages,
      model: OpenAIConfig.gpt4oModel,
      temperature: 0.7,
      maxTokens: 600,
    );
  }
}