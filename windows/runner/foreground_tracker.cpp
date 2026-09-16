#include "foreground_tracker.h"

#include <windows.h>

#include <chrono>
#include <filesystem>

namespace {

long long NowMs() {
  using namespace std::chrono;
  return duration_cast<milliseconds>(
             system_clock::now().time_since_epoch())
      .count();
}

std::wstring ExeOfPid(DWORD pid) {
  HANDLE proc = OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION, FALSE, pid);
  if (!proc) return L"";
  wchar_t path[MAX_PATH] = {0};
  DWORD size = MAX_PATH;
  std::wstring result;
  if (QueryFullProcessImageNameW(proc, 0, path, &size)) {
    result = path;
  }
  CloseHandle(proc);
  return result;
}

std::wstring BaseNameNoExt(const std::wstring& exe) {
  std::filesystem::path p(exe);
  return p.stem().wstring();
}

}  // namespace

ForegroundTracker& ForegroundTracker::Instance() {
  static ForegroundTracker instance;
  return instance;
}

ForegroundTracker::~ForegroundTracker() {
  Stop();
}

void ForegroundTracker::Start(int interval_seconds) {
  if (interval_seconds < 2) interval_seconds = 2;
  interval_ = interval_seconds;
  if (running_) return;
  running_ = true;
  thread_ = std::thread([this]() { Loop(); });
}

void ForegroundTracker::Stop() {
  running_ = false;
  if (thread_.joinable()) thread_.join();
}

void ForegroundTracker::Loop() {
  long long last_tick = NowMs();
  while (running_) {
    int sec = interval_.load();
    for (int i = 0; i < sec * 2 && running_; ++i) {
      Sleep(500);
    }
    long long now = NowMs();
    Sample(now, last_tick);
    last_tick = now;
  }
}

void ForegroundTracker::Sample(long long now_ms, long long last_tick_ms) {
  HWND hwnd = GetForegroundWindow();
  std::wstring exe;
  if (hwnd) {
    DWORD pid = 0;
    GetWindowThreadProcessId(hwnd, &pid);
    if (pid) exe = ExeOfPid(pid);
  }

  std::lock_guard<std::mutex> lock(mutex_);
  if (exe == current_exe_ && !exe.empty()) {
    current_end_ = now_ms;
    return;
  }

  // 收尾旧片段（至少 2 秒才记录，过滤瞬时切换）
  if (!current_exe_.empty() && current_end_ - current_start_ >= 2000) {
    buffered_.push_back(ForegroundSession{
        current_exe_, current_name_, current_start_, current_end_});
  }

  if (exe.empty()) {
    current_exe_.clear();
    current_name_.clear();
    current_start_ = 0;
    current_end_ = 0;
    return;
  }

  current_exe_ = exe;
  current_name_ = BaseNameNoExt(exe);
  current_start_ = last_tick_ms;
  current_end_ = now_ms;
}

std::vector<ForegroundSession> ForegroundTracker::Pull() {
  std::lock_guard<std::mutex> lock(mutex_);
  std::vector<ForegroundSession> out;
  out.swap(buffered_);
  // 正在进行的片段也一并给出（到当前时刻），保留在内存中继续累积
  if (!current_exe_.empty()) {
    long long now = NowMs();
    out.push_back(ForegroundSession{
        current_exe_, current_name_, current_start_, now});
    // 下一段从现在开始，避免重复计数
    current_start_ = now;
  }
  return out;
}

bool ForegroundTracker::SetAutoStart(bool on) {
  const wchar_t* kRunPath =
      L"Software\\Microsoft\\Windows\\CurrentVersion\\Run";
  const wchar_t* kValueName = L"ScreenTimeJournal";
  HKEY key;
  if (RegOpenKeyExW(HKEY_CURRENT_USER, kRunPath, 0, KEY_SET_VALUE | KEY_READ,
                    &key) != ERROR_SUCCESS) {
    return false;
  }
  bool ok = true;
  if (on) {
    wchar_t exe[MAX_PATH] = {0};
    if (GetModuleFileNameW(nullptr, exe, MAX_PATH) == 0) {
      ok = false;
    } else {
      std::wstring cmd = L"\"";
      cmd += exe;
      cmd += L"\"";
      ok = RegSetValueExW(key, kValueName, 0, REG_SZ,
                          reinterpret_cast<const BYTE*>(cmd.c_str()),
                          static_cast<DWORD>((cmd.size() + 1) * sizeof(wchar_t))) ==
           ERROR_SUCCESS;
    }
  } else {
    RegDeleteValueW(key, kValueName);
  }
  RegCloseKey(key);
  return ok;
}

bool ForegroundTracker::GetAutoStart() {
  const wchar_t* kRunPath =
      L"Software\\Microsoft\\Windows\\CurrentVersion\\Run";
  const wchar_t* kValueName = L"ScreenTimeJournal";
  HKEY key;
  if (RegOpenKeyExW(HKEY_CURRENT_USER, kRunPath, 0, KEY_READ, &key) !=
      ERROR_SUCCESS) {
    return false;
  }
  DWORD type = 0;
  DWORD size = 0;
  bool found = false;
  if (RegQueryValueExW(key, kValueName, nullptr, &type, nullptr, &size) ==
      ERROR_SUCCESS) {
    found = true;
  }
  RegCloseKey(key);
  return found;
}

void ForegroundTracker::MinimizeAll() {
  // Win + M：最小化全部窗口，等效“回到桌面”
  keybd_event(VK_LWIN, 0, 0, 0);
  keybd_event('M', 0, 0, 0);
  keybd_event('M', 0, KEYEVENTF_KEYUP, 0);
  keybd_event(VK_LWIN, 0, KEYEVENTF_KEYUP, 0);
}

std::string ForegroundTracker::WideToUtf8(const std::wstring& w) {
  if (w.empty()) return {};
  int len = WideCharToMultiByte(CP_UTF8, 0, w.c_str(),
                                static_cast<int>(w.size()), nullptr, 0,
                                nullptr, nullptr);
  std::string s(len, 0);
  WideCharToMultiByte(CP_UTF8, 0, w.c_str(), static_cast<int>(w.size()),
                      s.data(), len, nullptr, nullptr);
  return s;
}
