# 超級單字 App - 性能分析報告

## 📊 執行日期
2026-01-16

## 🎯 分析範圍
- Flutter 應用程式架構
- 網路請求與快取策略
- UI 渲染性能
- 記憶體使用

---

## 🔴 發現的主要性能問題

### 1. 重複的 setState 導致不必要的重绘
**位置**: `lib/vocabulary_list_screen.dart:30-48`

**問題描述**:
```dart
Future<void> _loadVocabularyList() async {
  // 1. 先從快取載入 - 觸發第一次 setState
  final cachedData = await _loadFromCache();
  if (cachedData != null && cachedData.isNotEmpty) {
    setState(() {
      _vocabularyList = cachedData;
      _isLoading = false;
      _isFromCache = true;
    });
  }

  // 2. 立即從網路獲取 - 觸發第二次 setState
  await _fetchFromNetwork();
}
```

**影響**:
- UI 在短時間內重繪兩次
- 用戶可能看到畫面閃爍
- 浪費 CPU 資源

**嚴重程度**: 🟡 中等

---

### 2. 主線程阻塞 - JSON 解碼
**位置**:
- `lib/vocabulary_list_screen.dart:56`
- `lib/vocabulary_list_screen.dart:83`

**問題描述**:
```dart
// 在主線程執行 JSON 解碼
return json.decode(cachedJson) as List<dynamic>;
final decodedData = json.decode(utf8.decode(response.bodyBytes)) as List<dynamic>;
```

**影響**:
- 大型單字列表（數百或數千個單字）會阻塞 UI 線程
- 導致應用程式卡頓、無響應
- 用戶體驗差

**嚴重程度**: 🔴 高

---

### 3. 網路請求沒有超時設置
**位置**: `lib/vocabulary_list_screen.dart:80`

**問題描述**:
```dart
final response = await http.get(Uri.parse(url));
// 沒有設置 timeout 參數
```

**影響**:
- 網路緩慢時用戶可能長時間等待
- 沒有友好的錯誤提示
- 可能導致應用程式假死

**嚴重程度**: 🟡 中等

---

### 4. ListView 性能未優化
**位置**: `lib/vocabulary_list_screen.dart:154`

**問題描述**:
```dart
ListView.builder(
  padding: const EdgeInsets.all(8.0),
  itemCount: _vocabularyList.length,
  itemBuilder: (context, index) {
    // 沒有使用任何性能優化參數
  }
)
```

**影響**:
- 長列表滾動可能不流暢
- 記憶體使用不夠優化
- 特別是在低階設備上會有明顯卡頓

**嚴重程度**: 🟡 中等

---

### 5. 沒有取消正在進行的請求
**位置**: `lib/vocabulary_list_screen.dart:77`

**問題描述**:
- 用戶快速切換級別時，前一個請求不會被取消
- 多次點擊重新載入會產生多個並發請求
- 沒有使用 `CancelToken` 或類似機制

**影響**:
- 浪費網路資源和流量
- 可能出現競態條件（race condition）
- 錯誤的數據可能覆蓋正確的數據

**嚴重程度**: 🟡 中等

---

### 6. SharedPreferences 大數據存儲
**位置**: `lib/vocabulary_list_screen.dart:64-74`

**問題描述**:
```dart
Future<void> _saveToCache(List<dynamic> data) async {
  final prefs = await SharedPreferences.getInstance();
  final jsonString = json.encode(data);
  await prefs.setString(_cacheKey, jsonString);
}
```

**影響**:
- SharedPreferences 不適合存儲大型數據
- 可能導致讀寫性能問題
- 建議使用資料庫（如 SQLite、Hive）

**嚴重程度**: 🟡 中等

---

## 💡 建議的優化方案

### 優先級 1 - 立即修復

