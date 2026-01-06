import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class VocabularyListScreen extends StatefulWidget {
  final int level;

  const VocabularyListScreen({Key? key, required this.level}) : super(key: key);

  @override
  _VocabularyListScreenState createState() => _VocabularyListScreenState();
}

class _VocabularyListScreenState extends State<VocabularyListScreen> {
  List<dynamic> _vocabularyList = [];
  bool _isLoading = true;
  String? _errorMessage;
  bool _isFromCache = false;

  @override
  void initState() {
    super.initState();
    _loadVocabularyList();
  }

  String get _cacheKey => 'vocabulary_level_${widget.level}';

  // 載入單字列表（先從快取，再從網路）
  Future<void> _loadVocabularyList() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    // 1. 先嘗試從快取載入
    final cachedData = await _loadFromCache();
    if (cachedData != null && cachedData.isNotEmpty) {
      setState(() {
        _vocabularyList = cachedData;
        _isLoading = false;
        _isFromCache = true;
      });
    }

    // 2. 同時從網路獲取最新資料
    await _fetchFromNetwork();
  }

  // 從快取讀取資料
  Future<List<dynamic>?> _loadFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedJson = prefs.getString(_cacheKey);
      if (cachedJson != null) {
        return json.decode(cachedJson) as List<dynamic>;
      }
    } catch (e) {
      debugPrint('Failed to load from cache: $e');
    }
    return null;
  }

  // 儲存資料到快取
  Future<void> _saveToCache(List<dynamic> data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = json.encode(data);
      await prefs.setString(_cacheKey, jsonString);
      debugPrint('Saved ${data.length} words to cache for level ${widget.level}');
    } catch (e) {
      debugPrint('Failed to save to cache: $e');
    }
  }

  // 從網路獲取資料
  Future<void> _fetchFromNetwork() async {
    try {
      final url = 'https://raw.githubusercontent.com/AppPeterPan/TaiwanSchoolEnglishVocabulary/main/${widget.level}%E7%B4%9A.json';
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final decodedData = json.decode(utf8.decode(response.bodyBytes)) as List<dynamic>;

        // 儲存到快取
        await _saveToCache(decodedData);

        // 更新 UI
        if (mounted) {
          setState(() {
            _vocabularyList = decodedData;
            _isLoading = false;
            _isFromCache = false;
            _errorMessage = null;
          });
        }
      } else {
        // 網路請求失敗
        if (_vocabularyList.isEmpty) {
          // 如果沒有快取資料，顯示錯誤
          setState(() {
            _errorMessage = '無法載入單字列表 (錯誤碼: ${response.statusCode})';
            _isLoading = false;
          });
        } else {
          // 有快取資料，只顯示提示
          _showCacheWarning();
        }
      }
    } catch (e) {
      // 網路連線失敗
      if (_vocabularyList.isEmpty) {
        // 如果沒有快取資料，顯示錯誤
        setState(() {
          _errorMessage = '網路連線失敗，請檢查網路設定';
          _isLoading = false;
        });
      } else {
        // 有快取資料，只顯示提示
        _showCacheWarning();
      }
    }
  }

  // 顯示快取警告
  void _showCacheWarning() {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.offline_bolt, color: Colors.white),
              SizedBox(width: 8),
              Text('網路連線失敗，顯示快取資料'),
            ],
          ),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  // 手動重新載入
  Future<void> _refreshVocabularyList() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    await _fetchFromNetwork();
  }

  Widget _buildList() {
    return ListView.builder(
      padding: const EdgeInsets.all(8.0),
      itemCount: _vocabularyList.length,
      itemBuilder: (context, index) {
        final wordData = _vocabularyList[index];
        final word = wordData['word'] ?? '';

        // 安全地取得定義
        String definition = '無定義';
        if (wordData['definitions'] != null &&
            wordData['definitions'] is List &&
            (wordData['definitions'] as List).isNotEmpty) {
          definition = wordData['definitions'][0]['text'] ?? '無定義';
        }

        return Card(
          margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
          elevation: 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => BigWordPage(
                    word: word,
                    definition: definition,
                  ),
                ),
              );
            },
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Text(
                        '${index + 1}',
                        style: TextStyle(
                          color: Colors.blue.shade700,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          word,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          definition,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade700,
                            height: 1.3,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_ios,
                    size: 16,
                    color: Colors.grey.shade400,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(
            '載入單字中...',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red.shade300,
            ),
            const SizedBox(height: 16),
            Text(
              _errorMessage ?? '發生錯誤',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _refreshVocabularyList,
              icon: const Icon(Icons.refresh),
              label: const Text('重新載入'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('英文 ${widget.level} 級單字'),
        centerTitle: true,
        actions: [
          if (_isFromCache)
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.offline_bolt,
                        size: 16,
                        color: Colors.orange.shade700,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '離線',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.orange.shade700,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.info_outline),
            tooltip: '共 ${_vocabularyList.length} 個單字',
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('本級別共有 ${_vocabularyList.length} 個單字'),
                  duration: const Duration(seconds: 2),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: '重新載入',
            onPressed: _refreshVocabularyList,
          ),
        ],
      ),
      body: _isLoading
          ? _buildLoadingState()
          : _errorMessage != null
              ? _buildErrorState()
              : _buildList(),
    );
  }
}

class BigWordPage extends StatelessWidget {
  final String word;
  final String definition;

  const BigWordPage({
    Key? key,
    required this.word,
    required this.definition,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(word),
        centerTitle: true,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.blue.shade50,
              Colors.white,
            ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 20),
                // 單字卡片
                Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(32.0),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.blue.shade400,
                          Colors.blue.shade600,
                        ],
                      ),
                    ),
                    child: Column(
                      children: [
                        const Icon(
                          Icons.book,
                          size: 48,
                          color: Colors.white,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          word,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                // 定義區域
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.description,
                              color: Colors.blue.shade700,
                              size: 24,
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              '定義',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.grey.shade200,
                              width: 1,
                            ),
                          ),
                          child: Text(
                            definition,
                            style: const TextStyle(
                              fontSize: 18,
                              height: 1.6,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                // 返回按鈕
                OutlinedButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('返回單字列表'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
