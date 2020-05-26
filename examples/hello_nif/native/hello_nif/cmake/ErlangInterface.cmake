set(ERL_BIN_PATH
    $ENV{ERL_HOME}/bin
    /usr/bin
    /usr/local/bin
    /opt/local/bin
    /sw/bin)

find_program(ERL_RUNTIME NAMES erl PATHS ${ERL_BIN_PATH})
find_program(ERL_COMPILE NAMES erlc PATHS ${ERL_BIN_PATH})

execute_process(COMMAND
                erl -noshell -eval "io:format(\"~s\", [code:lib_dir()])" -s erlang halt
                OUTPUT_VARIABLE ERL_OTP_LIB_DIR)

execute_process(COMMAND
                erl -noshell -eval "io:format(\"~s\", [code:root_dir()])" -s erlang halt
                OUTPUT_VARIABLE ERL_OTP_ROOT_DIR)

if(ERL_OTP_LIB_DIR AND ERL_OTP_ROOT_DIR)
  execute_process(COMMAND ls ${ERL_OTP_LIB_DIR}
                  COMMAND grep erl_interface
                  COMMAND sort -n
                  COMMAND tail -1
                  COMMAND tr -d \n
                  OUTPUT_VARIABLE ERL_EI_DIR)

  execute_process(COMMAND ls ${ERL_OTP_ROOT_DIR}
                  COMMAND grep erts
                  COMMAND sort -n
                  COMMAND tail -1
                  COMMAND tr -d \n
                  OUTPUT_VARIABLE ERL_ERTS_DIR)

  message(STATUS "Using ${ERL_EI_DIR}")
  message(STATUS "Using ${ERL_ERTS_DIR}")

  add_library(erl_interface INTERFACE)
  target_include_directories(erl_interface INTERFACE ${ERL_OTP_LIB_DIR}/${ERL_EI_DIR}/include)
  target_link_directories(erl_interface INTERFACE ${ERL_OTP_LIB_DIR}/${ERL_EI_DIR}/lib)

  add_library(erl_runtime INTERFACE)
  target_include_directories(erl_runtime INTERFACE ${ERL_OTP_ROOT_DIR}/${ERL_ERTS_DIR}/include)
  target_link_directories(erl_runtime INTERFACE ${ERL_OTP_ROOT_DIR}/${ERL_ERTS_DIR}/lib)
else()
  message(SEND_ERROR "Erlang not found cannot use")
endif()
