#include <erl_nif.h>

static ERL_NIF_TERM add(ErlNifEnv *env, __attribute__((unused)) int argc, const ERL_NIF_TERM argv[])
{
  int a;
  int b;
  enif_get_int(env, argv[0], &a);
  enif_get_int(env, argv[1], &b);
  return enif_make_int(env, a + b);
}

static ErlNifFunc nif_funcs[] = {
  { "add", 2, add }
};

ERL_NIF_INIT(<%= native_module %>, nif_funcs, NULL, NULL, NULL, NULL)
