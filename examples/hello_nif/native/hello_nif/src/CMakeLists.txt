add_library(nif nif.cpp)
target_link_libraries(
  nif PRIVATE project_options project_warnings erl_interface erl_runtime)
