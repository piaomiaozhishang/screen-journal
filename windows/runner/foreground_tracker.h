#ifndef RUNNER_FOREGROUND_TRACKER_H_
#define RUNNER_FOREGROUND_TRACKER_H_

#include <atomic>
#include <mutex>
#include <string>
#include <thread>
#include <vector>

struct ForegroundSession {
  std::wstring exe;       // 完整 exe 路径，作为应用唯一标识
  std::wstring name;      // 去掉扩展名的 exe 文件名
  long long start_ms;     // Unix 毫秒
  long long end_ms;
};

// 定时采样前台窗口所属进程，合并为使用片段；Dart 侧定时拉取入库。
class ForegroundTracker {
 public:
  static ForegroundTracker& Instance();

  void Start(int interval_seconds);
  void Stop();
  std::vector<ForegroundSession> Pull();

  bool SetAutoStart(bool on);
  bool GetAutoStart();
  void MinimizeAll();

  static std::string WideToUtf8(const std::wstring& w);

 private:
  ForegroundTracker() = default;
  ~ForegroundTracker();
  void Loop();
  void Sample(long long now_ms, long long last_tick_ms);

  std::atomic<bool> running_{false};
  std::atomic<int> interval_{5};
  std::thread thread_;

  std::mutex mutex_;
  std::vector<ForegroundSession> buffered_;

  // 当前正在累积的片段
  std::wstring current_exe_;
  std::wstring current_name_;
  long long current_start_ = 0;
  long long current_end_ = 0;
};

#endif  // RUNNER_FOREGROUND_TRACKER_H_
