#ifndef RUNNER_WIN32_WINDOW_H_
#define RUNNER_WIN32_WINDOW_H_

#include <windows.h>

#include <functional>
#include <memory>
#include <string>

// Win32 窗口基类 — 创建窗口壳 + 消息路由 + DPI 缩放
class Win32Window
{
public:
  struct Point
  {
    unsigned int x;
    unsigned int y;
    Point(unsigned int x, unsigned int y) : x(x), y(y) {}
  };

  struct Size
  {
    unsigned int width;
    unsigned int height;
    Size(unsigned int width, unsigned int height)
        : width(width), height(height) {}
  };

  Win32Window();
  virtual ~Win32Window();

  // 创建窗口（不可见，由 window_manager 控制显示）
  bool Create(const std::wstring &title, const Point &origin, const Size &size);

  // 释放窗口资源
  void Destroy();

  // 嵌入 Flutter 视图
  void SetChildContent(HWND content);

  // 获取窗口句柄
  HWND GetHandle();

  // 关闭窗口时是否退出应用
  void SetQuitOnClose(bool quit_on_close);

  // 获取客户区矩形
  RECT GetClientArea();

protected:
  // 消息处理（子类可重写）
  virtual LRESULT MessageHandler(HWND window,
                                 UINT const message,
                                 WPARAM const wparam,
                                 LPARAM const lparam) noexcept;

  virtual bool OnCreate();
  virtual void OnDestroy();

private:
  friend class WindowClassRegistrar;

  // Win32 消息回调
  static LRESULT CALLBACK WndProc(HWND const window,
                                  UINT const message,
                                  WPARAM const wparam,
                                  LPARAM const lparam) noexcept;

  static Win32Window *GetThisFromHandle(HWND const window) noexcept;

  bool quit_on_close_ = false;
  HWND window_handle_ = nullptr;
  HWND child_content_ = nullptr;
};

#endif // RUNNER_WIN32_WINDOW_H_