#### 1.1 將 JSON 解碼移到 Isolate
```dart
import 'dart:isolate';

// 在背景線程解碼 JSON
Future<List<dynamic>> _decodeJsonInBackground(String jsonString) async {
  return await compute(_parseJson, jsonString);
}

List<dynamic> _parseJson(String jsonString) {
  return json.decode(jsonString) as List<dynamic>;
}
```

#### 1.2 添加網路請求超時
```dart
final response = await http.get(
  Uri.parse(url),
  headers: {'Connection': 'keep-alive'},
).timeout(
  const Duration(seconds: 15),
  onTimeout: () {
    throw TimeoutException('請求超時');
  },
);
```

### 優先級 2 - 重要優化

#### 2.1 優化快取載入策略
```dart
Future<void> _loadVocabularyList() async {
  setState(() {
    _isLoading = true;
  });

  // 並行執行快取和網路請求
  final results = await Future.wait([
    _loadFromCache(),
    _fetchFromNetwork(),
  ]);

  // 優先使用網路數據，失敗才用快取
  final networkData = results[1];
  final cacheData = results[0];

  setState(() {
    _vocabularyList = networkData ?? cacheData ?? [];
    _isLoading = false;
    _isFromCache = networkData == null && cacheData != null;
  });
}
```

#### 2.2 添加請求取消機制
```dart
import 'dart:async';

class _VocabularyListScreenState extends State<VocabularyListScreen> {
  http.Client? _httpClient;

  @override
  void dispose() {
    _httpClient?.close();
    super.dispose();
  }

  Future<void> _fetchFromNetwork() async {
    _httpClient?.close();
    _httpClient = http.Client();

    try {
      final response = await _httpClient!.get(Uri.parse(url));
      // ...
    } catch (e) {
      // ...
    }
  }
}
```

### 優先級 3 - 性能提升

#### 3.1 優化 ListView
```dart
ListView.builder(
  padding: const EdgeInsets.all(8.0),
  itemCount: _vocabularyList.length,
  cacheExtent: 500, // 增加快取範圍
  itemBuilder: (context, index) {
    // 使用 const 和 key 優化
    return VocabularyCard(
      key: ValueKey(_vocabularyList[index]['word']),
      wordData: _vocabularyList[index],
      index: index,
    );
  },
)
```

#### 3.2 使用更好的本地儲存方案
考慮使用：
- **Hive**: 輕量級、快速的 NoSQL 資料庫
- **SQLite**: 關聯式資料庫，適合複雜查詢
- **ObjectBox**: 高性能的物件導向資料庫

---

## 📈 預期改善效果

| 優化項目 | 預期改善 |
|---------|---------|
| JSON 解碼移至背景線程 | 減少 UI 卡頓 70-90% |
| 優化快取策略 | 減少不必要的重繪 50% |
| 添加請求超時 | 改善用戶體驗，減少假死 |
| ListView 優化 | 提升滾動流暢度 20-30% |
| 更換儲存方案 | 提升讀寫速度 2-5 倍 |

---

## 🧪 建議的測試方法

1. **性能測試**:
   - 使用 Flutter DevTools 的 Performance 頁面
   - 測試不同級別的載入時間
   - 檢查 UI 線程的 jank（卡頓）

2. **壓力測試**:
   - 快速切換不同級別
   - 多次點擊重新載入
   - 模擬慢速網路環境

3. **記憶體測試**:
   - 使用 DevTools 監控記憶體使用
   - 檢查是否有記憶體洩漏

---

## 📝 結論

這個 App 的主要性能問題集中在：
1. **UI 線程阻塞**（最嚴重）
2. **不必要的重繪**
3. **缺乏網路優化**

建議優先修復「JSON 解碼」和「網路超時」問題，這兩個改動相對簡單但效果顯著。

---

## 🔗 相關資源

- [Flutter Performance Best Practices](https://docs.flutter.dev/perf/best-practices)
- [Isolate 使用指南](https://dart.dev/guides/language/concurrency)
- [Compute Function](https://api.flutter.dev/flutter/foundation/compute-constant.html)
