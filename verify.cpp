#include <cstdlib>
#include <string>
#include <format>
#include <iostream>

int main()
{
  std::string name = "musl+clang";
  int v = 20;
  std::string out = std::format("Hello from {} with C++{}", name, v);
  std::cout << out << std::endl;
  return out == "Hello from musl+clang with C++20" ? EXIT_SUCCESS : EXIT_FAILURE;
}
