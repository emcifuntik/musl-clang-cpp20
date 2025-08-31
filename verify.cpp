#include <cstdlib>
#include <string>
#include <format>
#include <iostream>
#include <atomic>
#include <thread>

std::atomic_char32_t i = 0;

struct yeah { ~yeah() { i++; } };
thread_local yeah x;

int main()
{
  std::string name = "musl+clang";
  int v = 20;
  std::atomic<int> counter{0};
  counter++;
  std::thread{ []() { i++; } }.join();
  std::string out = std::format("Hello from {} with C++{} (atomic count: {})", name, v, counter.load());
  std::cout << out << std::endl;
  return out == "Hello from musl+clang with C++20 (atomic count: 1)" ? EXIT_SUCCESS : EXIT_FAILURE;
}
