#include "flutter_window.h"

#include <optional>

#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>

#include "foreground_tracker.h"
#include "flutter/generated_plugin_registrant.h"

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  RECT frame = GetClientArea();

  // The size here must match the window dimensions to avoid unnecessary surface
  // creation / destruction in the startup path.
  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  // Ensure that basic setup of the controller was successful.
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());
  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  RegisterNativeChannels();

  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    this->Show();
  });

  // Flutter can complete the first frame before the "show window" callback is
  // registered. The following call ensures a frame is pending to ensure the
  // window is shown. It is a no-op if the first frame hasn't completed yet.
  flutter_controller_->ForceRedraw();

  return true;
}

void FlutterWindow::OnDestroy() {
  channel_ = nullptr;
  ForegroundTracker::Instance().Stop();
  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  // Give Flutter, including plugins, an opportunity to handle window messages.
  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    if (result) {
      return *result;
    }
  }

  switch (message) {
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}

void FlutterWindow::RegisterNativeChannels() {
  auto messenger = flutter_controller_->engine()->messenger();
  channel_ = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      messenger, "com.screenjournal.app/native",
      &flutter::StandardMethodCodec::GetInstance());

  channel_->SetMethodCallHandler(
      [](const flutter::MethodCall<flutter::EncodableValue>& call,
         std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>
             result) {
        const std::string& name = call.method_name();

        if (name == "startTracking") {
          int interval = 5;
          const auto* args = call.arguments();
          if (args) {
            const flutter::internal::EncodableValueVariant& v = *args;
            if (std::holds_alternative<int32_t>(v)) {
              interval = std::get<int32_t>(v);
            } else if (std::holds_alternative<int64_t>(v)) {
              interval = static_cast<int>(std::get<int64_t>(v));
            }
          }
          ForegroundTracker::Instance().Start(interval);
          result->Success();
        } else if (name == "pullForegroundSessions") {
          auto sessions = ForegroundTracker::Instance().Pull();
          flutter::EncodableList list;
          for (const auto& s : sessions) {
            flutter::EncodableMap m;
            m[flutter::EncodableValue("exe")] =
                flutter::EncodableValue(ForegroundTracker::WideToUtf8(s.exe));
            m[flutter::EncodableValue("name")] =
                flutter::EncodableValue(ForegroundTracker::WideToUtf8(s.name));
            m[flutter::EncodableValue("startMs")] =
                flutter::EncodableValue(s.start_ms);
            m[flutter::EncodableValue("endMs")] =
                flutter::EncodableValue(s.end_ms);
            list.push_back(flutter::EncodableValue(m));
          }
          result->Success(flutter::EncodableValue(list));
        } else if (name == "setAutoStart") {
          bool on = false;
          const auto* args = call.arguments();
          if (args) {
            const flutter::internal::EncodableValueVariant& v = *args;
            if (std::holds_alternative<bool>(v)) on = std::get<bool>(v);
          }
          result->Success(ForegroundTracker::Instance().SetAutoStart(on));
        } else if (name == "getAutoStart") {
          result->Success(ForegroundTracker::Instance().GetAutoStart());
        } else if (name == "getDeviceName") {
          wchar_t computer_name[MAX_COMPUTERNAME_LENGTH + 1];
          DWORD size = MAX_COMPUTERNAME_LENGTH + 1;
          std::string out = "Windows PC";
          if (GetComputerNameW(computer_name, &size)) {
            out = ForegroundTracker::WideToUtf8(computer_name);
          }
          result->Success(flutter::EncodableValue(out));
        } else if (name == "minimizeToHome") {
          ForegroundTracker::Instance().MinimizeAll();
          result->Success();
        } else {
          result->NotImplemented();
        }
      });
}
