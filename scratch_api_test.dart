import 'dart:convert';
import 'dart:io';

Future<void> main() async {
  final rawText = 'This is a header. And this is a bullet point: point 1. And point 2.';
  
  // Format as ChatML assuming the backend doesn't apply a template
  final promptText = '<|im_start|>system\nYou are a helpful assistant that converts messy PDF text into structured Markdown.<|im_end|>\n<|im_start|>user\nConvert the following text to Markdown formatting:\n$rawText<|im_end|>\n<|im_start|>assistant\n';
  
  final httpClient = HttpClient();
  try {
    final predictUrl = Uri.parse('https://amielitos-text-to-markdown-api.hf.space/gradio_api/call/predict');
    final postRequest = await httpClient.postUrl(predictUrl);
    postRequest.headers.contentType = ContentType.json;
    postRequest.write(jsonEncode({"data": [promptText]}));
    
    final postResponse = await postRequest.close();
    final postBody = await postResponse.transform(utf8.decoder).join();
    final eventId = jsonDecode(postBody)['event_id'];
    
    final streamUrl = Uri.parse('https://amielitos-text-to-markdown-api.hf.space/gradio_api/call/predict/$eventId');
    final getRequest = await httpClient.getUrl(streamUrl);
    final getResponse = await getRequest.close();
    
    final responseBody = await getResponse.transform(utf8.decoder).join();
    print('\n--- RAW STREAM RESPONSE ---');
    print(responseBody);
    
  } catch (e) {
    print('Error: $e');
  } finally {
    httpClient.close();
  }
}
