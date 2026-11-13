# 上游接入：libgcrypt 用 autotools（需先 autoreconf），编进 <build>/pkg/prefix，
# 探针链接 libgcrypt 静态库；libgpg-error 由系统/pkg-config 提供。

set(PKG_ROOT "${CMAKE_BINARY_DIR}/pkg")
if(NOT DEFINED PKG_PREFIX)
  set(PKG_PREFIX "${PKG_ROOT}/prefix")
  add_custom_target(pkg ALL
  COMMAND "${CMAKE_CURRENT_SOURCE_DIR}/cmake/pkg-build.sh" "${SRC_DIR}" "${PKG_ROOT}"
  COMMENT "构建上游 libgcrypt（${SRC_DIR}）"
  VERBATIM)
  set(HAVE_PKG_TARGET TRUE)
endif()

add_executable(gcrypt_harness test/pkg_gcrypt.c)
if(HAVE_PKG_TARGET)
  add_dependencies(gcrypt_harness pkg)
endif()
target_include_directories(gcrypt_harness PRIVATE "${PKG_PREFIX}/include")
# gcrypt.h 会 include <gpg-error.h>：本机构建用系统库；交叉构建由 -DGPGERR_ROOT 指定 riscv 版
if(DEFINED GPGERR_ROOT)
  target_include_directories(gcrypt_harness PRIVATE "${GPGERR_ROOT}/include")
  target_link_directories(gcrypt_harness PRIVATE "${GPGERR_ROOT}/lib")
else()
  find_package(PkgConfig REQUIRED)
  pkg_check_modules(GPGERR REQUIRED gpg-error)
  target_include_directories(gcrypt_harness PRIVATE ${GPGERR_INCLUDE_DIRS})
  target_link_directories(gcrypt_harness PRIVATE ${GPGERR_LIBRARY_DIRS})
endif()
target_link_directories(gcrypt_harness PRIVATE "${PKG_PREFIX}/lib")
target_link_libraries(gcrypt_harness PRIVATE gcrypt gpg-error m)
target_compile_options(gcrypt_harness PRIVATE ${RVV_FLAGS})

add_test(NAME gcrypt_harness COMMAND gcrypt_harness)
