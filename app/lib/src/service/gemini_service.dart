import 'package:form_app/src/service/api_key.dart';
import 'package:google_generative_ai/google_generative_ai.dart'; // 実際のパッケージに合わせる

class GeminiService {
  // シングルトンとして実装する例
  static final GeminiService _instance = GeminiService._internal();
  factory GeminiService() => _instance;
  GeminiService._internal() {
    // クライアントの初期化
    _geminiClient = GenerativeModel(model: 'gemini-1.5-flash-latest', apiKey: _apiKey);
  }

  final String _apiKey = gemini_api_key;
  late GenerativeModel _geminiClient;

  /// ユーザー入力に基づいてサジェストキーワードを生成する。
  /// 出力は改行区切りのテキストをパースしてリストに変換。
  Future<List<String>> generateSuggestions(String userInput) async {
    final prompt =
        "入力キーワードから始まる旅先エリア名をおすすめ順に10個提案してください。" 
        + "キーワードは単語のみとし10文字以内にしてください。補足説明は不要です。\n\n入力キーワード: $userInput\n\n出力は各キーワードを改行で区切ってください。"
        + "連番は出力しないでください。";

    // final response = await _geminiClient.generateContent([Content.text(prompt)]);

    // final rawOutput = response.text ?? ''; // 例: "大阪\n京都\n福岡\n..."
    final rawOutput = "沖縄\n大阪\n京都\n福岡\n"; // 仮の出力
    final suggestions = rawOutput
        .split('\n')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    // 10件以上ある場合は先頭10件だけ返す
    if (suggestions.length > 10) {
      return suggestions.sublist(0, 10);
    }
    return suggestions;
  }

  Future<List<String>> fetchPurposeData(String area) async {
    final prompt = "旅先エリア「$area」に関連する旅行目的を30個提案してください。" 
      + "30個の内容は改行で区切ってください。"
      + "連番は出力しないでください。"
      + "キーワードは単語のみとし10文字以内にしてください。補足説明は不要です。"
      + "キーワードはエリア特有のものを中心に提案してください。"
      + "参考ジャンル：観光、食事、ショッピング、アウトドア、歴史、文化、アート、イベント、温泉、スポーツ、リゾート、自然、アクティビティ、エンターテイメント、ホテル、宿泊、レジャー、祭り、神社、寺院、公園、動物園、水族館、美術館、博物館、工場見学、体験、散策、クルーズ、ショー";

    // 構造化データを返したい
    final response = await _geminiClient.generateContent([Content.text(prompt)]);

    // 30個までの目的を取得
    final purposes = response.text?.split('\n').map((s) => s.trim()).where((s) => s.isNotEmpty).toList() ?? [];
    return purposes.length > 30 ? purposes.sublist(0, 30) : purposes;
  }
}
